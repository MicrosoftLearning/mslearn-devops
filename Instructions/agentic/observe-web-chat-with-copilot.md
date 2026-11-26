---
lab:
  topic: Agentic
  title: "Observe Web and Chat with Copilot"
  description: Correlate telemetry, verify Copilot-assisted KQL, investigate a controlled chat failure and improve a runbook.
  level: 400
  duration: 45 minutes
  islab: true
  primarytopics:
    - Azure Monitor
    - Application Insights
    - Azure Developer CLI
    - GitHub Copilot
    - Agentic DevOps
---

# Observe Web and Chat with Copilot

## Exercise scenario

EShopOnWebDN11 has a .NET 11 storefront on Azure App Service and a ChatApi
on Azure Container Apps. ChatApi uses a Microsoft Foundry model to answer
questions about the storefront's current catalog.

Deploy the sample with Azure Developer CLI (`azd`), observe a successful chat,
then investigate a reversible configuration fault. Use Copilot to help with
queries and analysis, but verify its conclusions against actual telemetry.
Finish with a reviewed runbook and a feedback item in your chosen platform.

This is one lab for Azure DevOps and GitHub learners. No build or deployment
lab is required, and no pipeline is created. Allow **45 guided minutes** after
setup; provisioning, builds, model availability and telemetry ingestion add
waiting time.

## Before you start

You need:

- VS Code with GitHub Copilot Chat/Agent access, Git, PowerShell 7.4 or later,
  Azure CLI, Azure Developer CLI, the .NET 11 SDK and Node.js.
- Docker with a running Linux container engine and Linux/amd64 image support.
- An Azure subscription with permission and quota for B1 Linux App Service,
  Container Apps, ACR, Log Analytics, Application Insights and a Foundry model.
- Azure subscription **Owner** access for provisioning and role assignments,
  plus separate Microsoft Entra permissions to create app registrations and
  service principals. Subscription ownership alone does not grant those
  directory permissions. You perform the setup yourself.
- Access to read workspace logs and create workbooks and Azure Monitor alerts.
  Owner access on the dedicated lab resources supplies these Azure permissions.
- A learner-owned GitHub repository or Azure DevOps project/repository for
  the feedback item. Do not create issues in the upstream training repository.

Use dedicated lab resources. `azd` and Azure CLI use your interactive Microsoft
Entra sign-in; there is no deployment service principal or client secret to
create for this local deployment. Azure workloads use managed identities for
Web-to-Chat, Foundry calls and telemetry ingestion.

Do not put customer conversations, credentials, tokens or complete log exports
into Copilot prompts or work items. Use synthetic catalog questions and
sanitized telemetry metadata only.

## Task 1: Prepare your local repository

1. Prepare your repository using **one** Microsoft DevOps platform option of choice:

   - **GitHub:** Create an empty repository named **eshop-observability-lab**.
     In the VS Code PowerShell terminal, run the following in an unused parent
     directory, replacing `YOUR-OWNER`:

     ```powershell
     git clone --branch main --single-branch https://github.com/MicrosoftLearning/mslearn-devops.git eshop-observability-lab
     Set-Location eshop-observability-lab
     git remote rename origin upstream
     git remote add origin https://github.com/YOUR-OWNER/eshop-observability-lab.git
     git push --set-upstream origin main
     code .
     ```

   - **Azure DevOps:** Create a project named **eshop-observability-lab**.
     In **Repos > Files > Import repository**, import
     `https://github.com/MicrosoftLearning/mslearn-devops.git`.
     Select **Clone**, copy your repository's HTTPS URL, then run in an unused
     parent directory in the VS Code PowerShell terminal:

     ```powershell
     git clone YOUR-REPOSITORY-HTTPS-URL eshop-observability-lab
     Set-Location eshop-observability-lab
     code .
     ```

1. In the **VS Code terminal**, create a working branch and enter the sample:

   ```powershell
   git switch -c observability-lab
   Set-Location EShopOnWebDN11
   dotnet --version
   docker info --format '{{.OSType}}'
   azd version
   ```

   **Expected output:** .NET `11.0.x`, Docker `linux`, and an installed azd
   version. Resolve missing prerequisites before continuing.

