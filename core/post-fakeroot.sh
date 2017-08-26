#!/bin/bash
#
# core/post-fakeroot.sh
#
# Clean the target dir if building an overlay. This cleans up anything
# created unconditionally in fakeroot (such as /dev/console)

main() {
    TARGET_DIR="$1"

    eval $(grep -w ^BR2_BUILD_OVERLAY "${BR2_CONFIG}")

    if [[ "${BR2_BUILD_OVERLAY}" == 'y' ]]; then
        rm -f "${TARGET_DIR}/dev/console"
        find "${TARGET_DIR}" -type d -empty -delete
        find "${TARGET_DIR}" -xtype l -delete
        find "${TARGET_DIR}" -type d -empty -delete
    fi
}

main "$@"
