#!/bin/bash

# Check if a file path is provided
if [ -z "$1" ]; then
    echo "Error: No input file provided."
    echo "Usage: $0 <path_to_lua_file>"
    exit 1
fi

# Process the Lua file to format comments for Doxygen
sed -e '/---/{
    :a;N;/\n---/!ba
    s/--- @brief/\/** \\brief/
    s/--- @/\/** @/
    s/-- @param \(.*\) \(.*\):/ * \\param \1 \2/g
    s/-- @return/ * \\return/g
    s/---/ * /g
    s/$/ \n **\//
}' $1
