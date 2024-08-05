#!/bin/bash

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

export SHLIB_SHELL_OPTS=$(set +o | grep 'pipefail\|xtrace\|errexit')
set -euo pipefail
#export	LC_COLLATE=C



# Source: https://stackoverflow.com/a/45828988
# or use system realpath !!!
# Use like this: realpath "${BASH_SOURCE[0]}"
# Usage:
#  realpath [<PATH>]
# Example:
#  realpath ../bin/file
#  realpath
realpath()
( 
  set -o errexit -o nounset
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
    >&2 printf "Error: Recursion limit ($limit) exceeded.\n" >&2
    return 2; }

  printf '%s/%s\n' "$(pwd -P)" "${link##*/}"
)


# Add a a <PATH> to <PATHS_VAR>
# Usage:
#  _importsh__path_add <PATHS_VAR> <PATH>
# Example:
#  _importsh__path_add PATH $PWD/app/bin
_importsh__path_add() {
  local var=$1
  local path=$2

  # if [ -d "$path" ] && [[ ":${!var}:" != *":$path:"* ]]; then
  if [[ ":${!var}:" != *":$path:"* ]]; then
    >&2 echo "DEBUG: Add path '$var': $path"
      export "${var}=$path${!var:+":${!var}"}"
  fi
}



# Call directly to name the current script
# or target any source file to init lib. Also
# you can mention one relative path.
_importsh__init()
{
  local d=${1-} # ${1:-$(ps -o args= $$)}
  
  local path=$(realpath "$0")
  local root="${path%/*}${d:+/$d}"

  export SHLIB_LVL=${SHLIB_LVL:-0}${SHLIB_LVL:+$(( $SHLIB_LVL + 1 ))}
  export SHLIB_PATH_NEEDLE=$(cksum <<< "$path" | cut -f 1 -d ' ')

  local dl_path="/tmp"
  if [[ -d "$HOME/.local" ]]; then
    export dl_path="$HOME/.local/share/import.sh/downloads"
  fi
  export SHLIB_DIR_SHARED=${SHLIB_DIR_SHARED:-$HOME/.local/share/import.sh}
  export SHLIB_DIR_DOWNLOADS=${SHLIB_DIR_DOWNLOADS:-$dl_path}

  export SHLIB_LIB_PATH="${SHLIB_DIR_SHARED}/lib:${SHLIB_DIR_DOWNLOADS}/lib"
  export SHLIB_FILE_PATH="${SHLIB_DIR_SHARED}/lib:${SHLIB_DIR_DOWNLOADS}/lib"
  export PATH
  export SHLIB_FILE_MAP=
  # _importsh__path_add SHLIB_LIB_PATH "$root"
  # _importsh__path_add SHLIB_LIB_PATH "$root/bin"
  # _importsh__path_add SHLIB_LIB_PATH "$root/libexec"
  _importsh__path_add SHLIB_LIB_PATH "$root/lib"
  _importsh__path_add SHLIB_FILE_PATH "$root/files"

  _importsh__path_add PATH "$SHLIB_DIR_SHARED/bin"

  _importsh__register_lib "$path"
}


# Find first matching file called <NAME> in list of <PATHS_VAR>
# Usage:
#  _importsh__find_in_paths <PATHS_VAR> <NAME>
_importsh__find_in_paths ()
{
  local var_name=$1
  local target=$2
  local path=

  local paths=$(/usr/bin/tr ':' '\n' <<< "${!var_name}")
  while  read  path ; do
    file="$path/$target"
    if [[ -f "$file" ]]; then
      >&2 printf "%s\n" "DEBUG: Found: $file"
      printf "%s\n" "$file"
      return 0
    fi
  done <<<"$paths"
  >&2 printf "%s\n" "DEBUG: Could not find file '$file' in "${!var_name}""
  return 1
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
      echo "Neither curl nor wget is installed. Please install one of them to use this function."
      return 1
  fi

  # Report
  if [ $? -eq 0 ]; then
      echo "File downloaded successfully as $filename"
  else
      echo "Failed to download the file."
      return 1
  fi
}

# Source a shell file
_importsh__source_file ()
{
  local path=$1
  shift 1 || true
  local rc=

  if [[ "$kind" == 'lib' ]]; then
    set +eu
    PWD="${path%/*}" . "$path" $@ || \
      {
        rc=$?
        >&2 printf "Failed to load lib returned $rc: %s\n" "$p"
      }
    set -eu
    return $rc
  fi


}


