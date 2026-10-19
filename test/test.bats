#!/usr/bin/env bats

setup() {
  DOCKER_IMAGE=${DOCKER_IMAGE:="test/code-security-azure"}

  echo "Building image..."
  docker build -t ${DOCKER_IMAGE}:test .
}

@test "Push scan finds vulnerabilities, weaknesses, secrets, and IaC violations" {
    run docker run \
        -e LW_ACCOUNT="$LW_ACCOUNT" \
        -e LW_API_KEY="$LW_API_KEY" \
        -e LW_API_SECRET="$LW_API_SECRET" \
        -e BUILD_REASON="IndividualCI" \
        -e BUILD_SOURCEBRANCHNAME="main" \
        -v $(pwd):$(pwd) \
        -w $(pwd) \
        ${DOCKER_IMAGE}:test

    echo "Status: $status"
    echo "Output: $output"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Total vulnerabilities:"* ]]
    [[ "$output" != *"Total vulnerabilities: 0"* ]]
    [[ "$output" == *"Total weaknesses:"* ]]
    [[ "$output" != *"Total weaknesses: 0"* ]]
    [[ "$output" == *"Total secrets:"* ]]
    [[ "$output" != *"Total secrets: 0"* ]]
    [[ "$output" == *"iac scan found"* ]]
    [[ "$output" == *"findings"* ]]
}

# Replaces the unified scanner with a stub that prints what scan.sh exported,
# so these tests run without credentials or network access.
run_with_stub_scanner() {
    stub_dir="$BATS_TEST_TMPDIR"
    cat > "$stub_dir/unified-codesec.sh" <<'STUB'
#!/bin/bash
echo "CI_PLATFORM=[${CI_PLATFORM:-}] LW_CODESEC_GIT_BRANCH=[${LW_CODESEC_GIT_BRANCH:-}]"
STUB
    chmod +x "$stub_dir/unified-codesec.sh"
    run docker run --rm \
        -e LW_ACCOUNT="test.lacework.net" \
        -e LW_API_KEY="test" \
        -e LW_API_SECRET="test" \
        "$@" \
        -v "$stub_dir/unified-codesec.sh:/app/bin/unified-codesec.sh" \
        -v $(pwd):$(pwd) \
        -w $(pwd) \
        ${DOCKER_IMAGE}:test
    echo "Status: $status"
    echo "Output: $output"
}

@test "Push scan outside Azure Pipelines warns and leaves platform and branch unset" {
    run_with_stub_scanner

    [ "$status" -eq 0 ] || false
    [[ "$output" == *"WARNING: TF_BUILD is not set"* ]] || false
    [[ "$output" == *"CI_PLATFORM=[] LW_CODESEC_GIT_BRANCH=[]"* ]] || false
}

@test "Push scan inside Azure Pipelines sets platform and branch without warning" {
    run_with_stub_scanner -e TF_BUILD="True" -e BUILD_SOURCEBRANCHNAME="main"

    [ "$status" -eq 0 ] || false
    [[ "$output" != *"WARNING: TF_BUILD is not set"* ]] || false
    [[ "$output" == *"CI_PLATFORM=[azuredevops] LW_CODESEC_GIT_BRANCH=[main]"* ]] || false
}