## Task 2: Deploy with optional instrumentation

1. In **Azure portal > Microsoft Entra ID > Overview**, copy your
   **Tenant ID**. In **Subscriptions**, copy your **Subscription ID**.
   Choose an Azure region with the required quota. Foundry can use a different
   supported region.
1. In the **VS Code terminal**, replace the placeholders and run:

   ```powershell
   $ErrorActionPreference = 'Stop'
   $PSNativeCommandUseErrorActionPreference = $true
   az login --tenant "YOUR-TENANT-ID"
   az account set --subscription "YOUR-SUBSCRIPTION-ID"
   azd auth login --tenant-id "YOUR-TENANT-ID"
   azd env new eshop-observe --subscription "YOUR-SUBSCRIPTION-ID" --location "YOUR-AZURE-REGION"
   azd env set FOUNDRY_LOCATION "YOUR-FOUNDRY-REGION"
   azd env set ENABLE_OBSERVABILITY true
   azd up
   ```

   Accept deployment to the dedicated **rg-eshop-observe** resource group.
   The hook creates a separate Chat API Entra registration, builds/tests the
   app, provisions Azure resources and deploys both services. It finishes by
   checking health, anonymous ChatApi rejection and a real catalog response.
   If registration permissions or region/quota checks fail, resolve the
   reported error before retrying; do not bypass authentication.

1. After `azd up` succeeds, capture its outputs in the same terminal:

   ```powershell
   $settings = (azd env get-values -o json | Out-String) | ConvertFrom-Json -AsHashtable
   $group = $settings.AZURE_RESOURCE_GROUP
   $chat = $settings.AZURE_CHAT_APP_NAME
   $workspace = $settings.AZURE_LOG_ANALYTICS_WORKSPACE_RESOURCE_ID
   $sourceVersion = $settings.SOURCE_VERSION
   Write-Host "Web: $($settings.WEB_URI)"
   Write-Host "Workspace: $($settings.AZURE_LOG_ANALYTICS_WORKSPACE_NAME)"
   Write-Host "Environment: $($settings.AZURE_ENV_NAME); source/release: $sourceVersion"
   ```

1. In **Azure portal > Resource groups > rg-eshop-observe**, open the
   Application Insights resource. Check **Access control (IAM) > Role
   assignments**: the Web and Chat managed identities each have
   **Monitoring Metrics Publisher**, scoped to this resource.
   Under **Properties**, local authentication is disabled.

   OpenTelemetry collects and correlates signals; Application Insights stores
   application telemetry in the linked Log Analytics workspace. It does not
   automatically capture Copilot prompts, tool calls or token counts.

**Expected result:** The storefront and chat work, and optional telemetry is
configured for both services. A successful deployment is not yet evidence
that telemetry has arrived.

## Task 3: Establish and verify a correlated baseline

1. In your **browser**, open the Web URL, browse the catalog, then open
   **Chat**. Ask **Which mugs are in the catalog?** Wait for a complete answer
   and product cards. Use only this synthetic question.
1. In **Azure portal**, open the Log Analytics workspace named in Task 2.
   Select **Logs**, switch to **KQL mode** if a simplified query view opens,
   and close the query gallery.

   Use **workspace context** throughout this lab. Its tables are
   `AppRequests`, `AppDependencies` and `AppTraces`, not the resource-context
   `requests`, `dependencies` and `traces` names.

1. In **VS Code**, open `EShopOnWebDN11\observability\chat-outcomes.kql`.
   Copy its query into **Logs**, replace `YOUR-ENVIRONMENT` with
   `eshop-observe`, and run it.
1. Locate a **completed** `eshop-web` operation. Verify a completed
   `eshop-chat` row has the **same OperationId**, and both rows have your source
   commit/release ID. Copy that OperationId.

   **Expected result:** `Outcome` is `completed`, `FailureReason` is `none`,
   `ItemCount` is `1`, and both service roles are present. The source/release ID
   is the deployed Git commit, not an Azure pipeline run ID. Extra rows from
   the deployment smoke test are expected.

