################################################################################
#
# HAOS - Custom Core Integration with Enhanced Logging
#
################################################################################

HASSIO_VERSION = 1.0.0
HASSIO_LICENSE = Apache License 2.0
HASSIO_SITE = $(BR2_EXTERNAL_HASSOS_PATH)/package/hassio
HASSIO_SITE_METHOD = local

# Force stable channel for our custom build
HASSIO_VERSION_CHANNEL = "stable"

HASSIO_CONTAINER_IMAGES_ARCH = supervisor dns audio cli multicast observer core

define HASSIO_CONFIGURE_CMDS
	echo "[CUSTOM BUILD] Configuring Hassio with custom core..."
	# Ensure custom version file exists
	if [ ! -f "$(BR2_EXTERNAL_HASSOS_PATH)/package/hassio/version-custom.json" ]; then \
		echo "[ERROR] Custom version file not found"; \
		exit 1; \
	fi
	# Copy custom version configuration
	cp $(BR2_EXTERNAL_HASSOS_PATH)/package/hassio/version-custom.json $(@D)/version.json
	echo "[CUSTOM BUILD] Using custom version configuration:"
	cat $(@D)/version.json
endef

define HASSIO_BUILD_CMDS
	echo "[CUSTOM BUILD] Building Hassio package..."
	$(Q)mkdir -p $(@D)/images
	$(Q)mkdir -p $(HASSIO_DL_DIR)
	echo "[CUSTOM BUILD] Starting container downloads..."
	$(foreach image,$(HASSIO_CONTAINER_IMAGES_ARCH),\
		echo "[CUSTOM BUILD] Fetching container: $(image)"; \
		$(BR2_EXTERNAL_HASSOS_PATH)/package/hassio/fetch-container-image.sh \
			$(BR2_PACKAGE_HASSIO_ARCH) $(BR2_PACKAGE_HASSIO_MACHINE) $(@D)/version.json $(image) "$(HASSIO_DL_DIR)" "$(@D)/images" || exit 1; \
	)
	echo "[CUSTOM BUILD] All containers downloaded successfully"
	echo "[CUSTOM BUILD] Verifying custom core was downloaded..."
	if [ ! -f "$(@D)/images/core_2025.5.0-custom.tar" ]; then \
		echo "[ERROR] Custom core container was not downloaded!"; \
		echo "[ERROR] Available containers:"; \
		ls -la "$(@D)/images/" || true; \
		exit 1; \
	else \
		echo "[SUCCESS] Custom core container found"; \
		ls -lh "$(@D)/images/core_2025.5.0-custom.tar"; \
	fi
endef

HASSIO_INSTALL_IMAGES = YES

define HASSIO_INSTALL_IMAGES_CMDS
	echo "[CUSTOM BUILD] Installing Hassio images and creating data partition..."
	$(BR2_EXTERNAL_HASSOS_PATH)/package/hassio/create-data-partition.sh "$(@D)" "$(BINARIES_DIR)" "$(HASSIO_VERSION_CHANNEL)"
	echo "[CUSTOM BUILD] Data partition creation completed"
endef

$(eval $(generic-package))
