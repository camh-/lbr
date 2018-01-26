#!/bin/bash
# vim: set ts=8 sw=2 sts=2 et sta fileencoding=utf-8:
#
# bash library for operating on kconfig files
#
# Functions here operate on the file in KCONFIG by default, unless a file is
# specified.
#
#-----------------------------------------------------------------------------
usage() {
  printf 'Usage: %s {<options>...} <cmd>\n' "${0##*/}"
  printf 'Available commands:\n'
  printf '  merge <fragment>...\n'
  printf '  demerge <defconfig> <fragment>...\n'
  printf 'Available options:\n'
}

#-----------------------------------------------------------------------------
main() {
  parse_args "$@"
  case "$1" in
    merge)
      kconfig_merge "${@:2}"
      ;;
    demerge)
      kconfig_demerge "${@:2}"
      ;;
  esac
}

#-----------------------------------------------------------------------------
parse_args() {
  OPTSTRING=':'
  while getopts "${OPTSTRING}" opt; do
    case "${opt}" in
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
# kconfig_val_set <kconfig_var> <value> <kconfig_file>?
# Set <kconfig_var> to <value> in <kconfig_file>. This should not be used for
# string values - use kconfig_str_set or kconfig_str_append instead. The value
# should be appropriate for the kconfig_var type. No validation is done.
kconfig_val_set() {
  sed -i \
    -e 's|^\('"$1"'\)=.*|\1='"$2"'|' \
    -e 's|^# \('"$1"'\) is not set|\1='"$2"'|' \
    "${3:-${KCONFIG}}"
}

#-------------------------------------------------------------------------------
# set a string value in the kconfig file.
# $1: kconfig var
# $2: string to append
# $3: kconfig file (optional, default $KCONFIG)
# Note: If the variable is not present in the kconfig file at all, no value
# will be set.
kconfig_str_set() {
  local qval=$(kconfig_str_quote "$2")  # quote for kconfig
  qval="${qval//\\/\\\\}"               # quote for sed
  kconfig_val_set "$1" "\"${qval}\"" "$3"
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
# kconfig_merge: Merge a list of defconfig fragments files into one defconfig
# file. Settings in later fragments override earlier fragments.
# The merged defconfig is written to stdout.
kconfig_merge() {
  declare -A config
  declare -a order

  # Read in the fragments
  _merge config order "$@"

  # Write out the merged config
  for var in "${order[@]}"; do
    printf '%s\n' "${config[${var}]}"
  done
}

#-------------------------------------------------------------------------------
# kconfig_demerge: Remove defconfig fragment from a defconfig file.
# $1: A full defconfig file
# $2..: defconfig fragments
# The demerged config is written to stdout.
kconfig_demerge() {
  declare -A config
  declare -a order
  local defconfig="$1"; shift

  _merge config order "$@"

  while read -r var setting; do
    if [[ "${config[${var}]-}" != "${setting}" ]]; then
      printf '%s\n' "${setting}"
    fi
    unset config["${var}"]
  done < <(_read_defconfig "${defconfig}")

  # Any settings left unset from the fragments must have been reset back to
  # defaults in the defconfig. Make sure we override the setting in the
  # fragment by putting a "default" setting in the output.
  for setting in "${!config[@]}"; do
    printf '# %s is default\n' "${setting}"
  done
}

#-------------------------------------------------------------------------------
# Merge kconfig fragments into a pair of arrays.
# $1: Name of associative array to hold config values keyed by setting name
# $2: Name of indexed array to hold order of config values
# $@: kconfig fragments
_merge() {
  declare -n _config="$1"; shift
  declare -n _order="$1"; shift

  for fragment; do
    while read -r var setting; do
      if [[ -z "${_config[${var}]-}" ]]; then
        _order+=("${var}")
      # else check if different and warn?
      fi
      _config["${var}"]="${setting}"
    done < <(_read_defconfig "${fragment}")
  done
}

#-------------------------------------------------------------------------------
# Read a defconfig file outputting the variable name as the first field of
# each line followed by the line from the kconfig file.
# e.g.
# "FOO=1" becomes "FOO FOO=1",
# "# BAR is not set" becomes "BAR # BAR is not set".
# "# BAR is default" is also parsed as a whiteout entry for a non-default value
# in an earlier config fragment where the later fragment resets a value to the
# default.
_read_defconfig() {
  local extract='s/^\(# \)\?\([A-Za-z0-9_]\+\)\(=.*\| is \(default\|not set\)\)$/\2 &/p'
  sed -n "${extract}" "$1"
}

#-------------------------------------------------------------------------------
[[ "$(caller)" != "0 "* ]] || main "$@"
