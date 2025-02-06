#!/bin/bash -eu

set -o pipefail

# Add bin directory to PATH
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PATH="$REPO_ROOT/bin:$PATH"

# Create a temporary git repository for testing
create_tmp_repo_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    echo "$temp_dir"
}

# Initialize the test repository
init_test_repo() {
    local repo_dir="$1"
    ORIGINAL_DIR=$(pwd)
    
    # Create a bare repo to act as remote
    mkdir -p "$repo_dir/remote"
    git init --bare "$repo_dir/remote"
    
    # Create the working repo
    mkdir -p "$repo_dir/local"
    pushd "$repo_dir/local"

    # Initialize git repo
    git init
    git config user.email "test@example.com"
    git config user.name "Test User"

    # Add remote
    git remote add origin "$repo_dir/remote"

    # Create and commit initial files on main branch
    echo "initial" > initial.txt
    git add initial.txt
    git commit -m "Initial commit"

    # Create base branch
    git checkout -b base
    echo "base" > base.txt
    git add base.txt
    git commit -m "Base branch commit"
    
    # Push base branch to remote
    git push -u origin base

    # Create PR branch
    git checkout -b pr
}

# Clean up the temporary repository
cleanup_git_repo() {
    # Return to original directory if we're still in the temp dir
    if [[ "$(pwd)" == "$1/local" ]]; then
        cd "$ORIGINAL_DIR"
    fi
    rm -rf "$1"
}

# Helper to assert expected output
assert_output() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    if [[ "$actual" != "$expected" ]]; then
        echo "❌ Assertion failed: $message"
        echo "Expected: $expected"
        echo "Actual  : $actual"
        exit 1
    fi
}
