---
lab:
  topic: Agentic
  title: "Deploy Web then Chat with Copilot-assisted GitHub Actions"
  description: Use precreated CI and Copilot to configure multijob Web and Chat deployment.
  level: 400
  duration: 45 minutes
  islab: true
  primarytopics:
    - GitHub
    - GitHub Actions
    - Azure
    - GitHub Copilot
    - Agentic DevOps
---

# Deploy Web then Chat with Copilot-assisted GitHub Actions

## Exercise scenario

EShopOnWebDN11 is a sample retail application with a .NET 11 Web storefront
for browsing a product catalog. Its separate, containerized ChatApi service
uses a model deployed in Microsoft Foundry to answer customer questions and
recommend products from that catalog.

Use supplied CI to deploy EShopOnWebDN11 infrastructure, deploy Web to Azure
App Service, then approve and deploy Chat to Azure Container Apps.
No previous lab is required.

## Before you start

You need:

- GitHub access to create a repository, run Actions and configure environments
  with required reviewers under the available plan.
- Git, VS Code, Azure CLI, PowerShell 7.4 or later and Copilot Chat/Agent access.
- Available Ubuntu hosted-runner capacity.
- An Azure subscription, dedicated empty resource group and B1/Container Apps/model quota.
- Your account must have Azure subscription **Owner** access to assign roles,
  plus Microsoft Entra permissions to create app registrations and service principals.
- An authorized reviewer for Chat.

This lab uses **OIDC workload identity federation with Microsoft Entra ID**.
GitHub Actions authenticates as a dedicated service principal without a client
secret. OIDC is the authentication method; the service principal is the identity.

In Task 3, you create and record:

- **Deployment Application (client) ID**: used by `azure/login`.
- **Deployment service principal Object ID**: from **Enterprise applications**,
  used for Azure role assignments.
- **Chat API Application (client) ID**: from a separate registration, used
  to identify the Chat API when Web requests access tokens.
- **Directory (tenant) ID** and **Subscription ID**: identify the Azure target.

These IDs are configuration values, not secrets. Do not create or store client
secrets in YAML or Copilot prompts. Use only dedicated lab resources.

## Part 1: Prepare the supplied workflow

## Task 1: Clone the source and create your repository

1. In **VS Code**, open an integrated PowerShell terminal in an unused parent
   directory. Run:

   ```powershell
   git clone --branch main --single-branch https://github.com/MicrosoftLearning/mslearn-devops.git eshop-release-github-lab
   Set-Location eshop-release-github-lab
   git remote rename origin upstream
   code .
   ```

1. In **GitHub in your browser**, create an empty repository named
   **eshop-release-github-lab**. Leave initialization options unselected.
1. In the **VS Code terminal**, replace `YOUR-OWNER` and run:

   ```powershell
   git remote add origin https://github.com/YOUR-OWNER/eshop-release-github-lab.git
   git remote -v
   git push --set-upstream origin main
   ```

1. Check `origin` is your repository and `EShopOnWebDN11` is present.

**Expected result:** Your lab repository is open in VS Code.

## Task 2: Register the precreated CI workflow

The supplied workflow contains `ci`, `infrastructure` and `cd` jobs. CI builds,
tests and packages Web and Chat, including the Docker image, as **Course**.
The manual-run `deploy` input controls Azure deployment and is off by default.
In this task, run CI only; you will split `cd` into `web` and `chat` later.

1. In the **VS Code terminal**, run:

   ```powershell
   New-Item -ItemType Directory -Path .github\workflows -Force | Out-Null
   Copy-Item EShopOnWebDN11\.github\workflows\eshoponweb-chat-cicd.yml .github\workflows\eshoponweb-release-lab.yml
   git add -- .github\workflows\eshoponweb-release-lab.yml
   git --no-pager diff --cached
   git commit -m "Add supplied release workflow"
   git push origin main
   ```

1. In **GitHub > Actions**, select **eShop .NET 11 Web and Foundry Chat**
   and **Run workflow**.
   Select `main` and leave **deploy unchecked**.
1. Check CI succeeds, **Course** is published and deployment jobs are skipped.

**Expected result:** Supplied CI builds Web, Chat and the Docker image.

## Task 3: Configure variables, OIDC and approval

### Create the deployment identity in Microsoft Entra ID

1. In **Azure Portal > Subscriptions > your subscription > Properties**,
   record the **Subscription ID** and **Directory (tenant) ID**.
1. In **Azure Portal > Microsoft Entra ID**, check you are in that tenant.
   Open **App registrations > New registration**.
1. Name the application **eshoponweb-github-deploy**. Select **Accounts in this
   organizational directory only (Single tenant)**, leave the redirect URI
   empty and select **Register**.
