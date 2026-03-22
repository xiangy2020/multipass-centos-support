#!/bin/bash
################################################################################
# CentOS 镜像下载脚本
# 下载 CentOS 7, 8, Stream 8, Stream 9 镜像到本地
################################################################################

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CentOS 镜像下载工具                                          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# 镜像存储目录
IMAGE_DIR="${HOME}/multipass-images"
mkdir -p "${IMAGE_DIR}"
cd "${IMAGE_DIR}"

echo -e "${YELLOW}镜像存储目录: ${IMAGE_DIR}${NC}"
echo ""

# CentOS 镜像列表
declare -A CENTOS_IMAGES=(
    ["CentOS-7"]="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2"
    ["CentOS-8"]="https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2"
    ["CentOS-Stream-8"]="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
    ["CentOS-Stream-9"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
)

# 下载函数
download_image() {
    local name=$1
    local url=$2
    local filename=$(basename "${url}")
    
    echo -e "${BLUE}[下载]${NC} ${name}"
    echo "  URL: ${url}"
    echo "  文件: ${filename}"
    
    if [ -f "${filename}" ]; then
        echo -e "${YELLOW}  ✓ 文件已存在,跳过下载${NC}"
        return 0
    fi
    
    echo "  开始下载..."
    if curl -L -# -o "${filename}" "${url}"; then
        local size=$(du -h "${filename}" | cut -f1)
        echo -e "${GREEN}  ✓ 下载成功 (${size})${NC}"
        return 0
    else
        echo -e "${RED}  ✗ 下载失败${NC}"
        rm -f "${filename}"
        return 1
    fi
}

# 主下载流程
echo -e "${BLUE}开始下载 CentOS 镜像...${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for entry in "${CENTOS_IMAGES[@]}"; do
    name=$(echo "$entry" | cut -d'|' -f1)
    url=$(echo "$entry" | cut -d'|' -f2)
    if download_image "${name}" "${url}"; then
        ((SUCCESS_COUNT++))
    else
        ((FAIL_COUNT++))
    fi
    echo ""
done

# 总结
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  下载完成                                                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "成功: ${SUCCESS_COUNT} 个"
echo "失败: ${FAIL_COUNT} 个"
echo ""
echo -e "${YELLOW}已下载的镜像:${NC}"
ls -lh "${IMAGE_DIR}"/*.qcow2 2>/dev/null || echo "  (无)"
echo ""
echo -e "${YELLOW}使用方法:${NC}"
echo "  # CentOS Stream 9 (推荐)"
echo "  multipass launch file://${IMAGE_DIR}/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2 -n centos9-test"
echo ""
echo "  # CentOS 7"
echo "  multipass launch file://${IMAGE_DIR}/CentOS-7-x86_64-GenericCloud.qcow2 -n centos7-test"
echo ""
echo "  # CentOS Stream 8"
echo "  multipass launch file://${IMAGE_DIR}/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2 -n centos8-test"
echo ""
