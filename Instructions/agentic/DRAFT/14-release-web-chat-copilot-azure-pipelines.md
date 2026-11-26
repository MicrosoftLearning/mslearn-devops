---
lab:
  topic: Agentic
  title: "Deploy Web then Chat with Copilot-assisted Azure Pipelines"
  description: Use precreated CI and Copilot to configure multistage Web and Chat deployment.
  level: 400
  duration: 45 minutes
  islab: true
  primarytopics:
    - Azure DevOps
    - Azure Pipelines
    - Azure
    - GitHub Copilot
    - Agentic DevOps
---

# Deploy Web then Chat with Copilot-assisted Azure Pipelines

## Exercise scenario

EShopOnWebDN11 is a sample retail application with a .NET 11 Web storefront
for browsing a product catalog. Its separate, containerized ChatApi service
uses a model deployed in Microsoft Foundry to answer customer questions and
recommend products from that catalog.

Use the supplied CI pipeline to deploy EShopOnWebDN11 infrastructure,
deploy Web to Azure App Service, then approve and deploy Chat to Azure
Container Apps. No previous lab is required.

## Before you start

You need:

- Azure DevOps permissions to create a private project and administer its
  pipelines, service connections and environments.
- Git, VS Code, Azure CLI, PowerShell 7.4 or later and Copilot Chat/Agent access.
- Available Ubuntu hosted-agent capacity.
- An Azure subscription and a dedicated empty resource group.
- B1 App Service, Container Apps and Foundry model quota in the chosen regions.
- Your account must have Azure subscription **Owner** access for automatic
  service-connection setup, plus Microsoft Entra permissions to create app
  registrations and service principals.
- An authorized reviewer for the Chat environment.

This lab uses **OIDC workload identity federation with Microsoft Entra ID**.
The pipeline authenticates as a dedicated service principal without a client
secret. OIDC is the authentication method; the service principal is the identity.

In Task 3, you create and record:

- **Service connection name**: used by Azure Pipelines to authenticate to Azure.
- **Deployment service principal object ID**: from Microsoft Entra
  **Enterprise applications**, used for Azure role assignments.
- **Chat API application/client ID**: from a separate Microsoft Entra app
  registration, used to identify the Chat API when Web requests access tokens.

These names and IDs are configuration values, not secrets. Do not create or
store client secrets in YAML or Copilot prompts. Use only dedicated lab resources.

## Part 1: Prepare the supplied pipeline

## Task 1: Import the source and open it in VS Code

1. In **Azure DevOps in your browser**, create a private Git project named
   **eshop-release-ado-lab**.
1. Open **Repos > Files > Import a repository**. Import
   `https://github.com/MicrosoftLearning/mslearn-devops.git` without authentication.
1. Check that `main` contains `EShopOnWebDN11` and is the default branch.
1. Select **Repos > Files > Clone > Clone in VS Code**. Open the clone in
   an unused local folder.
1. In **VS Code > Terminal > PowerShell**, run:

   ```powershell
   git remote -v
   git switch main
   git pull --ff-only
   git status --short
   ```

   Check `origin` is your lab repository and the working tree is clean.

**Expected result:** The lab repository is open in VS Code.

## Task 2: Copy the precreated CI pipeline

The supplied YAML contains CI, Infrastructure and CD stages. CI builds, tests
and packages Web and Chat, including the Docker image, as the **Course**
artifact. The `deploy` parameter controls Azure deployment and is off by
default. Copy the pipeline now, configure access in the next task, then run
CI only. You will split CD into Web and Chat later.

1. In the **VS Code terminal**, run:

   ```powershell
   New-Item -ItemType Directory -Path .ado -Force | Out-Null
   Copy-Item EShopOnWebDN11\.ado\eshoponweb-chat-cicd.yml .ado\eshoponweb-release-lab.yml
   git add -- .ado\eshoponweb-release-lab.yml
   git --no-pager diff --cached
   git commit -m "Add supplied release pipeline"
   git push origin main
   ```

