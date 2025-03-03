#!/usr/bin/env bats

setup() {
    # Get the directory of the test file
    DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    
    # Create a temporary directory for test artifacts
    export TEMP_DIR="$(mktemp -d)"
    export DIFF_DEPENDENCIES_FOLDER="$TEMP_DIR"
    export COMMENT_FILE="$DIFF_DEPENDENCIES_FOLDER/comment_body.txt"
    export TLDR_DIFF_DEPENDENCIES_FILE="$TEMP_DIR/tldr_dependencies.txt"
    export TLDR_DIFF_BUILD_ENV_FILE="$TEMP_DIR/tldr_build_env.txt"
    export DIFF_DEPENDENCIES_FILE="$TEMP_DIR/dependencies.txt"
    export DIFF_BUILD_ENV_FILE="$TEMP_DIR/build_env.txt"
    
    # Mock Buildkite environment variables
    export BUILDKITE_BUILD_URL="https://buildkite.com/test/build"
    export BUILDKITE_JOB_ID="job123"
}

teardown() {
    rm -rf "$TEMP_DIR"
}

@test "should create comment with both TLDRs and trees when content is small" {
    # Create test dependency files with small content
    echo "org.test:library:2.0.0 (from 1.0.0)" > "$TLDR_DIFF_DEPENDENCIES_FILE"
    echo "org.test:build-tool:3.0.0 (from 2.0.0)" > "$TLDR_DIFF_BUILD_ENV_FILE"
    
    echo "+org.test:library:2.0.0
-org.test:library:1.0.0" > "$DIFF_DEPENDENCIES_FILE"
    
    echo "+org.test:build-tool:3.0.0
-org.test:build-tool:2.0.0" > "$DIFF_BUILD_ENV_FILE"

    # Run the script
    run "$DIR/../bin/craft_comment_with_dependency_diff"

    # Assert success
    [ "$status" -eq 0 ]
    
    # Read generated comment
    local comment_content=$(<"$COMMENT_FILE")
    
    # Assert both sections are present
    [[ "$comment_content" =~ "## Project dependencies changes" ]]
    [[ "$comment_content" =~ "## Build environment changes" ]]
    
    # Assert both TLDRs are present
    [[ "$comment_content" =~ "org.test:library:2.0.0 (from 1.0.0)" ]]
    [[ "$comment_content" =~ "org.test:build-tool:3.0.0 (from 2.0.0)" ]]
    
    # Assert both trees are present
    [[ "$comment_content" =~ "+org.test:library:2.0.0" ]]
    [[ "$comment_content" =~ "+org.test:build-tool:3.0.0" ]]
    
    # Assert no "too large" warnings
    [[ ! "$comment_content" =~ "tree is too large" ]]
}

@test "should handle mixed tree sizes with large project dependencies" {
    # Create large project dependencies tree
    echo "org.test:library:2.0.0 (from 1.0.0)" > "$TLDR_DIFF_DEPENDENCIES_FILE"
    
    # Generate a large tree for project dependencies
    local large_tree=""
    for i in {1..1100}; do
        large_tree+="+org.test:large-lib-${i}:2.0.0
-org.test:large-lib-${i}:1.0.0
"
    done
    echo "$large_tree" > "$DIFF_DEPENDENCIES_FILE"
    
    # Create small build environment changes
    echo "org.test:build-tool:3.0.0 (from 2.0.0)" > "$TLDR_DIFF_BUILD_ENV_FILE"
    echo "+org.test:build-tool:3.0.0
-org.test:build-tool:2.0.0" > "$DIFF_BUILD_ENV_FILE"

    # Run the script
    run "$DIR/../bin/craft_comment_with_dependency_diff"

    # Assert success
    [ "$status" -eq 0 ]
    
    # Read generated comment
    local comment_content=$(<"$COMMENT_FILE")

    echo "$comment_content";
    
    # Assert both sections are present
    [[ "$comment_content" =~ "## Project dependencies changes" ]]
    [[ "$comment_content" =~ "## Build environment changes" ]]
    
    # Assert both TLDRs are present
    [[ "$comment_content" =~ "org.test:library:2.0.0 (from 1.0.0)" ]]
    [[ "$comment_content" =~ "org.test:build-tool:3.0.0 (from 2.0.0)" ]]
    
    # Assert small build environment tree is present
    [[ "$comment_content" =~ "+org.test:build-tool:3.0.0" ]]
    [[ "$comment_content" =~ "-org.test:build-tool:2.0.0" ]]
    
    # Assert large project dependencies tree is replaced with warning
    [[ "$comment_content" =~ "Project dependencies tree is too large" ]]
    [[ "$comment_content" =~ "View it in Buildkite artifacts" ]]
    
    # Assert only one "too large" warning
    [[ ! "$comment_content" =~ "Build environment tree is too large" ]]
}
