#!/bin/bash

# Get the current working directory
current_dir=$(pwd)

# Find the git root directory
git_root=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$git_root" ]; then
	echo "Error: Not in a git repository"
	exit 1
fi

# Get the last folder in the git root path
prefix=$(basename "$git_root")

# Run the git subtree push command
git subtree push --prefix="$prefix/Mods/$prefix/ScriptExtender/Lua/Utilities" git@github.com:osirisOfGit/BG3-Common-Dev-Utilities.git main