**Expected result:** The supplied pipeline file is committed to your repository.

## Task 3: Configure and run the supplied pipeline

### Create the OIDC service connection

1. In **Azure DevOps > Project settings > Service connections**, select
   **New service connection > Azure Resource Manager > Next**.
1. Select **App registration (automatic)** and
   **Workload identity federation** as the credential type.
1. Set **Scope level** to **Subscription**, select the lab subscription,
   and select the dedicated lab **Resource group**.
1. Name the connection **eshop-release-azure**. Leave **Grant access permission
   to all pipelines** unchecked and select **Save**.
1. Open the connection and select **Manage service principal**. In its
   Microsoft Entra app registration, record the **Application (client) ID**.
   Under **Certificates & secrets > Federated credentials**, confirm a
   federated credential exists. Do not add a client secret.
1. In **Azure Portal > Microsoft Entra ID > Enterprise applications**, find
   the application using that client ID. Open **Overview** and copy its
   **Object ID** for `deploymentPrincipalId`. Do not use the app registration's
   object ID or its client ID for this variable.
1. In **Azure Portal > Resource groups > your lab group > Access control (IAM) >
   Role assignments**, check that the deployment Enterprise application
   identified above has **Contributor** on this group.
1. If Contributor is missing, select **Add > Add role assignment**, choose
   **Contributor**, then open **Members**. Select **User, group, or service
   principal**, select the deployment Enterprise application, and complete
   **Review + assign**.
1. Add a **Role Based Access Control Administrator** role assignment to the
   same deployment Enterprise application using the same steps. Keep both
   assignments scoped to this lab group. Do not grant the pipeline
   subscription-wide Owner access.

### Register the Chat API in Microsoft Entra ID

1. In **Azure Portal > Subscriptions > your subscription > Properties**,
   record the **Subscription ID** and **Directory (tenant) ID**.
1. Back in **VS Code**, open a **PowerShell terminal** at the cloned repository
   root. Run the following and enter those IDs when prompted. Choose a unique
   registration name, such as `eshop-chat-api-lab01`, and sign in with your
   account that has the Microsoft Entra permissions listed in the prerequisites:

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

   The supplied helper creates your single-tenant Chat API registration,
   configures v2 access tokens and creates its service principal. It does not
   create a client secret. Run it once, not on every pipeline execution.
1. In **Azure Portal > Microsoft Entra ID > App registrations > All applications**,
   open the registration using the name you entered. Under **Overview**, check
   that its **Application (client) ID** matches the helper's printed
   **CHAT_API_CLIENT_ID**.
1. Use that client ID for the pipeline's `chatApiClientId` value in the next
   section. Do not use the deployment identity's client ID. If setup fails after
   creating the registration, correct the reported error and finish configuring
   that registration rather than rerunning the helper and creating another.

### Configure and run the pipeline

1. Back in **VS Code**, open `.ado/eshoponweb-release-lab.yml`, the copy created
   in Task 2. In its existing
   top-level `variables` section, replace the values listed below and save:

   | Variable | Value to enter |
   |---|---|
   | `azureServiceConnection` | `eshop-release-azure` |
   | `resourceGroup` | Dedicated lab resource-group name |
   | `location` | Hosting region with B1 and Container Apps quota |
   | `foundryLocation` | Region with model quota |
   | `chatApiClientId` | Separate Chat API registration's Application (client) ID |
   | `deploymentPrincipalId` | Deployment Enterprise application's Object ID |
   | `foundryDeploymentName` | Approved model deployment name, such as `gpt-5.4-mini` |

1. In **Azure DevOps > Pipelines > Environments**, create **Training** and
   **Training-Chat**.
1. Open **Training-Chat > Approvals and checks**. Add the authorized reviewer
   and save.
1. Back in the **VS Code terminal**, commit the configured values:

   ```powershell
   git add -- .ado\eshoponweb-release-lab.yml
   git --no-pager diff --cached
   git commit -m "Configure lab deployment targets"
   git push origin main
   ```

