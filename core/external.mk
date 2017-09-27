
ifneq (,$(BRP_BUILD_OVERLAY))
# Override the pattern rule for installing to the target. This prevents
# the libraries being copied to the target if BRP_BUILD_OVERLAY is set
$(BUILD_DIR)/toolchain-external-custom/.stamp_target_installed: ;
endif

.PHONY: linux-oldconfig
linux-oldconfig: linux-config-dotconfig
	$(LINUX_CONFIGURATOR_MAKE_ENV) $(MAKE) -C $(LINUX_DIR) \
		$(LINUX_KCONFIG_OPTS) oldconfig

.PHONY: linux-config-dotconfig
linux-config-dotconfig: linux-configure
	cp $(dir $(LINUX_KCONFIG_FILE))/config $(LINUX_DIR)/.config

# Define a rule for updating a linux kernel defconfig in the presence of
# config fragments. Buildroot errors out with this, but we have a kconfig
# demerge script we can use to make this work.
.PHONY: linux-config-demerge
ifeq (,$(LINUX_KCONFIG_FRAGMENT_FILES))
linux-config-demerge: linux-update-defconfig
else
linux-config-demerge: linux-savedefconfig
	$(BRP_ROOT)/kconfig.sh demerge $(LINUX_DIR)/defconfig \
		$(LINUX_KCONFIG_FRAGMENT_FILES) > $(LINUX_KCONFIG_FILE)
	cp $(LINUX_DIR)/.config $(dir $(LINUX_KCONFIG_FILE))/config
endif
