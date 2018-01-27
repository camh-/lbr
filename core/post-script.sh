#!/bin/bash
# vim: set ts=8 sw=2 sts=2 et sta fileencoding=utf-8:
#
# post-build, post-fakeroot and post-image script for core lbr features.
# One script because there is a lot of common functionality, but should be
# named post-build.sh, post-fakeroot.sh or post-image.sh to invoke the
# correct function. Those names should be symlinks to this script.
#
#-----------------------------------------------------------------------------

KCONFIG="${BR2_CONFIG}"
source "${LBR_LIB_DIR}"/kconfig.sh

#-----------------------------------------------------------------------------
usage() {
  printf 'Usage: post-config <script-dir>\n'
  printf 'Usage: post-build <target-dir>\n'
  printf 'Usage: post-fakeroot <target-dir>\n'
  printf 'Usage: post-image <image-dir>\n'
}

#-----------------------------------------------------------------------------
main() {
  parse_args "$@"
  if [[ "$0" =~ /post-(config|build|fakeroot|image) ]]; then
    function="${BASH_REMATCH[1]}"
  else
    printf 'Called with unknown name: %s\n' "${0##*/}" >&2
    usage >&2
    exit 1
  fi

  "post_${function}" "$@"
}

#-----------------------------------------------------------------------------
parse_args() {
  OPTSTRING=':h'
  while getopts "${OPTSTRING}" opt; do
    case "${opt}" in
      h)
        usage
        exit 0
        ;;
      \?)
        printf 'Invalid option: -%s\n\n' "${OPTARG}" >&2
        usage >&2
        exit 1
        ;;
      :)
        printf 'Option -%s requires an argument\n\n' "${OPTARG}" >&2
        usage >&2
        exit 1
        ;;
    esac
  done
  shift $((OPTIND-1))

  # Process remaining in "$@"
}

#-----------------------------------------------------------------------------
post_config() {
  # Ensure buildroot runs our post-{build,fakeroot,image}.sh scripts
  local d='$(BR2_EXTERNAL_LBR_CORE_PATH)'
  kconfig_str_append BR2_ROOTFS_POST_BUILD_SCRIPT "${d}/post-build.sh"
  kconfig_str_append BR2_ROOTFS_POST_FAKEROOT_SCRIPT "${d}/post-fakeroot.sh"
  kconfig_str_append BR2_ROOTFS_POST_IMAGE_SCRIPT "${d}/post-image.sh"

  # Override some defaults when building an overlay image
  if kconfig_y LBR_BUILD_OVERLAY; then

    # Use an empty skeleton if none configured
    if kconfig_y BR2_ROOTFS_SKELETON_CUSTOM; then
      kconfig_get BR2_ROOTFS_SKELETON_CUSTOM_PATH
      if [[ -z "${BR2_ROOTFS_SKELETON_CUSTOM_PATH-}" ]]; then
        kconfig_str_set BR2_ROOTFS_SKELETON_CUSTOM_PATH "${d}/skeleton"
      fi
    fi

  fi  # LBR_BUILD_OVERLAY=y
}

#-----------------------------------------------------------------------------
post_build() {
  local target_dir="$1"
  local -a unwanted=(
      /etc/os-release
      /etc/nsswitch.conf
      /lib32
      /usr/lib32
  )

  if kconfig_y LBR_BUILD_OVERLAY; then
    message "Cleaning target dir for overlay"
    rm_unwanted "${target_dir}" "${unwanted[@]}"
    clean_empty "${target_dir}"
  fi
}

#-----------------------------------------------------------------------------
post_fakeroot() {
  local target_dir="$1"
  local -a unwanted=(
      /dev/console
  )

  if kconfig_y LBR_BUILD_OVERLAY; then
    message "Cleaning target dir for overlay"
    rm_unwanted "${target_dir}" "${unwanted[@]}"
    clean_empty "${target_dir}"
  fi

  local image_file
  kconfig_get LBR_OVERLAY_IMAGES
  for image in ${LBR_OVERLAY_IMAGES-}; do
    image_file=$(get_image_file "${image}") || continue
    message "Extracting image ${image}"
    tar -x -f "${image_file}" -C "${target_dir}"
  done
}

