#!/usr/bin/env bats


setup() {
    echo Setup phase
    importsh_script_file="../bin/import.sh"
    mkdir -p tmp/tests
}



# Test lib
# ===================

@test "Test import bin: download reference (is.sh)" {

    . "$importsh_script_file"

    local issh_version=1.1.0
    import bin https://raw.githubusercontent.com/qzb/is.sh/v$issh_version/is.sh
    local out=$(import get is.sh)
    [[ -f "$out" ]]
    grep "https://github.com/qzb/is.sh" "$out"

    # Test binary
    command -v is.sh
    is.sh --version | grep "$issh_version"
}

@test "Test import bin: explicit download reference (yadm)" {

    . "$importsh_script_file"

    local yadm_version=3.2.2
    import bin yadm2 https://raw.githubusercontent.com/TheLocehiliosan/yadm/$yadm_version/yadm
    local out=$(import get yadm)
    [[ ! -f "$out" ]]
    local out=$(import get yadm2)
    [[ -f "$out" ]]
    grep "yadm - Yet Another Dotfiles Manager" "$out"

    # Test binary
    yadm2 --version | grep "$yadm_version"
}


# Test binaries
# ===================

@test "Test import lib: download reference (bash-argparse)" {

    . "$importsh_script_file"

    local bash_argparse_version=1.8
    import lib https://raw.githubusercontent.com/Anvil/bash-argsparse/bash-argsparse-${bash_argparse_version}/argsparse.sh

    echo IMPORTED
    local out=$(import get argsparse.sh)
    [[ -f "$out" ]]
    grep "@version $bash_argparse_version" "$out"
    echo IMPORTED "$out"

    # Test lib
    set +u
    argsparse_use_option option1 "An option."
}

@test "Test import lib: explicit download reference (shflags)" {

    . "$importsh_script_file"

    local shflag_version=1.3.0
    import lib shflag2.sh https://raw.githubusercontent.com/kward/shflags/v${shflag_version}/shflags
    local out=$(import get shflag)
    [[ ! -f "$out" ]]
    local out=$(import get shflag2.sh)
    [[ -f "$out" ]]
    grep "FLAGS_VERSION='$shflag_version'" "$out"

    # Test lib
    flags_setLoggingLevel 1
}


# Test files
# ===================

@test "Test import file: download reference (Linux Readme)" {

    . "$importsh_script_file"

    local linux_version=6.10
    import file https://raw.githubusercontent.com/torvalds/linux/v${linux_version}/README
    local out=$(import get README)
    [[ -f "$out" ]]
    grep "Linux kernel" "$out"

}

@test "Test import file: explicit download reference (Linux Maintainers)" {

    . "$importsh_script_file"

    local linux_version=6.10
    import file MAINTAINERS.md https://raw.githubusercontent.com/torvalds/linux/v${linux_version}/MAINTAINERS
    local out=$(import get MAINTAINERS)
    [[ ! -f "$out" ]]
    local out=$(import get MAINTAINERS.md)
    [[ -f "$out" ]]
    grep "List of maintainers" "$out"

}
