#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"

strip_quotes() {
    local v="$1"
    v="${v#\"}"
    v="${v%\"}"
    echo "${v}"
}

USER_NAME="$(strip_quotes "${CONFIG_NAME}")"
USER_PASSWORD="$(strip_quotes "${CONFIG_PASSWORD}")"
ROOT_PASSWORD="$(strip_quotes "${CONFIG_ROOT_PASSWORD}")"

if [ -z "${USER_NAME}" ]; then
    USER_NAME="cocolamp"
fi

CACHE_ROOTFS_DIR="${CACHE_ROOTFS_DIR:-${TOP_DIR}/output/${CONFIG_NAME:-default}/cache/rootfs}"
CACHE_APT_DIR="${CACHE_APT_DIR:-${TOP_DIR}/dl/packages-${CONFIG_UBUNTU_BASE}-${CONFIG_CPU_ARCH}}"
CACHE_FILE="${CACHE_ROOTFS_DIR}/ubuntu-base-${BASE_CACHE_HASH}.tar.gz"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

if [ -f "${CACHE_FILE}" ]; then
    echo "Found cached base package, extracting..."
    sudo rm -rf "${ROOTFS}"
    mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"
    sudo tar zxf "${CACHE_FILE}" -C "${ROOTFS}"
else
    sudo rm -rf "${ROOTFS}"
    mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"

    BASE_URL="http://cdimage.ubuntu.com/ubuntu-base/releases/${CONFIG_UBUNTU_BASE}/release"
    BASE_TARBALL="ubuntu-base-${CONFIG_UBUNTU_BASE}-base-${CONFIG_CPU_ARCH}.tar.gz"

    if [ ! -f "${TOP_DIR}/dl/${BASE_TARBALL}" ]; then
        echo "Downloading Ubuntu base ${CONFIG_UBUNTU_BASE} (${CONFIG_CPU_ARCH})..."
        mkdir -p "${TOP_DIR}/dl"
        wget -O "${TOP_DIR}/dl/${BASE_TARBALL}" "${BASE_URL}/${BASE_TARBALL}"
    fi

    echo "Extracting Ubuntu base to ${ROOTFS}..."
    sudo tar zxf "${TOP_DIR}/dl/${BASE_TARBALL}" -C "${ROOTFS}"

    sudo cp -b /usr/bin/qemu-aarch64-static "${ROOTFS}/usr/bin/"
    sudo cp /etc/resolv.conf "${ROOTFS}/etc/resolv.conf"

    # Restore cached deb packages if available
    DEB_CACHE_DIR="${CACHE_APT_DIR}"
    mkdir -p "${DEB_CACHE_DIR}"
    if ls "${DEB_CACHE_DIR}"/*.deb &>/dev/null; then
        echo "Restoring cached deb packages..."
        sudo cp "${DEB_CACHE_DIR}"/*.deb "${ROOTFS}/var/cache/apt/archives/"
    fi

    "${TOP_DIR}/ch-mount.sh" -m "${ROOTFS}"
    trap '"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"' INT TERM EXIT

    sudo chroot "${ROOTFS}" /usr/bin/env USER_NAME="${USER_NAME}" USER_PASSWORD="${USER_PASSWORD}" ROOT_PASSWORD="${ROOT_PASSWORD}" /bin/bash << 'CHROOT_EOF'
set -e
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

if [ -n "${ROOT_PASSWORD}" ]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd
fi

# allow root login
sed -i '/pam_securetty.so/s/^/# /g' /etc/pam.d/login

groupadd -f messagebus
groupadd -f kvm
groupadd -f systemd-journal
groupadd -f systemd-network
useradd -r -g systemd-network -s /usr/sbin/nologin systemd-network 2>/dev/null || true

dpkg --configure -a
apt-get -y update
apt-get -f -y upgrade

echo "${USER_NAME}" > /etc/hostname

# Create User
useradd -G sudo -m -s /bin/bash "${USER_NAME}" 2>/dev/null || true
if [ -n "${USER_PASSWORD}" ]; then
    echo "${USER_NAME}:${USER_PASSWORD}" | chpasswd
fi
gpasswd -a "${USER_NAME}" video
gpasswd -a "${USER_NAME}" audio
groupadd -f render
gpasswd -a "${USER_NAME}" render
gpasswd -a "${USER_NAME}" dialout

ln -sf /usr/lib/aarch64-linux-gnu/ /usr/lib64

if [ -d "/home/${USER_NAME}" ]; then
    chown -R "${USER_NAME}:${USER_NAME}" "/home/${USER_NAME}"
fi
sync
CHROOT_EOF

    "${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
    trap - INT TERM EXIT

    # Cache downloaded deb packages for next build
    echo "Caching deb packages..."
    mkdir -p "${DEB_CACHE_DIR}"
    sudo cp "${ROOTFS}/var/cache/apt/archives/"*.deb "${DEB_CACHE_DIR}/" 2>/dev/null || true

    echo "Caching base package..."
    sudo tar zcf "${CACHE_FILE}" -C "${ROOTFS}" .
fi
