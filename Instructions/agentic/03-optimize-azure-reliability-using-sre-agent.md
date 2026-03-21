---
lab:
  topic: Agentic
  title: 'Optimizing Azure Reliability using Azure SRE Agent'
  description: 'This exercise demonstrates the full agentic operations control loop **Detect → Investigate → Explain → Propose → Approve → Execute → Verify**. Which gets applied to a traditional Azure workload architecture using App Service and Cosmos DB.'
  level: 300
  Duration: 45 minutes
  islab: true
  primarytopics:
    - Azure
    - Azure DevOps
    - MCP
---

# Optimizing Azure Reliability using Azure SRE Agent

## Exercise scenario

This scenario demonstrates the full agentic operations control loop:

**Detect → Investigate → Explain → Propose → Approve → Execute → Verify**

Which gets applied to a traditional Azure workload architecture using App Service and Cosmos DB. Starting from a successfully running scenario, you simulate a managed identity authorization failure error, resulting in HTTP 500 error messages. By using Azure SRE Agent and Agentic AI concepts, you gain experience in using Azure SRE Agent to investigate, troubleshoot, mitigate the incident. The outcome is having a reliable workload scenario back, at the end of the exercise.

A product catalog API running on **Azure App Service** suddenly begins returning HTTP 500 errors. There was no code deployment, and, crucially, no changes to application settings — the `COSMOS_ACCOUNT_ENDPOINT` value is correct. The App Service uses a **system-assigned managed identity** to authenticate to Azure Cosmos DB via Cosmos DB's built-in data-plane RBAC. You as cloud operator, cleaning up stale role assignments, inadvertently deleted the role assignment that granted the App Service identity access to Cosmos DB. Every request that queries the database now fails with an authorization exception. You rely on Azure SRE Agent to investigate, triage, provide a solution and assist in fixing the problem and restoring the workload to a healthy state. 

This is a realistic and increasingly common failure pattern in organizations that have migrated to keyless authentication (managed identity / workload identity). There is no secret to rotate and no connection string to check — the failure lives entirely in the identity and RBAC layer.

This exercise should take approximately **45** minutes to complete.

## Before you start

Before you can start this exercise, ensure you have:

