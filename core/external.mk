
ifneq (,$(BRP_BUILD_OVERLAY))
# Override the pattern rule for installing to the target. This prevents
# the libraries being copied to the target if BRP_BUILD_OVERLAY is set
$(BUILD_DIR)/toolchain-external-custom/.stamp_target_installed: ;
endif

ifeq (,$(LINUX_KCONFIG_FRAGMENT_FILES))
linux-config-demerge: linux-update-defconfig
else
linux-config-demerge: linux-savedefconfig
	$(BRP_ROOT)/kconfig.sh demerge $(LINUX_DIR)/defconfig \
		$(LINUX_KCONFIG_FRAGMENT_FILES) > $(LINUX_KCONFIG_FILE)
	cp $(LINUX_DIR)/.config $(dir $(LINUX_KCONFIG_FILE))/config
endif
