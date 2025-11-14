---
lab:
  topic: Advanced
  title: "Implement Self-Service Infrastructure with Bicep"
  description: "Learn how to implement Infrastructure as Code using Bicep for self-service platform engineering scenarios."
---

# Implement Self-Service Infrastructure with Bicep

In this lab, you will learn how to implement Infrastructure as Code (IaC) using Bicep to create self-service infrastructure capabilities for development teams. You will create Bicep templates to deploy Azure resources, enforce governance through policies and tags, and implement automated scaling for platform engineering scenarios.

You will learn how to:

- Set up and use Bicep for Infrastructure as Code
- Create Bicep templates to define and deploy Azure resources
- Deploy Azure App Service with SQL Database backend using Bicep
- Enforce governance using tags and Azure policies
- Implement automated scaling with Bicep

This lab takes approximately **30** minutes to complete.

## Before you start

To complete the lab, you need:

- An Azure subscription to which you have at least the Contributor-level access. If you don't already have one, you can [sign up for one](https://azure.microsoft.com/).
- Access to Azure Cloud Shell or a local environment with Azure CLI installed.
- Basic knowledge of Azure services and Infrastructure as Code concepts.
- Basic familiarity with JSON and declarative syntax.

> **Note:** This lab uses Azure Cloud Shell, which is accessible from the Azure portal and requires no local installation. However, you can also complete this lab using a local environment with Azure CLI and Visual Studio Code installed.

## Create and deploy Bicep templates for Azure resources

In this exercise, you will create a Bicep template to deploy an Azure App Service with a SQL Database backend. This template will include security best practices and governance controls.

### Set up Bicep environment

1. Start a web browser and navigate to the Azure portal at `https://portal.azure.com`.
1. When prompted to authenticate, sign in by using your Azure account.
1. In the Azure portal, select the **Cloud Shell** icon in the top menu bar.
1. If prompted to choose between **Bash** and **PowerShell**, select **Bash**.
1. If this is your first time using Cloud Shell, follow the prompts to create a storage account.
1. Once Cloud Shell is ready, verify that Bicep is available by running:

   ```bash
   az bicep version
   ```

   > **Note:** Bicep comes pre-installed in Azure Cloud Shell. You should see output indicating the Bicep CLI version.

1. To ensure you have the latest version, run:

   ```bash
   az bicep upgrade
   ```

### Create a Bicep template

1. In the Cloud Shell, create a new Bicep file:

   ```bash
   code main.bicep
   ```

1. Copy and paste the following Bicep code into the file:

   ```bicep
   param location string = 'eastus'
   param appServicePlanName string = 'asp-bicep-${uniqueString(resourceGroup().id)}'
   param webAppName string = 'app-bicep-${uniqueString(resourceGroup().id)}'
   param storageAccountName string = 'stbicep${uniqueString(resourceGroup().id)}'
   param sqlServerName string = 'sql-bicep-${uniqueString(resourceGroup().id)}'
   param sqlDatabaseName string = 'bicepdb'
   param sqlAdminUser string
   @secure()
   param sqlAdminPassword string

   targetScope = 'resourceGroup'

   // Storage Account
   resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
     name: storageAccountName
     location: location
     sku: {
       name: 'Standard_LRS'
     }
     kind: 'StorageV2'
     properties: {
       accessTier: 'Hot'
       allowBlobPublicAccess: false
       minimumTlsVersion: 'TLS1_2'
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // App Service Plan
   resource appPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
     name: appServicePlanName
     location: location
     sku: {
       name: 'F1'
       tier: 'Free'
     }
     properties: {
       reserved: false
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // Web App
   resource webApp 'Microsoft.Web/sites@2023-01-01' = {
     name: webAppName
     location: location
     properties: {
       serverFarmId: appPlan.id
       httpsOnly: true
       siteConfig: {
         minTlsVersion: '1.2'
         ftpsState: 'FtpsOnly'
       }
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // SQL Server
   resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
     name: sqlServerName
     location: location
     properties: {
       administratorLogin: sqlAdminUser
       administratorLoginPassword: sqlAdminPassword
       version: '12.0'
       minimalTlsVersion: '1.2'
       publicNetworkAccess: 'Enabled'
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // SQL Database
   resource sqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
     name: sqlDatabaseName
     location: location
     parent: sqlServer
     properties: {
       collation: 'SQL_Latin1_General_CP1_CI_AS'
       maxSizeBytes: 2147483648
       requestedServiceObjectiveName: 'Basic'
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // SQL Server Firewall Rule (Allow Azure Services)
   resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
     name: 'AllowAzureServices'
     parent: sqlServer
     properties: {
       startIpAddress: '0.0.0.0'
       endIpAddress: '0.0.0.0'
     }
   }

   // Outputs
   output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
   output storageAccountName string = storage.name
   output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
   ```

   > **Note:** This template uses the `uniqueString()` function to generate unique names for resources, ensuring that deployments don't fail due to naming conflicts.