1. Under **Overview**, record the **Application (client) ID** for
   `AZURE_CLIENT_ID` and **Directory (tenant) ID** for `AZURE_TENANT_ID`.
   Do not create a client secret.
1. In **Microsoft Entra ID > Enterprise applications**, find the application
   using that client ID. Open **Overview** and copy its **Object ID** for
   `DEPLOYMENT_PRINCIPAL_ID`. Do not use the app registration's Object ID
   or its client ID for this variable.
1. In **Azure Portal > Resource groups > your lab group > Access control (IAM)**,
   select **Add > Add role assignment** and choose **Contributor**.
   Under **Members**, select **User, group, or service principal**, select
   the deployment Enterprise application, and complete **Review + assign**.
1. Add **Role Based Access Control Administrator** to the same application
   using the same steps. Scope both assignments to this lab group only;
   do not grant the pipeline subscription-wide Owner access.

### Configure GitHub environments and OIDC trust

1. In **GitHub > Settings > Environments**, create **Training** and
   **Training-Chat**. In each environment's **Deployment branches and tags**,
   select **Selected branches and tags** and add a branch rule for `main`.
1. Open **Training-Chat**. Under **Deployment protection rules**, add the
   authorized required reviewer and save.
1. In **Azure Portal > Microsoft Entra ID > App registrations**, open the
   **eshoponweb-github-deploy** registration. Under **Certificates & secrets >
   Federated credentials**, select **Add credential**, then **GitHub Actions
   deploying Azure resources**.
1. Enter your GitHub owner and repository **eshop-release-github-lab**.
   Select **Environment** as the entity type and enter **Training** as the
   environment. Name the credential **github-training**.
   Keep the generated issuer `https://token.actions.githubusercontent.com`
   and audience `api://AzureADTokenExchange`, then select **Add**.
1. Add a second credential for the same owner and repository, using
   **Training-Chat** as the environment and **github-training-chat** as the name.
1. Check that both credentials reference your exact owner/repository and
   their matching environment names. Do not create branch, pull-request or
   wildcard trust in place of these environment credentials.

### Register the Chat API in Microsoft Entra ID

1. Back in **VS Code**, open a **PowerShell terminal** at the cloned repository
   root. Run the following, entering the tenant and subscription IDs recorded
   above. Choose a unique registration name and sign in with your account:

   ```powershell
   $ErrorActionPreference = 'Stop'
   $PSNativeCommandUseErrorActionPreference = $true
   $tenantId = Read-Host "Directory (tenant) ID of the Azure subscription"
   $subscriptionId = Read-Host "Azure subscription ID"
   $registrationName = Read-Host "Unique Chat API registration name (letters, numbers, hyphens)"
   az login --tenant $tenantId
   az account set --subscription $subscriptionId
   .\EShopOnWebDN11\scripts\New-ChatApiRegistration.ps1 -DisplayName $registrationName -TenantId $tenantId
   ```

   The helper creates a separate single-tenant API registration with v2 access
   tokens and its service principal, without a client secret. Run it once,
   not on every workflow execution.
1. In **Azure Portal > Microsoft Entra ID > App registrations > All applications**,
   open the registration using the name you entered. Check its **Application
   (client) ID** matches the helper's printed **CHAT_API_CLIENT_ID**.
   Use this value for `CHAT_API_CLIENT_ID`, not the deployment identity's client ID.
   If setup fails after creation, finish configuring the reported registration
   rather than rerunning the helper and creating another.

### Configure workflow variables and check OIDC login

1. Back in **GitHub > Settings > Secrets and variables > Actions > Variables**,
   add repository variables:

   | Variable | Value to enter |
   |---|---|
   | `AZURE_CLIENT_ID` | Deployment registration's Application (client) ID |
   | `AZURE_TENANT_ID` | Subscription tenant ID |
   | `AZURE_SUBSCRIPTION_ID` | Lab subscription ID |
   | `DEPLOYMENT_PRINCIPAL_ID` | Deployment Enterprise application's Object ID |
   | `AZURE_RESOURCE_GROUP` | Dedicated lab resource-group name |
   | `AZURE_LOCATION` | Hosting region with B1 and Container Apps quota |
   | `FOUNDRY_LOCATION` | Region with model quota |
   | `FOUNDRY_DEPLOYMENT_NAME` | Approved model deployment name, such as `gpt-5.4-mini` |
   | `CHAT_API_CLIENT_ID` | Separate Chat API registration's Application (client) ID |

