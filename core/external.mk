
ifneq (,$(BRP_BUILD_OVERLAY))
# Override the pattern rule for installing to the target. This prevents
# the libraries being copied to the target if BRP_BUILD_OVERLAY is set
$(BUILD_DIR)/toolchain-external-custom/.stamp_target_installed: ;
endif
