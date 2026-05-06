# FortiCNAPP Code Security for Azure DevOps Pipelines

Lacework Code Security integration for Azure DevOps. Runs SCA (Software Composition Analysis) and IaC (Infrastructure as Code) scanning on your repositories, posting comparison results as PR comments.

## Prerequisites

- A Lacework/FortiCNAPP account with API credentials
- An Azure DevOps project with a Git repository

## Setup

### 1. Create a Variable Group for Lacework Credentials

1. Go to **Pipelines > Library** in your Azure DevOps project
2. Click **+ Variable group** and name it `lacework-credentials` (or any name you prefer)
3. Add the following variables:

| Variable | Description | Secret? |
|----------|-------------|---------|
| `LW_ACCOUNT` | Lacework account name (e.g., `mycompany.lacework.net`) | No |
| `LW_API_KEY` | Lacework API key | Yes |
| `LW_API_SECRET` | Lacework API secret | Yes |

4. Click **Save**

You can find your API credentials in the Lacework console under **Settings > API Keys**.

### 2. Add Pipeline YAML to Your Repository

Create an `azure-pipelines.yml` in the root of your repository:

```yaml
trigger:
  - main

pr:
  - main

variables:
  - group: lacework-credentials

pool:
  vmImage: 'ubuntu-latest'

steps:
  - checkout: self
    fetchDepth: 0

  - script: |
      docker run \
        -v $(Build.SourcesDirectory):/app/src \
        -e WORKSPACE=src \
        -e LW_ACCOUNT="$(LW_ACCOUNT)" \
        -e LW_API_KEY="$(LW_API_KEY)" \
        -e LW_API_SECRET="$(LW_API_SECRET)" \
        -e TF_BUILD \
        -e BUILD_REASON \
        -e BUILD_SOURCEBRANCHNAME \
        -e BUILD_SOURCEBRANCH \
        -e BUILD_REPOSITORY_ID \
        -e BUILD_REPOSITORY_NAME \
        -e BUILD_BUILDID \
        -e BUILD_BUILDNUMBER \
        -e BUILD_DEFINITIONNAME \
        -e SYSTEM_COLLECTIONURI \
        -e SYSTEM_TEAMFOUNDATIONCOLLECTIONURI \
        -e SYSTEM_TEAMPROJECT \
        -e SYSTEM_DEFINITIONID \
        -e SYSTEM_PULLREQUEST_SOURCEBRANCH \
        -e SYSTEM_PULLREQUEST_TARGETBRANCH \
        -e SYSTEM_PULLREQUEST_PULLREQUESTID \
        -e SYSTEM_ACCESSTOKEN \
        lacework/code-security-azure:latest
    displayName: 'FortiCNAPP Code Security Scan'
    env:
      LW_API_KEY: $(LW_API_KEY)
      LW_API_SECRET: $(LW_API_SECRET)
      SYSTEM_ACCESSTOKEN: $(System.AccessToken)
```

**Important notes:**
- `fetchDepth: 0` is required so the scanner can fetch and check out the target branch during PR comparison scans.
- Secret variables (`LW_API_KEY`, `LW_API_SECRET`, `SYSTEM_ACCESSTOKEN`) must be explicitly mapped in the `env:` block — Azure DevOps does not automatically pass secrets to scripts.

### 3. Create the Pipeline in Azure DevOps

1. Go to **Pipelines** in the left navigation
2. Click **New pipeline**
3. Select **Azure Repos Git** and pick your repository
4. Choose **Existing Azure Pipelines YAML file** and select `/azure-pipelines.yml`
5. Click **Run** (or Save, then Run)

After this initial setup, the pipeline will trigger automatically on pushes and PRs.

### 4. Grant PR Comment Permissions

For the integration to post PR comments, the build service account needs write access to pull requests:

1. Go to **Project Settings > Repos > Repositories**
2. Select your repository
3. Click the **Security** tab
4. Find the build service account — it will be named something like `<Project Name> Build Service (<Org Name>)`
5. Set **Contribute to pull requests** to **Allow**

Without this permission, scanning will work but PR comments will fail with a `TF401027` error.

### 5. Enable PR Build Validation (Recommended)

Azure DevOps YAML `pr:` triggers may not fire in all configurations. For reliable PR scanning, set up a branch policy:

1. Go to **Repos > Branches**
2. Click the `...` menu on your target branch (e.g., `main`) and select **Branch policies**
3. Under **Build Validation**, click **+ Add build policy**
4. Select your pipeline, leave defaults, and save

This ensures the scan runs automatically whenever a PR targets that branch.

## Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `LW_SUBACCOUNT` | _(empty)_ | Lacework sub-account for multi-tenant setups |

Add these as additional `-e` flags in the `docker run` command.

## How It Works

### Push Scanning
When code is pushed to a branch, the scanner runs SCA and IaC analysis and uploads results to the Lacework platform.

### Pull Request Scanning
When a PR is created or updated:
1. Scans the source branch (new code)
2. Checks out and scans the target branch (existing code)
3. Compares results to identify newly introduced issues
4. Posts (or updates) a PR comment thread with the findings

The PR comment thread is updated in-place on subsequent pushes — no duplicate comments are created.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `TF401027: You need the Git 'PullRequestContribute' permission` | Build service lacks PR write access | Follow step 4 above to grant permissions |
| PR scan doesn't trigger automatically | YAML PR triggers not active or branch policy missing | Set up Build Validation as described in step 5 |
| `fatal: could not read Password` errors in scan logs | Scanner tries `git remote show origin` inside the container — this is expected and non-fatal | No action needed; the scanner continues successfully |
| `ERROR unknown command "sca" for "lacework"` | Container running with wrong HOME directory | Ensure you're using `lacework/code-security-azure:latest` (not the base `lacework/codesec` image directly) |
| Scan exits with code 160 | Violations found that exceed the severity threshold | This is expected behavior — the scan completed successfully and found issues |

## License

Apache 2.0 — see [LICENSE.txt](LICENSE.txt).

The scanning tools included in the Docker image are licensed separately.
