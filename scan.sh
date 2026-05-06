#!/bin/bash

set -e
set -u
set -o pipefail
if [ "${DEBUG:-false}" = "true" ]; then
    set -x
fi

# =============================================================================
# Lacework Code Security Azure DevOps Pipeline Scanner
#
# Orchestrates /app/bin/unified-codesec.sh for SCA and IaC scanning.
# Runs inside a container built FROM lacework/codesec:latest.
#
# Workflows:
#   - push:          Scan current branch, upload results
#   - pull-request:  Scan source (new) + target (old), compare, post PR comment
# =============================================================================

# Environment setup that would normally be done by /app/bin/init
# (we override the entrypoint, so we must replicate the critical parts)
export PATH=/app/bin:${PATH}
export LW_NONINTERACTIVE=true

# Scanner toggles
export RUN_SCA="${RUN_SCA:-true}"
export RUN_IAC="${RUN_IAC:-true}"

# Validate required credentials
: "${LW_ACCOUNT:?'LW_ACCOUNT variable missing.'}"
: "${LW_API_KEY:?'LW_API_KEY variable missing.'}"
: "${LW_API_SECRET:?'LW_API_SECRET variable missing.'}"

export CI_PLATFORM="${CI_PLATFORM:-azuredevops}"

# soluble-cli reads SYSTEM_COLLECTIONURI for Azure DevOps detection,
# but Azure DevOps provides SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
export SYSTEM_COLLECTIONURI="${SYSTEM_COLLECTIONURI:-${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI:-}}"

# Resolve the actual source directory and ensure git trusts it
SOURCE_DIR="$(pwd)"
if [ -n "${WORKSPACE:-}" ]; then
    SOURCE_DIR="$(pwd)/${WORKSPACE}"
fi
git config --global --add safe.directory "$SOURCE_DIR"

