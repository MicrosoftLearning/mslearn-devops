---
lab:
    topic: Agentic
    title: Use GitHub Copilot prompts for Azure cloud operations
    description: In this exercise, you learn how to use GitHub Copilot prompts for several Azure cloud operations. 
    level: 300
    duration: 45 minutes
    islab: true
    primarytopics:
    - Azure
    - GitHub Copilot
---

# Use GitHub Copilot prompts for Azure cloud operations

## Customer scenario

## Lab scenario

You will work through several tasks that progressively build on each other. You will use GitHub Copilot to perform real infrastructure work. From writing CLI scripts to generating Bicep templates, building CI/CD pipeline syntax, documenting cloud infrastructure, and analyzing Azure cloud operations logs.

By the end of this lab, you will be able to:

- generate Azure CLI and PowerShell Script 
- compose Bicep Template (with and without MCP)
- generate CI/CD Pipeline syntax for Azure DevOps + GitHub Actions
- use GitHub Copilot to assist in writing cloud infrastructure documentation 
- analyze Azure Activity log and Azure Firewall logs using GitHub Copilot 

This lab takes approximately **45** minutes to complete.

## Before you start

> **Note**: Complete these steps before starting the actual exercise. If you are running this in a prehosted lab environment, some or all of these steps might have been completed for you already. Check with the trainer or lab hosting partner for accurate information.

This lab requires access to the following resources:

