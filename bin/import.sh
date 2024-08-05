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

set -euo pipefail
#export	LC_COLLATE=C

# Source: https://stackoverflow.com/a/45828988
# or use system realpath !!!
# Use like this: realpath "${BASH_SOURCE[0]}"

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


_importsh__path_add() {
  local var=$1
  local path=$2
  
  if [ -d "$path" ] && [[ ":${!var}:" != *":$path:"* ]]; then
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
  local s="${path%/*}${d:+/$d}"
  
  local dl_path="/tmp"
  if [[ -d "$HOME/.local" ]]; then
    export dl_path="$HOME/.local/share/import.sh/lib"
  fi
  export SHLIB_PATH_SHARED=${SHLIB_PATH_SHARED:-$HOME/.local/share/import.sh/lib}
  export SHLIB_PATH_DOWNLOADS=${SHLIB_PATH_DOWNLOADS:-$HOME/.local/share/import.sh/downloads}

  export SHLIB_PATH="${SHLIB_PATH_SHARED}:${SHLIB_PATH_DOWNLOADS}"
  _importsh__path_add SHLIB_PATH "$s"
  _importsh__path_add SHLIB_PATH "$s/bin"
  _importsh__path_add SHLIB_PATH "$s/lib"
  _importsh__path_add SHLIB_PATH "$s/libexec"

  export SHLIB_PATH_NEEDLE=$(cksum <<< "$path" | cut -f 1 -d ' ')

  _importsh__register "$path"
}

_importsh__command ()
{
  local target=$1
  local path2=

  local paths=$(/usr/bin/tr ':' '\n' <<< "${SHLIB_PATH}")
  while  read  path2 ; do
    file="$path2/$target"
    # >&2 printf "%s\n" "DEBUG: Searching: $file"
    if [[ -f "$file" ]]; then
      >&2 printf "%s\n" "DEBUG: Found: $file"
      printf "%s\n" "$file"
      return 0
    fi
  done <<<"$paths"
  >&2 printf "%s\n" "DEBUG: Could not find file '$file' in "${SHLIB_PATH//:/ }""
  return 1
}


download_file() {
    local url=$1
    local filename=$2

    # if [ -z "$url" ] || [ -z "$filename" ]; then
    #     echo "Usage: download_file <URL> <FILENAME>"
    #     return 1
    # fi

    if command -v curl > /dev/null; then
        curl -o "$filename" "$url"
    elif command -v wget > /dev/null; then
        wget -O "$filename" "$url"
    else
        echo "Neither curl nor wget is installed. Please install one of them to use this function."
        return 1
    fi

    if [ $? -eq 0 ]; then
        echo "File downloaded successfully as $filename"
    else
        echo "Failed to download the file."
        return 1
    fi
}

_importsh__source_file ()
{
  local path=$1
  shift 1 || true
  local rc=

  set +eu
  PWD="${path%/*}" . "$path" $@ || \
    {
      rc=$?
      >&2 printf "Failed to load lib returned $rc: %s\n" "$p"
    }
  set -eu
  return $rc
}


# This all the thing you need to source
# other libs.
import()
{
  # set -x
  local target=$1
  shift

  # Detect type
  local is_path=false
  local is_url=false
  case "$target" in
    http://*) is_url=true ;;
    https://*) is_url=true ;;
    *) is_path=true ;;
  esac


  if $is_path; then
    local path=$(PATH="$SHLIB_PATH" _importsh__command "$target" || true )

    if [ -f "$path" ] ; then
      if _importsh__register "$path"; then
        _importsh__source_file "$path"
        # PWD="${path%/*}" . "$path" $@ || {
        #   local rc=$?
        #   >&2 printf "Failed to load lib returned $rc: %s\n" "$p"
        #   return $rc; }
        return
      fi
    fi
  fi

  if $is_url; then
    local file="${target##*/}"
    local path="$SHLIB_PATH_DOWNLOADS/$SHLIB_PATH_NEEDLE"
    local dest="$path/$file"

    if [[ ! -f "$dest" ]]; then
      [[ -d "$path" ]] || mkdir -p "$path"
      download_file "$target" "$dest"
    fi

    _importsh__source_file "$dest"
    return
  fi  

  set +x
  >&2 printf "No candidates found '%s' in: %s\n" "$target" "${SHLIB_PATH//:/ }"
  return 4
}


_importsh__register()
{
  local f d n p=$1
  f=${p##*/}
  d=${p%/*}
  
  # Do initial load
  if [[ -z "${SHLIB-}" ]]; then
    SHSRC=$p
    SHSRC_FILE=$f
    SHSRC_DIR=$d
  fi
  
  # Check if lib is not already loaded
  [[ ":${SHLIB-}:" != *:$f:* ]] || {
    >&2 printf "Library already loaded: %s\n" "$f"
    return 3
  }
  
  # Add module into SHLIB
  SHLIB="${SHLIB:+$SHLIB:}$f"
 
  # Importing vars
  IMPORT_PATH=$p
  IMPORT_FILE=$f
  IMPORT_DIR=$d
}

# Ignitiate a default instance
_importsh__init $@
set +x






# # set  -x

# # _importsh__path_add SHLIB_PATH tutu

# echo YOOO $SHLIB_PATH
# _importsh__path_add SHLIB_PATH tata
# _importsh__path_add SHLIB_PATH tutu
# echo YOOO $SHLIB_PATH
# set +x