#!/bin/bash


# =============================================================
# Documentation
# =============================================================

# Usage API:
# source import.sh ../lib
# import https://raw.githubusercontent.com/qzb/is.sh/master/is.sh
# import myapp_lib1.sh
# import myapp_lib2.sh

# package.sh file is.sh@v1.1.2 

# See: https://github.com/dylanaraps/pure-bash-bible/blob/master/README.md#get-the-terminal-size-in-lines-and-columns-from-a-script

# a vars from untouched shell: 
# bash: ( env -i bash --norc -o posix -c set ) | less
# sh: ( env -i sh --norc -c -- set )


# =============================================================
# Libraries
# =============================================================


# Check if current script is sourced or executed
# Source: https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
is_sourced() {
  # (return 0 2>/dev/null) && sourced=1 || sourced=0
  if [ -n "${ZSH_VERSION:-}" ]; then 
      case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
  else  # Add additional POSIX-compatible shell names here, if needed.
      case ${0##*/} in dash|-dash|bash|-bash|ksh|-ksh|sh|-sh) return 0;; esac
  fi
  return 1  # NOT sourced.
}

# # Return current shell options
# shell_options ()
# {
#   local oldstate="$(shopt -po; shopt -p)"
#   if [[ -o errexit ]]; then
#     oldstate="$oldstate; set -e"
#   fi
#   echo "$oldstate"
# }

# Portable realpath implementation in shell script
# Usage:
#  realpath [<PATH>]
# Example:
#  realpath "${BASH_SOURCE[0]}"
#  realpath ../bin/file
#  realpath
# Source: https://stackoverflow.com/a/45828988
realpath()
( 
  # TOFIX: Verify this function still work in strict mode
  # set -o errexit -o nounset
  declare link="${1:-$PWD}"
  
  # Try with real realpath first
  if command realpath "$link" 2>/dev/null; then return; fi

  # If it's a directory, just skip all this.
  if cd "$link" 2>/dev/null; then
    pwd -P "$link"; return 0
  fi

  # Resolve until we are out of links (or recurse too deep).
  declare n=0 limit=1024
  while [[ -L $link ]] && [[ $n -lt $limit ]]; do 
    n=$((n + 1))
    cd "$(dirname -- ${link})" \
      && link="$(readlink -- "${link##*/}")"
  done; cd "${link%/*}"

  # Check limit recursion
  [[ $n -lt $limit ]] || {
    >&2 printf "ERROR: Recursion limit ($limit) exceeded.\n"
    return 2; }

  printf '%s/%s\n' "$(pwd -P)" "${link##*/}"
)


# Add a <PATH> to <PATHS_VAR>
# Usage:
#  varpath_prepend <PATHS_VAR> <PATH>
# Example:
#  varpath_prepend PATH $PWD/app/bin
varpath_prepend() {
  local var=$1
  local path=$2

  _importsh__logtrace "Prepend to $var: $path"

  # if [ -d "$path" ] && [[ ":${!var}:" != *":$path:"* ]]; then
  if [[ ":${!var}:" != *":$path:"* ]]; then
    # _importsh__logtrace "Add prepend to '$var': $path"
    export "${var}=$path${!var:+":${!var}"}"
  fi
}

# Add a <PATH> to <PATHS_VAR>
# Usage:
#  varpath_append <PATHS_VAR> <PATH>
# Example:
#  varpath_append PATH $PWD/app/bin
varpath_append() {
  local var=$1
  local path=$2

  _importsh__logtrace "Append to $var: $path"

  # if [ -d "$path" ] && [[ ":${!var}:" != *":$path:"* ]]; then
  if [[ ":${!var}:" != *":$path:"* ]]; then
    # _importsh__logtrace "Add append to '$var': $path"
    export "${var}=${!var:+"${!var}:"}$path"
  fi
}

# Find first matching file called <NAME> in list of <PATHS_VAR>
# Usage:
#  varpath_find <PATHS_VAR> <NAME>
varpath_find ()
{
  local var_name=$1
  local target=$2
  local path=
  _importsh__logtrace "File lookup: '$target' from \$${var_name}"

  local paths=$(/usr/bin/tr ':' '\n' <<< "${!var_name}")
  while read path ; do
    file="$path/$target"
    if [[ -f "$file" ]]; then
      _importsh__logtrace "File lookup successed: $file"
      printf "%s\n" "$file"
      return 0
    else
      _importsh__logtrace "File lookup failed: $file"
    fi
  done <<<"$paths"
  >&2 printf "%s\n" "WARN: Could not find file '$target' in "${!var_name}""
  return 1
}

# Source a shell file
shell_source ()
{
  local path=$1
  shift 1 || true
  local rc=0

  PWD="${path%/*}" . "$path" $@ || \
    {
      rc=$?
      >&2 printf "Failed to load lib returned $rc: %s\n" "$p"
    }
  return $rc
}


# Download an <URL> into <PATH>
# Usage:
#  download_file <URL> <PATH>
download_file() {
  local url=$1
  local filename=$2

  # if [ -z "$url" ] || [ -z "$filename" ]; then
  #     echo "Usage: download_file <URL> <FILENAME>"
  #     return 1
  # fi

  # Create destination dir
  local parent="${filename%/*}"
  [[ -d "${parent}" ]] || mkdir -p "${parent}"

  # Find download tool
  if command -v curl > /dev/null; then
      curl -s -o "$filename" "$url"
  elif command -v wget > /dev/null; then
      wget -O "$filename" "$url"
  else
      printf "%s\n" "Neither curl nor wget is installed. Please install one of them to use this function."
      return 1
  fi

  # Report
  if [ $? -ne 0 ]; then
    >&2 printf "ERROR: Failed to download the file: %s\n" "$url"
    return 1
  else
    _importsh__logtrace "File downloaded successfully as: $filename"
  fi
}


# =============================================================
# Internal libraries: Registries
# =============================================================


# Register library
_importsh__register_lib()
{
  local path=$1
  local file dir
  file=${path##*/}
  dir=${path%/*}
  
  # Do initial load
  if [[ -z "${SHLIB-}" ]]; then
    SHSRC=$path
    SHSRC_FILE=$file
    SHSRC_DIR=$dir
  fi
  
  # Check if lib is not already loaded
  [[ ":${SHLIB-}:" != *:$file:* ]] || {
    >&2 printf "Library already loaded: %s\n" "$file"
    return 3
  }
  
  # Add module into SHLIB
  SHLIB="${SHLIB:+$SHLIB:}$file"
 
  # Importing vars
  IMPORT_PATH=$path
  IMPORT_FILE=$file
  IMPORT_DIR=$dir
}

# Retrieve path from name
_importsh__query_api ()
{
  
  local name=$1
  # echo $SHLIB_FILE_MAP
  local match=$(grep -o ":$name=[^:]*:" <<< ":$SHLIB_FILE_MAP:")

  if [[ -z "$match" ]]; then
    >&2 printf "No candidates found for '%s'\n" "$name"
    return 1
  fi
  match=${match#*=}
  match="${match::${#match}-1}"

  # echo "$match"
  printf "%s\n" "$match"

  # echo "REGISTER==== $1 $2"
  # varpath_prepend SHLIB_FILE_MAP "$name=$path"
}


# # Restore shell options
# _importsh__restore_shell ()
# {
#   local curr=$(shell_options)

#   # echo "SHOW DIFF"
#   # diff -u <(echo "${SHLIB_SHELL_OPTS}" ) <(echo "$curr") || true
#   # echo "END DIFF"

#   if [[ "$curr" != "$SHLIB_SHELL_OPTS" ]]; then
#     _importsh__logtrace "Restore shell options: "
#     eval "$SHLIB_SHELL_OPTS"
#   fi
# }


# =============================================================
# Internal libraries
# =============================================================

# Log to stderr trace logs
_importsh__logtrace ()
{
  if [[ "$SHLIB_TRACE" -eq 1 ]]; then
    >&2 printf "TRACE: %s\n" "$@"
  fi
}


# Prepare import.sh environment
_importsh__init()
{
  local d=${1-} # ${1:-$(ps -o args= $$)}
  
  local path=$(realpath "$0")
  local root="${path%/*}${d:+/$d}"

  export SHLIB_TRACE=${SHLIB_TRACE:-0}
  export SHLIB_LVL=${SHLIB_LVL:-0}${SHLIB_LVL:+$(( $SHLIB_LVL + 1 ))}
  export SHLIB_PATH_NEEDLE=$(cksum <<< "$path" | cut -f 1 -d ' ')

  # Prepare user paths
  local dl_path="/tmp"
  if [[ -d "$HOME/.local" ]]; then
    export dl_path="$HOME/.local/share/import.sh/downloads"
  fi
  export SHLIB_DIR_SHARED=${SHLIB_DIR_SHARED:-$HOME/.local/share/import.sh}
  export SHLIB_DIR_DOWNLOADS=${SHLIB_DIR_DOWNLOADS:-$dl_path}

  # Prepare lookup paths
  export SHLIB_LIB_PATHS=
  varpath_append SHLIB_LIB_PATHS "$root/lib"
  varpath_append SHLIB_LIB_PATHS "$root/libexec"
  varpath_append SHLIB_LIB_PATHS "$root"
  varpath_append SHLIB_LIB_PATHS "$SHLIB_DIR_SHARED/lib"
  varpath_append SHLIB_LIB_PATHS "$SHLIB_DIR_DOWNLOADS/lib"

  export SHLIB_FILE_PATHS=
  varpath_append SHLIB_FILE_PATHS "$root/files"
  varpath_append SHLIB_FILE_PATHS "$root"
  varpath_append SHLIB_FILE_PATHS "$SHLIB_DIR_SHARED/files"
  varpath_append SHLIB_FILE_PATHS "$SHLIB_DIR_DOWNLOADS/files"

  export SHLIB_BIN_PATHS=
  varpath_append SHLIB_BIN_PATHS "$root/bin"
  varpath_append SHLIB_BIN_PATHS "$root"
  varpath_append SHLIB_BIN_PATHS "$SHLIB_DIR_SHARED/bin"
  varpath_append SHLIB_BIN_PATHS "$SHLIB_DIR_DOWNLOADS/bin"

  # Self register and init
  export PATH
  export SHLIB_FILE_MAP=
  _importsh__register_lib "$path"
}


_importsh__import_api ()
{
  local kind=$1
  local target=$2
  local source_url=${3-}

  # Detect kind
  local path_suffix=
  local kind_var=
  case "$kind" in
    bin)
      kind_var=PATH
      path_suffix="bin" ;;
    lib) 
      kind_var=SHLIB_LIB_PATHS
      path_suffix="lib" ;;
    file)
      kind_var=SHLIB_FILE_PATHS
      path_suffix="files" ;;
    
    *) 
      >&2 printf "Import.sh does not support kind '%s', please use one of: %s\n" "$kind" "bin, lib or file"
      return 8
    ;;
  esac
  local dl_path="$SHLIB_DIR_DOWNLOADS/$SHLIB_PATH_NEEDLE/$path_suffix"

  # Update lookup paths
  if [[ -n "$kind_var" ]]; then
    varpath_prepend $kind_var "$dl_path"
  fi

  # Process URL
  if [[ -n "$source_url" ]]; then
    local dest="$dl_path/$target"

    # Fetch and install target
    if [[ ! -f "$dest" ]]; then
      download_file "$source_url" "$dest"
      if [[ "$kind" == 'bin' ]]; then
        chmod +x "$dest"
      fi
    fi
  fi

  # Process path
  if [[ -n "$target" ]]; then
    local full_path=$(varpath_find "$kind_var" "$target")

    if [[ ! -f "$full_path" ]]; then
      >&2 printf "No candidates found22 '%s' in: %s\n" "$target" "${SHLIB_LIB_PATHS//:/ }"
      return 4
    fi

    full_path=$(realpath "$full_path")

    # Source lib
    if [[ "$kind" == "lib" ]]; then
      if [ -f "$full_path" ] ; then
        if _importsh__register_lib "$full_path"; then
          shell_source "$full_path"
        fi
      fi
    fi

    varpath_prepend SHLIB_FILE_MAP "$target=$full_path"
    return
  fi

}



# =============================================================
# Public interface
# =============================================================

# Show import usage
_importsh__usage ()
{
  local app_name=${0##*/}
  cat <<EOF
  $app_name simplistic shell resource loader

Usage:
  $app_name get <TARGET>           Get target file path
  $app_name read <TARGET>          Get target file content

  $app_name lib <TARGET> [<URL>]   Source a target
  $app_name bin <TARGET> [<URL>]   Ensure a target is available in PATH
  $app_name file <TARGET> [<URL>]  Ensure a path is available
EOF
}


# This all the thing you need to source other libs.
# Usage:
#  import <TYPE> <NAME> [<>URL]
# Example:
#  import lib my_lib.sh
#  import lib lib/my_lib.sh
#  import lib https://raw.githubusercontent.com/qzb/is.sh/v1.1.2/is.sh
#  import bin https://raw.githubusercontent.com/qzb/is.sh/v1.1.2/is.sh
#  import file https://raw.githubusercontent.com/mrjk/clish/main/README.md
import()
{
  local cmd=$1
  shift 1

  # Dispatch commands
  case "$cmd" in
    get)
      _importsh__query_api $@
      return ;;
    read)
      cat "$(_importsh__query_api $@)"
      return ;;
    help|-h|--help)
      _importsh__usage
      return
      ;;
    *)
      kind=$cmd ;;
  esac

  # Parse args
  local target=
  local source_url=
  if [[ $# -eq 2 ]]; then
    target=$1
    source_url=$2
    shift 2
  elif [[ $# -eq 1 ]]; then

    # Smart argument detection
    case "$1" in
      http://*) 
        source_url=$1 ;;
      https://*)
        source_url=$1 ;;
      *)
        target=$1 ;;
    esac
    shift 1
    [[ -n "$target" ]] || target=${source_url##*/}
  else
    >&2 printf "Bad command usage\n"
    return 1
  fi

  # Do import
  _importsh__import_api "$kind" "$target" "$source_url" || return $?
  # return $?
}


# =============================================================
# Script loader
# =============================================================

# Prepare shell env
# set -x
# export SHLIB_SHELL_OPTS=$(shell_options)
# set -euo pipefail

# set +x
# Run import.sh
_importsh__init $@

# Broken
# if is_sourced; then
#   _importsh__init $@
# else
#   echo AS_EXECTUED
#   _importsh__init
#   import $@
# fi
