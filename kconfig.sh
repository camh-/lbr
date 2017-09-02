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
  # unquote backslashes and double-quotes for string values
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
# set a string value in the kconfig file.
# $1: kconfig var
# $2: string to append
# $3: kconfig file (optional, default $KCONFIG)
kconfig_str_set() {
  local qval=$(kconfig_str_quote "$2")  # quote for kconfig
  qval="${qval//\\/\\\\}"               # quote for sed
  sed -i \
    -e 's|^\('"$1"'\)=".*"|\1="'"${qval}"'"|' \
    -e 's|^# \('"$1"'\) is not set|\1="'"${qval}"'"|' \
    "${3:-${KCONFIG}}"
}

#-------------------------------------------------------------------------------
# append a value to a string in the kconfig file. If the var is unset or set to
# the empty string, it will be set to the value, otherwise the separator then
# string will be appended.
# $1: kconfig var
# $2: string to append
# $3: separator (optional, default space)
# $4: kconfig file (optional, default $KCONFIG)
kconfig_str_append() {
  local qval=$(kconfig_str_quote "$2")  # quote for kconfig
  qval="${qval//\\/\\\\}"               # quote for sed
  sed -i \
    -e 's|^\('"$1"'=".\+\)"$|\1'"${3- }${qval}"'"|' \
    -e 's|^\('"$1"'\)=""|\1="'"${qval}"'"|' \
    -e 's|^# \('"$1"'\) is not set|\1="'"${qval}"'"|' \
    "${4:-${KCONFIG}}"
}

#-------------------------------------------------------------------------------
kconfig_str_quote() {
  local qval="$1"
  qval="${qval//\\/\\\\}"
  qval="${qval//\"/\\\"}"
  printf '%s' "${qval}"
}

#-------------------------------------------------------------------------------
