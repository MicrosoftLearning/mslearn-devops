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

- Access to an [Azure Subscription](https://portal.azure.com) with Contributor permissions. (**Get a free Azure account**: [https://azure.microsoft.com/free/](https://azure.microsoft.com/free/))

> **Note**: At the time of writing this lab, Azure SRE Agent can be deployed in *EastUS2*, *SwedenCentral* or *AustraliaEast* Azure Regions. The workload it will run against, can be deployed in any given Azure region of choice, supporting the workload scenario within your subscription limits.


> **Note**: The Azure SRE Agent uses Large Language Model and Generative AI agents, which don't require a separate GitHub Copilot or similar Generative AI subscription. Billing occurs through your Azure subscription.

- The Azure Developer CLI is used to provision the baseline Azure infrastructure and manage deployments. 

- **Download Azure Developer CLI**: [https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- **Installation guide**: [Install or update Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- **Verify installation**:
  ```bash
  azd version
  # Should show Azure Developer CLI version 1.5.0 or later
  ```

- The Azure Command-Line Interface (CLI) is used to authenticate and interact with Azure services.

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

To speed up the deployment of the Azure resources used in this scenario, you use Azure Developer CLI