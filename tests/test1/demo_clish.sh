#!/bin/bash

set -eu

source import.sh
import lib https://raw.githubusercontent.com/mrjk/clish/main/clish.bash
import file https://raw.githubusercontent.com/mrjk/clish/main/README.md

echo SUCCES TESTS

# set -x
import file README2.md https://raw.githubusercontent.com/mrjk/clish/main/README.md
import lib  clish2.sh https://raw.githubusercontent.com/mrjk/clish/main/clish.bash
import lib  sub/clish2.sh https://raw.githubusercontent.com/mrjk/clish/main/clish.bash


# import2 file README3.md
# import2 file https://raw.githubusercontent.com/mrjk/clish/main/README.md
# import2 file test/README3.md

# set +x

echo SUCCES TESTS222

import get sub/clish2.sh

exit


echo "$SHLIB_FILE_MAP"


# set -x
echo Show file match
# _importsh__query_db README.md
# _importsh__query_db clish.bash

import get clish.bash
import get README.md

echo "SHLIB_LVL=$SHLIB_LVL"

exit 

# set +x

# import lib "https://raw.githubusercontent.com/qzb/is.sh/v1.1.2/is.sh"
# import lib "https://raw.githubusercontent.com/juan131/bash-libraries/master/lib/libfs.bash"


# Define your commands
cli__hello ()
{
  : "help=Show word string"
  echo "World YEAAAHHH"
}

cli__test1 ()
{
  : "help=Show word string"
  : "args=NAME [FILE]"

  [[ "$#" != 0 ]] || _script_die 6 "Missing name for command: test1"
  
  echo "Name: $1"
  echo "File: ${2:-<NO_FILE>}"
}


clish_init "$@"