if [ "${BUILD_REASON:-}" = "PullRequest" ]; then
    PR_ID="${SYSTEM_PULLREQUEST_PULLREQUESTID:?'SYSTEM_PULLREQUEST_PULLREQUESTID variable missing.'}"
    echo "=== Pull Request scanning (PR #${PR_ID}) ==="

    # Step 1: Scan source branch (new code — already checked out by Azure DevOps)
    export SCAN_TARGET=new
    export LW_CODESEC_GIT_BRANCH="${SYSTEM_PULLREQUEST_SOURCEBRANCH#refs/heads/}"
    SCAN_EXIT_CODE=0
    /app/bin/unified-codesec.sh scan || SCAN_EXIT_CODE=$?
    if [ "$SCAN_EXIT_CODE" -eq 1 ]; then
        echo "ERROR: Source branch scan failed with a fatal error (exit code 1)"
        exit 1
    elif [ "$SCAN_EXIT_CODE" -ne 0 ]; then
        echo "WARNING: Source branch scan exited with code $SCAN_EXIT_CODE"
    fi

    # Step 2: Checkout target branch
    TARGET_BRANCH="${SYSTEM_PULLREQUEST_TARGETBRANCH#refs/heads/}"
    echo "Checking out target branch: $TARGET_BRANCH"
    git -C "$SOURCE_DIR" fetch origin "$TARGET_BRANCH" 2>/dev/null || git -C "$SOURCE_DIR" fetch --unshallow 2>/dev/null || true
    git -C "$SOURCE_DIR" checkout "origin/$TARGET_BRANCH"

    # Step 3: Scan target branch (old code)
    export SCAN_TARGET=old
    export LW_CODESEC_GIT_BRANCH="$TARGET_BRANCH"
    SCAN_EXIT_CODE=0
    /app/bin/unified-codesec.sh scan || SCAN_EXIT_CODE=$?
    if [ "$SCAN_EXIT_CODE" -eq 1 ]; then
        echo "ERROR: Target branch scan failed with a fatal error (exit code 1)"
        exit 1
    elif [ "$SCAN_EXIT_CODE" -ne 0 ]; then
        echo "WARNING: Target branch scan exited with code $SCAN_EXIT_CODE"
    fi

    # Step 4: Generate UI link
    LW_ACCOUNT_SHORT=$(echo "${LW_ACCOUNT}" | sed 's/\.lacework\.net$//')
    ORG_NAME="${SYSTEM_TEAMFOUNDATIONCOLLECTIONURI:-}"
    PROJECT_NAME="${SYSTEM_TEAMPROJECT:-}"
    REPO_NAME="${BUILD_REPOSITORY_NAME:-}"
    if [ -n "$ORG_NAME" ] && [ -n "$PROJECT_NAME" ] && [ -n "$REPO_NAME" ]; then
        REPO_PATH=$(echo "azure-devops/${PROJECT_NAME}/${REPO_NAME}" | sed 's|/|%2F|g')
        export LW_UI_LINK="https://${LW_ACCOUNT_SHORT}.lacework.net/ui/investigation/codesec/applications/repositories/${REPO_PATH}/${TARGET_BRANCH}"
        if [ -n "${LW_SUBACCOUNT:-}" ]; then
            export LW_UI_LINK="${LW_UI_LINK}?accountName=${LW_SUBACCOUNT}"
        fi
    fi

    # Step 5: Run comparison (directly, to control markdown variant)
    RESULTS_DIR="/tmp/scan-results"
    if [ "$RUN_SCA" = "true" ] && [ -f "$RESULTS_DIR/sca/sca-old.sarif" ] && [ -f "$RESULTS_DIR/sca/sca-new.sarif" ]; then
        echo "Running SCA compare..."
        # TODO: Switch to --markdown-variant AzureDevOps when supported by the scanner, and remove sanitize-markdown.py
        SCA_COMPARE_ARGS="--new $RESULTS_DIR/sca/sca-new.sarif --old $RESULTS_DIR/sca/sca-old.sarif --markdown /tmp/sca-compare.md --markdown-variant GitHub"
        if [ -n "${LW_UI_LINK:-}" ]; then
            SCA_COMPARE_ARGS="$SCA_COMPARE_ARGS --ui-link $LW_UI_LINK"
        fi
        lacework sca compare $SCA_COMPARE_ARGS || echo "WARNING: SCA compare failed"
    fi

    if [ "$RUN_IAC" = "true" ] && [ -f "$RESULTS_DIR/iac/iac-old.json" ] && [ -f "$RESULTS_DIR/iac/iac-new.json" ]; then
        echo "Running IAC compare..."
        lacework iac compare --new "$RESULTS_DIR/iac/iac-new.json" --old "$RESULTS_DIR/iac/iac-old.json" --format markdown --save-result /tmp/iac-compare.md || echo "WARNING: IAC compare failed"
    fi

    # Step 6: Pick the best comparison markdown
    COMPARE_FILE=""
    if [ -f "/tmp/sca-compare.md" ] && [ -f "/tmp/iac-compare.md" ]; then
        python3 /merge-results.py
        if [ -f "/tmp/merged-compare.md" ]; then
            COMPARE_FILE="/tmp/merged-compare.md"
        fi
    elif [ -f "/tmp/sca-compare.md" ]; then
        COMPARE_FILE="/tmp/sca-compare.md"
    elif [ -f "/tmp/iac-compare.md" ]; then
        COMPARE_FILE="/tmp/iac-compare.md"
    fi

    if [ -n "$COMPARE_FILE" ]; then
        python3 /app/azure-integration/sanitize-markdown.py "$COMPARE_FILE" /tmp/comparison-sanitized.md
    fi

    # Step 7: Post/update PR comment via Azure DevOps API (Node.js)
    node /app/azure-integration/dist/index.js

else
    echo "=== Push scanning ==="
    BRANCH="${BUILD_SOURCEBRANCHNAME:-unknown}"
    echo "Scanning branch: $BRANCH"

    export LW_CODESEC_GIT_BRANCH="$BRANCH"
    export SCAN_TARGET=scan
    SCAN_EXIT_CODE=0
    /app/bin/unified-codesec.sh scan || SCAN_EXIT_CODE=$?
    if [ "$SCAN_EXIT_CODE" -eq 1 ]; then
        echo "ERROR: Scan failed with a fatal error (exit code 1)"
        exit 1
    elif [ "$SCAN_EXIT_CODE" -ne 0 ]; then
        echo "WARNING: Scan exited with code $SCAN_EXIT_CODE"
    fi

    echo "Push scan complete."
fi
