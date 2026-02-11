---
lab:
  topic: Advanced
  title: "Enable Dynamic Configuration and Feature Flags"
  description: "Learn how to use Azure App Configuration to manage application settings and feature flags centrally with dynamic feature toggling."
---

# Enable Dynamic Configuration and Feature Flags

**Estimated time:** 45 minutes

You will learn how to use Azure App Configuration to manage application settings and feature flags centrally. You'll explore how modern cloud applications can benefit from centralized configuration management and dynamic feature toggling without requiring application redeployment.

This lab takes approximately **45** minutes to complete.

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
1. Select **New Project**
1. Give your project the name **eShopOnWeb**
1. Choose **Scrum** on the **Work Item process** dropdown
1. Select **Create**

## Import the eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code.

1. In your Azure DevOps organization, open the **eShopOnWeb** project
1. Select **Repos > Files**
1. Select **Import**
1. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
1. Select **Import**

The repository is organized this way:

- **.ado** folder contains Azure DevOps YAML pipelines
- **src** folder contains the .NET 8 website used in the lab scenarios

1. Go to **Repos > Branches**
1. Hover on the **main** branch then select the ellipsis on the right
1. Select **Set as default branch**

## Import and run CI/CD Pipelines

You'll import CI/CD pipelines to build and deploy the eShopOnWeb application. The CI pipeline is prepared to build the application and run tests. The CD pipeline will deploy the application to an Azure Web App.

### Import and run the CI pipeline

Let's start by importing the CI pipeline named [eshoponweb-ci.yml](https://github.com/MicrosoftLearning/eShopOnWeb/blob/main/.ado/eshoponweb-ci.yml).

1. Go to **Pipelines > Pipelines**
1. Select **Create Pipeline** (if there are no pipelines) or **New pipeline** (if there are already created pipelines)
1. Select **Azure Repos Git (Yaml)**
1. Select the **eShopOnWeb** repository
1. Select **Existing Azure Pipelines YAML File**
1. Select the **main** branch and the **/.ado/eshoponweb-ci.yml** file
1. Select **Continue**
1. Select the **Run** button to run the pipeline
1. Your pipeline will take a name based on the project name. Let's **rename** it for better identification
1. Go to **Pipelines > Pipelines** and select the recently created pipeline
1. Select on the ellipsis and **Rename/Remove** option
1. Name it **eshoponweb-ci** and select **Save**

### Setup service connection

An Azure Resource Manager service connection allows you to connect to Azure resources like Azure Key Vault from your pipeline. This connection lets you use a pipeline to deploy to Azure resources, such as an Azure App Service app, without needing to authenticate each time.

1. In the Azure DevOps project, go to **Project settings > Service connections**.
1. Select **Create service connection**, then select **Azure Resource Manager** and **Next**.
1. In the **New Azure service connection** pane, verify the following settings and then select **Save**:
   - **Identity type**: App registration (automatic)
   - **Credential**: Workload identity federation
   - **Scope level**: Subscription
   - **Subscription**: _Select the subscription you are using for this lab_
   - **Service Connection Name**: `azure subs`
   - **Grant access permission to all pipelines**: Enabled

### Import and run the CD pipeline

Let's import the CD pipeline named [eshoponweb-cd-webapp-code.yml](https://github.com/MicrosoftLearning/eShopOnWeb/blob/main/.ado/eshoponweb-cd-webapp-code.yml).

1. Go to **Pipelines > Pipelines**
1. Select **New pipeline**
1. Select **Azure Repos Git (Yaml)**
1. Select the **eShopOnWeb** repository
1. Select **Existing Azure Pipelines YAML File**
1. Select the **main** branch and the **/.ado/eshoponweb-cd-webapp-code.yml** file
1. Select **Continue**
1. In the YAML pipeline definition, update the **variable** section:
   - **resource-group**: the name of the resource group, for example **rg-az400-container-NAME** (replace NAME)
   - **location**: the name of the Azure region, for example **southcentralus**
   - **templateFile**: **'webapp.bicep'**
   - **subscriptionid**: your Azure subscription id (From Azure Portal / Subscriptions)
   - **azureserviceconnection**: **'azure subs'**
   - **webappname**: the globally unique name of the web app, for example **az400-webapp-NAME** (replace NAME)
