---
lab:
  topic: Agentic
  title: Transition traditional operations using agent automation in Azure 
  description: Build a minimal multi-agent solution from scratch. You create the agent files, shared skill, and Bicep instruction that let GitHub Copilot orchestrate an end-to-end Azure infrastructure provisioning workflow from a single natural-language prompt.
  level: 300
  duration: 45 minutes
  islab: true
  primarytopics:
    - Azure Developer CLI
    - Bicep
    - GitHub Copilot
    - Agentic DevOps
---

# Compose a Multi-Agent solution for Azure Infrastructure

## Lab Scenario

You are experienced with Azure and Bicep, but you have always written templates and run deployments yourself. In this lab you take a different approach: instead of writing the Bicep, you compose a small system of GitHub Copilot agents that does it for you.

You build a three-file agent solution in a new VS Code workspace:

| Agent | Responsibility |
|---|---|
| **Conductor** | Receives the user's prompt, delegates to the other two agents in sequence, and verifies each stage completed before proceeding |
| **Architect** | Parses the scenario description into structured requirements and recommends Azure services, SKUs, and security decisions |
| **Bicep + Deploy** | Reads the architecture assessment, generates Bicep templates, and deploys the infrastructure with `azd` |

You also create a **shared skill** that carries naming conventions and security defaults across all three agents, and a **Bicep instruction file** that is automatically injected whenever an agent creates a `.bicep` file.

By the end of this lab you will be able to:

- Create an `.agent.md` file, including its YAML front matter and Markdown   system prompt body.
- Explain the difference between a skill (pull model) and an instruction file (push model) and when to use each.
- Wire agents together using the `agents` array and subagent delegation.
- Run a Conductor agent that drives a two-stage solution from a single prompt through to a deployed Azure environment.
- Commit the finished solution to your own GitHub repository.

This lab takes approximately **45 minutes** to complete.

---

## Before You Start

