#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"
source "${TOP_DIR}/cache-common.sh"

ensure_cache_rootfs_dir
CACHE_APT_DIR="${CACHE_APT_DIR:-${TOP_DIR}/dl/packages-${CONFIG_UBUNTU_BASE}-${CONFIG_CPU_ARCH}}"
CACHE_FILE="${CACHE_ROOTFS_DIR}/ubuntu-app-${APP_CACHE_HASH}.tar.gz"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

if [ -f "${CACHE_FILE}" ]; then
    echo "Found cached app package, extracting..."
    sudo rm -rf "${ROOTFS}"
    mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"
    sudo tar zxf "${CACHE_FILE}" -C "${ROOTFS}"
else
    if [ ! -d "${ROOTFS}/var/cache/apt/archives" ]; then
        restore_from_first_available_stage fstab base || true
    fi
    sudo mkdir -p "${ROOTFS}/var/cache/apt/archives"

    # Restore cached deb packages if available
    DEB_CACHE_DIR="${CACHE_APT_DIR}"
    mkdir -p "${DEB_CACHE_DIR}"
    if ls "${DEB_CACHE_DIR}"/*.deb &>/dev/null; then
        echo "Restoring cached deb packages..."
        sudo cp "${DEB_CACHE_DIR}"/*.deb "${ROOTFS}/var/cache/apt/archives/"
    fi

    "${TOP_DIR}/ch-mount.sh" -m "${ROOTFS}"
    trap '"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"' INT TERM EXIT

    sudo chroot "${ROOTFS}" /bin/bash -c "
        export LC_ALL=C.UTF-8
        export DEBIAN_FRONTEND=noninteractive
        dpkg --configure -a
        apt-get install -f -y ${CONFIG_UBUNTU_APP}
        sync
    "

    "${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
    trap - INT TERM EXIT

    # Copy overlay files
    if [ -d "${SCRIPT_DIR}/overlay" ]; then
        echo "Copying overlay files..."
        sudo cp -rf "${SCRIPT_DIR}/overlay/"* "${ROOTFS}/"
    fi

    # Cache downloaded deb packages for next build
    echo "Caching deb packages..."
    mkdir -p "${DEB_CACHE_DIR}"
    sudo cp "${ROOTFS}/var/cache/apt/archives/"*.deb "${DEB_CACHE_DIR}/" 2>/dev/null || true

    echo "Caching app package..."
    sudo tar zcf "${CACHE_FILE}" -C "${ROOTFS}" .
fi
