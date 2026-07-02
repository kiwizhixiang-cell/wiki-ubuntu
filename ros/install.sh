#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"

CACHE_ROOTFS_DIR="${CACHE_ROOTFS_DIR:-${TOP_DIR}/output/${CONFIG_NAME:-default}/cache/rootfs}"
CACHE_APT_DIR="${CACHE_APT_DIR:-${TOP_DIR}/dl/packages-${CONFIG_UBUNTU_BASE}-${CONFIG_CPU_ARCH}}"
ROS_CACHE_HASH="${ROS_CACHE_HASH:-$(echo "${CONFIG_NAME}${CONFIG_CPU_ARCH}${CONFIG_CPU}${CONFIG_UBUNTU_BASE}${CONFIG_UBUNTU_DEVLOP}${CONFIG_UBUNTU_ROS}" | md5sum | cut -d' ' -f1)}"
CACHE_FILE="${CACHE_ROOTFS_DIR}/ubuntu-ros-${ROS_CACHE_HASH}.tar.gz"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

if [ -z "${CONFIG_UBUNTU_ROS}" ]; then
    echo "No ROS packages configured, skip."
    exit 0
fi

ROS_PACKAGES=""
for pkg in ${CONFIG_UBUNTU_ROS}; do
    ROS_PACKAGES+=" ${pkg}"
done

if [ -f "${CACHE_FILE}" ]; then
    echo "Found cached ROS package, extracting..."
    sudo rm -rf "${ROOTFS}"
    mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"
    sudo tar zxf "${CACHE_FILE}" -C "${ROOTFS}"
else
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
        apt-get update
        apt-get install -y software-properties-common curl
        add-apt-repository -y universe
        apt-get update
        ROS_APT_SOURCE_VERSION=\$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest | grep -F 'tag_name' | awk -F'\"' '{print \$4}')
        ROS_CODENAME=\$(. /etc/os-release && echo \${UBUNTU_CODENAME:-\${VERSION_CODENAME}})
        curl -L -o /tmp/ros2-apt-source.deb \"https://github.com/ros-infrastructure/ros-apt-source/releases/download/\${ROS_APT_SOURCE_VERSION}/ros2-apt-source_\${ROS_APT_SOURCE_VERSION}.\${ROS_CODENAME}_all.deb\"
        dpkg -i /tmp/ros2-apt-source.deb
        apt-get update
        apt-get install -y ${ROS_PACKAGES}
        if command -v sync >/dev/null 2>&1; then sync; fi
    "

    "${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
    trap - INT TERM EXIT

    echo "Caching deb packages..."
    mkdir -p "${DEB_CACHE_DIR}"
    sudo cp "${ROOTFS}/var/cache/apt/archives/"*.deb "${DEB_CACHE_DIR}/" 2>/dev/null || true

    echo "Caching ROS package..."
    sudo tar zcf "${CACHE_FILE}" -C "${ROOTFS}" .
fi
