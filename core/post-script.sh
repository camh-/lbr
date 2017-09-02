#!/bin/bash
# vim: set ts=8 sw=2 sts=2 et sta fileencoding=utf-8:
#
# post-build and post-fakeroot script for core brp features.
# One script because there is a lot of common functionality, but should be
# named post-build.sh or post-fakeroot.sh to invoke the correct function.
# Those names should be symlinks to this script.
#
#-----------------------------------------------------------------------------
usage() {
  printf 'Usage: post-build <target-dir>\n'
  printf 'Usage: post-fakeroot <target-dir>\n'
}

#-----------------------------------------------------------------------------
main() {
  parse_args "$@"
  if [[ "$0" =~ /post-(build|fakeroot) ]]; then
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
