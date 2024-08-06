#!/usr/bin/env bats


setup() {
    echo Setup phase

    script_file="../bin/import.sh"
    # export dst_tarball="${BATS_TMPDIR}/dst.tar.gz"
    # export src_dir="${BATS_TMPDIR}/src_dir"


    mkdir -p tmp/tests
    # rm -rf "${dst_tarball}" "${src_dir}"
    # mkdir "${src_dir}"
    # touch "${src_dir}"/{a,b,c}
}

main() {
    echo RUN MAIN-Start
    . "$script_file"
    echo RUN MAIN-Over

#   bash "${BATS_TEST_DIRNAME}"/package-tarball
}

# @test "fail when \$src_dir and \$dst_tarball are unbound" {
#   unset src_dir dst_tarball

#   run main

#   echo "$output"
#   [ "${status}" -eq 0 ]
# }


@test "Test file downloading" {

    local url="https://raw.githubusercontent.com/torvalds/linux/master/README"
    local dest=tmp/test_download_1/MY_FILE

    main
    download_file "$url" "$dest"
    grep "Linux kernel" "$dest"

}


@test "Test path_add" {

    main
    export PATH_LIST="val1:val2:val3"
    varpath_prepend PATH_LIST tmp/
    varpath_prepend PATH_LIST tmp/
    varpath_prepend PATH_LIST tmp/tests
    varpath_prepend PATH_LIST tmp/

    echo "$PATH_LIST"
    [[ "$PATH_LIST" == "tmp/tests:tmp/:val1:val2:val3" ]]

}


# Return current shell options
shell_options ()
{
  local oldstate="$(shopt -po; shopt -p)"
  if [[ -o errexit ]]; then
    oldstate="$oldstate; set -e"
  fi
  echo "$oldstate"
}


@test "Test strict mode persistance: Off" {

    local before=$(shell_options)
    main
    local after=$(shell_options)

    echo "SHOW DIFF"
    diff -u <(echo "${before}" ) <(echo "$after") || true
    echo "END DIFF"

    [[ "$before" == "$after" ]]
}

@test "Test strict mode persistance: On" {

    set -euo pipefail
    local before=$(shell_options)
    main
    local after=$(shell_options)

    [[ "$before" == "$after" ]]
}
