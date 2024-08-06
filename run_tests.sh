#!/bin/bash

set -eu

cd tests/

for i in *.bats; do
  echo "INFO: Run test $i"
  bats "$i"
done

echo SUCCESS