- Access to an **[Azure Subscription](https://portal.azure.com)** with Contributor permissions. (Get a free Azure account: [https://azure.microsoft.com/free/](https://azure.microsoft.com/free/))
- Access to the **[Azure portal Cloud Shell](https://shell.azure.com)** 

> **Note**: At the time of writing this lab, Azure SRE Agent can only be deployed in *EastUS2*, *SwedenCentral* or *AustraliaEast* Azure Regions. The application workload itself, can be deployed in any given Azure region of choice, supporting the workload scenario within your subscription limits.

> **Note**: The Azure SRE Agent uses Large Language Model and Generative AI agents, which don't require a separate GitHub Copilot or similar Generative AI subscription. Billing occurs through your Azure subscription.

---
**OPTIONAL**

For ease of deployment across different platforms, this exercise **suggests to use Azure Cloud Shell**. However, if you want, you can run the scenario deployment from your local development workstation. You need both Azure CLI and Azure Developer CLI installed for this. 

- The Azure Developer CLI is used to provision the baseline Azure infrastructure and manage deployments. Azure Developer CLI is embedded in Azure Cloud Shell. Only if you want to run the deployment from your local machine, instead of Azure Cloud Shell, you need to follow the below installation guidelines.

- **Download Azure Developer CLI**: [https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- **Installation guide**: [Install or update Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- **Verify installation**:
  ```bash
  azd version
  # Should show Azure Developer CLI version 1.5.0 or later
  ```

- The Azure Command-Line Interface (CLI) is used to authenticate and interact with Azure services. Azure CLI is embedded in Azure Cloud Shell. Only if you want to run the deployment from your local machine, instead of Azure Cloud Shell, you need to follow the below installation guidelines.

- **Download Azure CLI**: [https://learn.microsoft.com/cli/azure/install-azure-cli](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Installation guide**: [How to install the Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- **Verify installation**:
  ```bash
  az --version
  # Should show Azure CLI version 2.50.0 or later
  ```

**Platform-specific installation**:
- **Windows**: [Install Azure CLI on Windows](https://learn.microsoft.com/cli/azure/install-azure-cli-windows)
- **macOS**: [Install Azure CLI on macOS](https://learn.microsoft.com/cli/azure/install-azure-cli-macos)
- **Linux**: [Install Azure CLI on Linux](https://learn.microsoft.com/cli/azure/install-azure-cli-linux)

---

### Task 1: Baseline scenario deployment

In this task, you will use Azure Developer CLI to deploy the baseline app API workload in a healthy state. 

1. Log on to the [Azure Portal](https://portal.azure.com) using your Azure admin credentials
2. In the top menu bar, select **Cloud Shell**
3. When it asks for the Shell mode, choose **Bash**
4. From within the terminal view, execute a git clone command, to clone the exercise repo into the Cloud Shell

```bash
git clone https://github.com/MicrosoftLearning/mslearn-devops.git
```
5. Next, navigate into the mslearn-devops folder

```bash
cd ./mslearn-devops
```

6. Trigger the Azure Developer CLI authentication by running the following command:

```bash
azd auth login
```

7. You will get prompted with a **devicelogin** URL and code, similar to below:

```bash
Cloud Shell is automatically authenticated under the initial account used to sign in. Run 'azd auth login' only if you need to use a different account.
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code <YOURCODE> to authenticate.
```

8. Open the **[https://microsoft.com/devicelogin](https://microsoft.com/devicelogin)** URL in the browser, and provide the device login code in the popup window that says 'Enter code to allow access"
9. Select **Next**
10. When asked for your Azure credentials, log on with your Azure admin account credentials. Select **Sign-in**
11. When you are asked if you are trying to sign in to Microsoft Azure CLI, confirm by selecting **Continue**
12. After successful login, you can **close** the devicelogin browser window
13. Back in Azure Cloud Shell, **run** the following command to start the Azure resources deployment

```bash
cd ./sre-agent-src
azd up
```

14. You are prompted for a **unique environment name**. Enter **srelab**
15. You are then prompted for your Azure subscription(s). Select the **subscription** you want to use for this deployment
16. You are prompted for the **Azure region**. Select an Azure region of your choice which support the workload scenario
17. The deployment starts with **'Packaging services (azd package)'**; this should take only a few minutes
18. Next, azd will switch to **'Provisioning Azure resources (azd provision)'**; it will regularly update the deployment status
19. **Wait** for the azd deployment to complete. you see a message **SUCCESS: Your up workflow to provision and deploy to Azure completed in x minutes x seconds.**

> **Note**: The scenario deployment could take 8-10 minutes on average

> **Note**: if the deployment should fail because of regional quota limits, run 'azd down --purge --force', which will delete the resource group and all resources within. Once complete, run 'azd environment new', give a new environment name, followed by 'azd up'. To then select a different Azure region.

20. Once azd deployment is complete, you can **close Azure Cloud Shell**
21. From the Azure Portal, navigate to the new Resource Group that got created **rg-srelab** and validate the resources within (WebApp, Cosmos DB, Log Analytics workspace and a few other).
22. Select the App Service **app-%uniquestring%**. From the **Overview** blade, navigate to **Default domain** and select the **azurewebsites.net** URL. 
23. This opens the web app API in the browser, showing **Catalog API is running**, together with different API links

```
- GET /health - service and Cosmos connectivity check
- GET /products - list products
- GET /orders - list orders
- Swagger UI - interactive API explorer
- OpenAPI JSON - API schema
```

24. Select **GET /health**; this results in a json message similar to this:

```json
{"status":"healthy","timestamp":"2026-03-14T04:22:59.8100086Z"}
```

25. Return to the API home page, and select **GET /products**. This shows a list of products in json format, similar to this:

```json
[{"id":"f8182df5-ee0e-4d72-ad96-2319a0cbe91d","name":"Wireless Keyboard","category":"Electronics","description":"Ergonomic wireless keyboard with backlight","price":79.99,"stock":150},{"id":"41ca5862-a661-4758-93c1-30b2e41137b4","name":"USB-C Monitor","category":"Electronics",
...}]
```

26. This **confirms** the app is running healthy. 

### Task 2: Simulate a failure

With both the app API workload running healthy and Azure SRE Agent deployed, you are ready to break the application and simulate a failure.

1. Navigate to the **App Service**
2. Navigate to **Settings** and select **Identity**
3. Notice the App Service is configured with a **System-Assigned Managed Identity**
4. Select the **Status** toggle button, to switch it off
5. **Save** the changes
6. **Confirm** the popup message *disable system assigned managed identity** by selecting **Yes**
7. From the **App Service Overview** topic, select **Restart** to restart the web app
8. Once restarted, connect to the **web API URL** and select **GET /products**
9. This will result in an error message **Page isn't working**

### Task 3: Deploy Azure SRE Agent

In this task, you will use go through the Azure SRE Agent initial setup and configuration of context. 

1. **Browse** to the [Azure SRE Agent Portal](https://sre.azure.com) in a new browser tab

2. Select **Create Agent**
3. Provide the following information in the **Create agent** window:
- Subscription: **Your Azure Subscription**
- Resource Group: **rg-srelab**
- Agent name: **srelabagent**
- Region: **Azure region of choice**
- Application Insights: **Use existing** / **appi-%uniquestring%**
4. Select **Next** and review the information
5. Select **Create** and wait for the SRE Agent deployment to complete successfully

> **Note**: This task should take only a few minutes

6. Once you get notified about "Deployment succeeded", select **Set up your agent**
7. This brings you to the **More context. Better investigations** page. This is where yo add more context to the SRE agent.
8. Select **Azure Resources**
9. From the **Add Azure resources** popup window, select **Choose resource groups**
10. Select **Next**
11. Select **rg-srelab**
12. Select **Next**
13. Validate **Permission level** = **Reader**
14. Select **Add Resource Group**
15. Wait for the **Granting Permissions** step to complete successfully
16. Back in the **context** page, select **Done and go to agent**

> **Note**: There are more context options available to configure, but they go outside of the scope of this lab exercise

### Task 4: Using Azure SRE Agent to investigate, triage, troubleshoot and mitigate reliability

In this task, you use the deployed SRE Agent as the AI assistant to investigate the outage, verify, reason and suggest a solution. You will then use human-in-the-loop approval to allow Azure SRE Agent to run Azure CLI commands to restore the API to a healthy state.

1. From the **Azure SRE Agent / srelabagent** page, you are greated with a **welcome message** *Hey <account>, let's get to know each other*
2. Also notice several **az cli** commands the agent executed, to get insights on the resource group and resources context
3. The agent collected context information and provides you with a summary, similar to below example:

```
Hey there, System Administrator! I'm your Azure SRE Agent — I help with incident response, debugging, monitoring, and keeping your services running smoothly.

I've already poked around your Azure subscription and here's what I see in rg-srelab (East US 2):

- Web App: app-rcfylfyxlqkau on an App Service Plan
- Cosmos DB: cosmos-rcfylfyxlqkau
- Application Insights: appi-rcfylfyxlqkau with smart detection enabled
- Log Analytics Workspace: log-rcfylfyxlqkau
- Metric Alerts set up for CPU, HTTP 5xx, response time, and dependency failures — nice, you've got monitoring covered!
No code repos connected yet, and this is a fresh start for our knowledge base — so I'm a blank slate ready to learn.

I'd love to understand how all of this fits together. To start — what's your role on the team, and what does this service do? Is this a production workload, a lab environment, something you're building out? And is it just you, or is there a broader team?
```

4. In the chat prompt field, enter the following prompt:
```
Hi srelabagent. I am a cloud operator for my company. Can you investigate the outage of the web app
```

5. The srelabagent gets triggered and triggers different **az cli commands** to start the investigation by **executing webapp show**

The az cli commands look similar to this:

```
az webapp show -g rg-srelab -n app-rcfylfyxlqkau --subscription 498ab842-<redacted> --query "{state:state, defaultHostName:defaultHostName, kind:kind, httpsOnly:httpsOnly, enabled:enabled, availabilityState:availabilityState, runtime:siteConfig.linuxFxVersion, alwaysOn:siteConfig.alwaysOn}" -o json
```

6. Srelabagent asks you for a confirmation to execute this az cli command
7. Select **Grant permissions**
8. **Repeat** for the **executing webapp log** step
9. Srelabagent starts the investigation by reporting **different stages**

- verifying app health status
- starting azure resource
- executing monitor alert
- activating specialized skill
- handling unavailable specialized tools
- starting azure resource

> **Note**: Generative AI is non-determenistic, which means that each agent execution could be slightly different, using different steps, running different az cli commands,... depending on the workload, the outage cause or other. The mentioned steps are examples, so you can become familiar with the reasoning process of the SRE agent, from investigate, collecting and inspecting logs to determine possible mitigation steps.

10. After several investigative steps, srelabagent should detect **HTTP Error 403** (or **HTTP 503 or 500 would also be possible** from App Insights, followed by a new sequence of **az cli commands** to dig in further

11. After this sequence of investigation, it should detect the **authentication flow**, by reporting COSMOS_ACCOUNT_ENDPOINT and validating if the app is using Managed Identity or keys or connection strings.

12. Next, it reports back **Major finding: the webapp has NO managed identity**, as well as confirming the **root cause** of the problem being a missing identity. The response looks like below example:

---
**Root Cause: Missing Managed Identity**

`Azure.Identity.CredentialUnavailableException` — the web app has no Managed Identity assigned (identity: null), but the code uses DefaultAzureCredential to authenticate to Cosmos DB.

**Evidence**

| Signal | Finding |
|--------|---------|
| App Settings | COSMOS_ACCOUNT_ENDPOINT set, but no key — app expects Managed Identity auth |
| Dependencies | GET /metadata/identity/oauth2/token to 169.254.169.254 → Failing |
| Exceptions | CredentialUnavailableException — "No response received from the managed identity endpoint" |
| GET / (home page) | 200 OK (no Cosmos dependency) |
| GET /health | 503 Unhealthy — Cosmos connectivity check fails |
| GET /orders | 500 Internal Server Error |
| GET /products | 500 Internal Server Error |
| Identity | null — no system or user-assigned identity |

**What Happened**

The app is designed to use Managed Identity to authenticate to Cosmos DB (via DefaultAzureCredential). The identity was either never assigned or was removed. Without it, every Cosmos DB operation fails, causing all data endpoints to return 500s.

**Mitigation (2 steps)**

Step 1 — Enable System-Assigned Managed Identity on the web app:

`az webapp identity assign -g rg-srelab -n app-rcfylfyxlqkau --subscription 498ab842-<redacted>
`

Step 2 — Grant the new identity the "Cosmos DB Built-in Data Contributor" role (role ID 00000000-0000-0000-0000-000000000002):

`az cosmosdb sql role assignment create --account-name cosmos-rcfylfyxlqkau -g rg-srelab \
  --role-definition-id 00000000-0000-0000-0000-000000000002 \
  --principal-id <principalId-from-step-1> \
  --scope /subscriptions/498ab842-<redacted>/resourceGroups/rg-srelab/providers/Microsoft.DocumentDB/databaseAccounts/cosmos-rcfylfyxlqkau \
  --subscription 498ab842-<redacted>
`

---

13. **Inspect** the level of detail of the investigation, followed by a detailed overview of evidence, together with detailed steps on how to mitigate the problem. This is the true power of SRE Agent

14. Srelabagent prompts you **would you like me to execute these mitigation steps**. In the chat field, respond with:

```
Yes, go ahead and assist me with fixing this problem using the described steps
```

15. Srelabagent creates a **todo list** of steps, showing the **az cli** command it needs to execute. The first step is **enabling system-assigned managed identity for the web app**

`az webapp identity assign --name app-rcfylfyxlqkau --resource-group rg-srelab --subscription 498ab842-<redacted>`

16. **You are prompted to grant approval**

> **Note**: This approach is known as **human-in-the-loop**, guaranteeing that the AI Agent needs human oversight and approval before executing tasks

17. Select **Approve action**

18. Next, it moves to **step 2: assigning "Cosmos DB Built-in Data Contributor**, and prompting again for your approval. 

`az cosmosdb sql role assignment create --account-name cosmos-rcfylfyxlqkau --resource-group rg-srelab --subscription 498ab842-<redacted> --role-definition-id 00000000-0000-0000-0000-000000000002 --principal-id 7adba2f1-dfb4-4cdb-b8d4-a89e2271aaea --scope /subscriptions/498ab842-<redacted>/resourceGroups/rg-srelab/providers/Microsoft.DocumentDB/databaseAccounts/cosmos-rcfylfyxlqkau`

19. Select **Approve action**

20. Next, it continues with **step 3: restarting the app and verifying**,again asking for your approval.

`az webapp restart --name app-rcfylfyxlqkau --resource-group rg-srelab --subscription 498ab842-<redacted>`

21. Select **Approve action**

22. Srelabagent will confirm the restart step, followed by a validation of the app's health endpoint and data endpoint.

23. Last, Srelabagent confirms the **issue as resolved**, with an overview table of its observation and findings. Similar to below example:

| Step | Action | Result |
| ---- | ------ | ------ |
| 1 | Enabled system-assigned managed identity on the web app | Principal ID: 7adba2f1-dfb4-4cdb-b8d4-a89e2271aaea | 
| 2 | Assigned Cosmos DB Built-in Data Contributor role to the identity | RBAC role assignment created on the Cosmos DB account |
| 3 | Restarted the app and verified | /health → healthy, /products → 200 OK (8 products returned) |

24. From the **Azure portal**, navigate to the **App Service / Overview / Default domain** and select the **web app URL**, to open the web app API in the browser

25. The page should load successfully

26. Select **GET /products**, which should look the product details in json format, **confirming the app's reliability is restored and working successfully** 

## Summary

In this exercise, you applied traditional SRE principles to validate the reliability of a web app workload. You learned how to deploy Azure SRE Agent, and how to configure agent context. Next, you used natural language prompts, to trigger the agent. Using AI skills, in combination with **human-in-the-loop** approvals, Azure SRE Agent assisted with the root-cause investigation and analysis, as well as running the necessary steps to **mitigate** the problem. All this with detailed feedback.

