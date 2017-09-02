#!/bin/bash
# vim: set ts=8 sw=2 sts=2 et sta fileencoding=utf-8:
#
# bash library for operating on kconfig files
#
# Functions here operate on the file in KCONFIG by default, unless a file is
# specified.

#-------------------------------------------------------------------------------
# Get a config setting from a kconfig file. Option will be set as an environment
# variable if set in config, unset otherwise.
kconfig_get() {
  unset "$1"
  local val
  val=$(sed -n \
    -e '/^'"$1"'=".*"$/{s/^'"$1"'="\(.*\)"$/\1/;s/\\"/"/g;s/\\\\/\\/g;p;q}' \
    -e '/^'"$1"'=/{s/^'"$1"'=\(.*\)$/\1/p;q}' \
    "${2:-${KCONFIG}}")
  if [[ -n "${val}" ]]; then
    declare -g "$1"="${val}"
  fi
}

#-------------------------------------------------------------------------------
kconfig_y() {
  kconfig_get "$1" "${2-}"
  [[ "${!1-n}" == 'y' ]]
}

#-------------------------------------------------------------------------------