1. Copy `observability\trace.kql` into **Logs**, replace
   `YOUR-OPERATION-ID` with the copied value and run it. Follow the Web request,
   Web-to-Chat dependency, Chat request, chat operation and Foundry HTTP
   dependency. Check their OperationId and span/parent IDs; ignore unrelated
   health and identity-token requests.
1. Run `observability\evidence-health.kql`, replacing the environment and
   `YOUR-SOURCE-VERSION` with Task 2's source commit.

   **Expected result:** Two rows, with at least one completed operation per
   role, `InvalidEvidence` equal to `0`, and recent timestamps.
   `successful answers observed` describes this small sample, not a production
   health certification.

If data has not arrived, refresh for up to ten minutes. If a table is missing,
either role is absent, the trace is disconnected, or evidence is stale or
incorrectly attributed, stop and investigate resource scope, app configuration,
ingestion permissions and application logs. Do not classify no data as healthy.
After a long wait, send one more question to create fresh evidence.

## Task 4: Verify a Copilot-assisted query

1. In **VS Code Copilot Chat**, use **Ask** mode and provide the supplied
   `requests.kql` and `evidence-health.kql` files as context. Ask:

   ```text
   Explain these workspace-context Azure Monitor queries. Propose a query for
   the last 30 minutes of AppRequests, scoped to eshop-web and eshop-chat,
   deployment.environment eshop-observe, and my source.commit value.
   Report request count, HTTP 5xx count, HTTP 5xx percentage and p95 DurationMs
   by AppRoleName. Exclude /health and /health/live. Explain why this does not
   prove chat-answer success, and how missing data should be handled.
   Do not modify application files or invent columns.
   ```

1. Review the proposed KQL before running it: check table names, field types,
   scope, denominator, time window and health exclusions. Replace the source
   commit placeholder yourself. Run it in the same workspace.
1. Compare the result with the supplied `requests.kql` query. Use that supplied
   query as the fallback if the generated one is incorrect.
1. Ask Copilot to explain any disagreement, then verify the explanation with
   the actual rows and chat outcomes. Record a short correction for your
   runbook, if needed.

There is no 500-ms chat target or 1,000-request requirement here. Those are not
appropriate for this small, streamed model-call sample. A missing service row
in the HTTP query is not a zero-error result.

## Task 5: Create a workbook and an actionable alert

1. In the **VS Code terminal**, generate the supplied workbook:

   ```powershell
   .\observability\New-Workbook.ps1 -WorkspaceResourceId $workspace `
       -EnvironmentName $settings.AZURE_ENV_NAME -SourceVersion $sourceVersion
   code .\artifacts\observability-workbook.json
   ```

   This creates a new local JSON file; it does not provision Azure resources.
   If you rerun it, use `-OutputPath` with a different filename.

1. In **Azure portal > Azure Monitor > Workbooks**, select **New**.
   Open **Edit > Advanced Editor**, select the workbook JSON editor if offered,
   replace its contents with the generated JSON and select **Apply**.
   Save it as **eShop Web and Chat** in **rg-eshop-observe**.

   If your portal layout differs, create a blank workbook and add three **Log
   Analytics query** items manually using the supplied evidence-health,
   requests and chat-outcomes queries and the same workspace/placeholders.

1. Refresh the workbook. Verify it shows evidence completeness, HTTP latency
   and individual chat outcomes. A stale sample must become **unknown**.
1. In the **VS Code terminal**, deploy the supplied lab-only alert:

   ```powershell
   az deployment group create --name eshop-observability-alert --resource-group $group `
       --template-file .\infra\chat-observability-alert.bicep `
       --parameters "workspaceResourceId=$workspace" "environmentName=$($settings.AZURE_ENV_NAME)" `
       --output none
   ```

1. In **Azure Monitor > Alerts > Alert rules**, open
   **eShop Chat: repeated failed answers**. Confirm the workspace scope,
   `eshop-chat` role, environment filter, **three failed chat operations in
   five minutes**, five-minute evaluation frequency and severity **3**.

   The rule has no notification action group by default; alerts appear in
   Azure Monitor. For email notifications, create an action group in your lab
   resource group with your email receiver, confirm the receiver, and redeploy
   with the additional parameter `actionGroupId=YOUR-ACTION-GROUP-RESOURCE-ID`.
   Record yourself as alert owner and the runbook as the investigation path.

