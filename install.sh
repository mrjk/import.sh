#!/usr/bin/env bash
#
# A good old bash | curl script for import.sh.
#
set -euo pipefail

{ # Prevent execution if this script was only partially downloaded

  log() {
    echo "[installer] $*" >&2
  }

  die() {
    log "$@"
    exit 1
  }

  at_exit() {
    ret=$?
    if [[ $ret -gt 0 ]]; then
      log "the script failed with error $ret.\n" \
        "\n" \
        "To report installation errors, submit an issue to\n" \
        "    https://github.com/import.sh/import.sh/issues/new/choose"
    fi
    exit "$ret"
  }
  trap at_exit EXIT


  : "${use_sudo:=}"
  : "${bin_path:=}"

  if [[ -z "$bin_path" ]]; then
    log "bin_path is not set, you can set bin_path to specify the installation path"
    log "e.g. export bin_path=/path/to/installation before installing"
    log "looking for a writeable path from PATH environment variable"
    for path in $(echo "$PATH" | tr ':' '\n'); do
      if [[ -w $path ]]; then
        bin_path=$path
        break
      fi
    done
  fi
  if [[ -z "$bin_path" ]]; then
    die "did not find a writeable path in $PATH"
  fi
  echo "bin_path=$bin_path"

  if [[ -n "${version:-}" ]]; then
    release="tags/${version}"
  else
    release="latest"
    release="dev"
  fi
  echo "release=$release"

  log "looking for a download URL"
  download_url=https://raw.githubusercontent.com/mrjk/import.sh/$release/import.sh
  echo "download_url=$download_url"

  log "downloading"
  curl -o "$bin_path/import.sh" -fL "$download_url"
  chmod a+x "$bin_path/import.sh"

  cat <<DONE

The import.sh binary is now available in:

    $bin_path/import.sh

The last step is to configure your shell to use it. For example for bash, add
the following lines at the end of your ~/.bashrc:

    eval "\$(import.sh hook bash)"

Then restart the shell.

Thanks!
DONE
}
