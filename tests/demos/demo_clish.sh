#!/bin/bash

set -eu

source import.sh
import lib https://raw.githubusercontent.com/mrjk/clish/main/clish.bash


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

# Init clish
clish_init "$@"