1. Save the file by pressing **Ctrl+S** and then close the editor by pressing **Ctrl+Q**.

### Deploy the Bicep template

1. Create a resource group for the deployment:

   ```bash
   az group create --name rg-bicep-infrastructure --location eastus
   ```

1. Validate the Bicep template before deployment:

   ```bash
   az deployment group validate \
     --resource-group rg-bicep-infrastructure \
     --template-file main.bicep \
     --parameters sqlAdminUser='bicepAdmin' sqlAdminPassword='SecureP@ssw0rd123!'
   ```

   > **Note:** Replace the password with a strong password that meets Azure SQL Database requirements.

1. Deploy the template to the resource group:

   ```bash
   az deployment group create \
     --resource-group rg-bicep-infrastructure \
     --template-file main.bicep \
     --parameters sqlAdminUser='bicepAdmin' sqlAdminPassword='SecureP@ssw0rd123!'
   ```

   > **Note:** The deployment may take 3-5 minutes to complete.

1. Wait for the deployment to complete. You should see a confirmation message indicating successful deployment.

1. View the deployment outputs:

   ```bash
   az deployment group show \
     --resource-group rg-bicep-infrastructure \
     --name main \
     --query properties.outputs
   ```

1. Verify the resources were created successfully by listing the resources in the resource group:

   ```bash
   az resource list --resource-group rg-bicep-infrastructure --output table
   ```

You have successfully deployed an Azure App Service with a SQL Database backend using a Bicep template. The template includes security best practices such as HTTPS enforcement, TLS version requirements, and proper tagging for governance.

## Enforce governance with tags and Azure policies

In a self-service infrastructure environment, it is essential to enforce governance to ensure compliance, cost control, and proper resource management. Azure tags and policies are two key mechanisms to achieve this. In this exercise, you will implement governance controls for your infrastructure deployments.

### Verify resource tagging

1. In the Cloud Shell, verify that the resources were deployed with the appropriate tags:

   ```bash
   az resource list --resource-group rg-bicep-infrastructure \
     --query "[].{Name:name, Type:type, Tags:tags}" \
     --output table
   ```

1. Check the tags on the resource group itself:

   ```bash
   az group show --name rg-bicep-infrastructure --query tags
   ```

1. Add tags to the resource group to identify ownership and environment:

   ```bash
   az group update --name rg-bicep-infrastructure \
     --set tags.Environment='Development' tags.Owner='PlatformEngineering' tags.Project='BicepInfrastructure'
   ```

1. Verify the tags were applied:

   ```bash
   az group show --name rg-bicep-infrastructure --query tags
   ```

### Create and implement Azure policies for governance

1. Create a policy definition file to enforce required tags:

   ```bash
   cat > tagging-policy.json << EOF
   {
     "if": {
       "allOf": [
         {
           "field": "type",
           "notIn": [
             "Microsoft.Resources/subscriptions/resourceGroups"
           ]
         },
         {
           "anyOf": [
             {
               "not": {
                 "field": "tags[Environment]",
                 "exists": "true"
               }
             },
             {
               "not": {
                 "field": "tags[Owner]",
                 "exists": "true"
               }
             }
           ]
         }
       ]
     },
     "then": {
       "effect": "deny"
     }
   }
   EOF
   ```

1. Get your subscription ID:

   ```bash
   SUBSCRIPTION_ID=$(az account show --query id --output tsv)
   echo "Subscription ID: $SUBSCRIPTION_ID"
   ```

1. Create the policy definition:

   ```bash
   az policy definition create \
     --name 'require-tags-policy' \
     --display-name 'Require Environment and Owner tags' \
     --description 'Deny creation of resources without Environment and Owner tags' \
     --rules tagging-policy.json \
     --mode All
   ```

1. Assign the policy to the resource group:

   ```bash
   az policy assignment create \
     --name 'require-tags-assignment' \
     --display-name 'Require tags on resources' \
     --policy "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyDefinitions/require-tags-policy" \
     --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-bicep-infrastructure"
   ```

1. Verify the policy assignment:

   ```bash
   az policy assignment list --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-bicep-infrastructure" --output table
   ```

### Test policy enforcement

