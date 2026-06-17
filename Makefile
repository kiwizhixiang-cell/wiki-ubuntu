SHELL := /bin/bash
-include .config
export

TOP_DIR  := $(CURDIR)
DL_DIR   := $(TOP_DIR)/dl

# Strip quotes from string config values
Q = $(subst ",,$1)
_CONFIG_NAME    := $(call Q,$(CONFIG_NAME))
_UBUNTU_BASE    := $(call Q,$(CONFIG_UBUNTU_BASE))
_CPU_ARCH       := $(call Q,$(CONFIG_CPU_ARCH))
_UBUNTU_APP     := $(call Q,$(CONFIG_UBUNTU_APP))
_UBUNTU_DESKTOP := $(call Q,$(CONFIG_UBUNTU_DESKTOP))
_UBUNTU_DEVLOP  := $(call Q,$(CONFIG_UBUNTU_DEVLOP))

ifeq ($(_CONFIG_NAME),)
_CONFIG_NAME := default
endif

CACHE_OUTPUT_DIR := $(TOP_DIR)/output/$(_CONFIG_NAME)
ROOTFS           ?= $(CACHE_OUTPUT_DIR)/rootfs
CACHE_ROOT       := $(CACHE_OUTPUT_DIR)/cache
CACHE_ROOTFS_DIR := $(CACHE_ROOT)/rootfs
CACHE_APT_DIR    := $(DL_DIR)/packages-$(_UBUNTU_BASE)-$(_CPU_ARCH)

export TOP_DIR ROOTFS DL_DIR CACHE_ROOT CACHE_ROOTFS_DIR CACHE_APT_DIR

BASE_CACHE_HASH    := $(shell printf '%s' '$(_CONFIG_NAME)|base|$(CONFIG_UBUNTU_BASE)|$(CONFIG_PASSWORD)|$(CONFIG_ROOT_PASSWORD)' | md5sum | cut -d' ' -f1)
FSTAB_CACHE_HASH   := $(shell printf '%s' '$(BASE_CACHE_HASH)|fstab|$(CONFIG_UBUNTU_FSTAB)' | md5sum | cut -d' ' -f1)
APP_CACHE_HASH     := $(shell printf '%s' '$(FSTAB_CACHE_HASH)|app|$(CONFIG_UBUNTU_APP)' | md5sum | cut -d' ' -f1)
DESKTOP_CACHE_HASH := $(shell printf '%s' '$(APP_CACHE_HASH)|desktop|$(CONFIG_UBUNTU_DESKTOP)' | md5sum | cut -d' ' -f1)
DEB_CACHE_HASH     := $(shell printf '%s' '$(DESKTOP_CACHE_HASH)|deb|$(CONFIG_UBUNTU_DEB_ADB)|$(CONFIG_UBUNTU_DEB_MALI)|$(CONFIG_UBUNTU_DEB_MPP)|$(CONFIG_UBUNTU_DEB_MPP_DEV)|$(CONFIG_UBUNTU_DEB_RGA)|$(CONFIG_UBUNTU_DEB_RGA_DEV)|$(CONFIG_UBUNTU_DEB_RKNPU2)|$(CONFIG_UBUNTU_DEB_RKNPU2_DEV)|$(CONFIG_UBUNTU_DEB_ROCKIT)|$(CONFIG_UBUNTU_DEB_ROCKIT_DEV)|$(CONFIG_UBUNTU_DEB_ROCKIT_TEST)|$(CONFIG_UBUNTU_DEB_CAMERA)|$(CONFIG_UBUNTU_DEB_IVA)|$(CONFIG_UBUNTU_DEB_IVA_DEV)|$(CONFIG_UBUNTU_DEB_COMMON_ALGO)|$(CONFIG_UBUNTU_DEB_COMMON_ALGO_DEV)|$(CONFIG_UBUNTU_DEB_GSTREAMER)|$(CONFIG_UBUNTU_DEB_RECOVERY)|$(CONFIG_UBUNTU_DEB_WIFI_AIC8800)|$(CONFIG_UBUNTU_DEB_WIFI_AP6256)|$(CONFIG_UBUNTU_DEB_WIFI_RTL8822CE)' | md5sum | cut -d' ' -f1)
DEVLOP_CACHE_HASH  := $(shell printf '%s' '$(DEB_CACHE_HASH)|devlop|$(CONFIG_UBUNTU_DEVLOP)|$(CONFIG_UBUNTU_DEVLOP_AUTOLOGIN)|$(CONFIG_UBUNTU_DEVLOP_USB_ADB)|$(CONFIG_UBUNTU_DEVLOP_USB_RNDIS)|$(CONFIG_UBUNTU_DEVLOP_MOUSEHOP)' | md5sum | cut -d' ' -f1)

export BASE_CACHE_HASH FSTAB_CACHE_HASH APP_CACHE_HASH DESKTOP_CACHE_HASH DEB_CACHE_HASH DEVLOP_CACHE_HASH

LAST_HIT_STAGE := $(shell \
	if [ -n "$(_UBUNTU_DEVLOP)" ] && [ -f "$(CACHE_ROOTFS_DIR)/ubuntu-devlop-$(DEVLOP_CACHE_HASH).tar.gz" ]; then echo devlop; \
	elif [ "$(CONFIG_UBUNTU_DEB)" = "y" ] && [ -f "$(CACHE_ROOTFS_DIR)/ubuntu-deb-$(DEB_CACHE_HASH).tar.gz" ]; then echo deb; \
	elif [ -n "$(_UBUNTU_DESKTOP)" ] && [ -f "$(CACHE_ROOTFS_DIR)/ubuntu-desktop-$(DESKTOP_CACHE_HASH).tar.gz" ]; then echo desktop; \
	elif [ -n "$(_UBUNTU_APP)" ] && [ -f "$(CACHE_ROOTFS_DIR)/ubuntu-app-$(APP_CACHE_HASH).tar.gz" ]; then echo app; \
	elif [ -f "$(CACHE_ROOTFS_DIR)/ubuntu-fstab-$(FSTAB_CACHE_HASH).tar.gz" ]; then echo fstab; \
	elif [ -f "$(CACHE_ROOTFS_DIR)/ubuntu-base-$(BASE_CACHE_HASH).tar.gz" ]; then echo base; \
	fi)

export LAST_HIT_STAGE

MODULES := base fstab app desktop deb devlop rootfs_clean packge

.PHONY: all $(MODULES) clean clean_uncache distclean help menuconfig savedefconfig

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
	@mkdir -p $(CACHE_ROOTFS_DIR) $(CACHE_APT_DIR)
	@if [ -n "$(LAST_HIT_STAGE)" ] && [ "$(LAST_HIT_STAGE)" != "base" ]; then \
		echo "==> Skipping base (latest hit: $(LAST_HIT_STAGE))"; \
	else \
		$(MAKE) -C base -f Makefile install; \
	fi

fstab: base
	@if [ "$(LAST_HIT_STAGE)" = "app" ] || [ "$(LAST_HIT_STAGE)" = "desktop" ] || [ "$(LAST_HIT_STAGE)" = "deb" ] || [ "$(LAST_HIT_STAGE)" = "devlop" ]; then \
		echo "==> Skipping fstab (latest hit: $(LAST_HIT_STAGE))"; \
	else \
		$(MAKE) -C fstab -f MakeFile install; \
	fi

app: fstab
	@if [ -n "$(_UBUNTU_APP)" ]; then \
		if [ "$(LAST_HIT_STAGE)" = "desktop" ] || [ "$(LAST_HIT_STAGE)" = "deb" ] || [ "$(LAST_HIT_STAGE)" = "devlop" ]; then \
			echo "==> Skipping app (latest hit: $(LAST_HIT_STAGE))"; \
		else \
			$(MAKE) -C app -f Makefile install; \
		fi; \
	fi

desktop: app
	@if [ -n "$(_UBUNTU_DESKTOP)" ]; then \
		if [ "$(LAST_HIT_STAGE)" = "deb" ] || [ "$(LAST_HIT_STAGE)" = "devlop" ]; then \
			echo "==> Skipping desktop (latest hit: $(LAST_HIT_STAGE))"; \
		else \
			$(MAKE) -C desktop -f Makefile install; \
		fi; \
	fi

deb: desktop
	@if [ "$(CONFIG_UBUNTU_DEB)" = "y" ]; then \
		if [ "$(LAST_HIT_STAGE)" = "devlop" ]; then \
			echo "==> Skipping deb (latest hit: $(LAST_HIT_STAGE))"; \
		else \
			$(MAKE) -C deb -f Makefile install; \
		fi; \
	fi

devlop: deb
	@if [ -n "$(_UBUNTU_DEVLOP)" ]; then \
		$(MAKE) -C devlop -f Makefile install; \
	fi

rootfs_clean: devlop
	@if [ "$(CONFIG_UBUNTU_CLEAN)" = "y" ]; then \
		$(MAKE) -C clean -f Makefile install; \
	fi

packge: rootfs_clean
	@if [ "$(CONFIG_UBUNTU_PACKGE)" = "y" ]; then \
		$(MAKE) -C packge -f Makefile install; \
	fi

%_defconfig:
	@cp configs/$@ .config
	@echo "Configuration written to .config"

clean:
	rm -rf $(CACHE_OUTPUT_DIR)

clean_uncache:
	@mkdir -p $(CACHE_ROOTFS_DIR)
	@echo "Cleaning cache files not matched by current config in $(CACHE_ROOTFS_DIR)"
	@set -e; \
	keep="ubuntu-base-$(BASE_CACHE_HASH).tar.gz ubuntu-fstab-$(FSTAB_CACHE_HASH).tar.gz ubuntu-app-$(APP_CACHE_HASH).tar.gz ubuntu-desktop-$(DESKTOP_CACHE_HASH).tar.gz ubuntu-deb-$(DEB_CACHE_HASH).tar.gz ubuntu-devlop-$(DEVLOP_CACHE_HASH).tar.gz"; \
	for f in "$(CACHE_ROOTFS_DIR)"/*.tar.gz; do \
		[ -e "$$f" ] || continue; \
		name=$$(basename "$$f"); \
		case " $$keep " in \
			*" $$name "*) ;; \
			*) echo "  remove $$name"; rm -f "$$f" ;; \
		esac; \
	done

distclean: clean
	rm -f .config .config.old
	rm -rf $(DL_DIR)

help:
	@echo "Usage:"
	@echo "  make <board>_defconfig  - Load a board configuration (e.g. make rk3576_base_defconfig)"
	@echo "  make menuconfig         - Interactive configuration menu"
	@echo "  make                    - Build the rootfs"
	@echo "  make clean              - Remove current CONFIG_NAME output directory"
	@echo "  make clean_uncache      - Remove unmatched cache tarballs for current config"
	@echo "  make distclean          - Remove output, config and downloads"
