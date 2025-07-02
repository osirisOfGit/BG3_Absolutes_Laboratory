#!/bin/bash

# Get the current working directory
current_dir=$(pwd)

# Find the git root directory
git_root=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$git_root" ]; then
	echo "Error: Not in a git repository"
	exit 1
fi

# Calculate the relative path from git root to current directory
relative_path=$(realpath --relative-to="$git_root" "$current_dir")

# Construct the prefix path
prefix="$relative_path"

# Run the git subtree add command
git subtree pull --prefix="$prefix" git@github.com:osirisOfGit/BG3-Common-Dev-Utilities.git main