1. Create a simple Bicep template without required tags to test the policy:

   ```bash
   cat > test-policy.bicep << EOF
   param location string = 'eastus'
   param storageAccountName string = 'testpolicy\${uniqueString(resourceGroup().id)}'

   resource testStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
     name: storageAccountName
     location: location
     sku: {
       name: 'Standard_LRS'
     }
     kind: 'StorageV2'
     // Note: No tags defined - this should be blocked by policy
   }
   EOF
   ```

1. Attempt to deploy the template without required tags:

   ```bash
   az deployment group create \
     --resource-group rg-bicep-infrastructure \
     --template-file test-policy.bicep
   ```

   > **Note:** This deployment should fail due to the policy enforcement, demonstrating that the governance controls are working correctly.

1. Now create a compliant version with the required tags:

   ```bash
   cat > test-policy-compliant.bicep << EOF
   param location string = 'eastus'
   param storageAccountName string = 'testcomp\${uniqueString(resourceGroup().id)}'

   resource testStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
     name: storageAccountName
     location: location
     sku: {
       name: 'Standard_LRS'
     }
     kind: 'StorageV2'
     tags: {
       Environment: 'Testing'
       Owner: 'PlatformEngineering'
     }
   }
   EOF
   ```

1. Deploy the compliant template:

   ```bash
   az deployment group create \
     --resource-group rg-bicep-infrastructure \
     --template-file test-policy-compliant.bicep
   ```

   > **Note:** This deployment should succeed because it includes the required tags.

1. Clean up the test storage account:

   ```bash
   az storage account delete \
     --name "testcompliant$(az group show --name rg-bicep-infrastructure --query id --output tsv | sed 's/.*\///' | tr -d '\n' | openssl dgst -sha1 | cut -c1-13)" \
     --resource-group rg-bicep-infrastructure \
     --yes
   ```

You have successfully implemented and tested governance controls using Azure policies. The policy ensures that all resources deployed to the resource group must include the required Environment and Owner tags, enforcing organizational standards for resource management.

## Implement automated scaling with Bicep

In this exercise, you will enhance your Bicep template to include automated scaling capabilities for the Azure App Service. This will allow the platform to automatically adjust resources based on demand, improving performance and cost efficiency.

### Create an enhanced Bicep template with autoscaling

1. Create a new Bicep template that includes autoscaling capabilities:

   ```bash
   cat > main-autoscale.bicep << 'EOF'
   param location string = 'eastus'
   param appServicePlanName string = 'asp-autoscale-${uniqueString(resourceGroup().id)}'
   param webAppName string = 'app-autoscale-${uniqueString(resourceGroup().id)}'
   param sqlServerName string = 'sql-autoscale-${uniqueString(resourceGroup().id)}'
   param sqlDatabaseName string = 'autoscaledb'
   param sqlAdminUser string
   @secure()
   param sqlAdminPassword string

   targetScope = 'resourceGroup'

   // App Service Plan (Standard tier required for autoscaling)
   resource appPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
     name: appServicePlanName
     location: location
     sku: {
       name: 'S1'
       tier: 'Standard'
       capacity: 1
     }
     properties: {
       perSiteScaling: false
       maximumElasticWorkerCount: 10
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // Web App
   resource webApp 'Microsoft.Web/sites@2023-01-01' = {
     name: webAppName
     location: location
     properties: {
       serverFarmId: appPlan.id
       httpsOnly: true
       siteConfig: {
         minTlsVersion: '1.2'
         ftpsState: 'FtpsOnly'
         alwaysOn: true
       }
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // SQL Server
   resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
     name: sqlServerName
     location: location
     properties: {
       administratorLogin: sqlAdminUser
       administratorLoginPassword: sqlAdminPassword
       version: '12.0'
       minimalTlsVersion: '1.2'
       publicNetworkAccess: 'Enabled'
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // SQL Database
   resource sqlDb 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
     name: sqlDatabaseName
     location: location
     parent: sqlServer
     properties: {
       collation: 'SQL_Latin1_General_CP1_CI_AS'
       maxSizeBytes: 2147483648
       requestedServiceObjectiveName: 'S1'
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // Autoscale Settings
   resource autoscaleSetting 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
     name: 'autoscale-${appServicePlanName}'
     location: location
     properties: {
       targetResourceUri: appPlan.id
       enabled: true
       profiles: [
         {
           name: 'defaultProfile'
           capacity: {
             minimum: '1'
             maximum: '5'
             default: '1'
           }
           rules: [
             {
               metricTrigger: {
                 metricName: 'CpuPercentage'
                 metricResourceUri: appPlan.id
                 operator: 'GreaterThan'
                 threshold: 75
                 timeAggregation: 'Average'
                 timeGrain: 'PT1M'
                 timeWindow: 'PT5M'
                 statistic: 'Average'
               }
               scaleAction: {
                 direction: 'Increase'
                 type: 'ChangeCount'
                 value: '1'
                 cooldown: 'PT5M'
               }
             }
             {
               metricTrigger: {
                 metricName: 'CpuPercentage'
                 metricResourceUri: appPlan.id
                 operator: 'LessThan'
                 threshold: 25
                 timeAggregation: 'Average'
                 timeGrain: 'PT1M'
                 timeWindow: 'PT10M'
                 statistic: 'Average'
               }
               scaleAction: {
                 direction: 'Decrease'
                 type: 'ChangeCount'
                 value: '1'
                 cooldown: 'PT10M'
               }
             }
           ]
         }
       ]
     }
     tags: {
       Environment: 'Development'
       Owner: 'PlatformEngineering'
     }
   }

   // Outputs
   output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
   output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
   output autoscaleSettingName string = autoscaleSetting.name
   EOF
   ```

