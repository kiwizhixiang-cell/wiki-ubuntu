#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"

CACHE_ROOTFS_DIR="${CACHE_ROOTFS_DIR:-${TOP_DIR}/output/${CONFIG_NAME:-default}/cache/rootfs}"
CACHE_APT_DIR="${CACHE_APT_DIR:-${TOP_DIR}/dl/packages-${CONFIG_UBUNTU_BASE}-${CONFIG_CPU_ARCH}}"
CACHE_FILE="${CACHE_ROOTFS_DIR}/ubuntu-devlop-${DEVLOP_CACHE_HASH}.tar.gz"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

if [ -f "${CACHE_FILE}" ]; then
    echo "Found cached devlop package, extracting..."
    sudo rm -rf "${ROOTFS}"
    mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"
    sudo tar zxf "${CACHE_FILE}" -C "${ROOTFS}"
else
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
        apt-get install -f -y ${CONFIG_UBUNTU_DEVLOP}
        sync
    "

    "${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
    trap - INT TERM EXIT

    if [ "${CONFIG_UBUNTU_DEVLOP_AUTOLOGIN}" = "y" ] && [ -f "${SCRIPT_DIR}/overlay/etc/gdm3/custom.conf" ]; then
        echo "Copying GDM auto login config..."
        sudo mkdir -p "${ROOTFS}/etc/gdm3"
        sudo cp -f "${SCRIPT_DIR}/overlay/etc/gdm3/custom.conf" "${ROOTFS}/etc/gdm3/custom.conf"
    fi

    if [ "${CONFIG_UBUNTU_DEVLOP_USB_ADB}" = "y" ] || [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS}" = "y" ]; then
        echo "Generating .usb_config..."
        USB_CONFIG=""
        [ "${CONFIG_UBUNTU_DEVLOP_USB_ADB}" = "y" ] && USB_CONFIG="${USB_CONFIG}usb_adb_en\n"
        [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS}" = "y" ] && USB_CONFIG="${USB_CONFIG}usb_rndis_en\n"
        echo -e "${USB_CONFIG}" | sudo tee "${ROOTFS}/etc/init.d/.usb_config" > /dev/null
    fi

    if [ "${CONFIG_UBUNTU_DEVLOP_MOUSEHOP}" = "y" ] && [ -f "${SCRIPT_DIR}/overlay/usr/bin/mousehop" ]; then
        echo "Installing mousehop..."
        sudo cp -f "${SCRIPT_DIR}/overlay/usr/bin/mousehop" "${ROOTFS}/usr/bin/mousehop"
        sudo chown root:root "${ROOTFS}/usr/bin/mousehop"
        sudo chmod 777 "${ROOTFS}/usr/bin/mousehop"
    fi

    # Cache downloaded deb packages for next build
    echo "Caching deb packages..."
    mkdir -p "${DEB_CACHE_DIR}"
    sudo cp "${ROOTFS}/var/cache/apt/archives/"*.deb "${DEB_CACHE_DIR}/" 2>/dev/null || true

    echo "Caching devlop package..."
    sudo tar zcf "${CACHE_FILE}" -C "${ROOTFS}" .
fi