1. In the same YAML pipeline definition, notice the **task: AzureResourceManagerTemplateDeployment@3** section,  
   **inputs** values:
   - **csmFile**: **`\$(Pipeline.Workspace)/eshoponweb-ci/Bicep/$(templateFile)`**
   - this points to the `webapp.bicep` file in the /Bicep folder in the repo; it's a required setting for the AzureResourceManagerTemplateDeployment task configuration. 
1. In the same YAML pipeline definition, notice the **task: AzureRMWebAppDeployment@4** section,  
   **inputs** values:
   - **packageForLinux**: **`\$(Pipeline.Workspace)/eshoponweb-ci/WebSite/Web.zip`**
   - this refers to the Webdeploy zip package (artifact), created out of the Continuous Integration pipeline. 
1. Select **Save and Run**
1. Open the pipeline and wait for it to execute successfully. Deployment should take about 3-5 min on average.

> **Important**: If you see the message "This pipeline needs permission to access resources before this run can continue", select on View, Permit and Permit again.

1. Rename the pipeline to **eshoponweb-cd-webapp-code** for better identification
1. Navigate to the Azure Portal - App Services and select your deployed App Service. From the **Overview** tab, click on the URL in **Default domain** top open the link in your browser. 
1. Confirm the EShopOnWeb web app is running as expected, and showing several product items.

> **Note**: The first time you load the web app, or after a restart of the App Service, it will take a minute or more (browser showing Loading... message in the browser tab), before the site is fully loaded and ready. This is expected, since the product database is getting seeded and loaded into memory on the first load.

## Create Azure App Configuration service

You'll create the Azure App Configuration service to centrally store the application configuration and feature flags.

1. In the Azure portal, search for **App Configuration** and select **Create app configuration**
1. Select the same Resource Group you used for the App Service deployment earlier
1. Specify the same location you used for the App Service deployment for the app configuration resource
1. Enter a name for the configuration store (must be globally unique)
1. Select the **Standard** pricing tier for this lab (required for feature flags)
1. Click **Next: Access settings** and select **Enable Access Keys** under Authentication type
1. Select **Pass-through (Recommended)** as Authentication Method

> **Note:** By enabling both the key-based Authentication type and Pass-through Authentication method, you as an admin get immediate access to configure actual App Configuration settings, as well as enabling Azure RBAC permissions for the Web App resource. Without enabling access keys, there is a potential waiting time of 15min before you as an admin can define App Configuration settings.

1. Select **Review + create** followed by **Create** and wait for the resource deployment to complete.
1. Once the resource is created, go to the resource

## Set up feature flags in App Configuration

You'll create a feature flag to control application features dynamically. In this example, we show a "SalesWeekend" banner on the home page. The Feature Flag toggle enables or disables this.

1. In the left pane of the App Configuration service, select **Feature manager**
1. Select **Create**:
   - **What will you be using your feature flag for**: Switch
   - **Enable feature flag**: toggle to enable
   - **Feature flag name**: SalesWeekend
   - **Key**: _.appconfig.featureflag/_**SalesWeekend** (Gets filled automatically)
   - **Label**: leave empty
   - **Description**: Enables the SalesWeekend promotion banner
1. Confirm the creation with **Review + Create** and once more **Create**

## Configure the Web Application to use App Configuration, using Managed Identity RBAC

