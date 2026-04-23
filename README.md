# FortiCNAPP Code Security for Azure DevOps Pipelines

Lacework Code Security integration for Azure DevOps. Runs SCA (Software Composition Analysis) and IaC (Infrastructure as Code) scanning on your repositories, posting comparison results as PR comments.

## Prerequisites

- A Lacework/FortiCNAPP account with API credentials
- An Azure DevOps project with a Git repository

## Setup

### 1. Configure Pipeline Variables

In your Azure DevOps project, go to **Pipelines > Library** and create a variable group (or add variables directly to the pipeline) with:

| Variable | Description | Secret? |
|----------|-------------|---------|
| `LW_ACCOUNT` | Lacework account name (e.g., `mycompany.fra`) | No |
| `LW_API_KEY` | Lacework API key | Yes |
| `LW_API_SECRET` | Lacework API secret | Yes |

### 2. Grant PR Comment Permissions

For the integration to post PR comments, the build service account needs "Contribute to pull requests" permission:

1. Go to **Project Settings > Repositories > Security**
2. Find your build service account (e.g., `<Project Name> Build Service`)
3. Set "Contribute to pull requests" to **Allow**

### 3. Add Pipeline Configuration

Add the following to your `azure-pipelines.yml`:

```yaml
trigger:
  - main

pr:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - checkout: self
    fetchDepth: 0
  - script: |
      docker run \
        -v $(Build.SourcesDirectory):/app/src \
        -e WORKSPACE=src \
        -e LW_ACCOUNT=$(LW_ACCOUNT) \
        -e LW_API_KEY=$(LW_API_KEY) \
        -e LW_API_SECRET=$(LW_API_SECRET) \
        -e BUILD_REASON=$(Build.Reason) \
        -e BUILD_SOURCEBRANCHNAME=$(Build.SourceBranchName) \
        -e BUILD_SOURCEBRANCH=$(Build.SourceBranch) \
        -e BUILD_REPOSITORY_ID=$(Build.Repository.ID) \
        -e BUILD_REPOSITORY_NAME=$(Build.Repository.Name) \
        -e SYSTEM_PULLREQUEST_SOURCEBRANCH=$(System.PullRequest.SourceBranch) \
        -e SYSTEM_PULLREQUEST_TARGETBRANCH=$(System.PullRequest.TargetBranch) \
        -e SYSTEM_PULLREQUEST_PULLREQUESTID=$(System.PullRequest.PullRequestId) \
        -e SYSTEM_TEAMFOUNDATIONCOLLECTIONURI=$(System.TeamFoundationCollectionUri) \
        -e SYSTEM_TEAMPROJECT=$(System.TeamProject) \
        -e SYSTEM_ACCESSTOKEN=$(System.AccessToken) \
        lacework/code-security-azure:latest
    displayName: 'Lacework Code Security'
    env:
      SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

**Important**: `fetchDepth: 0` is required so the scanner can check out the target branch for PR comparison. The `SYSTEM_ACCESSTOKEN` must be explicitly mapped in the `env:` block.

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `RUN_SCA` | `true` | Enable SCA (dependency vulnerability) scanning |
| `RUN_IAC` | `true` | Enable IaC (infrastructure-as-code) scanning |
| `DEBUG` | `false` | Enable debug logging |
| `LW_SUBACCOUNT` | _(empty)_ | Lacework sub-account for multi-tenant setups |

Add these as additional `-e` flags in the `docker run` command to customize behavior.

## How It Works

### Push Scanning
When code is pushed to a branch, the scanner runs SCA and IaC analysis and uploads results to the Lacework platform.

### Pull Request Scanning
When a PR is created or updated:
1. Scans the source branch (new code)
2. Checks out and scans the target branch (existing code)
3. Compares results to identify newly introduced issues
4. Posts (or updates) a PR comment thread with findings

The PR comment thread is updated in-place on subsequent runs — no duplicate comments.

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).

The scanning tools included in the Docker image are licensed separately.
