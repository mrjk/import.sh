#!/bin/bash

# Load import.sh
source import.sh

# Import the tools or library you need
import lib https://raw.githubusercontent.com/qzb/is.sh/v1.1.0/is.sh
import bin https://raw.githubusercontent.com/TheLocehiliosan/yadm/3.2.2/yadm
import bin yadm-3.1.0 https://raw.githubusercontent.com/TheLocehiliosan/yadm/3.1.0/yadm

# Test is.sh library
command -v is || true
echo "is version: $(is --version)"

# Test yadm-3.1.0 binary
command -v yadm
echo "yadm version: $(yadm --version)"

# Test yadm-3.1.0 binary
command -v yadm-3.1.0
echo "yadm-3.1.0 version: $(yadm --version)"