# import2()
# {
#   local command=$1
#   shift 1
#   echo
#   echo "FROM: $@"

#   # Parse args
#   local target=
#   local source_url=
#   if [[ $# -eq 2 ]]; then
#     target=$1
#     source_url=$2
#     shift 2
#   elif [[ $# -eq 1 ]]; then

#     case "$1" in
#       http://*) 
#         source_url=$1 ;;
#       https://*)
#         source_url=$1 ;;
#       *)
#         target=$1 ;;
#     esac
#     [[ -n "$target" ]] || target=${source_url##*/}
#     shift 1
#   else
#     >&2 printf "Bad command usage\n"
#     return 1
#   fi

#   echo target=$target
#   echo source_url=$source_url
# }


# This all the thing you need to source
# other libs.
# Usage:
#  import <TYPE> <NAME>
# Example:
#  import lib my_lib.sh
#  import lib lib/my_lib.sh
#  import lib https://raw.githubusercontent.com/qzb/is.sh/v1.1.2/is.sh
#  import bin https://raw.githubusercontent.com/qzb/is.sh/v1.1.2/is.sh
#  import file https://raw.githubusercontent.com/mrjk/clish/main/README.md
import()
{
  # set -x
  local cmd=$1
  shift 1

  # Dispatch commands
  case "$cmd" in
    get)
      _importsh__query_api $@
      return ;;
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
    [[ -n "$target" ]] || target=${source_url##*/}
    shift 1
  else
    >&2 printf "Bad command usage\n"
    return 1
  fi

  echo DEBUG: target=$target
  echo DEBUG: source_url=$source_url

  _importsh__import_api "$kind" "$target" "$source_url"
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
      kind_var=SHLIB_LIB_PATH
      path_suffix="lib" ;;
    file)
      kind_var=SHLIB_FILE_PATH
      path_suffix="files" ;;
    
    *) 
      >&2 printf "Import.sh does not support kind '%s', please use one of: %s\n" "$kind" "bin, lib or file"
      return 8
    ;;
  esac
  local dl_path="$SHLIB_DIR_DOWNLOADS/$SHLIB_PATH_NEEDLE/$path_suffix"

  # Update lookup paths
  if [[ -n "$kind_var" ]]; then
    _importsh__path_add $kind_var "$dl_path"
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

  # Expose vars
  local var_name=

  # Process path
  if [[ -n "$target" ]]; then
    local full_path=

    if [[ "$kind" == "lib" ]]; then
      full_path=$(_importsh__find_in_paths SHLIB_LIB_PATH "$target" || true )
      if [ -f "$full_path" ] ; then
        if _importsh__register_lib "$full_path"; then
          _importsh__source_file "$full_path"
          # return
        fi
      fi
    else
      full_path=$(_importsh__find_in_paths "$kind_var" "$target" || true )

    fi

    set +x
    _importsh__register_file "$target" "$full_path"
    return
  fi

  set +x
  >&2 printf "No candidates found '%s' in: %s\n" "$target" "${SHLIB_LIB_PATH//:/ }"
  return 4
}

# Register name and path in local DB
_importsh__register_file ()
{
  local name=$1
  local path=$2

  echo "REGISTER==== $1 $2"

  _importsh__path_add SHLIB_FILE_MAP "$name=$path"

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

  # _importsh__path_add SHLIB_FILE_MAP "$name=$path"

}


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

# Ignitiate a default instance
_importsh__init $@
set +x






# # set  -x

# # _importsh__path_add SHLIB_LIB_PATH tutu

# echo YOOO $SHLIB_LIB_PATH
# _importsh__path_add SHLIB_LIB_PATH tata
# _importsh__path_add SHLIB_LIB_PATH tutu
# echo YOOO $SHLIB_LIB_PATH
# set +x





















  # ###################  V1

  # local source_url=
  # if [[ $# -eq 2 ]]; then
  #   local target=$1
  #   local source_url=$2
  #   shift 2
  # elif [[ $# -eq 1 ]]; then
  #   local target=$1
  #   shift 1
  # else
  #   >&2 printf "Bad command usage\n"
  #   return 1
  # fi
  # # shift 2

  # # Prepare vars
  # local filename="${target##*/}"

  # # Detect local or remote
  # local is_path=false
  # local is_url=false
  # if [[ -z "$source_url" ]]; then
  #   case "$target" in
  #     http://*) is_url=true ;source_url=$target ;;
  #     https://*) is_url=true ;source_url=$target ;;
  #     *) is_path=true ;;
  #   esac
  # fi

  # ###################  V1 EOF