1. In the Azure Portal, App Services, go to the WebApp you deployed earlier
1. From **Settings** / **Identity**, **System Assigned** tab, click the **Status** toggle to **On**
1. Click **Save** to save the changes
1. Confirm the popup message _enable system assigned managed identity_ with **Yes**
1. Wait for the **Object (principal) ID** to get created
1. Navigate to the **App Configuration** resource, **Access Control (IAM)** tab
1. Click **Add+** / Add Role Assignment
1. In the _Search by role name, description, permission, or ID_, field, search for **App Configuration Data Reader**  and select it
1. in the **Add Role Assignment** page / **Members** tab, **Assign Access To**, select **Managed Identity**
1. click the **+ Select Members** link, which opens the **Select Managed Identities** blade
1. Under **Managed Identity**, select **App Service (x)**, and select your **App Service Identity**
1. Confirm by clicking **Select** 
1. Confirm by clicking **Review + Assign** twice
1. You can **validate the RBAC permission**, by navigating back to the **Access Control (IAM)** tab of the **App Configuration** resource, select **Role Assignments** and search/filter on **App Configuration**. This will show the App Configuration Data Reader role, and your App Service Managed Identity

### Add App Configuration Environment Variables

In this step, you'll define several App Service Environment Variables to connect to Azure App Configuration.

1. In the Azure Portal, go to your deployed **App Services Web App**
1. Navigate to **Settings / Environment Variables**
1. Notice a few Variables are already defined; don't make any changes to the values or parameters
1. Click **+ Add**, to create the following 2 new variables:

> **Note**: use the "Show Values" option (the eye icon) to unhide the characters while typing

- **Name**: AppConfigEndPoint
- **Value**: The URL of the App Configuration resource, including **https://** (_https://%yourappconfigname%.azconfig.io)
- **Name**: UseAppConfig
- **Value**: true

1. Click **Apply**, **Apply** and **Confirm** to save the changes

### Test feature flag changes

1. In your web application, observe whether the ""SalesWeekend" banner (_All T-Shirts on sale this weekend_) feature is displayed
1. Go back to App Configuration in the Azure portal
1. In **Feature manager**, find the **SalesWeekend** feature flag
1. Toggle its state (enable/disable)
1. Select **Apply**
1. After about 10 seconds, refresh your web application
1. Notice that the "SalesWeekend" banner appears or disappears based on the flag state

## Set up dynamic configuration parameters using Configuration Explorer in App Configuration

You'll create a dynamic configuration parameter to control application features dynamically. In this example, we show a "different message to the user" for empty search results, instead of what has been hard-coded in the application codebase. 

1. From the **Web App Home Page**, notice the **Brand** and **Type** filter options. 
1. In **Brand**, select **.NET**; in **Type**, select **USB Memory Stick**, and press the arrow key to execute a search
1. Notice the default response message "THERE ARE NO RESULTS THAT MATCH YOUR SEARCH"

Using App Configuration, we will change this message, without needing to make changes to the application code.

1. In the left pane of the App Configuration service, select **Configuration Explorer**
1. Select **Create**
1. Select **Key-Value**
   - **Key**: `eShopWeb:Settings:NoResultsMessage`
   - **Value**: `Sorry, we couldn't find what you're looking for. But hey, why not checking for a different item. We heard the T-Shirts are sway!`
   - **Label**: leave empty
   - **Content Type**: leave empty
1. Confirm the creation with **Apply** and once more **Create**

1. From the **Web App Home Page**, notice the **Brand** and **Type** filter options. 
1. In **Brand**, select **.NET**; in **Type**, select **Mugs**. Which will show a few product items.
1. Now, select **Brand** **.NET** and **Type** **USB Memory Stick**. 
1. Notice the **new custom message** as defined in the App Configuration Explorer

> **Note**: This works because the app code itself looks for a parameter _eShopWeb:Settings:NoResultsMessage_ and uses the value from App Config.

## Clean up resources

Remember to delete the resources created in the Azure portal to avoid unnecessary charges:

1. Delete the resource group containing your App Configuration and Web App resources
1. In the Azure portal, navigate to your resource group
1. Select **Delete resource group**
1. Type the resource group name to confirm deletion
1. Select **Delete**

## Summary

In this lab, you learned how to:

- **Enable dynamic configuration** using Azure App Configuration
- **Manage feature flags** for controlled feature rollouts
- **Configure applications** to consume centralized configuration
- **Test configuration changes** without application redeployment

Azure App Configuration provides a powerful way to manage application settings and feature flags centrally, enabling dynamic configuration changes and controlled feature rollouts without requiring application redeployment. This leads to more flexible and maintainable cloud applications.