1. In **VS Code**, open `.github/workflows/eshoponweb-release-lab.yml`, the copy
   created in Task 2. Check its `infrastructure` and `cd` jobs use
   `azure/login@v2` and job-level `id-token: write`, as in this example:

   ```yaml
   permissions:
     contents: read
     id-token: write
   steps:
     - uses: azure/login@v2
       with:
         client-id: ${{ vars.AZURE_CLIENT_ID }}
         tenant-id: ${{ vars.AZURE_TENANT_ID }}
         subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
   ```

   This is the authentication portion of each deployment job, not a complete
   workflow. Keep the existing artifact downloads and deployment steps.
   CI must not receive `id-token: write`. The Web and Chat jobs you create
   next must retain this OIDC login pattern.

**Expected result:** Your deployment identity, two environment-specific OIDC
credentials, separate Chat API registration, variables and Chat approval are configured.

## Part 2: Deploy Web and Chat

## Task 4: Create Web and Chat jobs with Copilot

1. Back in **VS Code's terminal**, create a Git branch:

   ```powershell
   git switch -c feature/web-then-chat
   git branch --show-current
   ```

   Check the output is `feature/web-then-chat`.
1. Open **Copilot Chat > Ask**. Attach the lab workflow,
   `EShopOnWebDN11/scripts/Deploy-Course.ps1` and
   `EShopOnWebDN11/infra/chat-foundation.bicep`. Enter:

   ```text
   Modify only .github/workflows/eshoponweb-release-lab.yml.
   Keep supplied ci unchanged and preserve infrastructure's existing steps.
   Replace cd with web and chat jobs: ci -> infrastructure -> web -> chat.
   Require successful needs, deploy=true and main only; block PR deployment.
   Each new web/chat job downloads this run's Course and DeploymentMetadata.
   Reuse azure/login@v2 with OIDC and target variables.
   Grant id-token: write only in deploy jobs; do not use a client secret.
   Web uses Training. Chat uses approval-protected Training-Chat.
   Web reads Metadata/foundation.json and deploys Course/Website/Web.zip using
   az webapp deploy, with ShopChat__Enabled=false.
   Use the Web script I will provide next and fail if /health/live is not ready.
   Do not call DeployWeb before Chat or rebuild applications in deployment.
   Chat calls PublishImage, DeployChat, ConfigureWeb, Verify in that order.
   Add a failure-only authenticated step to disable chat and retain failed status.
   Keep B1, managed identities and non-cancelling release concurrency.
   Do not add slots, secrets or broader permissions.
   Wait for my Web script and health-check requirements, then show proposed YAML.
   Do not edit files, execute commands, commit, push or approve.
   ```

1. In **Copilot Chat > Ask**, paste the following script with the instruction:
   **Use this as the Web deployment portion of a step with shell: pwsh,
   inside its run block, after azure/login. Keep the supplied target variables.**

   This is PowerShell inside the generated workflow step, not a complete
   workflow. Do not run it in your local terminal.

   ```powershell
   $ErrorActionPreference = 'Stop'
   $PSNativeCommandUseErrorActionPreference = $true
   $course = "$PWD/Course"
   $metadata = "$PWD/Metadata"
   $foundation = Get-Content "$metadata/foundation.json" -Raw | ConvertFrom-Json
   $manifest = Get-Content "$course/manifest.json" -Raw | ConvertFrom-Json
   $zip = "$course/Website/Web.zip"
   if ($manifest.sourceVersion -ne "${{ github.sha }}") { throw 'Wrong source revision.' }
   if ((Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $manifest.webZipSha256) {
     throw 'Web package mismatch.'
   }
   az webapp config appsettings set --resource-group $env:AZURE_RESOURCE_GROUP --name $foundation.webAppName.value --settings ShopChat__Enabled=false -o none
   az webapp deploy --resource-group $env:AZURE_RESOURCE_GROUP --name $foundation.webAppName.value --src-path $zip --type zip --clean true --restart true
   Write-Host "Web URL: $($foundation.webAppUrl.value)"
   ```

1. Still in **Copilot Chat > Ask**, request Web liveness polling after that
   script: require 200 from
   `webAppUrl.value + /health/live`; allow up to 12 attempts, 30-second request
   timeouts and 10-second waits. Retry only startup 404/502/503 or logged
   timeouts; fail on other errors or exhaustion. Ask Copilot to show the
   complete proposed YAML changes.
1. Review the proposal. Switch **Copilot Chat** to **Agent** mode and send:

   ```text
   Apply the reviewed web and chat jobs, including the supplied Web script
   and health checks. Edit only .github/workflows/eshoponweb-release-lab.yml.
   Do not run commands, change Azure resources, commit, push or approve.
   ```

   If Copilot requests approval, review the action before approving.
   Decline command execution or edits to other files. File edits may be
   applied without an approval prompt, depending on your settings.
