---
lab:
    topic: Agentic
    title: 'Optimizing Azure Reliability using Azure SRE Agent'
    description: 'This exercise demonstrates the full agentic operations control loop **Detect → Investigate → Explain → Propose → Approve → Execute → Verify**. Which gets applied to a traditional Azure workload architecture using App Service and Cosmos DB.'
    level: 300
    Duration: 45 minutes
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
- Access to the **Azure portal Cloud Shell** 

> **Note**: At the time of writing this lab, Azure SRE Agent can only be deployed in *EastUS2*, *SwedenCentral* or *AustraliaEast* Azure Regions. The application workload itself, can be deployed in any given Azure region of choice, supporting the workload scenario within your subscription limits.

> **Note**: The Azure SRE Agent uses Large Language Model and Generative AI agents, which don't require a separate GitHub Copilot or similar Generative AI subscription. Billing occurs through your Azure subscription.

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

### Baseline scenario deployment

1. Log on to the [Azure Portal](https://portal.azure.com) using your Azure admin credentials
2. In the top menu bar, select **Cloud Shell**
3. When it asks for the Shell mode, choose **Bash**
4. From within the terminal view, execute a git clone command, to clone the exercise repo into the Cloud Shell

```bash
git clone https://github.com/MicrosoftLearning/mslearn-devops.git
```
5. Next, navigate into the mslearn-devops folder

```bash
cd .\mslearn-devops
```

6. Trigger the Azure Developer CLI authentication by running the following command:

```bash
azd auth login
```

7. You will get prompted with a **devicelogin** URL and code, similar to below:

```bash
Cloud Shell is automatically authenticated under the initial account used to sign in. Run 'azd auth login' only if you need to use a different account.
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code EC3Q7F2GQ to authenticate.
```

8. Open the **devicelogin** URL in the browser, and provide the device login code in the popup window
9. Select "Next"
10. When asked for your Azure credentials, log on with your Azure admin account credentials
11. When you are asked if you are trying to sign in to Microsoft Azure CLI, confirm by selecting **Continue**
12. After successful login, you can close the devicelogin browser window
13. Back in Azure Cloud Shell, run the following command to start the Azure resources deployment

```bash
azd up
```

14. You are prompted for an environment name. Enter **srelab**
15. You are prompted for your Azure subscription(s). Select the subscription you want to use for this deployment
16. You are prompted for the Azure region. Select an Azure region of your choice which support the workload scenario

> **Note**: if the deployment should fail because of regional quota limits, run 'azd down --purge --force', which will delete the resource group and all resources within. Once complete, run 'azd environment new', give a new environment name, followed by 'azd up'. To then select a different Azure region.

17. The deployment starts with 'Packaging services (azd package); this should take only a few minutes
18. Next, azd will switch to 'Provisioning Azure resources (azd provision); i will regularly update the deployment status
19. Wait for the azd deployment to complete. you should see a message **SUCCESS: Your up workflow to provision and deploy to Azure completed in x minutes x seconds.

> **Note**: The scenario deployment could take 10-15 minutes on average

20. Once azd deployment is complete, you can close Azure Cloud Shell
21. From the Azure Portal, navigate to the new Resource Group that got created **rg-srelab** and validate the resources within (WebApp, Cosmos DB, Log Analytics workspace and a few other).
22. Select the App Service **app-%uniquestring%**. From the **Overview** blade, navigate to **Default domain** and select the **azurewebsites.net** URL. 
23. This opens the web app API in the browser  