1. In **Azure DevOps > Pipelines > New pipeline**, select **Azure Repos Git**,
   the lab repository, then **Existing Azure Pipelines YAML file**.
   Choose `main` and `/.ado/eshoponweb-release-lab.yml`.
1. Run with **deploy unchecked**. Name the pipeline **eshoponweb-release-lab**.
   If resource permission is requested, authorize the named service connection
   for this pipeline only, then resume
   or rerun with **deploy unchecked**.
1. Under **Pipelines > Environments**, restrict **Training** and
   **Training-Chat** pipeline access to **eshoponweb-release-lab**.
1. Open the CI run. Check it succeeds, **Course** is published and deployment
   stages are skipped.

**Expected result:** Supplied CI passes. Microsoft Entra OIDC authentication,
the Chat API registration, deployment values and Chat approval are configured.

## Part 2: Deploy Web and Chat

## Task 4: Create Web and Chat stages with Copilot

1. Back in **VS Code's terminal**, create a Git branch:

   ```powershell
   git switch -c feature/web-then-chat
   git branch --show-current
   ```

   Check the output is `feature/web-then-chat`.
1. Open **Copilot Chat > Ask**. Attach the lab YAML,
   `EShopOnWebDN11/scripts/Deploy-Course.ps1` and
   `EShopOnWebDN11/infra/chat-foundation.bicep`. Enter:

   ```text
   Modify only .ado/eshoponweb-release-lab.yml.
   Keep supplied CI unchanged and preserve Infrastructure's existing steps.
   Replace CD with Web and Chat stages: CI -> Infrastructure -> Web -> Chat.
   Require successful predecessors, deploy=true and main only; block PR deployment.
   Each new Web/Chat job downloads this run's Course and DeploymentMetadata.
   Reuse the existing Azure CLI service connection and environment bindings.
   Web uses Training. Chat uses approval-protected Training-Chat.
   Web reads Metadata/foundation.json and deploys Course/Website/Web.zip using
   az webapp deploy, with ShopChat__Enabled=false.
   Use the Web script I will provide next and fail if /health/live is not ready.
   Do not call DeployWeb before Chat or rebuild applications in deployment.
   Chat calls PublishImage, DeployChat, ConfigureWeb, Verify in that order.
   Add a failure-only authenticated step to disable chat and retain failed status.
   Keep B1 and managed identities. Do not add slots, secrets or broader permissions.
   Wait for my Web script and health-check requirements, then show proposed YAML.
   Do not edit files, execute commands, commit, push or approve.
   ```

1. In **Copilot Chat > Ask**, paste the following script with the instruction:
   **Use this as the Web deployment portion of the generated AzureCLI@2
   task's inlineScript. Keep authentication and target-variable bindings
   from the supplied CD task.**

   This is PowerShell inside the generated YAML task, not a complete pipeline.
   Do not run it in your local terminal.

   ```powershell
   $ErrorActionPreference = 'Stop'
   $PSNativeCommandUseErrorActionPreference = $true
   $course = "$(Pipeline.Workspace)/Course"
   $metadata = "$(Pipeline.Workspace)/Metadata"
   $foundation = Get-Content "$metadata/foundation.json" -Raw | ConvertFrom-Json
   $manifest = Get-Content "$course/manifest.json" -Raw | ConvertFrom-Json
   $zip = "$course/Website/Web.zip"
   if ($manifest.sourceVersion -ne "$(Build.SourceVersion)") { throw 'Wrong source revision.' }
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
   Apply the reviewed Web and Chat stages, including the supplied Web script
   and health checks. Edit only .ado/eshoponweb-release-lab.yml.
   Do not run commands, change Azure resources, commit, push or approve.
   ```

   If Copilot requests approval, review the action before approving.
   Decline command execution or edits to other files. File edits may be
   applied without an approval prompt, depending on your settings.