1. In **Source Control**, confirm only the lab workflow changed.
   Review the generated YAML and check:
   - CI is unchanged; infrastructure steps are preserved.
   - All deploy jobs require `main`, `deploy=true` and successful predecessors.
   - `web` needs `infrastructure`; `chat` needs successful `web`.
   - Each new `web`/`chat` job downloads **Course** and **DeploymentMetadata** and uses OIDC.
   - The Web step contains the supplied deployment script followed by health polling.
   - Chat targets **Training-Chat**.

   The generated Chat step should use `shell: pwsh` and contain this sequence
   in its `run` block:

   ```powershell
   $ErrorActionPreference = 'Stop'
   $PSNativeCommandUseErrorActionPreference = $true
   foreach ($phase in 'PublishImage', 'DeployChat', 'ConfigureWeb', 'Verify') {
     & ./Course/Scripts/Deploy-Course.ps1 -Phase $phase -ArtifactRoot "$PWD/Course" -MetadataRoot "$PWD/Metadata"
   }
   ```

   If Agent generated incorrect deployment commands, use the Web script above
   or this Chat script to replace only the corresponding deployment portion.
   Keep artifact downloads, authentication, Web health checks and failure-only
   Chat containment. Confirm native errors fail the step and failed Chat
   deployment disables `ShopChat__Enabled` without suppressing failure.
1. In the **VS Code terminal**, commit and push:

   ```powershell
   git add -- .github\workflows\eshoponweb-release-lab.yml
   git --no-pager diff --cached
   git commit -m "Split Web and Chat deployment"
   git push --set-upstream origin feature/web-then-chat
   ```

1. In **GitHub > Pull requests > New pull request**, select `main` as base
   and `feature/web-then-chat` as compare.
   Review and merge it after applicable checks pass.

**Expected result:** The workflow has separate Web and approved Chat jobs.

## Task 5: Deploy Web, then approve Chat

1. In **GitHub > Actions > eShop .NET 11 Web and Foundry Chat > Run workflow**,
   select `main`.
   Check **deploy** and leave **useExistingFoundry unchecked**.
1. Check CI, infrastructure and web succeed. Copy the Web URL from its task log.
1. Open that URL in your **browser**. Check the catalog loads and chat is disabled.
1. Back in **GitHub Actions**, use **Review deployments** and ask the authorized
   reviewer to approve **Training-Chat**.
1. Check `chat` completes successfully, including **Verify**.
1. Refresh the **Web page**, open Chat and enter:

   ```text
   Recommend a catalog mug costing less than 10 and give its price.
   ```

1. Check the response completes and its product card/price matches the catalog.
1. If a job fails, copy the relevant error to **VS Code > Copilot Chat > Ask**,
   request a focused diagnosis, inspect the fix and rerun. Do not bypass
   tests, authentication or approval.

**Expected result:** Web and catalog chat are deployed and usable.

## Exercise Summary

In this lab, you:

- Used precreated CI to build Web, Chat and the Docker image without completing another lab.
- Created a Microsoft Entra deployment identity, configured GitHub OIDC trust and registered the separate Chat API.
- Restricted deployment permissions to the lab resource group and configured a Chat environment approval.
- Used GitHub Copilot to create separate Web and Chat deployment jobs.
- Deployed Web to Azure App Service, then approved Chat deployment to Azure Container Apps.
- Tested the storefront and Foundry-powered catalog chat.

## Troubleshooting

| Problem | Action |
|---|---|
| OIDC sign-in fails for Chat | Check the exact Training-Chat federated credential and token permission. |
| Deployment cannot assign roles | Check the deployment identity's Contributor and Role Based Access Control Administrator assignments on the lab group. |
| B1 or model quota is unavailable | Stop and obtain an approved quota or region change. |
| Chat remains pending | Check the required reviewer in **Settings > Environments > Training-Chat**. |

## Clean up

1. In **GitHub**, disable the release workflow.
1. In **Azure Portal > Resource groups**, open the dedicated lab group.
   Confirm its name, then select **Delete resource group**.
1. Wait until that group is removed. Do not delete shared identities,
   registrations or resource groups.
1. Remove the **eshoponweb-github-deploy** and Chat API app registrations only
   if they were created exclusively for this lab. Keep any shared registration.
1. Delete only the dedicated GitHub repository and local clone if no longer needed.

## Additional resources

- [GitHub deployment environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- [Authenticate GitHub Actions to Azure with OIDC](https://learn.microsoft.com/azure/developer/github/connect-from-azure-openid-connect)
- [Chat API registration helper](../../../EShopOnWebDN11/scripts/New-ChatApiRegistration.ps1)
- [Supplied release workflow](../../../EShopOnWebDN11/.github/workflows/eshoponweb-chat-cicd.yml)
