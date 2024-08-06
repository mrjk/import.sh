#!/bin/bash

set -eu -o pipefail

echo ==== BEFORE
set -o | grep errexit
echo ====

# set -x
source import.sh
# set +x


echo ==== AFTER
set -o | grep errexit
echo ====


# import lib ../lib/lib_demo.sh
# import lib ../lib/lib_custom.sh


exit 0

# # set -eu -o pipefail

# import bin demo-completion.sh

# echo "Apps started succesfully in strict mode: $?"