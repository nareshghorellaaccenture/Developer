# Salesforce Deployment Using GitHub Actions

## Overview

This GitHub Actions workflow automatically deploys Salesforce metadata whenever code is pushed to the `feature1` branch.

The workflow performs the following tasks:

1. Determines the GitHub Environment from the branch name.
2. Displays pipeline and repository information.
3. Checks out the source code.
4. Checks whether the Salesforce CLI is available.
5. Installs the Salesforce CLI when required.
6. Authenticates to Salesforce using an SFDX Auth URL.
7. Verifies the authenticated Salesforce org.
8. Deploys metadata from the `force-app` directory.

---

## Branch-to-Environment Mapping

| Git branch | GitHub Environment |
|---|---|
| `main` | `PROD` |
| `uat` | `UAT` |
| `qa` | `QA` |
| Any other branch, including `feature1` | `DEV` |

> **Note:** The current push trigger runs only for the `feature1` branch. Therefore, this workflow will use the `DEV` environment unless additional branches are added to the trigger.

---

## Required Repository Structure

```text
salesforce-project/
├── .github/
│   └── workflows/
│       └── salesforce-deployment.yml
├── force-app/
├── sfdx-project.json
└── README.md
```

---

## Required GitHub Secret

Create the following secret in the appropriate GitHub Environment or repository:

| Secret name | Purpose |
|---|---|
| `SFDX_AUTH_URL` | Authenticates the GitHub Actions runner to the target Salesforce org |

Go to:

```text
GitHub Repository > Settings > Environments > DEV > Environment secrets
```

Add a secret named:

```text
SFDX_AUTH_URL
```

The value should follow this general format:

```text
force://<client-id>:<client-secret>:<refresh-token>@<instance-url>
```

> **Security:** Never commit an SFDX Auth URL, access token, refresh token, client secret, certificate, or private key to the repository.

---

## GitHub Actions Workflow

Save the following content as:

```text
.github/workflows/salesforce-deployment.yml
```

```yaml
name: Salesforce Deployment

on:
  push:
    branches:
      - feature1

jobs:
  deploy-to-salesforce:
    runs-on: ubuntu-24.04

    # Map the Git branch to a GitHub Environment.
    environment:
      name: ${{ github.ref_name == 'main' && 'PROD' ||
                github.ref_name == 'uat' && 'UAT' ||
                github.ref_name == 'qa' && 'QA' ||
                'DEV' }}

    steps:
      # -------------------------------------------------------
      # Display pipeline information
      # -------------------------------------------------------
      - name: Display deployment information
        run: |
          echo "=========================================="
          echo " Salesforce Deployment Pipeline Started"
          echo "=========================================="
          echo "Branch      : ${{ github.ref_name }}"
          echo "Repository  : ${{ github.repository }}"
          echo "Triggered by: ${{ github.actor }}"
          echo "=========================================="

      # -------------------------------------------------------
      # 1. Check out the repository
      # -------------------------------------------------------
      - name: Checkout repository
        uses: actions/checkout@v7

      # -------------------------------------------------------
      # 2. Check whether Salesforce CLI is installed
      # -------------------------------------------------------
      - name: Check Salesforce CLI
        id: check-sf
        shell: bash
        run: |
          if command -v sf >/dev/null 2>&1; then
            echo "Salesforce CLI is already installed."
            sf --version
            echo "installed=true" >> "$GITHUB_OUTPUT"
          else
            echo "Salesforce CLI is not installed."
            echo "installed=false" >> "$GITHUB_OUTPUT"
          fi

      # -------------------------------------------------------
      # 3. Install Salesforce CLI when it is unavailable
      # -------------------------------------------------------
      - name: Install Salesforce CLI
        if: steps.check-sf.outputs.installed != 'true'
        run: |
          echo "Installing Salesforce CLI..."
          npm install --global @salesforce/cli
          echo "Salesforce CLI installation completed."
          sf --version

      # -------------------------------------------------------
      # 4. Authenticate using the SFDX Auth URL
      # -------------------------------------------------------
      - name: Authenticate to Salesforce
        shell: bash
        run: |
          echo "${{ secrets.SFDX_AUTH_URL }}" > sfdx_auth_url.txt

          sf org login sfdx-url \
            --sfdx-url-file sfdx_auth_url.txt \
            --alias GitHubDeveloper \
            --set-default

          rm -f sfdx_auth_url.txt

      # -------------------------------------------------------
      # 5. Verify Salesforce authentication
      # -------------------------------------------------------
      - name: Verify Salesforce org
        run: |
          sf org display --target-org GitHubDeveloper

      # -------------------------------------------------------
      # 6. Deploy metadata to Salesforce
      # -------------------------------------------------------
      - name: Deploy to Salesforce
        run: |
          sf project deploy start \
            --source-dir force-app \
            --target-org GitHubDeveloper \
            --wait 30
```

