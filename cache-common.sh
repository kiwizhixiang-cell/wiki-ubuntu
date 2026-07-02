#!/bin/bash

# Shared cache helpers for stage install scripts.

strip_quotes() {
    local v="$1"
    v="${v#\"}"
    v="${v%\"}"
    echo "${v}"
}

ensure_cache_rootfs_dir() {
    if [ -n "${CACHE_ROOTFS_DIR}" ]; then
        return
    fi

    local cfg_name
    cfg_name="$(strip_quotes "${CONFIG_NAME}")"
    if [ -z "${cfg_name}" ]; then
        cfg_name="default"
    fi
    CACHE_ROOTFS_DIR="${TOP_DIR}/output/${cfg_name}/cache/rootfs"
}

stage_hash() {
    case "$1" in
        base) echo "${BASE_CACHE_HASH}" ;;
        fstab) echo "${FSTAB_CACHE_HASH}" ;;
        app) echo "${APP_CACHE_HASH}" ;;
        desktop) echo "${DESKTOP_CACHE_HASH}" ;;
        deb) echo "${DEB_CACHE_HASH}" ;;
        devlop) echo "${DEVLOP_CACHE_HASH}" ;;
        *) echo "" ;;
    esac
}

find_stage_cache() {
    local stage="$1"
    local hash
    hash="$(stage_hash "${stage}")"

    if [ -n "${hash}" ] && [ -f "${CACHE_ROOTFS_DIR}/ubuntu-${stage}-${hash}.tar.gz" ]; then
        echo "${CACHE_ROOTFS_DIR}/ubuntu-${stage}-${hash}.tar.gz"
        return
    fi

    ls -1t "${CACHE_ROOTFS_DIR}"/ubuntu-"${stage}"-*.tar.gz 2>/dev/null | head -n1 || true
}

extract_rootfs_cache() {
    local cache_file="$1"
    if [ -z "${cache_file}" ]; then
        return 1
    fi

    echo "Restoring rootfs cache: $(basename "${cache_file}")"
    sudo rm -rf "${ROOTFS}"
    sudo mkdir -p "${ROOTFS}"
    sudo chown root:root "${ROOTFS}"
    sudo tar zxf "${cache_file}" -C "${ROOTFS}"
    return 0
}

restore_from_first_available_stage() {
    local stage
    local cache_file

    for stage in "$@"; do
        cache_file="$(find_stage_cache "${stage}")"
        if [ -n "${cache_file}" ]; then
            extract_rootfs_cache "${cache_file}"
            return 0
        fi
    done

    return 1
}