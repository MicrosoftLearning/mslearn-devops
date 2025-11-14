---
lab:
  topic: Advanced
  title: "Control Deployments using Release Gates"
  description: "Learn how to configure deployment gates and use them to control the execution of Azure Pipelines with environment-specific deployment criteria."
---

# Control Deployments using Release Gates

**Estimated time:** 75 minutes

You will learn how to configure deployment gates and use them to control the execution of Azure Pipelines. You'll configure a release definition with two environments for an Azure Web App, deploying to the DevTest environment only when there are no blocking bugs, and marking the DevTest environment complete only when there are no active alerts in Application Insights.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure subscription:** You need an active Azure subscription or can create a new one
- **Azure DevOps organization:** Create one at [Create an organization or project collection](https://docs.microsoft.com/azure/devops/organizations/accounts/create-organization) if you don't have one
- **Account permissions:** You need a Microsoft account or Microsoft Entra account with:
  - Owner role in the Azure subscription
  - Global Administrator role in the Microsoft Entra tenant
  - For details, see [List Azure role assignments using the Azure portal](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-list-portal) and [View and assign administrator roles in Azure Active Directory](https://docs.microsoft.com/azure/active-directory/roles/manage-roles-portal)

## About release gates

A release pipeline specifies the end-to-end release process for an application to be deployed across various environments. Deployments to each environment are fully automated using jobs and tasks. It's a best practice to expose updates in a phased manner - expose them to a subset of users, monitor their usage, and expose them to other users based on the experience of the initial set.

Approvals and gates enable you to take control over the start and completion of deployments in a release. You can wait for users to approve or reject deployments manually with approvals. Using release gates, you can specify application health criteria to be met before the release is promoted to the following environment.

Gates can be added to an environment in the release definition from the pre-deployment conditions or the post-deployment conditions panel. Multiple gates can be added to ensure all inputs are successful for the release.

There are 4 types of gates included by default:

- **Invoke Azure Function:** Trigger execution of an Azure Function and ensure successful completion
- **Query Azure Monitor alerts:** Observe configured Azure Monitor alert rules for active alerts
- **Invoke REST API:** Make a call to a REST API and continue if it returns a successful response
- **Query work items:** Ensure the number of matching work items returned from a query is within a threshold

## Create and configure the team project

First, you'll create an Azure DevOps project for this lab.

1. In your browser, open your Azure DevOps organization
1. Select **New Project**
1. Give your project the name **eShopOnWeb**
1. Leave other fields with defaults
1. Select **Create**

   ![Screenshot of the create new project panel](media/create-project.png)

## Import the eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code.

1. In your Azure DevOps organization, open the **eShopOnWeb** project
1. Select **Repos > Files**
1. Select **Import a Repository**
1. Select **Import**
1. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
1. Select **Import**

   ![Screenshot of the import repository panel](media/import-repo.png)

The repository is organized this way:

- **.ado** folder contains Azure DevOps YAML pipelines
- **.devcontainer** folder contains setup to develop using containers
- **infra** folder contains Bicep & ARM infrastructure as code templates
- **.github** folder contains YAML GitHub workflow definitions
- **src** folder contains the .NET 8 website used in the lab scenarios

1. Go to **Repos > Branches**
1. Hover on the **main** branch then select the ellipsis on the right
1. Select **Set as default branch**

## Configure CI Pipeline

You'll add a YAML build definition to the project.

1. Navigate to the **Pipelines** section
1. In the **Create your first Pipeline** window, select **Create pipeline**
1. On the **Where is your code?** pane, select **Azure Repos Git (YAML)**
1. On the **Select a repository** pane, select **eShopOnWeb**
1. On the **Configure your pipeline** pane, scroll down and select **Existing Azure Pipelines YAML File**
1. In the **Selecting an existing YAML File** blade, specify:
   - Branch: **main**
   - Path: **.ado/eshoponweb-ci.yml**
1. Select **Continue** to save these settings
1. From the **Review your Pipeline YAML** screen, select **Run** to start the Build Pipeline
1. Wait for the Build Pipeline to complete successfully
1. Go to **Pipelines > Pipelines** and select on the recently created pipeline
1. Select on the ellipsis and **Rename/move** option
1. Name it **eshoponweb-ci** and select **Save**

## Create Azure Resources for the Release Pipeline

You'll create two Azure web apps representing the DevTest and Production environments.

### Create two Azure web apps

1. From your lab computer, navigate to the [Azure Portal](https://portal.azure.com)
1. Sign in with the user account that has the Owner role in your Azure subscription
1. In the Azure portal, select the **Cloud Shell** icon (to the right of the search box)
1. If prompted to select either **Bash** or **PowerShell**, select **Bash**

> **Note**: If this is your first time starting Cloud Shell and you see the "You have no storage mounted" message, select your subscription and select "Apply".

1. From the Bash prompt, run this command to create a resource group (replace `<region>` with your preferred Azure region):

   ```bash
   REGION='<region>'
   RESOURCEGROUPNAME='az400m03l08-RG'
   az group create -n $RESOURCEGROUPNAME -l $REGION
   ```

1. Create an App service plan:

   ```bash
   SERVICEPLANNAME='az400m03l08-sp1'
   az appservice plan create -g $RESOURCEGROUPNAME -n $SERVICEPLANNAME --sku S1
   ```

1. Create two web apps with unique names:

   ```bash
   SUFFIX=$RANDOM$RANDOM
   az webapp create -g $RESOURCEGROUPNAME -p $SERVICEPLANNAME -n RGATES$SUFFIX-DevTest
   az webapp create -g $RESOURCEGROUPNAME -p $SERVICEPLANNAME -n RGATES$SUFFIX-Prod
   ```

> **Note**: Record the name of the DevTest web app. You'll need it later.

> **Note**: If you get an error about the subscription not being registered to use namespace 'Microsoft.Web', run: `az provider register --namespace Microsoft.Web` and wait for registration to complete.

1. Wait for the provisioning process to complete and close the Cloud Shell pane

### Configure an Application Insights resource

1. In the Azure portal, search for **Application Insights** and select it from the results
1. On the **Application Insights** blade, select **+ Create**
1. On the **Basics** tab, specify these settings:

   | Setting        | Value                                                  |
   | -------------- | ------------------------------------------------------ |
   | Resource group | **az400m03l08-RG**                                     |
   | Name           | the name of the DevTest web app from the previous task |
   | Region         | the same Azure region where you deployed the web apps  |

1. Select **Review + create** and then select **Create**
1. Wait for the provisioning process to complete
1. Navigate to the resource group **az400m03l08-RG**
1. In the list of resources, select the **DevTest** web app
1. On the DevTest web app page, in the left menu under **Monitoring**, select **Application Insights**
1. Select **Turn on Application Insights**
1. In the **Change your resource** section, select **Select existing resource**
1. Select the newly created Application Insight resource
1. Select **Apply** and when prompted for confirmation, select **Yes**
1. Wait until the change takes effect

### Create monitor alerts

1. From the same **Application Insights** menu, select **View Application Insights Data**
1. On the Application Insights resource blade, under **Monitoring**, select **Alerts**
1. Select **Create > Alert rule**
1. In the **Condition** section, select **See all signals**
1. Type **Requests** and from the results, select **Failed Requests**
1. In the **Condition** section, leave **Threshold** set to **Static** and validate these defaults:
   - Aggregation Type: Count
   - Operator: Greater Than
   - Unit: Count
1. In the **Threshold value** textbox, type **0**
1. Select **Next:Actions**
1. Don't make changes in Actions, and define these parameters under **Details**:

   | Setting                                        | Value                            |
   | ---------------------------------------------- | -------------------------------- |
   | Severity                                       | **2- Warning**                   |
   | Alert rule name                                | **RGATESDevTest_FailedRequests** |
   | Advanced Options: Automatically resolve alerts | **cleared**                      |

1. Select **Review+Create**, then **Create**
1. Wait for the alert rule to be created successfully

> **Note**: Metric alert rules might take up to 10 minutes to activate.

## Configure the Release Pipeline

You'll configure a release pipeline with deployment gates.

### Set Up Release Tasks

1. From the **eShopOnWeb** project in Azure DevOps, select **Pipelines** and then **Releases**
1. Select **New Pipeline**
1. From the **Select a template** window, choose **Azure App Service Deployment** under **Featured** templates
1. Select **Apply**
1. In the Stage window, update the default "Stage 1" name to **DevTest**
1. Close the popup window using the **X** button
1. On the top of the page, rename the pipeline from **New release pipeline** to **eshoponweb-cd**
1. Hover over the DevTest Stage and select the **Clone** button
1. Name the cloned stage **Production**

> **Note**: The pipeline now contains two stages named **DevTest** and **Production**.

1. On the **Pipeline** tab, select the **Add an Artifact** rectangle
1. Select **eshoponweb-ci** in the **Source (build pipeline)** field
1. Select **Add** to confirm the selection
1. From the **Artifacts** rectangle, select the **Continuous deployment trigger** (lightning bolt)
1. Select **Disabled** to toggle the switch and enable it
1. Leave all other settings at default and close the pane

### Configure DevTest stage

1. Within the **DevTest Environments** stage, select the **1 job, 1 task** label
1. In the **Azure subscription** dropdown, select your Azure subscription and select **Authorize**
1. Authenticate using the user account with the Owner role in the Azure subscription
1. Confirm the App Type is set to "Web App on Windows"
1. In the **App Service name** dropdown, select the name of the **DevTest** web app
1. Select the **Deploy Azure App Service** task
1. In the **Package or Folder** field, update the default value to: `$(System.DefaultWorkingDirectory)/**/Web.zip`
1. Open **Application and Configuration Settings** and enter this in **App settings**: `-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development`

### Configure Production stage

1. Navigate to the **Pipeline** tab and within the **Production** Stage, select **1 job, 1 task**
1. Under the Tasks tab, in the **Azure subscription** dropdown, select the Azure subscription you used for the DevTest stage
1. In the **App Service name** dropdown, select the name of the **Prod** web app
1. Select the **Deploy Azure App Service** task
1. In the **Package or Folder** field, update the default value to: `$(System.DefaultWorkingDirectory)/**/Web.zip`
1. Open **Application and Configuration Settings** and enter this in **App settings**: `-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development`
1. Select **Save** and in the Save dialog box, select **OK**

### Test the release pipeline

1. In the **Pipelines** section, select **Pipelines**
1. Select the **eshoponweb-ci** build pipeline and then select **Run Pipeline**
1. Accept the default settings and select **Run** to trigger the pipeline
1. Wait for the build pipeline to finish

> **Note**: After the build succeeds, the release will be triggered automatically and the application will be deployed to both environments.

1. In the **Pipelines** section, select **Releases**
1. On the **eshoponweb-cd** pane, select the entry representing the most recent release
1. Track the progress of the release and verify that deployment to both web apps completed successfully
1. Switch to the Azure portal, navigate to the **az400m03l08-RG** resource group
1. Select the **DevTest** web app, then select **Browse**
1. Verify that the web page loads successfully in a new browser tab
1. Repeat for the **Production** web app
1. Close the browser tabs displaying the EShopOnWeb web site

## Configure Release Gates

You'll set up Quality Gates in the release pipeline.

### Configure pre-deployment gates for approvals

1. In the Azure DevOps portal, open the **eShopOnWeb** project
1. In **Pipelines > Releases**, select **eshoponweb-cd** and then **Edit**
1. On the left edge of the **DevTest Environment** stage, select the oval shape representing **Pre-deployment conditions**
1. On the **Pre-deployment conditions** pane, set the **Pre-deployment approvals** slider to **Enabled**
1. In the **Approvers** text box, type and select your Azure DevOps account name

> **Note**: In a real-life scenario, this should be a DevOps Team name alias instead of your own name.

1. **Save** the pre-approval settings and close the popup window
1. Select **Create Release** and confirm by pressing **Create**
1. Notice "Release-2" has been created. Select the "Release-2" link to navigate to its details
1. Notice the **DevTest** Stage is in a **Pending Approval** state
1. Select the **Approve** button to trigger the DevTest Stage

### Configure post-deployment gates for Azure Monitor

1. Back on the **eshoponweb-cd** pane, on the right edge of the **DevTest Environment** stage, select the oval shape representing **Post-deployment conditions**
1. Set the **Gates** slider to **Enabled**
1. Select **+ Add** and select **Query Azure Monitor Alerts**
1. In the **Query Azure Monitor Alerts** section:
   - **Azure subscription**: Select the service connection representing your Azure subscription
   - **Resource group**: Select **az400m03l08-RG**
1. Expand the **Advanced** section and configure:
   - Filter type: **None**
   - Severity: **Sev0, Sev1, Sev2, Sev3, Sev4**
   - Time Range: **Past Hour**
   - Alert State: **Acknowledged, New**
   - Monitor Condition: **Fired**
1. Expand **Evaluation options** and configure:
   - **Time between re-evaluation of gates**: **5 Minutes**
   - **Timeout after which gates fail**: **8 Minutes**
   - Select **On successful gates, ask for approvals**

> **Note**: The sampling interval and timeout work together so that gates will call their functions at suitable intervals and reject the deployment if they don't succeed within the timeout period.

1. Close the **Post-deployment conditions** pane
1. Select **Save** and in the Save dialog box, select **OK**

## Test Release Gates

You'll test the release gates by updating the application and triggering a deployment.

### Generate alerts and test the release process

1. From the Azure Portal, browse to the **DevTest Web App** resource
1. From the Overview pane, notice the **URL** field showing the web application hyperlink
1. Select this link to open the eShopOnWeb web application
1. To simulate a **Failed Request**, add **/discount** to the URL, which will result in an error since that page doesn't exist
1. Refresh this page several times to generate multiple events
1. From the Azure Portal, search for **Application Insights** and select the **DevTest-AppInsights** resource
1. Navigate to **Alerts**
1. There should be at least **1** new alert with **Severity 2 - Warning** showing up

> **Note**: If no Alert shows up yet, wait another few minutes.

1. Return to the Azure DevOps Portal and open the **eShopOnWeb** Project
1. Navigate to **Pipelines > Releases** and select **eshoponweb-cd**
1. Select the **Create Release** button
1. Wait for the Release pipeline to start and **approve** the DevTest Stage release action
1. Wait for the DevTest release Stage to complete successfully
1. Notice how the **Post-deployment Gates** switches to **Evaluation Gates** status
1. Select the **Evaluation Gates** icon
1. For **Query Azure Monitor Alerts**, notice an initial failed state
1. Let the Release pipeline remain in pending state for the next 5 minutes
1. After 5 minutes pass, notice the 2nd evaluation failing again

This is expected behavior, since there's an Application Insights Alert triggered for the DevTest Web App.

> **Note**: Since there's an alert triggered by the exception, **Query Azure Monitor** gate will fail. This prevents deployment to the **Production** environment.

1. Wait a couple more minutes and validate the status of the Release Gates again
1. Within a few minutes after the initial Release Gates check, since the initial Application Insight Alert was triggered with "Fired" action, it should result in a successful Release Gate, allowing deployment to the Production Release Stage

> **Note**: If your gate fails, close the alert in Azure Monitor.

## Clean up resources

Remember to delete the resources created in the Azure portal to avoid unnecessary charges:

1. In the Azure portal, navigate to the **az400m03l08-RG** resource group
1. Select **Delete resource group**
1. Type the resource group name to confirm deletion
1. Select **Delete**

## Summary

In this lab, you configured release pipelines and then configured and tested release gates. You learned how to:

- Configure release pipelines with multiple environments
- Set up pre-deployment approvals for manual control
- Configure post-deployment gates with Azure Monitor alerts
- Test release gates by generating application alerts
- Control deployments based on application health criteria

Release gates enable you to specify application health criteria that must be met before a release is promoted to the following environment, providing automated quality controls in your deployment pipeline.