This teaching threshold is not a production SLO. No-data detection would need
a separate signal/alert; this failure rule resolving does not prove recovery.

## Task 6: Investigate a controlled configuration failure

1. In the **VS Code terminal**, save the real deployment name before making
   any change:

   ```powershell
   $originalModel = az containerapp show --name $chat --resource-group $group `
       --query "properties.template.containers[0].env[?name=='Foundry__DeploymentName'].value | [0]" -o tsv
   if ([string]::IsNullOrWhiteSpace($originalModel) -or $originalModel -eq 'lab-missing-deployment') {
       throw 'A valid original deployment name is required before this experiment.'
   }
   $originalModel | Set-Content .\artifacts\observability-original-model.txt
   Write-Host "Fault starts (UTC): $([DateTime]::UtcNow.ToString('o'))"
   az containerapp update --name $chat --resource-group $group `
       --set-env-vars Foundry__DeploymentName=lab-missing-deployment -o none
   ```

   This changes only the dedicated ChatApi configuration. It does not delete
   the Foundry deployment, change credentials or deploy new application code.
   If interrupted, restore the saved value using Task 7 before leaving.

1. In **Azure portal > your Container App > Revisions and replicas**, wait for
   the new active revision to be healthy. In the terminal, run:

   ```powershell
   Invoke-WebRequest "$($settings.CHAT_URI.TrimEnd('/'))/health" |
       Select-Object StatusCode
   ```

   **Expected output:** `200`. Platform liveness does not test inference.

1. In the **Web Chat browser**, send **Which mugs are in the catalog?** three
   times, sequentially within one minute. Wait for each error before sending
   the next. The app allows twelve requests per minute; do not run a load test
   or retry loop.

   **Expected result:** The assistant reports it is unavailable. No completed
   answer/product result is presented. An error before streaming can return
   HTTP 503; an error after streaming starts can retain HTTP 200.

1. In **Logs**, refresh chat-outcomes and select a failed operation. Run
   trace.kql for its OperationId. Verify `chat.outcome=failed` on Web and Chat,
   and inspect the Foundry HTTP dependency's actual response code.
   A nonexistent deployment commonly produces a 404; use the observed code,
   not an assumed one.
1. In **Azure Monitor > Alerts**, look for the fired alert. Allow for ingestion
   and rule evaluation. If it does not fire, inspect the rule query with a
   five-minute window: it must contain three attributed ChatApi failures.
   A delayed or missing alert is not evidence that inference worked.
1. In **Copilot Chat**, provide only sanitized timestamps, service names,
   operation IDs, outcome/status codes and the fact that you changed the
   model deployment setting. Ask:

   ```text
   Separate verified facts, hypotheses and missing checks for this chat
   incident. Explain the difference between healthy liveness, HTTP success
   and completed chat answers. Identify the evidence supporting a Foundry
   configuration fault rather than a storefront outage. Propose the smallest
   reversible recovery, but do not execute commands or change resources.
   ```

1. Verify the analysis against the trace and the Container App's **Activity
   log/configuration**. The source commit did not change; this was a
   configuration change, not a new code release.

**Optional:** If **Azure Copilot's Observability Agent** is available to your
account, open Copilot in Azure portal and request an on-demand investigation
scoped to this resource group and UTC failure interval. Compare its claims
with your KQL evidence. Do not provision a preview autonomous-agent resource
or Azure SRE Agent, and do not authorize remediation. Continue with KQL and
VS Code Copilot if this feature is unavailable.

## Task 7: Restore and verify the application