#-----------------------------------------------------------------------------
post_image() {
  local image_dir="$1"

  # When building a board image, we copy the layer images into the board
  # image directory without renaming them (i.e. without adding the layer
  # name to the image). This gives these final board images a consistent
  # name for the build-image script to work with.
  local rename_arg
  kconfig_y LBR_RENAME_LAYER_IMAGE || rename_arg='norename'

  message 'Copying images to board dir'
  copy_images "${image_dir}" "${rename_arg}"

  kconfig_get LBR_POST_IMAGE_SCRIPTS
  local script
  for script in ${LBR_POST_IMAGE_SCRIPTS-}; do
    [[ "${script}" =~ ^[^/] ]] && script=$(locate_source "${script}")
    if [[ -x "${script}" ]]; then
      message "Running lbr post-script ${script}"
      (
        cd "${LBR_IMAGE_DIR}" && "${script}" "${LBR_IMAGE_DIR}"
      )
    fi
  done
}

#-----------------------------------------------------------------------------
rm_unwanted() {
  dir="$1"; shift
  rm -f "${@/#/${dir}}"
}

#-----------------------------------------------------------------------------
# Remove empty directories and dangling symlinks. This is done iteratively
# until nothing is removed.
clean_empty() {
  local link_count=1 dir_count=0
  while (( link_count + dir_count > 0 )); do
    link_count=$(find "$1" -xtype l -print -delete | wc -l)
    dir_count=$(find "$1" -mindepth 1 -type d -empty -print -delete | wc -l)
  done
}

#-----------------------------------------------------------------------------
get_image_file() {
  # $1: image name, either <board>/<layer> or <layer>. In the latter case,
  #     the board is the same as what we are.
  if [[ "$1" =~ ([^/]*)/([^/]*) ]]; then
    local image_dir="${LBR_OUTPUT_ROOT}/${BASH_REMATCH[1]}/images"
    local image_layer="${BASH_REMATCH[2]}"
  else
    local image_dir="${LBR_IMAGE_DIR}"
    local image_layer="$1"
  fi
  shopt -s nullglob
  local image_file=("${image_dir}/rootfs-${image_layer}.tar"*)
  case "${#image_file[@]}" in
    0)
      printf 'Could not locate image: %s\n' "$1" >&2
      ;;
    1)
      printf '%s\n' "${image_file[0]}"
      ;;
    *)
      printf 'Found multiple image archives for image: %s\n' "$1" >&2
      ;;
  esac
}

#-----------------------------------------------------------------------------
# Copy images from a layer image directory to the board image directory.
# rootfs images will be renamed to add "-<layer>" into the name.
# An uncompressed rootfs image will not be copied if there is also a
# compressed rootfs image. Only the compressed image will be copied.
# All other non-rootfs images will be copied.
copy_images() {
  shopt -s nullglob
  for image in "$1"/*; do
    local image_name="${image##*/}"
    # don't copy an uncompressed rootfs if there's a compressed one.
    if [[ "${image_name}" =~ ^rootfs\.[^.]*$ ]] && globmatch "${image}.*"; then
      printf '%s: skipping uncompressed image\n' "${image_name}"
      continue
    fi
    # don't copy an empty image tar file
    if [[ "${image_name}" =~ ^rootfs\.tar* ]]; then
      if [[ "$(tar -t -f "${image}" | head -n 2)" == './' ]]; then
        printf '%s: skipping empty image\n' "${image_name}"
        continue
      fi
    fi
    printf '%s: copying as ' "${image_name}"
    [[ "${2-}" != 'norename' ]] && image_name="${image_name/rootfs/rootfs-${LBR_LAYER}}"
    printf '%s\n' "${image_name}"
    if [[ -L "${image}" ]] && [[ "${2-}" != 'norename' ]]; then
      local target
      target=$(readlink "${image}")
      ln -nsf "${target/rootfs/rootfs-${LBR_LAYER}}" "${LBR_IMAGE_DIR}/${image_name}"
    else
      cp -a "${image}" "${LBR_IMAGE_DIR}/${image_name}"
    fi
  done
}

#-----------------------------------------------------------------------------
locate_source() {
  _locate_source "${LBR_BOARD_DIR}" "$1"
}

_locate_source() {
  if [[ -e "$1/$2" ]] ; then
    readlink -f "$1/$2"
  elif [[ -L "$1/parent" ]] ; then
    _locate "$1/parent" "$2"
  else
    return 1
  fi
}

#-----------------------------------------------------------------------------
message() {
  tput smso   # bold
  printf '>>> post-%s %s\n' "${function}" "$*"
  tput rmso   # normal
}

#-----------------------------------------------------------------------------
# $1: A glob pattern
# Returns true if $1 matches any files, false if not
globmatch() {
  compgen -G "$1" > /dev/null
}

#-----------------------------------------------------------------------------
[[ "$(caller)" != "0 "* ]] || main "$@"
