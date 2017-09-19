################################################################################
#
# sunxi-fel
#
################################################################################

SUNXI_FEL_VERSION = cd9e6099e8668f4aa25d3ffc71283c0b138af1b7
SUNXI_FEL_SITE = $(call github,linux-sunxi,sunxi-tools,$(SUNXI_FEL_VERSION))
SUNXI_FEL_LICENSE = GPL-2.0+
SUNXI_FEL_LICENSE_FILES = LICENSE.md
HOST_SUNXI_FEL_DEPENDENCIES = host-libusb host-pkgconf

define HOST_SUNXI_FEL_BUILD_CMDS
	$(HOST_MAKE_ENV) $(MAKE) CC="$(HOSTCC)" PREFIX=$(HOST_DIR) \
		EXTRA_CFLAGS="$(HOST_CFLAGS)" LDFLAGS="$(HOST_LDFLAGS)" \
		-C $(@D) sunxi-fel
endef

define HOST_SUNXI_FEL_INSTALL_CMDS
	install -m0775 $(@D)/sunxi-fel $(HOST_DIR)/bin
endef

$(eval $(host-generic-package))