- GitHub Copilot subscription (**any [plan](https://docs.github.com/en/copilot/get-started/plans#ready-to-choose-a-plan) will work, although some tasks might impact the capacity of the free plan; paid GitHub Copilot plan is recommended**)
- Azure subscription (required for az cli validation steps, optional to deploy resources)

### Step 1: Enable or Validate GitHub Copilot Subscription

1. Navigate to [github.com/copilot](https://github.com/copilot)
1. Open **User Navigation Menu / Copilot Settings**
1. If you don't have Copilot enabled:
   - Select **Enable GitHub Copilot**
   - (if needed, choose your subscription (Pro, Pro+, Business, or Enterprise))
   - Complete the subscription process (**Note**: This lab does not work with the Free Copilot subscription)
1. Verify **Copilot coding agent** is Enabled

### Step 2: Azure Subscription access

> **Note**: If you cannot get access to an Azure subscription, there are still several tasks you can complete successfully. You won't be able to run the Azure template validation or run actual Azure template deployment steps.

1. Navigate to [portal.azure.com](https://portal.azure.com)
1. Sign in with your administrative credentials
1. Validate you have Contributor permissions on subscription or Resource Group level

> **Note**: If you don't have access to an Azure subscription, consider creating a Free one by using [this link](https://azure.microsoft.com/en-us/pricing/purchase-options/azure-account?icid=azurefreeaccount.)

### Step 3: Development environment prerequisites

Before starting, ensure the following tools are available on your workstation:

| Requirement | Details |
|---|---|
| [Git Source Control](https://git-scm.com) | required to clone the mslearn-devops repo |
| [GitHub Copilot](https://github.com/copilot) | Active subscription with access to Copilot Chat in VS Code |
| [VS Code](https://code.visualstudio.com/download) | Latest stable version with GitHub Copilot and Bicep extensions installed |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest) | Installed and authenticated (`az login`) to an Azure subscription |
| [Azure PowerShell](https://learn.microsoft.com/powershell/azure/install-azure-powershell?view=azps-15.5.0) | `Az` module installed |

### Step 4: Cloning the lab resource repository

1. **Clone** the [Microsoft Learning mslearn-devops](https://github.com/MicrosoftLearning/mslearn-devops.git) repo to your local machine.

```powershell
git clone https://github.com/MicrosoftLearning/mslearn-devops.git
```

2. Navigate into the cloned **mslearn-devops** folder on your local machine

```powershell
cd .\mslearn-devops
```
3. Unzip the agentic-iac-lab-files.zip file

```powershell
tar -xvf agentic-iac-lab-files.zip
```
After extracting the archive, the lab-files working directory will contain:

```
lab-files/
├── app/                    # Node.js Express API — used in Task 3
│   ├── server.js
│   ├── package.json
│   └── routes/
│       ├── health.js
│       └── resources.js
├── templates/
│   └── main-v1.bicep       # Older Bicep template — used in Task 2 and Task 5
├── logs/
│   ├── firewall-logs.json  # Sample Azure Firewall logs — used in Task 6
│   ├── failed-deployment.log  # Deployment error log — used in Task 6
│   └── activity-log.json   # Azure Activity Logs — used in Task 6
├── k8s/                    # Save your Kubernetes manifests here (Task 3)
├── scripts/                # Save your CLI/PowerShell scripts here (Task 1)
└── kql/                    # Save your KQL queries here (Task 6)
docs/                       # Save your generated documentation here (Task 5)
```

With all the above steps completed, you are ready to continue with the exercise.

---

## Task 1: Azure CLI and PowerShell Script Generation using GitHub Copilot

**Objective:** Use GitHub Copilot to generate CLI and PowerShell commands for Azure resource provisioning and convert between the two.

### Step 1.1 — Generate an Azure CLI Provisioning Script

1. Open VS Code and launch **Copilot Chat** (`Ctrl+Alt+I`).

2. Select **Ask** in the *Set Agent* property field.

3. Enter the following prompt in the chat window:

    ```
    Generate an Azure CLI bash script that:
    - Creates a resource group called "rg-agentic-iaclab" in East US
    - Creates a VNet called "vnet-agentic-iaclab" with address space 10.10.0.0/16
    - Adds two subnets: "snet-app" (10.10.1.0/24) and "snet-data" (10.10.2.0/24)
    - Creates an Ubuntu 22.04 LTS VM called "vm-iaclab" in snet-app with Standard_B2s SKU
    - Tags all resources with Environment=Training and Owner=agentic-iaclab
    Include error handling and parameter validation.
    ```

4. Review the generated script. Note whether Copilot included:
    - Resource group existence check before creation
    - Tag application on all resources
    - A clean variable block at the top

5. If needed, ask Copilot to refine it:

    ```
    Refactor this script to use variables at the top for all hardcoded values,
    and add a --no-wait flag to the VM creation with a status check loop.
    ```

6. Create a new file and save the script as `lab-files/scripts/deploy-infra.sh`.

---

### Step 1.2 — Transform CLI to Azure PowerShell

1. Open the **deploy-infra.sh** file in the VS Code window. 

2. In Copilot Chat, notice how the file gets added as context. Run the following prompt:

    ```
    Transform this Azure CLI script into an equivalent Azure PowerShell script
    using Az module cmdlets. Maintain the same structure, variable names,
    error handling, and tag application logic.
    ```

3. Review the output. Verify:
    - `New-AzResourceGroup`, `New-AzVirtualNetwork`, `New-AzVM` are used correctly
    - Tags are applied via the `-Tag` parameter on each resource

4. Save as `lab-files/scripts/deploy-infra.ps1`.

---

### Step 1.3 — Validate and Run

> **Note**: If you don't have access to an Azure subscription, you can skip this step without impacting the remaining flow of the exercise.

1. Run a dry-run check in your terminal:

    ```bash
    az group show --name rg-agentic-iaclab 2>&1 || echo "Resource group not found — safe to create"
    ```

2. Run the CLI script:

    ```bash
    chmod +x lab-files/scripts/deploy-infra.sh && ./lab-files/scripts/deploy-infra.sh
    ```

3. Verify in the Azure Portal that the resource group, VNet, and VM were created with correct tags.

> **Checkpoint:** Resource group `rg-agentic-iaclab` exists with a tagged VNet, subnets, and VM.

---

## Task 2: Bicep Template Generation (LLM-Only vs. Bicep MCP Server Enhanced)

**Objective:** Use GitHub Copilot to generate Bicep templates for Azure infrastructure — first using only the model's built-in knowledge, then with the Bicep MCP server enabled — and compare the difference in accuracy.

---

### Step 2.1 — Generate a Bicep Template (LLM Knowledge Only)

1. Ensure the Bicep MCP server is **stopped**:
    - Open Command Palette (`Ctrl+Shift+P`), search **MCP: List Servers** and confirm `Bicep MCP Server` is **stopped**.

2. Create a new file `main.bicep` in your working lab directory.

3. In Copilot Chat, enter the following prompt:

    ```
    Generate a Bicep template that deploys a hub-spoke network topology with:
    - A hub VNet (10.0.0.0/16) with an AzureFirewallSubnet and a GatewaySubnet
    - One spoke VNet (10.1.0.0/16) with an application subnet
    - VNet peering between hub and spoke (both directions)
    - An Azure Firewall with a public IP in the hub
    - An NSG on the application subnet with a rule denying inbound SSH from the internet
    - All resources tagged with Environment, Owner, and CostCenter parameters
    Use the latest stable API versions.
    ```

4. Paste the generated output into `main.bicep`.

5. Run a build validation:

    ```bash
    az bicep build --file main.bicep
    ```

6. Note any errors or warnings, in particular:
    - Outdated or incorrect API versions
    - Missing required properties
    - Incorrect resource references

7. **Save the error output** — you will compare this with the Bicep MCP Server task output in Step 2.3.

---

### Step 2.2 — Ask Copilot to Extend the Template

1. With `main.bicep` open in your VS Code window, run the following prompt in Copilot Chat:

    ```
    Add the following to the existing Bicep template:
    - Azure Bastion in the hub VNet (requires AzureBastionSubnet)
    - A Log Analytics workspace to capture diagnostic logs
    - Diagnostic settings linking the Azure Firewall to the Log Analytics workspace
    - A User-Assigned Managed Identity for future automation use
    ```

2. Integrate the suggestions into `main.bicep`, by using the editor options from Copilot chat view. 

3. Validate the template file by running `az bicep build --file main.bicep` again.

---

### Step 2.3 — Enable Bicep MCP Server and regenerate template syntax

1. Enable the **Bicep MCP server**:
    - Open Command Palette (`Ctrl+Shift+P`), select `MCP: List Servers` 
    - Select **Bicep** and select **Start Server**
    - Confirm it is active in the Copilot status bar or from the Terminal Output view

> **Note**: If you don't see the Bicep MCP Server in the list, you might need to **add the Bicep VS Code extension** first.

2. Create a new file `main-mcp.bicep`.

3. Use the **exact same prompt** from Step 2.1 earlier - in Copilot Chat. Note how Copilot Chat will try and use the Bicep MCP Server, based on the context of the prompt (bicep keyword).

4. Paste the output into `main-mcp.bicep`, save the changes and validate the template by running the following command:

    ```bash
    az bicep build --file main-mcp.bicep
    ```

5. Compare the two outputs side by side:

    | Attribute | Without MCP (`main.bicep`) | With MCP (`main-mcp.bicep`) |
    |---|---|---|
    | API Versions | Older / guessed | Current / validated |
    | Required properties | May be missing | Complete |
    | Build errors | Likely present | Fewer or none |
    | Resource dependencies | Manual `dependsOn` | Implicit via references |

6. With MCP still active, ask Copilot to improve the template:

    ```
    Review this Bicep template for security best practices. Suggest improvements
    for the NSG rules, firewall policy, and any missing diagnostic configurations.
    ```

---

### Step 2.4 — Run a What-If Deployment

> **Note**: If you don't have access to an Azure subscription, you can skip this step without impacting the remaining flow of the exercise. 

1. Run a what-if to validate the final template before deploying:

    ```bash
    az deployment group what-if \
      --resource-group rg-agentic-iaclab \
      --template-file main-mcp.bicep \
      --parameters environment=Training owner=iaclab costCenter=Lab001
    ```

2. Review the output and confirm expected resources appear with no unintended deletions.

> **Checkpoint:** `main-mcp.bicep` builds without errors and the what-if shows the expected resources. If there are any issues, use Copilot chat for assisting in troubleshooting.

---

## Task 3: CI/CD Pipeline Generation for Azure DevOps and/or GitHub Actions

> **Note**: No access to an Azure DevOps Organization or GitHub Actions is required to complete this task. You generate the pipeline syntax, but won't run the actual pipeline.

**Objective:** Use GitHub Copilot to generate multi-stage deployment pipelines for both Azure DevOps and GitHub Actions, including environment approvals and an Infrastructure as Code validation stage.

---

### Step 4.1 — Generate an Azure DevOps Pipeline

1. In Copilot Chat, prompt:

    ```
    Generate an Azure DevOps multi-stage YAML pipeline for deploying the Bicep template
    from this lab across two environments: staging and production.
    Requirements:
    - Trigger on changes to the main branch under the infra/ folder
    - Stage 1 (Validate): Run az bicep build and az deployment group what-if
      against the staging resource group
    - Stage 2 (Deploy Staging): Deploy the Bicep template to rg-iaclab-staging
      using an Azure service connection called "sc-iaclab-staging"
    - Stage 3 (Deploy Production): Deploy to rg-iaclab-production using
      "sc-iaclab-production" with a manual approval gate before execution
    - Use variable groups: "vg-iaclab-staging" and "vg-iaclab-production"
    - All stages run on ubuntu-latest hosted agents
    ```

2. From the Chat response view, inside the YAML snippet, select **apply in editor** from the chat response view. 
3. Then, select **New untitled editor** and **saving** the new file as `azure-pipelines.yml`

4. Ask Copilot to add a rollback stage:

    ```
    Add a Stage 4 (Rollback) that only triggers if Stage 3 (Deploy Production) fails.
    It should re-deploy the last successful Bicep artifact from the staging drop.
    ```

---

### Step 4.2 — Generate a GitHub Actions Equivalent

1. With `azure-pipelines.yml` open in the editor, prompt:

    ```
    Translate this Azure DevOps pipeline into an equivalent GitHub Actions workflow.
    Use:
    - OIDC-based Azure authentication (azure/login action with federated credentials)
    - GitHub Environments named "staging" and "production"
      (production requires a reviewer approval)
    - Reusable workflow jobs where possible
    - Secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID from GitHub Secrets
    ```

2. Save as `.github/workflows/deploy-infra.yml`.

3. Ask Copilot to add a compliance check:

    ```
    Add a job before the staging deployment that runs az policy state list
    and fails the workflow if any non-compliant resources are found
    in the staging resource group.
    ```

---

## Task 5: Infrastructure Documentation Generation

**Objective:** Use GitHub Copilot to automatically generate human-readable documentation from the Bicep template you built in Task 2. Without writing a single word manually.

---

### Step 5.1 — Generate a Plain-Language Architecture Description

1. Open `main-mcp.bicep` in VS Code and select all content (`Ctrl+A`).

2. In Copilot Chat, prompt:

    ```
    Explain what this Bicep template deploys in plain, non-technical language
    suitable for a project manager or business stakeholder.
    Describe the purpose of each major component and how they relate to each other.
    ```

3. Save the output to `docs/architecture-overview.md`.

---

### Step 5.2 — Generate a Parameter Reference Table

1. Prompt:

    ```
    Generate a markdown parameter reference table for this Bicep template.
    Include columns: Parameter Name | Type | Default Value | Allowed Values | Description
    Cover all parameters and outputs.
    ```

2. Append the table to `docs/architecture-overview.md`.

---

### Step 5.3 — Generate a Mermaid Architecture Diagram

> **Note**: Mermaid is a popular diagram representation tool, supported in Markdown documents

1. Prompt:

    ```
    Represent the network topology from this Bicep template as a Mermaid diagram.
    Show: hub VNet, spoke VNet, VNet peering, Azure Firewall, Bastion,
    subnets, and the Log Analytics workspace. Use a left-to-right layout.
    ```

2. Paste the Mermaid code block into `docs/architecture-overview.md`.

3. Preview the rendered diagram: open the file and press `Ctrl+Shift+V` (VS Code Markdown Preview).

---

### Step 5.4 — Generate a Change Summary

1. Open `lab-files/templates/main-v1.bicep` alongside `main-mcp.bicep` — this is the older version of the template.

2. Prompt Copilot:

    ```
    Compare these two Bicep templates and generate a change summary in markdown.
    For each change, state: what changed, why it likely changed
    (e.g. added security, added observability), and any potential impact
    on existing deployments.
    ```

    Paste both templates into the chat when prompted.

3. Save the output as `docs/changelog.md`.

> **Checkpoint:** `docs/` contains `architecture-overview.md` (with description, parameter table, and diagram) and `changelog.md`.

---

## Task 6: Cloud Operations Log Analysis

**Objective:** Use GitHub Copilot to analyze sample Azure operational logs, identify security and operational issues, and generate KQL queries for Azure Monitor.

**Relevant Unit:** Unit 8 — Log and Configuration Analysis

---

### Step 6.1 — Analyze Azure Firewall Logs

1. Open `lab-files/logs/firewall-logs.json` in VS Code.
   This file contains 80 Azure Firewall network rule log entries.

2. In Copilot Chat, attach the file if not already attached, and run the following prompt:

    ```
    Analyze these Azure Firewall logs and provide:
    1. The top 5 source IPs generating denied traffic
    2. The top 5 destination ports being targeted
    3. Any patterns that suggest port scanning or reconnaissance activity
    4. The time window with the highest volume of denied connections
    5. Any allowed traffic to unusual destinations that might warrant investigation
    ```

3. Review the output, then follow up:

    ```
    Based on the top offending source IPs you identified, what Azure Firewall rule
    or NSG rule would you recommend to block them permanently?
    Write it as a Bicep resource snippet I can add to my template.
    ```

---

### Step 6.2 — Troubleshoot a Failed Deployment

1. Open `lab-files/logs/failed-deployment.log`. Validate it gets attached to the Copilot chat context.

2. Prompt Copilot with the following:

    ```
    This is an Azure resource deployment log that ended in failure.
    Identify the root cause of the failure, explain what went wrong in plain language,
    and provide the exact fix needed in the Bicep template or deployment parameters.
    ```

3. Apply the fix Copilot suggests to `main-mcp.bicep` and re-validate:

    ```bash
    az bicep build --file main-mcp.bicep
    ```

---

### Step 6.3 — Generate KQL Queries for Azure Monitor

1. In Copilot Chat, prompt:

    ```
    Generate three KQL queries for Azure Log Analytics based on the firewall
    logs we analyzed:

    Query 1: Count of denied connections grouped by source IP over the last 24 hours,
    sorted descending, suitable for a bar chart visualization.

    Query 2: All connections where the destination port is 22 (SSH) or 3389 (RDP)
    that were allowed — highlight these as a potential security risk.

    Query 3: Hourly trend of denied vs. allowed traffic over the last 7 days
    as a time chart.

    Use the AzureDiagnostics table. Include comments explaining each query.
    ```

2. Save the output as `lab-files/kql/firewall-queries.kql`.

---

### Step 6.4 — Generate a Compliance Audit Summary

1. Open `lab-files/logs/activity-log.json`.
   This file contains 30 days of Azure Activity Log entries.

2. Prompt Copilot:

    ```
    Review these Azure Activity Logs and generate a compliance audit summary
    in markdown format that includes:
    - All role assignments or permission changes in this period
    - Any resource deletions
    - Any Azure Policy exemptions created
    - Changes made outside of business hours (assume IST: 09:00–18:00)
    - A risk rating (Low / Medium / High) for each category of activity
    ```

3. Save the output as `docs/compliance-summary.md`.

> **Checkpoint:** `docs/compliance-summary.md` exists and all three KQL queries run without errors in Log Analytics.

---

## Lab Summary

Congratulations — you have completed all typical cloud infrastructure operations tasks, using GitHub Copilot Ask mode as your virtual assistant.