1. In the **VS Code terminal**, restore the saved setting:

   ```powershell
   $originalModel = (Get-Content .\artifacts\observability-original-model.txt -Raw).Trim()
   if ([string]::IsNullOrWhiteSpace($originalModel)) { throw 'The saved deployment name is missing.' }
   az containerapp update --name $chat --resource-group $group `
       --set-env-vars "Foundry__DeploymentName=$originalModel" -o none
   Write-Host "Restored (UTC): $([DateTime]::UtcNow.ToString('o'))"
   ```

1. Wait for the restored active revision to become healthy. In **Web Chat**,
   send the same catalog question and verify a complete answer and valid
   catalog product cards.
1. In **Logs**, verify new **completed** Web and Chat operations share an
   OperationId and match the deployed source commit. Review recovery rows
   after your restoration timestamp, rather than older successful rows.
1. Refresh the workbook. Earlier failures remain in its thirty-minute sample
   until they age out. The alert can resolve after its five-minute failure
   window clears; verify fresh completed operations independently.

**Expected result:** Both user-visible recovery and recent correlated
completed-answer telemetry are verified. If either check fails, keep the
incident unresolved and inspect the actual error.

## Task 8: Turn verified evidence into feedback

1. In the **VS Code terminal**, create your runbook from the supplied template:

   ```powershell
   New-Item ..\docs -ItemType Directory -Force | Out-Null
   Copy-Item .\observability\runbook-template.md ..\docs\observability-runbook.md
   code ..\docs\observability-runbook.md
   ```

1. In **Copilot Chat > Agent mode**, explicitly ask it to update **only**
   `docs/observability-runbook.md` using your sanitized, verified investigation
   notes. Require facts versus hypotheses, the rollback command, recovery
   checks, the no-data limitation and an alert owner. Do not grant access to
   environment-state files or ask it to change infrastructure.
1. Inspect the change in **VS Code Source Control**. Correct unsupported
   claims and compare the runbook against one completed and one failed trace.
   Check that it does not equate HTTP 200 or alert resolution with successful
   chat. Agent approvals depend on your settings; always review the diff.
1. In your **chosen platform in the browser**, create an actual feedback item:

   - **GitHub:** Your repository > **Issues > New issue**.
   - **Azure DevOps:** Your project > **Boards > Work items > New work item**,
     using **Bug** or **Issue**, depending on the project's process.

   Use a title such as **Detect Foundry configuration drift after deployment**.
   Include the synthetic symptom, scoped UTC interval/operation ID, verified
   cause, recovery, unresolved limitations and acceptance criteria for a
   model-name/configuration check and a tested chat-outcome alert.
   Existing deployment smoke tests already check chat; distinguish later
   configuration drift from missing initial deployment validation.

1. Add the created item's URL to the runbook. Commit and push the reviewed
   document to your repository:

   ```powershell
   git add -- ..\docs\observability-runbook.md
   git --no-pager diff --cached
   git commit -m "document verified chat observability and recovery"
   git push --set-upstream origin observability-lab
   ```

This small experiment cannot establish team-wide reliability or DORA trends.
The reusable result is a reviewed investigation workflow, not an unverified
AI-generated incident narrative.

## Exercise Summary

You deployed a platform-neutral Web/Chat sample with optional observability,
verified distributed correlation and source attribution, and distinguished
chat outcomes from HTTP status and liveness.

You reviewed Copilot-assisted KQL, built a scoped workbook and alert,
investigated and reversed a controlled configuration fault, and turned
verified evidence into a runbook and a real feedback item.

## Clean up

1. Confirm the original model setting is restored. In the sample's **VS Code
   terminal**, capture the dedicated Chat API registration ID before removal:

   ```powershell
   $chatApiClientId = $settings.CHAT_API_CLIENT_ID
   azd down
   ```

   Review the resource list and confirm deletion of **only** this lab
   environment. This removes its App Service, Container App, registry,
   monitoring resources, workbook, alert and lab-owned action group.

1. In **Azure portal > Resource groups**, confirm **rg-eshop-observe** is gone.
   The Foundry account can remain soft-deleted; do not purge shared resources.
1. In **Microsoft Entra ID > App registrations**, locate the registration
   matching `$chatApiClientId` and delete it only after confirming it was
   created exclusively for this lab. `azd down` does not delete it.
   Verify the corresponding enterprise application is removed.
1. Retain your reviewed runbook and feedback item. Delete the local generated
   workbook and saved model-name files when no longer needed; keep ignored
   azd environment state until Azure and Entra cleanup is verified.
