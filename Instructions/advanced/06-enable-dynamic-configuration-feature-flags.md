---
lab:
  topic: Advanced
  title: "Enable Dynamic Configuration and Feature Flags"
  description: "Learn how to use Azure App Configuration to manage application settings and feature flags centrally with dynamic feature toggling."
---

# Enable Dynamic Configuration and Feature Flags

**Estimated time:** 45 minutes

You will learn how to use Azure App Configuration to manage application settings and feature flags centrally. You'll explore how modern cloud applications can benefit from centralized configuration management and dynamic feature toggling without requiring application redeployment.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://learn.microsoft.com/azure/devops/server/compatibility)
- **Azure subscription:** You need an active Azure subscription or can create a new one
- **Azure DevOps organization:** Create one at [Create an organization or project collection](https://learn.microsoft.com/azure/devops/organizations/accounts/create-organization?view=azure-devops) if you don't have one
- **Account permissions:** You need a Microsoft account or Microsoft Entra account with Contributor or Owner role in the Azure subscription
  - For details, see [List Azure role assignments using the Azure portal](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-list-portal) and [View and assign administrator roles in Azure Active Directory](https://learn.microsoft.com/azure/active-directory/roles/manage-roles-portal)

## About Azure App Configuration

[Azure App Configuration](https://learn.microsoft.com/azure/azure-app-configuration/overview) provides a service to manage application settings and feature flags centrally. Modern programs, especially those running in a cloud, generally have many distributed components. Spreading configuration settings across these components can lead to hard-to-troubleshoot errors during application deployment. Use App Configuration to store all the settings for your application and secure their access in one place.

Key benefits include:

- **Centralized management** of application settings and feature flags
- **Dynamic configuration** changes without application restart
- **Feature flag management** for controlled feature rollouts
- **Point-in-time configuration** snapshots for rollback scenarios
- **Integration** with Azure Key Vault for sensitive settings

## Create and configure the team project

First, you'll create an Azure DevOps project for this lab.

1. In your browser, open your Azure DevOps organization
2. Select **New Project**
3. Give your project the name **eShopOnWeb**
4. Choose **Scrum** on the **Work Item process** dropdown
5. Select **Create**

## Import the eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code.

1. In your Azure DevOps organization, open the **eShopOnWeb** project
2. Select **Repos > Files**
3. Select **Import**
4. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
5. Select **Import**

The repository is organized this way:

- **.ado** folder contains Azure DevOps YAML pipelines
- **src** folder contains the .NET 8 website used in the lab scenarios

6. Go to **Repos > Branches**
7. Hover on the **main** branch then select the ellipsis on the right
8. Select **Set as default branch**

## Import and run CI/CD Pipelines

You'll import CI/CD pipelines to build and deploy the eShopOnWeb application. The CI pipeline is prepared to build the application and run tests. The CD pipeline will deploy the application to an Azure Web App.

### Setup service connection

An Azure Resource Manager service connection allows you to connect to Azure resources like Azure Key Vault from your pipeline. This connection lets you use a pipeline to deploy to Azure resources, such as an Azure App Service app, without needing to authenticate each time.

1. In the Azure DevOps project, go to **Project settings > Service connections**.
2. Select **Create service connection**, then select **Azure Resource Manager** and **Next**.
3. In the **New Azure service connection** pane, verify the following settings and then select **Save**:
   - **Identity type**: App registration (automatic)
   - **Credential**: Workload identity federation
   - **Scope level**: Subscription
   - **Subscription**: *Select the subscription you are using for this lab*
   - **Service Connection Name**: `azure subs`
   - **Grant access permission to all pipelines**: Enabled

### Import and run the CI pipeline

Let's start by importing the CI pipeline named [eshoponweb-ci.yml](https://github.com/MicrosoftLearning/eShopOnWeb/blob/main/.ado/eshoponweb-ci.yml).

1. Go to **Pipelines > Pipelines**
2. Select **Create Pipeline** (if there are no pipelines) or **New pipeline** (if there are already created pipelines)
3. Select **Azure Repos Git (Yaml)**
4. Select the **eShopOnWeb** repository
5. Select **Existing Azure Pipelines YAML File**
6. Select the **main** branch and the **/.ado/eshoponweb-ci.yml** file
7. Select **Continue**
8. Select the **Run** button to run the pipeline
9. Your pipeline will take a name based on the project name. Let's **rename** it for better identification
10. Go to **Pipelines > Pipelines** and select the recently created pipeline
11. Select the ellipsis and **Rename/Remove** option
12. Name it **eshoponweb-ci** and select **Save**

### Import and run the CD pipeline

Let's import the CD pipeline named [eshoponweb-cd-webapp-code.yml](https://github.com/MicrosoftLearning/eShopOnWeb/blob/main/.ado/eshoponweb-cd-webapp-code.yml).

1. Go to **Pipelines > Pipelines**
2. Select **New pipeline**
3. Select **Azure Repos Git (Yaml)**
4. Select the **eShopOnWeb** repository
5. Select **Existing Azure Pipelines YAML File**
6. Select the **main** branch and the **/.ado/eshoponweb-cd-webapp-code.yml** file
7. Select **Continue**
8. In the YAML pipeline definition, set the variable section:
   - **resource-group**: the name of the resource group, for example **rg-az400-container-NAME** (replace NAME)
   - **location**: the name of the Azure region, for example **southcentralus**
   - **templateFile**: **'webapp.bicep'**
   - **subscriptionid**: your Azure subscription id
   - **azureserviceconnection**: **'azure subs'**
   - **webappname**: the globally unique name of the web app, for example **az400-webapp-NAME**
9. Select **Save and Run**
10. Open the pipeline and wait for it to execute successfully

> **Important**: If you see the message "This pipeline needs permission to access resources before this run can continue", select View, Permit and Permit again.

11. Rename the pipeline to **eshoponweb-cd-webapp-code** for better identification

## Create Azure App Configuration service

You'll create the Azure App Configuration service to centrally store the application configuration and feature flags.

1. In the Azure portal, search for **App Configuration** and select **Create app configuration**
2. Select or create a resource group
3. Specify the location for the app configuration resource
4. Enter a name for the configuration store (must be globally unique)
5. Select the **Standard** pricing tier for this lab (required for feature flags)
6. Select **Review + create** then **Create**
7. Once the resource is created, go to the resource

## Set up configuration keys in App Configuration

You'll add configuration keys that your application will consume.

1. In the left pane of the App Configuration service, under **Operations**, select **Configuration explorer**
2. Select **Create > Key-value** and add:
   - **Key**: eShopOnWeb:Settings:ShowPipelineInfo
   - **Value**: true
   - **Label**: leave empty
   - **Content type**: leave empty
3. Select **Apply** and repeat the process to add these keys:
   - **Key**: eShopOnWeb:Settings:ShowImageDevVersion, **Value**: false
   - **Key**: eShopOnWeb:Settings:ShowImageProdVersion, **Value**: true

## Set up feature flags in App Configuration

You'll create feature flags to control application features dynamically.

1. In the left pane of the App Configuration service, select **Feature manager**
2. Select **Create** and add **Feature flag**:
   - **Enable feature flag**: checked
   - **Feature flag name**: ShoppingCart
   - **Label**: leave empty
   - **Description**: Enable the shopping cart feature
3. Select **Apply**
4. Repeat to create another feature flag:
   - **Feature flag name**: Pipeline
   - **Description**: Enable the pipeline information display

## Configure the application to use App Configuration

You'll modify the application to connect to Azure App Configuration.

### Add App Configuration connection string

1. In the Azure portal, go to your App Configuration resource
2. Select **Access settings** under **Settings** from the left menu
3. Copy the **Primary** connection string
4. Go to your Azure Web App resource (created by the CD pipeline)
5. In the left menu, under **Settings**, select **Environment variables**
6. Select the **Connection strings** tab and add:
   - **Name**: AppConfig
   - **Value**: [paste the App Configuration connection string]
   - **Type**: Custom
   - **Deployment slot setting**: leave unchecked
7. Select **Apply**, then select **Apply** again

### Update application code

The sample application is already configured to use Azure App Configuration. The key integration points are:

1. **Program.cs** - The application is configured to use App Configuration:

   ```csharp
   builder.Host.ConfigureAppConfiguration((hostingContext, config) =>
   {
       var settings = config.Build();
       config.AddAzureAppConfiguration(options =>
       {
           options.Connect(settings.GetConnectionString("AppConfig"))
                  .UseFeatureFlags();
       });
   });
   ```

2. **Views** - The application uses feature flags to conditionally show content:
   ```html
   <feature name="ShoppingCart">
     <div>Shopping cart feature is enabled!</div>
   </feature>
   ```

## Test dynamic configuration and feature flags

You'll test the dynamic configuration capabilities by changing settings without redeploying the application.

### Test configuration changes

1. Navigate to your deployed web application URL
2. Observe the current display of pipeline information
3. Go back to App Configuration in the Azure portal
4. In **Configuration explorer**, find the **eShopOnWeb:Settings:ShowPipelineInfo** key
5. Change its value from **true** to **false**
6. Select **Apply**
7. Refresh your web application (may take up to 30 seconds to refresh)
8. Notice that the pipeline information is no longer displayed

### Test feature flag changes

1. In your web application, observe whether the shopping cart feature is displayed
2. Go back to App Configuration in the Azure portal
3. In **Feature manager**, find the **ShoppingCart** feature flag
4. Toggle its state (enable/disable)
5. Select **Apply**
6. Refresh your web application
7. Notice that the shopping cart feature appears or disappears based on the flag state

## Advanced feature flag scenarios

Feature flags support more advanced scenarios:

### Conditional activation

1. In the Azure portal, go to your App Configuration **Feature manager**
2. Select the **Pipeline** feature flag
3. Select **Add filter**
4. Select **Targeting filter**
5. Configure percentage-based rollout:
   - **Default percentage**: 50
   - **Groups**: Leave empty for this demo
6. Select **Apply**

This configuration will show the feature to 50% of users randomly.

### Time-based activation

1. Create a new feature flag called **SpecialOffer**
2. Add a **Time Window** filter
3. Set a start and end time for when the feature should be active
4. This allows you to automatically enable/disable features based on time

## Monitor App Configuration usage

You can monitor how your application uses App Configuration:

1. In the Azure portal, go to your App Configuration resource
2. Select **Monitoring** from the left menu
3. Select **Metrics** to see:
   - **Requests** - Number of configuration requests
   - **Throttled requests** - Requests that were throttled
   - **Storage utilization** - How much storage is being used

## Clean up resources

Remember to delete the resources created in the Azure portal to avoid unnecessary charges:

1. Delete the resource group containing your App Configuration and Web App resources
2. In the Azure portal, navigate to your resource group
3. Select **Delete resource group**
4. Type the resource group name to confirm deletion
5. Select **Delete**

## Summary

In this lab, you learned how to:

- **Enable dynamic configuration** using Azure App Configuration
- **Manage feature flags** for controlled feature rollouts
- **Configure applications** to consume centralized configuration
- **Test configuration changes** without application redeployment
- **Implement advanced feature flag scenarios** like percentage rollouts and time-based activation

Azure App Configuration provides a powerful way to manage application settings and feature flags centrally, enabling dynamic configuration changes and controlled feature rollouts without requiring application redeployment. This leads to more flexible and maintainable cloud applications.
