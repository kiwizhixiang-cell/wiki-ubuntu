#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"

OUTPUT_DIR="${TOP_DIR}/output"
ROOTFS_IMG="${OUTPUT_DIR}/rootfs-${CONFIG_UBUNTU_BASE}.img"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

echo "Creating rootfs image (bs=${CONFIG_UBUNTU_PACKGE_BS} count=${CONFIG_UBUNTU_PACKGE_COUNT})..."
dd if=/dev/zero of="${ROOTFS_IMG}" bs="${CONFIG_UBUNTU_PACKGE_BS}" count="${CONFIG_UBUNTU_PACKGE_COUNT}" status=progress

echo "Formatting rootfs image..."
sudo mkfs.ext4 -L rootfs -d "${ROOTFS}" "${ROOTFS_IMG}"

echo "Rootfs image created at ${ROOTFS_IMG}"
