SHELL := /bin/bash
-include .config
export

TOP_DIR  := $(CURDIR)
ROOTFS   ?= $(TOP_DIR)/output/rootfs
DL_DIR   := $(TOP_DIR)/dl

# Strip quotes from string config values
Q = $(subst ",,$1)
CONFIG_NAME_STRIPPED := $(call Q,$(CONFIG_NAME))
CACHE_ROOTFS_DIR ?= $(TOP_DIR)/output/$(if $(CONFIG_NAME_STRIPPED),$(CONFIG_NAME_STRIPPED),default)/cache/rootfs
_UBUNTU_FSTAB   := $(call Q,$(CONFIG_UBUNTU_FSTAB))
_UBUNTU_APP     := $(call Q,$(CONFIG_UBUNTU_APP))
_UBUNTU_DESKTOP := $(call Q,$(CONFIG_UBUNTU_DESKTOP))
_UBUNTU_DEVLOP  := $(call Q,$(CONFIG_UBUNTU_DEVLOP))

export TOP_DIR ROOTFS DL_DIR

# Cache detection - find the latest available cache to skip earlier stages
BASE_CACHE_HASH   := $(shell echo "$(CONFIG_UBUNTU_BASE)$(CONFIG_CPU_ARCH)$(CONFIG_CPU)$(CONFIG_NAME)$(CONFIG_PASSWORD)$(CONFIG_ROOT_PASSWORD)" | md5sum | cut -d' ' -f1)
FSTAB_CACHE_HASH  := $(shell echo "$(_UBUNTU_FSTAB)" | md5sum | cut -d' ' -f1)
APP_CACHE_HASH    := $(shell echo "$(_UBUNTU_APP)" | md5sum | cut -d' ' -f1)
DESKTOP_CACHE_HASH := $(shell echo "$(_UBUNTU_DESKTOP)" | md5sum | cut -d' ' -f1)
DEVLOP_CACHE_HASH := $(shell echo "$(_UBUNTU_DEVLOP)" | md5sum | cut -d' ' -f1)
DEB_CACHE_HASH   := $(shell echo "$(CONFIG_UBUNTU_DEB_ADB)$(CONFIG_UBUNTU_DEB_MALI)$(CONFIG_UBUNTU_DEB_MPP)$(CONFIG_UBUNTU_DEB_MPP_DEV)$(CONFIG_UBUNTU_DEB_RGA)$(CONFIG_UBUNTU_DEB_RGA_DEV)$(CONFIG_UBUNTU_DEB_RKNPU2)$(CONFIG_UBUNTU_DEB_RKNPU2_DEV)$(CONFIG_UBUNTU_DEB_ROCKIT)$(CONFIG_UBUNTU_DEB_ROCKIT_DEV)$(CONFIG_UBUNTU_DEB_ROCKIT_TEST)$(CONFIG_UBUNTU_DEB_CAMERA)$(CONFIG_UBUNTU_DEB_IVA)$(CONFIG_UBUNTU_DEB_IVA_DEV)$(CONFIG_UBUNTU_DEB_COMMON_ALGO)$(CONFIG_UBUNTU_DEB_COMMON_ALGO_DEV)$(CONFIG_UBUNTU_DEB_GSTREAMER)$(CONFIG_UBUNTU_DEB_RECOVERY)$(CONFIG_UBUNTU_DEB_WIFI_AIC8800)$(CONFIG_UBUNTU_DEB_WIFI_AP6256)$(CONFIG_UBUNTU_DEB_WIFI_RTL8822CE)" | md5sum | cut -d' ' -f1)

export BASE_CACHE_HASH FSTAB_CACHE_HASH APP_CACHE_HASH DESKTOP_CACHE_HASH DEB_CACHE_HASH DEVLOP_CACHE_HASH

HAS_DEB_CACHE     := $(shell (test -f $(CACHE_ROOTFS_DIR)/ubuntu-deb-$(DEB_CACHE_HASH).tar.gz || ls $(CACHE_ROOTFS_DIR)/ubuntu-deb-*.tar.gz >/dev/null 2>&1) && echo y)
HAS_DEVLOP_CACHE  := $(shell (test -f $(CACHE_ROOTFS_DIR)/ubuntu-devlop-$(DEVLOP_CACHE_HASH).tar.gz || ls $(CACHE_ROOTFS_DIR)/ubuntu-devlop-*.tar.gz >/dev/null 2>&1) && echo y)
HAS_DESKTOP_CACHE := $(shell (test -f $(CACHE_ROOTFS_DIR)/ubuntu-desktop-$(DESKTOP_CACHE_HASH).tar.gz || ls $(CACHE_ROOTFS_DIR)/ubuntu-desktop-*.tar.gz >/dev/null 2>&1) && echo y)
HAS_APP_CACHE     := $(shell (test -f $(CACHE_ROOTFS_DIR)/ubuntu-app-$(APP_CACHE_HASH).tar.gz || ls $(CACHE_ROOTFS_DIR)/ubuntu-app-*.tar.gz >/dev/null 2>&1) && echo y)
HAS_FSTAB_CACHE   := $(shell (test -f $(CACHE_ROOTFS_DIR)/ubuntu-fstab-$(FSTAB_CACHE_HASH).tar.gz || ls $(CACHE_ROOTFS_DIR)/ubuntu-fstab-*.tar.gz >/dev/null 2>&1) && echo y)
HAS_BASE_CACHE    := $(shell ls $(CACHE_ROOTFS_DIR)/ubuntu-base-*.tar.gz >/dev/null 2>&1 && echo y)

SKIP_base    := $(HAS_BASE_CACHE)
SKIP_fstab   := $(HAS_FSTAB_CACHE)
SKIP_app     := $(HAS_APP_CACHE)
SKIP_desktop := $(HAS_DESKTOP_CACHE)
SKIP_deb     := $(HAS_DEB_CACHE)
SKIP_devlop  := $(HAS_DEVLOP_CACHE)

export SKIP_base SKIP_fstab SKIP_app SKIP_desktop SKIP_devlop SKIP_deb

MODULES := base fstab app desktop deb devlop release packge

.PHONY: all $(MODULES) clean distclean help menuconfig savedefconfig

all: $(MODULES)

menuconfig:
	@kconfig-mconf Kconfig
	@if [ -f .config ]; then \
		echo "Configuration saved to .config"; \
	fi

savedefconfig:
	@kconfig-mconf --silentoldconfig Kconfig 2>/dev/null || true
	@grep -v '^#' .config | grep -v '^$$' > defconfig
	@echo "Minimal config saved to defconfig"

base:
	@mkdir -p $(ROOTFS) $(DL_DIR)
	@if [ "$(SKIP_base)" = "y" ]; then \
		echo "==> Skipping base (cache found)"; \
	else \
		$(MAKE) -C base -f Makefile install; \
	fi

fstab: base
	@if [ "$(SKIP_fstab)" = "y" ]; then \
		echo "==> Skipping fstab (cache found)"; \
	else \
		$(MAKE) -C fstab -f MakeFile install; \
	fi

app: fstab
	@if [ "$(SKIP_app)" = "y" ]; then \
		echo "==> Skipping app (cache found)"; \
	elif [ -n "$(_UBUNTU_APP)" ]; then \
		$(MAKE) -C app -f Makefile install; \
	fi

desktop: app
	@if [ "$(SKIP_desktop)" = "y" ]; then \
		echo "==> Skipping desktop (cache found)"; \
	elif [ -n "$(_UBUNTU_DESKTOP)" ]; then \
		$(MAKE) -C desktop -f Makefile install; \
	fi

deb: desktop
	@if [ "$(SKIP_deb)" = "y" ]; then \
		echo "==> Skipping deb (cache found)"; \
	elif [ "$(CONFIG_UBUNTU_DEB)" = "y" ]; then \
		$(MAKE) -C deb -f Makefile install; \
	fi

devlop: deb
	@if [ "$(SKIP_devlop)" = "y" ]; then \
		echo "==> Skipping devlop (cache found)"; \
	elif [ -n "$(_UBUNTU_DEVLOP)" ]; then \
		$(MAKE) -C devlop -f Makefile install; \
	fi

release: devlop
	@if [ "$(CONFIG_UBUNTU_RELEASE)" = "y" ]; then \
		$(MAKE) -C release -f Makefile install; \
	fi

packge: release
	@if [ "$(CONFIG_UBUNTU_PACKGE)" = "y" ]; then \
		$(MAKE) -C packge -f Makefile install; \
	fi

%_defconfig:
	@cp configs/$@ .config
	@echo "Configuration written to .config"

clean:
	sudo rm -rf $(TOP_DIR)/output

distclean: clean
	rm -f .config .config.old
	rm -rf $(DL_DIR)

help:
	@echo "Usage:"
	@echo "  make <board>_defconfig  - Load a board configuration (e.g. make rk3576_base_defconfig)"
	@echo "  make menuconfig         - Interactive configuration menu"
	@echo "  make                    - Build the rootfs"
	@echo "  make clean              - Remove output directory"
	@echo "  make distclean          - Remove output, config and downloads"
