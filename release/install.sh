#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"
source "${TOP_DIR}/cache-common.sh"

RELEASE_APT="${CONFIG_UBUNTU_RELEASE_APT:-y}"
RELEASE_RM_VIM="${CONFIG_UBUNTU_RELEASE_RM_VIM:-n}"
RELEASE_RM_APT="${CONFIG_UBUNTU_RELEASE_RM_APT:-n}"
RELEASE_RM_PASSWD="${CONFIG_UBUNTU_RELEASE_RM_PASSWD:-n}"
RELEASE_RM_PERL="${CONFIG_UBUNTU_RELEASE_RM_PERL:-n}"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

ensure_cache_rootfs_dir

if [ ! -x "${ROOTFS}/bin/bash" ] || [ ! -d "${ROOTFS}/etc" ]; then
    echo "Rootfs is missing or incomplete, restoring from latest cache..."
    restore_from_first_available_stage devlop deb desktop app fstab base || true
fi

if [ ! -x "${ROOTFS}/bin/bash" ]; then
    echo "Error: unable to prepare rootfs (/bin/bash is missing)."
    echo "Please run the build stages once without cache skip, or check cache files under ${CACHE_ROOTFS_DIR}."
    exit 1
fi

"${TOP_DIR}/ch-mount.sh" -m "${ROOTFS}"
trap '"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"' INT TERM EXIT

sudo chroot "${ROOTFS}" /bin/bash << CHROOT_EOF
set -e
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

if [ "${RELEASE_APT}" = "y" ]; then
    apt-get clean
    apt-get autoclean
    rm -rf /var/lib/apt/lists/*
    rm -f /var/cache/apt/pkgcache.bin
    rm -f /var/cache/apt/srcpkgcache.bin
    rm -rf /usr/share/doc/*
    rm -rf /usr/share/man/*
    rm -rf /usr/share/info/*
    rm -rf /usr/share/lintian/*
    rm -rf /usr/share/doc-base/*
    rm -rf /usr/share/gtk-doc/*
    rm -f /usr/bin/qemu-aarch64-static
fi

if [ "${RELEASE_RM_VIM}" = "y" ]; then
    apt-get purge -y --auto-remove vim vim-runtime vim-common 2>/dev/null || true
fi

if [ "${RELEASE_RM_PASSWD}" = "y" ]; then
    apt-get purge -y --auto-remove passwd 2>/dev/null || true
fi

if [ "${RELEASE_RM_PERL}" = "y" ]; then
    dpkg --force-remove-essential --purge perl-base 2>/dev/null || true
fi

if [ "${RELEASE_RM_APT}" = "y" ]; then
    apt-get purge -y --auto-remove apt 2>/dev/null || true
fi
CHROOT_EOF

"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
trap - INT TERM EXIT

echo "Rootfs released."
