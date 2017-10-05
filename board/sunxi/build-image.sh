#!/bin/bash
# vim: set ts=8 sw=2 sts=2 et sta fileencoding=utf-8:
#
#-----------------------------------------------------------------------------
# Generate images from build artefacts:
#   sd card image. Requires uboot, uboot environment, DTB, kernel and rootfs
#     as ext image.
#   A FEL boot script image. Requires felboot.cmd or felboot-nfs.cmd
#
# Args:
# $1: Path to images directory
# $2: dtb file
#
# CWD is the board image directory ($BRP_IMAGE_DIR)
#
# brp defines:
# BRP_BOARD_DIR: The directory contain the board files in the source tree
# BRP_IMAGE_DIR: The directory containing all the image outputs from each phase
# BRP_OUTPUT_DIR: The root output directory containing the output dirs
#   for each phase.
#
# TODO(camh): rewrite this as a makefile

# shellcheck disable=SC2034
# Unused vars are used via indirection
init() {
  uenv_req=($(collate uboot-env.txt))
  sdcard_req=("${BRP_IMAGE_DIR}"/{zImage,board.dtb})
  sdcard_sdroot_req=("${BRP_IMAGE_DIR}"/{rootfs.ext4,sdroot/uboot-env.bin})
  sdcard_nfsroot_req=("${BRP_IMAGE_DIR}"/nfsroot/uboot-env.bin)
  dryrun=0
}

main() {
  init
  link_dtb "$@"
  make_images sdroot nfsroot
  make_fel_image rdroot
}

link_dtb() {
  # If $2 is present, it is the name of the dtb. Symlink "board.dtb" to it
  # so the genimage and boot config can be generic for sunxi.
  if [[ -n "$2" ]] && [[ -f "${BRP_IMAGE_DIR}/$2" ]]; then
    ln -sf "$2" "${BRP_IMAGE_DIR}/board.dtb"
  fi
}

make_images() {
  for image; do
    make_uboot_env_image "${image}"
    make_sdcard_image "${image}"
    make_fel_image "${image}"
  done
}

make_uboot_env_image() {
  local env
  env="$(locate "${1}/uboot-env.txt")"
  if ! missing=$(req "${uenv_req[@]}" "${env}"); then
    echo "Not making ${1} uboot env image. Missing: $missing"
    return
  fi
  mkdir -p "${BRP_IMAGE_DIR}/${1}"
  cat "${uenv_req[@]}" "${env}" \
    | run mkenvimage -s 0x20000 -o "${BRP_IMAGE_DIR}/${1}/uboot-env.bin" -
}

make_sdcard_image() {
  local v="sdcard_${1}_req[@]"
  if ! missing=$(req "${sdcard_req[@]}" "${!v}"); then
    echo "Not making ${1} SD card image. Missing: $missing"
    return
  fi

  local GENIMAGE_CFG GENIMAGE_TMP ROOTPATH_TMP
  GENIMAGE_CFG=$(locate "${1}/genimage.cfg")
  GENIMAGE_TMP=$(mktemp -d "${BRP_IMAGE_DIR}/genimage.XXXXXXXXX")
  ROOTPATH_TMP=$(mktemp -d -t "genimage.root.XXXXXXXXX")

  cleanup() { rm -rf "${GENIMAGE_TMP}" "${ROOTPATH_TMP}"; }

  trap cleanup EXIT

  mkdir -p "${BRP_IMAGE_DIR}/${1}"
  run genimage \
    --rootpath "${ROOTPATH_TMP}" \
    --tmppath "${GENIMAGE_TMP}" \
    --inputpath "${BRP_IMAGE_DIR}" \
    --outputpath "${BRP_IMAGE_DIR}/${1}" \
    --config "${GENIMAGE_CFG}"

  cleanup
  trap - EXIT
}

make_fel_image() {
  if ! felboot_cmd=$(locate "${1}/felboot.cmd"); then
    echo "Not making $1 FEL image. Missing: ${1}/felboot.cmd"
    return
  fi

  # Create a boot script image for FEL booting the board. Also copy a
  # felboot script into the image directory that makes it easy to FEL
  # boot the generated images
  mkdir -p "${BRP_IMAGE_DIR}/${1}"
  run mkimage \
    -C none -A arm -T script \
    -d "${felboot_cmd}" \
    "${BRP_IMAGE_DIR}/${1}/felboot.scr"

  run cp "$(locate "felboot")" "${BRP_IMAGE_DIR}"
  if [[ -x "${HOST_DIR}/bin/sunxi-fel" ]]; then
    run sed -i '/: ${HOST_DIR:=}/s|.*|: ${HOST_DIR:='"${HOST_DIR}"'}|' \
      "${BRP_IMAGE_DIR}/felboot"
  fi
}

#-----------------------------------------------------------------------------
run() {
  echo "$@"
  (( dryrun == 1 )) || "$@"
}

req() {
  for arg; do
    [[ -e "$arg" ]] || { echo "$arg"; return 1; }
  done
  return 0
}

collate() {
  _collate "${BRP_BOARD_DIR}" "$1"
}

_collate() {
  if [[ -L "$1/parent" ]] ; then
    _collate "$1/parent" "$2"
  fi
  if [[ -e "$1/$2" ]] ; then
    readlink -f "$1/$2"
  fi
}

locate() {
  _locate "${BRP_BOARD_DIR}" "$1"
}

_locate() {
  if [[ -e "$1/$2" ]] ; then
    readlink -f "$1/$2"
  elif [[ -L "$1/parent" ]] ; then
    _locate "$1/parent" "$2"
  else
    return 1
  fi
}

#-----------------------------------------------------------------------------
[[ "$(caller)" != "0 "* ]] || main "$@"
