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
    _importsh__path_add PATH_LIST tmp/
    _importsh__path_add PATH_LIST tmp/
    _importsh__path_add PATH_LIST tmp/tests
    _importsh__path_add PATH_LIST tmp/

    echo "$PATH_LIST"
    [[ "$PATH_LIST" == "tmp/tests:tmp/:val1:val2:val3" ]]

}


