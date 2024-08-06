#!/bin/bash

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


# Call directly to name the current script
# or target any source file to init lib. Also
# you can mention one relative path.
import_init()
{
  local d=${1-} # ${1:-$(ps -o args= $$)}
  
  local p=$(realpath "$0")
  local s="${p%/*}${d:+/$d}"
  
  SHLIB_PATH="${SHLIB_PATH:-${SHLIB_PATH_SHARED:-$HOME/.local/share/import.sh}}"
  SHLIB_PATH="$s${SHLIB_PATH:+:$SHLIB_PATH}"

  import_register "$p"
}


# This all the thing you need to source
# other libs.
import()
{
  local target=$1
  shift
  local p=$(PATH="$SHLIB_PATH" command -v "$target" || true )

  if [ -f "$p" ] ; then
    if import_register "$p"; then
      PWD="${p%/*}" . "$p" $@ || {
        local rc=$?  
        >&2 printf "Failed to load lib returned $rc: %s\n" "$p"
        return $rc; }
    fi
  else
    >&2 printf "No candidates for: %s\n" "$target"
    return 4
  fi
}


import_register()
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
import_init $@

