#!/bin/bash
# colors.sh - Terminal color/style definitions
# Sourced by other lib files. Safe to source multiple times.

if [ -t 1 ]; then
    export C_RESET="\033[0m"
    export C_RED="\033[0;31m"
    export C_GREEN="\033[0;32m"
    export C_YELLOW="\033[0;33m"
    export C_BLUE="\033[0;34m"
    export C_CYAN="\033[0;36m"
    export C_BOLD="\033[1m"
else
    # Non-interactive shell (log redirected to file, CI, etc.) -> no colors
    export C_RESET=""
    export C_RED=""
    export C_GREEN=""
    export C_YELLOW=""
    export C_BLUE=""
    export C_CYAN=""
    export C_BOLD=""
fi
