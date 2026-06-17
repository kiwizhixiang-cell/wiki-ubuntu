#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"

# Backward-compatible defaults when old .config does not have new options yet.
CLEAN_APT="${CONFIG_UBUNTU_CLEAN_APT:-y}"
CLEAN_DOCS="${CONFIG_UBUNTU_CLEAN_DOCS:-n}"
CLEAN_TMP="${CONFIG_UBUNTU_CLEAN_TMP:-y}"
CLEAN_LOG="${CONFIG_UBUNTU_CLEAN_LOG:-y}"
CLEAN_HISTORY="${CONFIG_UBUNTU_CLEAN_HISTORY:-y}"
CLEAN_LOCALE="${CONFIG_UBUNTU_CLEAN_LOCALE:-n}"
CLEAN_REMOVE_QEMU="${CONFIG_UBUNTU_CLEAN_REMOVE_QEMU:-y}"
CLEAN_PKG_MANAGER="${CONFIG_UBUNTU_CLEAN_PKG_MANAGER:-n}"
CLEAN_PERL="${CONFIG_UBUNTU_CLEAN_PERL:-n}"
CLEAN_CARGO="${CONFIG_UBUNTU_CLEAN_CARGO:-y}"
CLEAN_SHELL_COMPLETIONS="${CONFIG_UBUNTU_CLEAN_SHELL_COMPLETIONS:-n}"
CLEAN_PACKAGING_MISC="${CONFIG_UBUNTU_CLEAN_PACKAGING_MISC:-n}"

if [ -z "${ROOTFS}" ]; then
    echo "Error: ROOTFS is not set"
    exit 1
fi

"${TOP_DIR}/ch-mount.sh" -m "${ROOTFS}"
trap '"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"' INT TERM EXIT

sudo chroot "${ROOTFS}" /usr/bin/env \
    CLEAN_APT="${CLEAN_APT}" \
    CLEAN_DOCS="${CLEAN_DOCS}" \
    CLEAN_TMP="${CLEAN_TMP}" \
    CLEAN_LOG="${CLEAN_LOG}" \
    CLEAN_HISTORY="${CLEAN_HISTORY}" \
    CLEAN_LOCALE="${CLEAN_LOCALE}" \
    CLEAN_PKG_MANAGER="${CLEAN_PKG_MANAGER}" \
    CLEAN_PERL="${CLEAN_PERL}" \
    CLEAN_CARGO="${CLEAN_CARGO}" \
    CLEAN_SHELL_COMPLETIONS="${CLEAN_SHELL_COMPLETIONS}" \
    CLEAN_PACKAGING_MISC="${CLEAN_PACKAGING_MISC}" \
    /bin/bash << 'CHROOT_EOF'
set -e
export LC_ALL=C.UTF-8
export DEBIAN_FRONTEND=noninteractive

if [ "${CLEAN_APT}" = "y" ]; then
    # Clean apt cache and package lists.
    apt-get clean
    apt-get autoclean
    rm -rf /var/lib/apt/lists/*
    rm -f /var/cache/apt/pkgcache.bin
    rm -f /var/cache/apt/srcpkgcache.bin
fi

if [ "${CLEAN_DOCS}" = "y" ]; then
    rm -rf /usr/share/doc/*
    rm -rf /usr/share/man/*
    rm -rf /usr/share/info/*
fi

if [ "${CLEAN_TMP}" = "y" ]; then
    rm -rf /tmp/*
    rm -rf /var/tmp/*
fi

if [ "${CLEAN_LOG}" = "y" ]; then
    rm -rf /var/log/*.log
    rm -rf /var/log/apt/*
fi

if [ "${CLEAN_HISTORY}" = "y" ]; then
    rm -f /root/.bash_history
    rm -f /home/*/.bash_history
fi

if [ "${CLEAN_LOCALE}" = "y" ]; then
    find /usr/share/locale -mindepth 1 -maxdepth 1 -type d \
        ! -name 'C' \
        ! -name 'C.UTF-8' \
        ! -name 'en' \
        ! -name 'en_*' \
        -exec rm -rf {} +
fi

if [ "${CLEAN_PKG_MANAGER}" = "y" ]; then
    # Remove apt/dpkg binaries
    rm -f /usr/bin/apt /usr/bin/apt-cache /usr/bin/apt-cdrom \
          /usr/bin/apt-config /usr/bin/apt-get /usr/bin/apt-mark
    rm -f /usr/bin/dpkg /usr/bin/dpkg-deb /usr/bin/dpkg-divert \
          /usr/bin/dpkg-maintscript-helper /usr/bin/dpkg-query \
          /usr/bin/dpkg-realpath /usr/bin/dpkg-split \
          /usr/bin/dpkg-statoverride /usr/bin/dpkg-trigger
    rm -f /usr/sbin/dpkg-preconfigure /usr/sbin/dpkg-reconfigure
    rm -f /usr/bin/gpgv
    # Remove apt/dpkg libraries and databases
    rm -rf /usr/lib/apt /usr/lib/dpkg
    rm -rf /var/lib/apt /var/lib/dpkg
    rm -rf /var/cache/apt /var/cache/debconf
fi

if [ "${CLEAN_PERL}" = "y" ]; then
    rm -f /usr/bin/perl /usr/bin/perl5* /usr/bin/perlbug /usr/bin/perldoc
    rm -rf /usr/lib/*/perl-base /usr/lib/*/perl5 /usr/lib/perl5
    rm -rf /usr/share/perl5 /usr/share/perl
fi

if [ "${CLEAN_CARGO}" = "y" ]; then
    rm -rf /usr/lib/cargo
fi

if [ "${CLEAN_SHELL_COMPLETIONS}" = "y" ]; then
    rm -rf /usr/share/bash-completion
    rm -rf /usr/share/zsh
    rm -rf /usr/share/fish
fi

if [ "${CLEAN_PACKAGING_MISC}" = "y" ]; then
    rm -rf /usr/share/lintian
    rm -rf /usr/share/bug
    rm -rf /usr/share/common-licenses
fi

if command -v sync >/dev/null 2>&1; then
    sync
fi
CHROOT_EOF

"${TOP_DIR}/ch-mount.sh" -u "${ROOTFS}"
trap - INT TERM EXIT

if [ "${CLEAN_REMOVE_QEMU}" = "y" ]; then
    sudo rm -f "${ROOTFS}/usr/bin/qemu-aarch64-static"
fi

echo "Rootfs cleaned."
