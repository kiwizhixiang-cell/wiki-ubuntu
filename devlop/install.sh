#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${TOP_DIR}/.config"
source "${TOP_DIR}/cache-common.sh"

ensure_cache_rootfs_dir
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
    if [ ! -d "${ROOTFS}/var/cache/apt/archives" ]; then
        restore_from_first_available_stage deb desktop app fstab base || true
    fi
    sudo mkdir -p "${ROOTFS}/var/cache/apt/archives"

    # Restore cached deb packages if available
    DEB_CACHE_DIR="${CACHE_APT_DIR}"
    EXTRA_DEVLOP_PACKAGES=""
    if [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS}" = "y" ] && [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS_DHCP}" = "y" ]; then
        EXTRA_DEVLOP_PACKAGES=" dnsmasq"
    fi
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
        apt-get install -f -y ${CONFIG_UBUNTU_DEVLOP}${EXTRA_DEVLOP_PACKAGES}
        if [ '${CONFIG_UBUNTU_DEVLOP_USB_RNDIS}' = 'y' ] && [ '${CONFIG_UBUNTU_DEVLOP_USB_RNDIS_DHCP}' = 'y' ]; then
            # adbd starts dnsmasq after the RNDIS interface exists.
            systemctl unmask dnsmasq.service >/dev/null 2>&1 || true
            systemctl disable dnsmasq.service >/dev/null 2>&1 || true
        fi
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
        USB_CONFIG_LINES=()
        [ "${CONFIG_UBUNTU_DEVLOP_USB_ADB}" = "y" ] && USB_CONFIG_LINES+=("usb_adb_en")
        if [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS}" = "y" ]; then
            USB_CONFIG_LINES+=("usb_rndis_en")
            USB_CONFIG_LINES+=("usb_rndis_ip=${CONFIG_UBUNTU_DEVLOP_USB_RNDIS_IPV4:-172.16.24.1/24}")
            if [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS_DHCP}" = "y" ]; then
                USB_CONFIG_LINES+=("usb_rndis_dhcp_en")
                USB_CONFIG_LINES+=("usb_rndis_dhcp_range=${CONFIG_UBUNTU_DEVLOP_USB_RNDIS_DHCP_RANGE:-172.16.24.100,172.16.24.150,12h}")
            fi
        fi
        printf '%s\n' "${USB_CONFIG_LINES[@]}" | sudo tee "${ROOTFS}/etc/init.d/.usb_config" > /dev/null
    fi

    if [ "${CONFIG_UBUNTU_DEVLOP_MOUSEHOP}" = "y" ] && [ -f "${SCRIPT_DIR}/overlay/usr/bin/mousehop" ]; then
        echo "Installing mousehop..."
        sudo cp -f "${SCRIPT_DIR}/overlay/usr/bin/mousehop" "${ROOTFS}/usr/bin/mousehop"
        sudo chown root:root "${ROOTFS}/usr/bin/mousehop"
        sudo chmod 777 "${ROOTFS}/usr/bin/mousehop"
    fi

    if [ "${CONFIG_UBUNTU_DEVLOP_SERIAL_CONSOLE}" = "y" ]; then
        echo "Configuring serial console..."
        SERIAL_TTY="${CONFIG_UBUNTU_DEVLOP_SERIAL_TTY:-ttyS0}"
        SERIAL_BAUDRATE="${CONFIG_UBUNTU_DEVLOP_SERIAL_BAUDRATE:-115200}"
        sudo mkdir -p "${ROOTFS}/etc/systemd/system/getty.target.wants"
        cat | sudo tee "${ROOTFS}/etc/systemd/system/serial-getty@${SERIAL_TTY}.service" > /dev/null << EOF
[Unit]
Description=Serial Console (%I)
Documentation=man:agetty(8) man:systemd-getty-generator(8)
After=dev-%i.device systemd-user-sessions.service plymouth-quit-wait.service
Before=shutdown.target
Environment="TERM=linux"

[Service]
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud ${SERIAL_BAUDRATE} %I linux
Type=idle
Restart=always
RestartSec=0
UtmpIdentifier=%I
TTYPath=/dev/%I
TTYReset=yes
KillMode=process
IgnoreSIGPIPE=no

[Install]
WantedBy=getty.target
EOF
        sudo ln -sf "${ROOTFS}/etc/systemd/system/serial-getty@${SERIAL_TTY}.service" "${ROOTFS}/etc/systemd/system/getty.target.wants/serial-getty@${SERIAL_TTY}.service"
    fi

    # Cache downloaded deb packages for next build
    echo "Caching deb packages..."
    mkdir -p "${DEB_CACHE_DIR}"
    sudo cp "${ROOTFS}/var/cache/apt/archives/"*.deb "${DEB_CACHE_DIR}/" 2>/dev/null || true

    echo "Caching devlop package..."
    sudo tar zcf "${CACHE_FILE}" -C "${ROOTFS}" .
fi

if [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS}" = "y" ] && [ "${CONFIG_UBUNTU_DEVLOP_USB_RNDIS_DHCP}" = "y" ]; then
    echo "Disabling dnsmasq autostart for RNDIS DHCP..."
    sudo rm -f "${ROOTFS}/etc/dnsmasq.d/rndis-usb.conf"
    sudo rm -f "${ROOTFS}/etc/systemd/system/multi-user.target.wants/dnsmasq.service"
    sudo rm -f "${ROOTFS}/etc/systemd/system/dbus-org.thekelleys.dnsmasq.service"
fi
