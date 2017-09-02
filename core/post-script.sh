#!/bin/bash
# vim: set ts=8 sw=2 sts=2 et sta fileencoding=utf-8:
#
# post-build, post-fakeroot and post-image script for core brp features.
# One script because there is a lot of common functionality, but should be
# named post-build.sh, post-fakeroot.sh or post-image.sh to invoke the
# correct function. Those names should be symlinks to this script.
#
#-----------------------------------------------------------------------------
usage() {
  printf 'Usage: post-build <target-dir>\n'
  printf 'Usage: post-fakeroot <target-dir>\n'
  printf 'Usage: post-image <image-dir>\n'
}

#-----------------------------------------------------------------------------
main() {
  parse_args "$@"
  if [[ "$0" =~ /post-(build|fakeroot|image) ]]; then
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
post_build() {
  local target_dir="$1"
  local -a unwanted=(
      /etc/os-release
      /etc/nsswitch.conf
      /lib32
      /usr/lib32
  )

  if config_y BR2_BUILD_OVERLAY; then
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

  if config_y BR2_BUILD_OVERLAY; then
    message "Cleaning target dir for overlay"
    rm_unwanted "${target_dir}" "${unwanted[@]}"
    clean_empty "${target_dir}"
  fi

  local image_file
  config_get BR2_OVERLAY_IMAGES
  for image in ${BR2_OVERLAY_IMAGES-}; do
    image_file=$(get_image_file "${image}") || continue
    message "Extracting image ${image}"
    tar -x -f "${image_file}" -C "${target_dir}"
  done
}

#-----------------------------------------------------------------------------
post_image() {
  local image_dir="$1"
  copy_images "${image_dir}"
}

#-----------------------------------------------------------------------------
config_y() {
  config_get "$1"
  [[ "${!1-n}" == 'y' ]]
}

#-----------------------------------------------------------------------------
# Get config settings from BR2_CONFIG file. Option will be set as environment
# variable if set in config, unset otherwise.
config_get() {
  for var; do
    unset "${var}"
    eval $(grep -w "^${var}" "${BR2_CONFIG}")
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
  # $1: image name, either <board>/<phase> or <phase>. In the latter case,
  #     the board is the same as what we are.
  if [[ "$1" =~ ([^/]*)/([^/]*) ]]; then
    local image_dir="${BRP_OUTPUT_ROOT}/${BASH_REMATCH[1]}/images"
    local image_phase="${BASH_REMATCH[2]}"
  else
    local image_dir="${BRP_IMAGE_DIR}"
    local image_phase="$1"
  fi
  shopt -s nullglob
  local image_file=("${image_dir}/rootfs-${image_phase}.tar"*)
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
# Copy images from a phase image directory to the board image directory.
# rootfs images will be renamed to add "-<phase>" into the name.
# An uncompressed rootfs image will not be copied if there is also a
# compressed rootfs image. Only the compressed image will be copied.
# All other non-rootfs images will be copied.
copy_images() {
  shopt -s nullglob
  for image in "$1"/*; do
    local image_name="${image##*/}"
    # don't copy an uncompressed rootfs if there's a compressed one.
    if [[ "${image_name}" =~ ^rootfs\.[^.]*$ ]] && globmatch "${image}.*"; then
      continue
    fi
    # don't copy an empty image tar file
    if [[ "${image_name}" =~ ^rootfs\.tar* ]]; then
      if [[ "$(tar -t -f "${image}")" == './' ]]; then
        printf 'Not copying empty image %s\n' "${image_name}"
        continue
      fi
    fi
    cp -a "${image}" "${BRP_IMAGE_DIR}/${image_name/rootfs/rootfs-${BRP_PHASE}}"
  done
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
