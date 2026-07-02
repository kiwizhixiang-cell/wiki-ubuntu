#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"
source "${TOP_DIR}/cache-common.sh"

DEB_DIR="${SCRIPT_DIR}/${CONFIG_CPU_ARCH}"
ensure_cache_rootfs_dir
CACHE_HASH="${DEB_CACHE_HASH:-$(echo "${CONFIG_NAME}${CONFIG_CPU_ARCH}${CONFIG_CPU}${CONFIG_UBUNTU_BASE}${CONFIG_UBUNTU_DEB_ADB}${CONFIG_UBUNTU_DEB_MALI}${CONFIG_UBUNTU_DEB_MPP}${CONFIG_UBUNTU_DEB_MPP_DEV}${CONFIG_UBUNTU_DEB_RGA}${CONFIG_UBUNTU_DEB_RGA_DEV}${CONFIG_UBUNTU_DEB_RKNPU2}${CONFIG_UBUNTU_DEB_RKNPU2_DEV}${CONFIG_UBUNTU_DEB_ROCKIT}${CONFIG_UBUNTU_DEB_ROCKIT_DEV}${CONFIG_UBUNTU_DEB_ROCKIT_TEST}${CONFIG_UBUNTU_DEB_CAMERA}${CONFIG_UBUNTU_DEB_IVA}${CONFIG_UBUNTU_DEB_IVA_DEV}${CONFIG_UBUNTU_DEB_COMMON_ALGO}${CONFIG_UBUNTU_DEB_COMMON_ALGO_DEV}${CONFIG_UBUNTU_DEB_GSTREAMER}${CONFIG_UBUNTU_DEB_RECOVERY}${CONFIG_UBUNTU_DEB_WIFI_AIC8800}${CONFIG_UBUNTU_DEB_WIFI_AP6256}${CONFIG_UBUNTU_DEB_WIFI_RTL8822CE}" | md5sum | cut -d' ' -f1)}"
CACHE_FILE="${CACHE_ROOTFS_DIR}/ubuntu-deb-${CACHE_HASH}.tar.gz"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

if [ -f "${CACHE_FILE}" ]; then
    echo "Found cached deb package, extracting..."
    sudo rm -rf "${ROOTFS}"
    sudo mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"
    sudo tar zxf "${CACHE_FILE}" -C "${ROOTFS}"
    exit 0
fi

if [ ! -d "${ROOTFS}/usr" ] || [ ! -d "${ROOTFS}/etc" ]; then
    restore_from_first_available_stage desktop app fstab base || true
fi

# Remove old deb cache files
rm -f "${TOP_DIR}"/dl/ubuntu-deb-*.tar.gz

install_deb() {
    local deb_file="$1"
    if [ -f "${deb_file}" ]; then
        echo "Installing $(basename "${deb_file}")..."
        sudo cp "${deb_file}" "${ROOTFS}/tmp/"
        sudo chroot "${ROOTFS}" /bin/bash -c "
            export DEBIAN_FRONTEND=noninteractive
            dpkg -i --force-depends --force-overwrite /tmp/$(basename "${deb_file}")
        " || true
        sudo rm -f "${ROOTFS}/tmp/$(basename "${deb_file}")"
    fi
}

"${TOP_DIR}/ch-mount.sh" -m "${ROOTFS}"
trap '"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"' INT TERM EXIT

if [ "${CONFIG_UBUNTU_DEB_ADB}" = "y" ]; then
    install_deb "${DEB_DIR}/adb_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_MALI}" = "y" ]; then
    install_deb "${DEB_DIR}/libmali-bifrost-g52-g13p0-x11-wayland-gbm_1.9-1_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_MPP}" = "y" ]; then
    install_deb "${DEB_DIR}/rockchip-mpp-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
    if [ "${CONFIG_UBUNTU_DEB_MPP_DEV}" = "y" ]; then
        install_deb "${DEB_DIR}/rockchip-mpp-${CONFIG_CPU}-dev_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
fi

if [ "${CONFIG_UBUNTU_DEB_RGA}" = "y" ]; then
    install_deb "${DEB_DIR}/rockchip-rga-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
    if [ "${CONFIG_UBUNTU_DEB_RGA_DEV}" = "y" ]; then
        install_deb "${DEB_DIR}/rockchip-rga-${CONFIG_CPU}-dev_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
fi

if [ "${CONFIG_UBUNTU_DEB_RKNPU2}" = "y" ]; then
    install_deb "${DEB_DIR}/rknpu2-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
    if [ "${CONFIG_UBUNTU_DEB_RKNPU2_DEV}" = "y" ]; then
        install_deb "${DEB_DIR}/rknpu2-${CONFIG_CPU}-dev_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
fi

if [ "${CONFIG_UBUNTU_DEB_ROCKIT}" = "y" ]; then
    install_deb "${DEB_DIR}/rockit-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
    if [ "${CONFIG_UBUNTU_DEB_ROCKIT_DEV}" = "y" ]; then
        install_deb "${DEB_DIR}/rockit-${CONFIG_CPU}-dev_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
    if [ "${CONFIG_UBUNTU_DEB_ROCKIT_TEST}" = "y" ]; then
        install_deb "${DEB_DIR}/rockit-${CONFIG_CPU}-test_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
fi

if [ "${CONFIG_UBUNTU_DEB_CAMERA}" = "y" ]; then
    install_deb "${DEB_DIR}/camera-engine-rkaiq-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_IVA}" = "y" ]; then
    install_deb "${DEB_DIR}/iva-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
    if [ "${CONFIG_UBUNTU_DEB_IVA_DEV}" = "y" ]; then
        install_deb "${DEB_DIR}/iva-${CONFIG_CPU}-dev_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
fi

if [ "${CONFIG_UBUNTU_DEB_COMMON_ALGO}" = "y" ]; then
    install_deb "${DEB_DIR}/common-algorithm-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
    if [ "${CONFIG_UBUNTU_DEB_COMMON_ALGO_DEV}" = "y" ]; then
        install_deb "${DEB_DIR}/common-algorithm-${CONFIG_CPU}-dev_1.0.0_${CONFIG_CPU_ARCH}.deb"
    fi
fi

if [ "${CONFIG_UBUNTU_DEB_GSTREAMER}" = "y" ]; then
    install_deb "${DEB_DIR}/gstreamer1-rockchip-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_RECOVERY}" = "y" ]; then
    install_deb "${DEB_DIR}/recovery_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_WIFI_AIC8800}" = "y" ]; then
    install_deb "${DEB_DIR}/wifibt-aic8800-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_WIFI_AP6256}" = "y" ]; then
    install_deb "${DEB_DIR}/wifibt-ap6256-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

if [ "${CONFIG_UBUNTU_DEB_WIFI_RTL8822CE}" = "y" ]; then
    install_deb "${DEB_DIR}/wifibt-rtl8822ce-${CONFIG_CPU}_1.0.0_${CONFIG_CPU_ARCH}.deb"
fi

echo "Fixing dependencies..."
sudo chroot "${ROOTFS}" /bin/bash -c "
    export DEBIAN_FRONTEND=noninteractive
    dpkg --configure -a || true
    apt-get install -f -y
"

"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
trap - INT TERM EXIT

echo "Caching deb package..."
sudo tar zcf "${CACHE_FILE}" -C "${ROOTFS}" .

echo "Deb packages installed."
