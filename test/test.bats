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
