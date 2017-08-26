################################################################################
#
# nomad
#
################################################################################

NOMAD_VERSION = v0.6.0
NOMAD_SITE = $(call github,hashicorp,nomad,$(NOMAD_VERSION))
NOMAD_LICENSE = MPL-2.0
NOMAD_LICENSE_FILES = LICENSE

NOMAD_PACKAGE_PATH = github.com/hashicorp/nomad
NOMAD_GLDFLAGS = \
	-X main.gitCommit=$(NOMAD_VERSION)


NOMAD_DEPENDENCIES = host-go

NOMAD_MAKE_ENV = \
	$(HOST_GO_TARGET_ENV) \
	GOPATH="$(@D)/_ws" \
	CGO_ENABLED=1


ifeq ($(BR2_STATIC_LIBS),y)
NOMAD_GLDFLAGS += -extldflags '-static'
endif

# Create a go workspace and symlink the package dir to the source
define NOMAD_CREATE_WORKSPACE
	mkdir -p $(@D)/_ws/src/$(dir $(NOMAD_PACKAGE_PATH))
	ln -s $(@D) $(@D)/_ws/src/$(NOMAD_PACKAGE_PATH)
endef
NOMAD_POST_EXTRACT_HOOKS += NOMAD_CREATE_WORKSPACE

define NOMAD_BUILD_CMDS
	cd $(@D) && $(NOMAD_MAKE_ENV) $(HOST_DIR)/bin/go \
		install -v -ldflags "$(NOMAD_GLDFLAGS)" $(NOMAD_PACKAGE_PATH)
endef

define NOMAD_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/_ws/bin/linux_$(GO_GOARCH)/* $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