---

## Workflow Explanation

### 1. Trigger

The workflow starts whenever code is pushed to `feature1`:

```yaml
on:
  push:
    branches:
      - feature1
```

To enable deployment from other branches, add them to the list:

```yaml
on:
  push:
    branches:
      - feature1
      - qa
      - uat
      - main
```

### 2. GitHub Environment Selection

The workflow selects a GitHub Environment based on the source branch:

```yaml
environment:
  name: ${{ github.ref_name == 'main' && 'PROD' ||
            github.ref_name == 'uat' && 'UAT' ||
            github.ref_name == 'qa' && 'QA' ||
            'DEV' }}
```

This allows each environment to have separate Salesforce credentials, protection rules, and approvals.

### 3. Salesforce CLI Check

The workflow uses `command -v sf` to determine whether the Salesforce CLI is available. It writes the result to `$GITHUB_OUTPUT`, allowing the installation step to run conditionally.

### 4. Salesforce Authentication

The `SFDX_AUTH_URL` secret is temporarily written to a file and used by this command:

```bash
sf org login sfdx-url \
  --sfdx-url-file sfdx_auth_url.txt \
  --alias GitHubDeveloper \
  --set-default
```

The temporary authentication file is removed immediately after login.

### 5. Salesforce Deployment

The workflow deploys metadata from `force-app` and waits for up to 30 minutes:

```bash
sf project deploy start \
  --source-dir force-app \
  --target-org GitHubDeveloper \
  --wait 30
```

---

## Recommended Enhancements

Consider adding the following steps before production deployment:

- Validate the deployment before applying changes.
- Run all required Apex tests.
- Store separate `SFDX_AUTH_URL` secrets in `DEV`, `QA`, `UAT`, and `PROD` environments.
- Configure required reviewers for the `PROD` GitHub Environment.
- Add a timeout to prevent a stalled job from running indefinitely.
- Use separate Salesforce aliases for each environment.
- Add a post-deployment verification or smoke-test step.

### Example: Deployment with Apex Tests

```yaml
- name: Deploy and run Apex tests
  run: |
    sf project deploy start \
      --source-dir force-app \
      --target-org GitHubDeveloper \
      --test-level RunLocalTests \
      --wait 30
```

---

## Troubleshooting

### `SFDX_AUTH_URL` is empty or unavailable

Confirm that the secret exists in the GitHub Environment selected by the branch. For `feature1`, the secret should be configured in `DEV`.

### Authentication fails

Generate a fresh SFDX Auth URL from a securely authenticated Salesforce CLI session and update the GitHub secret.

### The `force-app` directory is not found

Make sure the workflow runs from the Salesforce project root and that `force-app` is committed to the repository.

### Deployment times out

Increase the wait value when the deployment includes many components or Apex tests:

```bash
--wait 60
```

---

## Important Security Practices

- Do not print the `SFDX_AUTH_URL` value in workflow logs.
- Do not commit `sfdx_auth_url.txt` to GitHub.
- Protect the `PROD` environment with required reviewers.
- Rotate Salesforce credentials when access changes.
- Apply the minimum required permissions to the Salesforce integration user.