1. Validate the enhanced Bicep template:

   ```bash
   az deployment group validate \
     --resource-group rg-bicep-infrastructure \
     --template-file main-autoscale.bicep \
     --parameters sqlAdminUser='autoscaleAdmin' sqlAdminPassword='SecureP@ssw0rd123!'
   ```

### Deploy the autoscaling infrastructure

1. Deploy the enhanced template with autoscaling capabilities:

   ```bash
   az deployment group create \
     --resource-group rg-bicep-infrastructure \
     --template-file main-autoscale.bicep \
     --parameters sqlAdminUser='autoscaleAdmin' sqlAdminPassword='SecureP@ssw0rd123!'
   ```

   > **Note:** This deployment will upgrade the existing App Service Plan to Standard tier and add autoscaling rules.

1. Verify the deployment completed successfully:

   ```bash
   az deployment group show \
     --resource-group rg-bicep-infrastructure \
     --name main-autoscale \
     --query properties.provisioningState
   ```

1. Check the autoscale settings were created:

   ```bash
   az monitor autoscale list \
     --resource-group rg-bicep-infrastructure \
     --output table
   ```

1. View the details of the autoscale configuration:

   ```bash
   AUTOSCALE_NAME=$(az monitor autoscale list --resource-group rg-bicep-infrastructure --query "[0].name" --output tsv)
   az monitor autoscale show \
     --resource-group rg-bicep-infrastructure \
     --name "$AUTOSCALE_NAME" \
     --query "{Name:name, Enabled:enabled, MinCapacity:profiles[0].capacity.minimum, MaxCapacity:profiles[0].capacity.maximum, Rules:length(profiles[0].rules)}"
   ```

### Validate autoscaling configuration

1. Navigate to the Azure portal and verify the autoscaling configuration:

   - Go to your resource group `rg-bicep-infrastructure`
   - Select the App Service Plan
   - In the left menu, select **Scale out (App Service plan)**
   - Verify that autoscaling is enabled with the rules you defined

1. View the current instance count and scaling history:

   ```bash
   APP_SERVICE_PLAN=$(az appservice plan list --resource-group rg-bicep-infrastructure --query "[0].name" --output tsv)
   az appservice plan show \
     --resource-group rg-bicep-infrastructure \
     --name "$APP_SERVICE_PLAN" \
     --query "{Name:name, Sku:sku.name, CurrentInstances:numberOfWorkers, MaxWorkers:maximumNumberOfWorkers}"
   ```

   > **Note:** To fully test autoscaling behavior, you would need to generate load on the application to trigger the CPU threshold. This could be done using load testing tools, but for this lab, verifying the configuration is sufficient.

You have successfully implemented automated scaling for Azure App Service using Bicep. The autoscaling configuration will:

- Scale out (add instances) when CPU usage exceeds 75% for 5 minutes
- Scale in (remove instances) when CPU usage falls below 25% for 10 minutes
- Maintain between 1 and 5 instances
- Include cooldown periods to prevent rapid scaling actions

This ensures your applications can handle varying traffic loads efficiently while optimizing costs.

## Clean up resources

Now that you finished the exercise, you should delete the cloud resources you created to avoid unnecessary resource usage.

1. In your browser navigate to the Azure portal [https://portal.azure.com](https://portal.azure.com); signing in with your Azure credentials if prompted.
1. Navigate to the resource group you created and view the contents of the resources used in this exercise.
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name and confirm that you want to delete it.

> **CAUTION:** Deleting a resource group deletes all resources contained within it. If you chose an existing resource group for this exercise, any existing resources outside the scope of this exercise will also be deleted.
