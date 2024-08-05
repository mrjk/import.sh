#!/bin/bash

set -eu

cd tests/

./import.sh.bats

./use_cases_import.sh.bats

echo SUCCESS
