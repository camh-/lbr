#!/bin/bash
#
# core/post-build.sh
#
# Clean the target dir if building an overlay

UNWANTED=(
	/etc/os-release
	/etc/nsswitch.conf
	/lib32
	/usr/lib32
)

main() {
    TARGET_DIR="$1"

    eval $(grep -w ^BR2_BUILD_OVERLAY "${BR2_CONFIG}")

    if [[ "${BR2_BUILD_OVERLAY}" == 'y' ]]; then
	rm -f "${UNWANTED[@]/#/${TARGET_DIR}}"
        while [[ $(clean_empty "${TARGET_DIR}") != 0 ]]; do
            :
        done
    fi
}

# Remove dangling symlinks and empty directories.
# Output the count of files removed. This can be called iteratively until
# the count is zero.
clean_empty() {
    local link_count=$(find "$1" -xtype l -print -delete | wc -l)
    local dir_count=$(find "$1" -type d -empty -print -delete | wc -l)
    echo $((link_count + dir_count))
}

[[ "$(caller)" != 0\ * ]] || main "$@"