| Requirement | Notes |
|---|---|
| VS Code 1.100 or later | Agent mode requires this version |
| GitHub Copilot subscription | Pro, Pro+, Business, or Enterprise — **Free tier does not support custom agents** |
| Azure Developer CLI (`azd`) | [Install guide](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| Azure CLI (`az`) | [Install guide](https://learn.microsoft.com/cli/azure/install-azure-cli) |
| Bicep VS Code extension | Install `ms-azuretools.vscode-bicep` — also installs the Bicep CLI |
| GitHub CLI (`gh`) | [Install guide](https://cli.github.com/) |
| An Azure subscription | Contributor access — the deployment creates ~5 resources at development SKUs |

---

## Pre-Lab: Authenticate Your Tools

Before creating any files, sign in to all tools that the agents need.

1. Sign in to Azure CLI:

   ```bash
   az login
   ```

1. Sign in to Azure Developer CLI:

   ```bash
   azd auth login
   ```

1. Sign in to GitHub CLI:

   ```bash
   gh auth login
   ```

   Follow the browser prompts. When complete, verify with `gh auth status`.

1. Confirm the correct Azure subscription is active:

   ```bash
   az account show --query "{name:name, id:id}" -o table
   ```

   If needed, set the correct subscription:

   ```bash
   az account set --subscription "<your-subscription-id-or-name>"
   ```

---

## Exercise 1: Initialize the Workspace (5 minutes)

In this exercise you create the folder structure that the agent system requires and configure VS Code to discover your agent and skill files.

### Step 1: Create the Project Folder

1. On your local machine, create a new folder named **`my-agentic-ops`**.
1. Open VS Code and select **File → Open Folder**, then select the `my-agentic-ops` folder.

### Step 2: Create the Folder Structure

Inside `my-agentic-ops`, create the following subfolders. Use the VS Code terminal (`Ctrl+` `` ` ``):

```
mkdir .github
mkdir .github/agents
mkdir .github/skills
mkdir .github/instructions
mkdir .vscode
```

Your workspace should look like this:

```
my-agentic-ops/
├── .github/
│   ├── agents/          ← agent definition files
│   ├── skills/          ← shared skill files
│   └── instructions/    ← instruction files
└── .vscode/             ← VS Code settings
```

The `scenario/` output folder is created automatically by the agents when they run — you do not need to create it manually.

### Step 3: Create the VS Code Settings File

Create `.vscode/settings.json` with the content below. This file tells VS Code where to find your agent and skill files and enables the features that agent mode requires.

```json
{
  "chat.useAgentsMdFile": true,
  "chat.useNestedAgentsMdFiles": true,
  "chat.customAgentInSubagent.enabled": true,
  "chat.agentFilesLocations": {
    ".github/agents": true
  },
  "chat.agentSkillsLocations": {
    ".github/skills": true
  },
  "chat.useAgentSkills": true
}
```

> **What these settings do:**
> - `chat.agentFilesLocations` — tells VS Code to scan `.github/agents/` for `.agent.md` files and surface them in the Chat agent picker.
> - `chat.agentSkillsLocations` — tells the runtime where skill files live so agents can read them by name.
> - `chat.customAgentInSubagent.enabled` — allows the Conductor to call the other agents via `runSubagent`.

After saving the file, reload the VS Code window once:

`Ctrl+Shift+P` → **Developer: Reload Window**.

---

## Exercise 2: Create the agentic Agent definition files

### Task 1: Create the Skill Instruction file

A **skill** is a Markdown knowledge file that agents read explicitly at runtime. It carries domain information that is too large or too organization-specific to embed directly in every agent's system prompt. Because agents pull skills on demand, every agent in your solution can share the same naming conventions and security baseline while keeping its own system prompt focused.

Create the file `.github/skills/SKILL.md` and paste the following content:

```markdown
---
name: azure-ops-defaults
description: "Shared defaults for Azure infrastructure provisioning"
---

# Azure Operations Defaults

## Naming Conventions

Follow Azure Cloud Adoption Framework (CAF) naming patterns.

Keep workload names 8 characters or fewer. Use `dev`, `test`, or `prod` for environment.

| Resource | Pattern | Example |
|---|---|---|
| Resource group | `rg-{workload}-{env}` | `rg-webapp-dev` |
| App Service plan | `asp-{workload}-{env}` | `asp-webapp-dev` |
| App Service | `app-{workload}-{env}` | `app-webapp-dev` |
| SQL Server | `sql-{workload}-{env}` | `sql-webapp-dev` |
| SQL Database | `sqldb-{workload}-{env}` | `sqldb-webapp-dev` |
| Key Vault | `kv-{workload}-{env}` | `kv-webapp-dev` |

## Security Baseline

Apply these rules to every deployment:

- **TLS**: Minimum TLS 1.2 on all public endpoints.
- **HTTPS**: Set `httpsOnly: true` on every App Service.
- **Authentication**: Use managed identity for service-to-service access.   Never store passwords or connection strings in application settings.
- **Key Vault access**: Use RBAC (`Key Vault Secrets User` role), not access policies.
- **SQL**: Enable Entra ID authentication alongside SQL authentication.

## Default SKUs

| Service | Development | Production |
|---|---|---|
| App Service plan | B1 (Linux) | P1v3 (Linux) |
| SQL Database | Basic (5 DTU) | S1 (20 DTU) |
| Key Vault | Standard | Standard |
```

> **Pull model in practice:**
> This file is not injected automatically. Each agent's Markdown body contains an explicit instruction: *"Read `.github/skills/SKILL.md` before doing any other work."* The agent calls a file-read tool to load the content into its context window for that session. If you update the skill later, every agent picks up the change automatically on its next run — because they always read it fresh.

---

### Task 2: Create the Bicep Instruction File 

An **instruction file** is the opposite of a skill — it uses a **push** model. VS Code reads the `applyTo` glob in the file's front matter and automatically injects the instruction into any agent's context whenever that agent creates or edits a file whose path matches the pattern.

You do not reference this file anywhere in your agent definitions. It activates silently when a `.bicep` file is written.

Create the file `.github/instructions/bicep.instructions.md` and paste the following content:

```markdown
---
description: "Bicep coding standards for Azure infrastructure"
applyTo: "**/*.bicep"
---

# Bicep Development Standards

## Module Priority

1. Always check Azure Verified Modules (AVM) first.
   AVM reference format: `br/public:avm/res/<provider>/<resource>:<version>`
2. Use an AVM module when one exists for the resource type.
3. Fall back to a native `resource` block only when no AVM module is available.

## Security Defaults

Every generated Bicep file must:

- Set `httpsOnly: true` on all App Service resources.
- Set `minimumTlsVersion: '1.2'` on all web and storage resources.
- Assign a `SystemAssigned` managed identity to every App Service.
- Grant service identities access via RBAC `roleAssignments`. Never put connection strings or passwords in `appSettings`.

## Parameters and Outputs

- Declare `workloadName`, `environment`, and `location` as top-level parameters with `@description` decorators.
- Never hard-code subscription IDs, tenant IDs, resource group names, or passwords.
- Export at minimum: App Service default hostname and Key Vault URI.

## Structure

- Use a single `main.bicep` for deployments of six resources or fewer.
- Always pair `main.bicep` with a `main.bicepparam` file.
```

> **Skill vs. instruction — the one-line distinction:**
> `SKILL.md` tells agents *what to build* (which services, which names, which tiers). `bicep.instructions.md` tells agents *how to write the code* (which Bicep patterns, which security properties). Separating them means you can evolve your organization's service catalog without touching coding standards, and vice versa.

---

### Task 3: Create the Architect Agent

> **Why start with the leaf agents?**
> The Conductor (Exercise 6) references the other agents by name in its `agents` array. By creating the two leaf agents first, every name and capability in the Conductor's front matter is already concrete — no forward references to agents you haven't seen yet.

Your first specialized agent combines requirements gathering and architecture assessment. It reads the user's scenario description and produces a single structured document that the Bicep + Deploy agent uses as its source of truth.

#### The Agent File Format

Every agent is a single Markdown file with two parts:

1. **YAML front matter** (between the `---` delimiters): declares the agent's identity, tools it can use, and other agents it can call.
2. **Markdown body** (below the second `---`): this is the agent's **system prompt** — the instructions the model follows when acting as this agent.

#### Create the Agent File

Create `.github/agents/02-architect.agent.md` and paste the following content:

```markdown
---
name: 02-architect
description: >
  Parses a scenario description into structured requirements and produces an architecture assessment with service recommendations and security decisions.
tools: [readFile, createFile]
agents: []
user-invokable: false
---

# Architect Agent

You combine requirements gathering and architecture assessment into a single stage. Given a scenario description, you produce one Markdown artifact that captures what needs to be built and how it should be built on Azure.

## Mandatory: Read the Skill First

Before doing any other work, read the shared skill file:

  .github/skills/SKILL.md

Apply every naming convention and security rule from that file throughout your output. Do not invent resource names or SKUs that are not listed in the skill.

## Your Task

Produce the file `scenario/requirements-architecture.md` with these three sections:

### Section 1 – Parsed Requirements

List each resource the scenario requires:

- Resource type and its purpose in the architecture.
- Any constraints or preferences stated in the prompt.
- Resources implied but not stated explicitly (for example, App Service implies an App Service plan). Mark implied resources with "(implied)".

### Section 2 – Architecture Assessment

For each resource from Section 1:

- Recommended Azure service and SKU using the Default SKUs table from SKILL.md for the target environment.
- The CAF-compliant resource name from the naming convention table in SKILL.md.
- Which security baseline rules from SKILL.md apply to this resource.
- Deployment dependency: which other resources must be provisioned first.

### Section 3 – Artifact Contract

A table listing the files the Bicep + Deploy agent must produce:

| File | Purpose |
|---|---|
| `scenario/infra/main.bicep` | Bicep template for all resources |
| `scenario/infra/main.bicepparam` | Parameter values file |
| `scenario/azure.yaml` | azd project manifest |
| `scenario/deployment-summary.md` | Post-deployment record |

## Rules

- Apply CAF naming from SKILL.md to every resource name you recommend.
- Do not generate any Bicep code. Your output is documentation only.
- Write the file to `scenario/requirements-architecture.md`.
- Create the `scenario/` folder if it does not exist.
```

> **Front matter field reference:**
>
> | Field | Value | Why |
> |---|---|---|
> | `tools` | `[readFile, createFile]` | This agent only reads and writes files — no terminal access, limiting its blast radius |
> | `agents` | `[]` | Leaf agent — it does not delegate further |
> | `user-invokable` | `false` | Not meant to be called directly by the user; the Conductor invokes it |
>
> You can change `user-invokable` to `true` later if you want to re-run just
> the architecture stage without going through the Conductor.

---

### Task 4: Create the Bicep + Deploy Agent

Your second specialized agent handles both Bicep generation and deployment. In a larger solution you might separate these into two agents (so you can review templates before deploying), but keeping them combined here reduces the number of files and keeps the lab within the 45-minute target.

Create `.github/agents/03-bicep-deploy.agent.md` and paste the following content:

````markdown
---
name: 03-bicep-deploy
description: >
  Generates Bicep templates from the architecture assessment and deploys the infrastructure using Azure Developer CLI (azd).
tools: [readFile, createFile, runInTerminal]
agents: []
user-invokable: false
---

# Bicep + Deploy Agent

You generate Azure infrastructure-as-code from an architecture assessment and deploy it using the Azure Developer CLI.

## Mandatory: Read These Files First

Before writing any code, read the following files in order:

1. `.github/skills/SKILL.md` — naming conventions, security baseline, SKUs.
2. `scenario/requirements-architecture.md` — architecture decisions and deployment dependency order produced by the Architect agent.

## Phase 1 – Generate the Bicep Template

Create `scenario/infra/main.bicep`:

- Use Azure Verified Modules (AVM) for every resource type that has an available AVM module. Fall back to native `resource` blocks only when no AVM module exists.
- Declare parameters: `workloadName` (string), `environment` (string), `location` (string, default `'eastus2'`).
- Name every resource using the pattern from SKILL.md, composing the name from `workloadName` and `environment`.
- Apply all security baseline rules from SKILL.md:
  - `httpsOnly: true` on App Service.
  - Minimum TLS 1.2 where applicable.
  - `SystemAssigned` managed identity on App Service.
  - RBAC `roleAssignment` granting the App Service identity
    `Key Vault Secrets User` on the Key Vault.
- Respect the deployment dependency order from the architecture assessment.
- Export outputs: App Service default hostname, Key Vault URI.

## Phase 2 – Create the Parameter File

Create `scenario/infra/main.bicepparam` that provides values for `workloadName`, `environment`, and `location` matching the scenario.

## Phase 3 – Create the azd Manifest

Create `scenario/azure.yaml` with this structure (replace the angle-bracket placeholders with the actual workload name and environment):

```yaml
name: <workloadName>-<environment>
services: {}
infra:
  provider: bicep
  path: infra
```

## Phase 4 – Deploy with azd

The `scenario/` directory was created by this agent in Phase 1 when it wrote `scenario/infra/main.bicep`. Run the following commands from that directory:

```bash
cd scenario
azd env new <workloadName>-<environment> --no-prompt
azd provision --no-prompt
```

Replace `<workloadName>-<environment>` with the value used in `azure.yaml`.

If `azd provision` exits with a non-zero code, read the error, attempt one corrective fix (for example, adjusting a parameter value that violates Azure naming rules), and re-run. If the second attempt also fails, report the exact error to the user and stop.

## Phase 5 – Write the Deployment Summary

Create `scenario/deployment-summary.md` after deployment completes:

- Deployment date and time.
- Resource group name.
- App Service default hostname.
- Key Vault URI.
- Deployment status: **Succeeded** or **Failed: \<reason\>**.

## Rules

- Never hard-code passwords, subscription IDs, or tenant IDs.
- Do not delete any existing file in `scenario/`.
- The Bicep instruction file (`.github/instructions/bicep.instructions.md`) is automatically injected when you write `.bicep` files — you do not need to read it manually.
````

---

> **Why `runInTerminal` only here?**
> Only the Bicep + Deploy agent needs to execute `azd` commands. Keeping `runInTerminal` out of the Architect agent's tool list means that even if the Architect agent produced unexpected output, it could not run arbitrary commands on your machine. Restricting tools per agent is a key security practice in multi-agent systems.


### Task 5: Create the Conductor Agent

The Conductor is the only agent the user interacts with directly. It receives the scenario prompt, delegates work to the two specialized agents in sequence, and verifies that each stage produced the expected artifacts before moving on.
It does not write Bicep or architecture documents itself.

Create `.github/agents/01-conductor.agent.md` and paste the following content:

```markdown
---
name: 01-conductor
description: >
  Orchestrates a two-stage infrastructure provisioning solution. Delegates to the Architect and Bicep+Deploy agents in sequence
  and verifies each stage before proceeding. 
  tools: [readFile, createFile]
agents: [02-architect, 03-bicep-deploy]
user-invokable: true
---

# Conductor Agent

You orchestrate a two-stage solution for Azure infrastructure provisioning. You do not write Bicep templates or architecture assessments yourself — you delegate those tasks to specialized agents and verify each output before moving to the next stage.

## Workflow

### Stage 1 – Architecture Assessment

1. Delegate to **02-architect**. Pass the user's complete scenario description as the prompt.
2. After delegation completes, read `scenario/requirements-architecture.md` and confirm it contains all three sections: Parsed Requirements, Architecture Assessment, and Artifact Contract.
3. If the file is missing or incomplete, tell the user exactly what is missing and ask whether to retry before continuing.

### Stage 2 – Bicep Generation and Deployment

4. Delegate to **03-bicep-deploy** with the instruction:
   "Generate and deploy the infrastructure described in `scenario/requirements-architecture.md`."
5. After delegation completes, verify that all four output files exist:
   - `scenario/infra/main.bicep`
   - `scenario/infra/main.bicepparam`
   - `scenario/azure.yaml`
   - `scenario/deployment-summary.md`
6. Read `scenario/deployment-summary.md` and report the deployment status to the user.

## Rules

- Do not perform any architecture decisions or code generation yourself. 
- Always verify artifact existence before advancing to the next stage.
- If a stage fails or an artifact is missing, report the exact problem and ask for direction before retrying.
- After both stages complete, reply to the user with a single summary that includes: the resource group name, the App Service URL, and the Key Vault URI from `scenario/deployment-summary.md`.
```

> **The `agents` array is an authorization boundary:**
> VS Code reads `agents: [02-architect, 03-bicep-deploy]` to determine which agents this Conductor is allowed to invoke via `runSubagent`. Agents not listed here cannot be called by this Conductor — this prevents an agent from delegating to an agent that was not intended to be part of the solution.

---

### Task 6: Run the solution

Your workspace now contains all the files the solution needs. Verify the structure before running:

```
my-agentic-ops/
├── .github/
│   ├── agents/
│   │   ├── 01-conductor.agent.md
│   │   ├── 02-architect.agent.md
│   │   └── 03-bicep-deploy.agent.md
│   ├── skills/
│   │   └── SKILL.md
│   └── instructions/
│       └── bicep.instructions.md
└── .vscode/
    └── settings.json
```

### Step 1: Open Copilot Chat in Agent Mode

1. Open Copilot Chat with `Ctrl+Shift+I`.
1. Select the agent picker (the dropdown at the top of the Chat panel).
1. Select **`01-conductor`** from the list.

   > **If `01-conductor` does not appear:** Open the Command Palette
   > (`Ctrl+Shift+P`) and run **Developer: Reload Window**. If the agent still
   > does not appear, open `.vscode/settings.json` and confirm the path value
   > `.github/agents` exactly matches the folder name you created.

### Step 2: Submit the Scenario Prompt

Paste the following prompt into the Chat input and press **Enter**:

```
Build an Azure web application environment with these components:

- Azure App Service (Linux, .NET 8) for the web front-end
- Azure SQL Database for relational data storage
- Azure Key Vault to store connection strings and secrets
- Managed identity on the App Service to access Key Vault and SQL Database
  without hard-coded passwords

Target environment: development. 
Region: East US 2.
Workload name: webapp
```

### Step 3: Observe the Handoffs

> **Tip:** To follow the `azd` commands as they run, open and focus the Terminal panel: press **`Ctrl+`` ` ``** or run `Ctrl+Shift+P` → **Terminal: Focus Terminal**. The agent's `runInTerminal` calls stream output there in real time, so you can watch `azd provision` progress as it happens.

Watch the Copilot Chat panel. You will see the Conductor:

1. **Delegate to 02-architect** — the Chat panel shows the subagent being invoked. When the Architect finishes, `scenario/requirements-architecture.md` appears in your Explorer panel.

1. **Delegate to 03-bicep-deploy** — the agent reads the architecture file, then creates the files under `scenario/infra/`. When `main.bicep` is written, your `bicep.instructions.md` activates automatically (you do not see this explicitly, but it shapes the output). The agent then runs `azd provision` in the terminal.

1. **Return a summary** — the Conductor reports the resource group name, App Service URL, and Key Vault URI once the deployment summary is written.

> **Note:** `azd provision` may prompt once for subscription confirmation on first run. This is expected — respond in the terminal panel if prompted.

### Step 4: Validate the Output Files

Open each file below and verify that the skill and instruction influenced the output as expected.

**`scenario/requirements-architecture.md`**
- Every resource name in Section 2 should follow the CAF pattern from `SKILL.md` — for example, the Key Vault should be named `kv-webapp-dev`.
- Security notes should reference the rules from `SKILL.md`.

**`scenario/infra/main.bicep`**

Use `Ctrl+F` to search for:

| Search term | Expected result |
|---|---|
| `httpsOnly` | `true` |
| `minimumTlsVersion` | `'1.2'` |
| `identity` | `SystemAssigned` managed identity on App Service |
| `roleAssignment` | Assignment granting App Service identity access to Key Vault |
| `br/public:avm` | At least one AVM module reference |

**`scenario/deployment-summary.md`**
- Status should be **Succeeded**.
- The App Service hostname and Key Vault URI should be present.

> **If deployment failed:** Read the error in `deployment-summary.md` or the terminal. SQL Server names must be globally unique across Azure — if there is a name conflict, edit `scenario/infra/main.bicepparam` to change the `workloadName` value, then select `03-bicep-deploy`** in the agent picker and enter: *"Re-deploy from `scenario/requirements-architecture.md`."*

---

### Task 7 : Commit to Your GitHub Repository

Commit the agent solution to GitHub so you can reuse and share it.

### Step 1: Add a .gitignore

Create `.gitignore` at the workspace root to exclude `azd` environment state and generated artifacts:

```
.azure/
scenario/
*.env
```

### Step 2: Create a GitHub Repository and Push

```bash
gh repo create my-agentic-ops --public --description "Minimal multi-agent Azure provisioning solution"
git init
git add .github/ .vscode/ .gitignore
git commit -m "Initial agent solution: conductor, architect, bicep-deploy"
git branch -M main
git remote add origin https://github.com/<your-github-account>/my-agentic-ops.git
git push -u origin main
```

> **Why only commit `.github/` and `.vscode/`?**
> The `scenario/` folder contains generated deployment artifacts and `azd`
> environment state that includes subscription-specific values. Commit only the
> solution definition — the agent files, skill, instruction, and settings —
> which is what you would share with teammates or reuse in another project.

---

## Exercise 3: Cleanup

Remove the Azure resources created during Exercise 7 to avoid ongoing charges.

```bash
cd scenario
azd down --force --purge
```

The `--purge` flag permanently purges any soft-deleted Key Vault, preventing name conflicts on future deployments. Confirm the resource group is gone in the [Azure portal](https://portal.azure.com).

---

## Summary

You built a three-agent solution from scratch and ran it against a real Azure scenario. The table below maps each file you created to its role in the system:

| File | Building block | How it activates |
|---|---|---|
| `01-conductor.agent.md` | Agent — orchestrator | User selects it in the VS Code Chat agent picker |
| `02-architect.agent.md` | Agent — leaf | Conductor calls it via `runSubagent` |
| `03-bicep-deploy.agent.md` | Agent — leaf | Conductor calls it via `runSubagent` |
| `.github/skills/SKILL.md` | Skill | Each agent's body explicitly reads it (**pull** model) |
| `.github/instructions/bicep.instructions.md` | Instruction | VS Code injects it automatically when any `.bicep` file is written (**push** model) |

The key architectural insight you practiced: **agents share state only through files in `scenario/`**. The Architect writes `requirements-architecture.md`; the Bicep + Deploy agent reads it. They never communicate directly. This isolation means any stage can be replaced or re-run independently — swap the Architect agent for one that uses a different standard, and the downstream Bicep agent is unaffected as long as the output file structure stays the same.

When you want to extend this pipeline, the pattern is:

1. **Create a new `.agent.md`** file in `.github/agents/` for the new stage.
1. **Add its `name` to the Conductor's `agents` array** so the Conductor has permission to call it.
1. **Add a delegation step in the Conductor's workflow** section with the expected input and output artifact.

That is the full extensibility model — no framework, no configuration system, just files.

## Learn More

- [Azure Verified Modules (AVM)](https://aka.ms/avm)
- [Azure Developer CLI documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview)
- [Bicep documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)
- [GitHub Copilot agent mode](https://docs.github.com/en/copilot/using-github-copilot/agents)