1. In **Source Control**, confirm only `.ado/eshoponweb-release-lab.yml` changed.
   Review the generated YAML and check:
   - CI is unchanged; Infrastructure steps are preserved.
   - All deployment stages require `main`, `deploy=true` and successful predecessors.
   - Web waits for Infrastructure; Chat waits for successful Web.
   - Each new Web/Chat job downloads **Course** and **DeploymentMetadata**.
   - The Web task contains the supplied deployment script followed by health polling.
   - Chat targets **Training-Chat**.

   The generated Chat task's `inlineScript` should contain this sequence:

   ```powershell
   $ErrorActionPreference = 'Stop'
   $PSNativeCommandUseErrorActionPreference = $true
   foreach ($phase in 'PublishImage', 'DeployChat', 'ConfigureWeb', 'Verify') {
     & "$(Pipeline.Workspace)/Course/Scripts/Deploy-Course.ps1" -Phase $phase -ArtifactRoot "$(Pipeline.Workspace)/Course" -MetadataRoot "$(Pipeline.Workspace)/Metadata"
   }
   ```

   If Agent generated incorrect deployment commands, use the Web script above
   or this Chat script to replace only the corresponding deployment portion.
   Keep artifact downloads, authentication, Web health checks and failure-only
   Chat containment. Confirm native errors fail the task and failed Chat
   deployment disables `ShopChat__Enabled` without suppressing failure.
1. In the **VS Code terminal**, commit and push:

   ```powershell
   git add -- .ado\eshoponweb-release-lab.yml
   git --no-pager diff --cached
   git commit -m "Split Web and Chat deployment"
   git push --set-upstream origin feature/web-then-chat
   ```

1. In **Azure DevOps > Repos > Pull requests > New pull request**, select
   `feature/web-then-chat` as source and `main` as target.
   Review and complete it after applicable checks pass.

**Expected result:** The pipeline has separate Web and approved Chat stages.

## Task 5: Deploy Web, then approve Chat

1. In **Azure DevOps > Pipelines > eshoponweb-release-lab > Run pipeline**, select
   `main`, check **deploy**, and leave **useExistingFoundry unchecked**.
1. Check CI, Infrastructure and Web succeed. Open the Web task log and copy
   the printed Web URL.
1. Open that URL in your **browser**. Check the catalog loads and chat is disabled.
1. Navigate back to **Azure DevOps**. Ask the authorized reviewer to approve
   the waiting **Training-Chat** deployment.
1. Check the Chat stage completes successfully, including **Verify**.
1. Refresh the **Web page**, open Chat and enter:

   ```text
   Recommend a catalog mug costing less than 10 and give its price.
   ```

1. Check the response completes and its product card/price matches the catalog.
1. If a stage fails, copy the relevant error to **VS Code > Copilot Chat >
   Ask**, request a focused diagnosis, inspect the fix and rerun. Do not
   bypass tests, authentication or approval.

**Expected result:** Web and catalog chat are deployed and usable.

## Exercise Summary

In this lab, you:

- Used precreated CI to build Web, Chat and the Docker image without completing another lab.
- Configured Microsoft Entra OIDC authentication, a separate Chat API registration and a Chat environment approval.
- Used GitHub Copilot to create separate Web and Chat deployment stages.
- Deployed Web to Azure App Service, then approved Chat deployment to Azure Container Apps.
- Tested the storefront and Foundry-powered catalog chat.

## Clean up

1. In **Azure DevOps**, disable the lab pipeline.
1. In **Azure Portal > Resource groups**, open the dedicated lab group.
   Confirm its name, then select **Delete resource group**.
1. Wait until that group is removed. Do not delete shared identities,
   registrations or resource groups.
1. Remove **eshop-release-azure** and the two Microsoft
   Entra app registrations only if they were created exclusively for this lab.
   Keep any shared registration.
1. Delete only the dedicated Azure DevOps project and local clone if no longer needed.