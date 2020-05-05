#!/bin/bash
# Priority: 10

# Determine library inatallation path
export SHLIB_PATH_SHARED="$BASHER_PREFIX/lib/bash"

# Load the library into the shell
source import.sh || \
  >&2 echo "Can not load import.sh."

# This part is really import to avoid shell
# to exit on any error.
set +eu

