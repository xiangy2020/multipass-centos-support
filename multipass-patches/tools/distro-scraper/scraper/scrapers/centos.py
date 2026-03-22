import re
import aiohttp
import asyncio
from urllib.parse import urljoin
from bs4 import BeautifulSoup
from dateutil import parser
from ..base import BaseScraper, DEFAULT_TIMEOUT
from ..models import SUPPORTED_ARCHITECTURES


# CentOS Stream Cloud Images base URL
CENTOS_CLOUD_URL = "https://cloud.centos.org/centos/"

ARCH_MAP = {
    "arm64": "aarch64",
    "power64le": "ppc64le",
}

# Supported CentOS Stream versions
STREAM_VERSIONS = ["9-stream", "10-stream"]


class CentOSScraper(BaseScraper):
    def __init__(self):
        super().__init__()

    @property
    def name(self) -> str:
        return "CentOS"

    async def _fetch_dir_listing(
        self, session: aiohttp.ClientSession, url: str
    ) -> list[str]:
        """
        Fetch an Apache-style HTML directory listing and return the linked filenames.
        """
        text = await self._fetch_text(session, url)
        soup = BeautifulSoup(text, 'html.parser')
        
        # Find all links in directory listing
        links = soup.find_all('a')
        entries = []
        for link in links:
            href = link.get('href', '')
            if href and href not in ['../', './']:
                entries.append(href)
        
        return entries

    async def _fetch_latest_version_dir(
        self, session: aiohttp.ClientSession, stream_version: str
    ) -> str:
        """
        Fetch the latest version directory for a given stream version.
        Example: 9-stream/x86_64/images/ will have dated directories like 20260301/
        """
        # For CentOS Stream 9, the URL structure is:
        # https://cloud.centos.org/centos/9-stream/x86_64/images/
        base_url = urljoin(CENTOS_CLOUD_URL, f"{stream_version}/x86_64/images/")
        
        self.logger.info("Fetching version directories from %s", base_url)
        entries = await self._fetch_dir_listing(session, base_url)
        
        # Filter for date-like directories (YYYYMMDD format)
        date_dirs = [
            e.rstrip("/") for e in entries 
            if re.match(r"\d{8}/?$", e)
        ]
        
        if not date_dirs:
            raise RuntimeError(
                f"No dated version directories found in {base_url}"
            )
        
        latest = max(date_dirs)
        self.logger.info("Latest version directory: %s", latest)
        return latest

    async def _fetch_checksum_file(
        self, session: aiohttp.ClientSession, url: str
    ) -> dict[str, str]:
        """
        Fetch a CentOS CHECKSUM file and return a mapping of filename -> sha256.
        """
        text = await self._fetch_text(session, url)
        checksums = {}
        
        # CentOS uses format: SHA256 (filename) = hash
        for match in re.finditer(
            r"SHA256\s*\(([^)]+)\)\s*=\s*([0-9a-f]+)", text, re.IGNORECASE
        ):
            checksums[match.group(1)] = match.group(2)
        
        # Also support simple format: hash  filename
        for line in text.split('\n'):
            match = re.match(r'^([0-9a-f]{64})\s+(.+)$', line.strip())
            if match:
                checksums[match.group(2)] = match.group(1)
        
        return checksums

    async def _fetch_image_for_arch(
        self, 
        session: aiohttp.ClientSession, 
        stream_version: str,
        version_date: str,
        label: str
    ) -> tuple[str, dict]:
        """
        Locate, verify, and return image metadata for a single architecture.
        """
        centos_arch = ARCH_MAP.get(label, label)
        
        # CentOS Stream image URL structure:
        # https://cloud.centos.org/centos/9-stream/x86_64/images/20260301/
        images_url = urljoin(
            CENTOS_CLOUD_URL, 
            f"{stream_version}/{centos_arch}/images/{version_date}/"
        )
        
        self.logger.info(
            "Fetching image listing for %s from %s", 
            centos_arch, 
            images_url
        )
        
        try:
            files = await self._fetch_dir_listing(session, images_url)
        except Exception as e:
            self.logger.warning(
                "Architecture %s not available for CentOS %s: %s",
                centos_arch,
                stream_version,
                e
            )
            raise
        
        # Look for GenericCloud qcow2 images
        qcow2_pattern = rf"CentOS-Stream-GenericCloud-.*\.{centos_arch}\.qcow2$"
        qcow2_files = [f for f in files if re.match(qcow2_pattern, f)]
        
        if not qcow2_files:
            raise RuntimeError(
                f"No GenericCloud qcow2 found for arch={centos_arch} "
                f"version={stream_version}/{version_date}"
            )
        
        qcow2_filename = qcow2_files[0]
        qcow2_url = images_url + qcow2_filename
        
        # Find checksum file (usually CentOS-Stream-GenericCloud-*-CHECKSUM)
        checksum_files = [f for f in files if "CHECKSUM" in f.upper()]
        
        sha256 = None
        if checksum_files:
            try:
                checksums = await self._fetch_checksum_file(
                    session, 
                    images_url + checksum_files[0]
                )
                sha256 = checksums.get(qcow2_filename)
            except Exception as e:
                self.logger.warning("Failed to fetch checksum: %s", e)
        
        if not sha256:
            self.logger.warning(
                "SHA256 not found for %s, using empty hash", 
                qcow2_filename
            )
            sha256 = ""
        
        # Get file size via HEAD request
        self.logger.info("Sending HEAD request to %s", qcow2_url)
        async with session.head(
            qcow2_url,
            timeout=aiohttp.ClientTimeout(total=DEFAULT_TIMEOUT),
            allow_redirects=True,
        ) as resp:
            resp.raise_for_status()
            size = int(resp.headers.get("Content-Length", 0))
        
        return label, {
            "image_location": qcow2_url,
            "id": sha256,
            "version": version_date,
            "size": size,
        }

    async def fetch(self) -> dict:
        """
        Fetch CentOS Stream GenericCloud images for all supported architectures.
        """
        async with aiohttp.ClientSession() as session:
            # Use CentOS Stream 9 as default (most stable)
            stream_version = "9-stream"
            version_date = await self._fetch_latest_version_dir(
                session, 
                stream_version
            )
            
            # Fetch images for all architectures
            results = await asyncio.gather(
                *[
                    self._fetch_image_for_arch(
                        session, 
                        stream_version, 
                        version_date, 
                        label
                    )
                    for label in SUPPORTED_ARCHITECTURES
                ],
                return_exceptions=True,
            )
            
            items: dict[str, dict] = {}
            for label, result in zip(SUPPORTED_ARCHITECTURES, results):
                if isinstance(result, Exception):
                    self.logger.error("Failed to fetch arch %s: %s", label, result)
                else:
                    _, data = result
                    items[label] = data
            
            if not items:
                raise RuntimeError(
                    "Failed to fetch images for all architectures"
                )
            
            # Extract version number (9 from 9-stream)
            version_number = stream_version.split('-')[0]
            
            return {
                "aliases": "centos, centos-stream",
                "os": "CentOS",
                "release": stream_version,
                "release_codename": f"Stream {version_number}",
                "release_title": version_number,
                "items": items,
            }
