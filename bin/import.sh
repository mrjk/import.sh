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

  # _importsh__logtrace "Prepend to $var: $path"
  # if [[ ":${!var}:" != *":$path:"* ]]; then
  if [ -d "$path" ] && [[ ":${!var}:" != *":$path:"* ]]; then
    _importsh__logtrace "Add prepend to '$var': $path"
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

  # _importsh__logtrace "Append to $var: $path"
  # if [[ ":${!var}:" != *":$path:"* ]]; then
  if [ -d "$path" ] && [[ ":${!var}:" != *":$path:"* ]]; then
    _importsh__logtrace "Add append to '$var': $path"
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
  _importsh__logtrace "Could not find file '$target' in '\$${var_name}'"
  # >&2 printf "%s\n" "WARN: Could not find file '$target' in "${var_name}""
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

  if [[ -z "$SHLIB_FILE_MAP" ]]; then
    >&2 printf "ERROR: Nothing loaded yet, please import '%s' first\n" "$name"
    return 1
  fi
  
  local match=$(grep -o ":$name=[^:]*:" <<< ":$SHLIB_FILE_MAP:")
  if [[ -z "$match" ]]; then
    >&2 printf "No candidates found for '%s'\n" "$name"

    echo "$SHLIB_FILE_MAP" | tr ':' '\n'
    return 1
  fi
  match=${match#*=}
  match="${match::${#match}-1}"

  printf "%s\n" "$match"
}


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
  export SHLIB_VERSION=0.0.1

  # Prepare user paths
  export SHLIB_PATH_NEEDLE=${SHLIB_PATH_NEEDLE:-$(cksum <<< "$path" | cut -f 1 -d ' ')}
  export SHLIB_DIR_SHARED=${SHLIB_DIR_SHARED:-$HOME/.local/share/import.sh}
  local dl_path="/tmp"
  if [[ -d "$HOME/.local" ]]; then
    export dl_path="$SHLIB_DIR_SHARED/downloads"
  fi
  export SHLIB_DIR_DOWNLOADS=${SHLIB_DIR_DOWNLOADS:-$dl_path}

  # Prepare lookup paths
  export SHLIB_LIB_PATHS=
  varpath_append SHLIB_LIB_PATHS "$root/lib"
  varpath_append SHLIB_LIB_PATHS "$root/libexec"
  varpath_append SHLIB_LIB_PATHS "$root"
  varpath_append SHLIB_LIB_PATHS "$SHLIB_DIR_SHARED/lib"
  varpath_append SHLIB_LIB_PATHS "$SHLIB_DIR_DOWNLOADS/$SHLIB_PATH_NEEDLE/lib"

  export SHLIB_FILE_PATHS=
  varpath_append SHLIB_FILE_PATHS "$root/files"
  varpath_append SHLIB_FILE_PATHS "$root"
  varpath_append SHLIB_FILE_PATHS "$SHLIB_DIR_SHARED/files"
  varpath_append SHLIB_FILE_PATHS "$SHLIB_DIR_DOWNLOADS/$SHLIB_PATH_NEEDLE/files"

  export SHLIB_BIN_PATHS=
  varpath_append SHLIB_BIN_PATHS "$root/bin"
  varpath_append SHLIB_BIN_PATHS "$root"
  varpath_append SHLIB_BIN_PATHS "$SHLIB_DIR_SHARED/bin"
  varpath_append SHLIB_BIN_PATHS "$SHLIB_DIR_DOWNLOADS/$SHLIB_PATH_NEEDLE/bin"

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
      >&2 printf "ERROR: Can't find target '%s' in: %s\n" "$target" "${kind_var}"
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
  local lib_name="import"
  
  cat <<EOF
  $app_name simplistic shell resource loader.

Load as libaray:
  source "$app_name"            Load import.sh library

Usage as library:
  $lib_name lib <TARGET> [<URL>]   Source a target shell library
  $lib_name bin <TARGET> [<URL>]   Ensure a target is available in \$PATH
  $lib_name file <TARGET> [<URL>]  Ensure a file is available

  $lib_name get <TARGET>           Get target file path
  $lib_name read <TARGET>          Get target file content

  $lib_name debug                  Show informations

Example:
#!/bin/bash
source "$app_name"
import bin https://raw.githubusercontent.com/TheLocehiliosan/yadm/3.2.2/yadm
import bin yadm-3.1.0 https://raw.githubusercontent.com/TheLocehiliosan/yadm/3.1.0/yadm

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
    debug)
      # env|sort
      echo "SHLIB_LIB_PATHS:"
      echo "$SHLIB_LIB_PATHS" | tr ':' '\n' | sed 's/^/  - /'
      echo "SHLIB_BIN_PATHS:"
      echo "$SHLIB_BIN_PATHS" | tr ':' '\n' | sed 's/^/  - /'
      echo "SHLIB_FILE_PATHS:"
      echo "$SHLIB_FILE_PATHS" | tr ':' '\n' | sed 's/^/  - /'
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
}


# =============================================================
# Script loader
# =============================================================

# if [[ "${BASH_SOURCE[0]}" =~ .*"$0"$ ]]; then
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

  >&2 printf "$0 is not meant to be called, but sourced in shell scripts. See help usage below:\n\n"
  _importsh__usage
  exit 1

else
  _importsh__init "$@"
fi

