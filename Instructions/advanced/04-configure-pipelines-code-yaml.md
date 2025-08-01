# Configure Pipelines as Code with YAML

**Estimated time:** 45 minutes

You will learn how to define build and release pipelines using YAML, allowing you to access the same pipeline features as those using the visual designer but with a markup file that can be managed like any other source file. This includes configuring CI/CD pipelines as code with YAML in Azure DevOps, adding continuous delivery stages, and implementing environment approvals.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure subscription:** You need an active Azure subscription or can create a new one
- **Azure DevOps organization:** Create one at [Create an organization or project collection](https://docs.microsoft.com/azure/devops/organizations/accounts/create-organization) if you don't have one
- **Account permissions:** You need a Microsoft account or Microsoft Entra account with:
  - Owner role in the Azure subscription
  - Global Administrator role in the Microsoft Entra tenant
  - For details, see [List Azure role assignments using the Azure portal](https://docs.microsoft.com/azure/role-based-access-control/role-assignments-list-portal) and [View and assign administrator roles in Azure Active Directory](https://docs.microsoft.com/azure/active-directory/roles/manage-roles-portal)

## Create and configure the team project

First, you'll create an Azure DevOps project for this lab.

1. In your browser, open your Azure DevOps organization
2. Click **New Project**
3. Give your project the name **eShopOnWeb_MultiStageYAML**
4. Leave other fields with defaults
5. Click **Create**

   ![Screenshot of the create new project panel](media/create-project.png)

## Import the eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code.

1. In your Azure DevOps organization, open the **eShopOnWeb_MultiStageYAML** project
2. Click **Repos > Files**
3. Click **Import a Repository**
4. Select **Import**
5. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
6. Click **Import**

   ![Screenshot of the import repository panel](media/import-repo.png)

The repository is organized this way:
- **.ado** folder contains Azure DevOps YAML pipelines
- **.devcontainer** folder contains setup to develop using containers
- **infra** folder contains Bicep & ARM infrastructure as code templates
- **.github** folder contains YAML GitHub workflow definitions
- **src** folder contains the .NET 8 website used in the lab scenarios

7. Go to **Repos > Branches**
8. Hover on the **main** branch then click the ellipsis on the right
9. Click **Set as default branch**

> **Note**: If the main branch is already the default branch, this option will be grayed out. Continue with the instructions.

## Create Azure resources

You'll create an Azure web app to deploy your application to.

1. From your lab computer, navigate to the [Azure Portal](https://portal.azure.com)
2. Sign in with the user account that has the Owner role in your Azure subscription
3. In the Azure portal toolbar, click the **Cloud Shell** icon (to the right of the search box)
4. If prompted to select either **Bash** or **PowerShell**, select **Bash**

> **Note**: If this is your first time starting Cloud Shell and you see the "Getting started" pop-up, select "No storage account required" and your subscription, then click "Apply".

5. From the Bash prompt, run these commands to create a resource group (replace `<region>` with your preferred Azure region like 'centralus', 'westeurope'):

   ```bash
   LOCATION='<region>'
   RESOURCEGROUPNAME='az400m03l07-RG'
   az group create --name $RESOURCEGROUPNAME --location $LOCATION
   ```

6. Create a Windows App service plan:

   ```bash
   SERVICEPLANNAME='az400m03l07-sp1'
   az appservice plan create --resource-group $RESOURCEGROUPNAME --name $SERVICEPLANNAME --sku B3
   ```

> **Note**: If you get an error about the subscription not being registered to use namespace 'Microsoft.Web', run: `az provider register --namespace Microsoft.Web` and then retry the command.

7. Create a web app with a unique name:

   ```bash
   WEBAPPNAME=eshoponWebYAML$RANDOM$RANDOM
   az webapp create --resource-group $RESOURCEGROUPNAME --plan $SERVICEPLANNAME --name $WEBAPPNAME
   ```

> **Note**: Record the name of the web app. You'll need it later in this lab.

8. Close the Azure Cloud Shell, but leave the Azure Portal open

## Configure CI/CD Pipelines as Code with YAML

Now you'll configure CI/CD pipelines using YAML definitions.

### Add a YAML build definition

1. Navigate to the **Pipelines** section in Azure DevOps
2. In the **Create your first Pipeline** window, click **Create pipeline**
3. On the **Where is your code?** pane, click **Azure Repos Git (YAML)**
4. On the **Select a repository** pane, click **eShopOnWeb_MultiStageYAML**
5. On the **Configure your pipeline** pane, scroll down and select **Existing Azure Pipelines YAML File**
6. In the **Selecting an existing YAML File** blade, specify:
   - Branch: **main**
   - Path: **.ado/eshoponweb-ci.yml**
7. Click **Continue** to save these settings
8. From the **Review your Pipeline YAML** screen, click **Run** to start the Build Pipeline
9. Wait for the Build Pipeline to complete successfully

> **Note**: Each task from the YAML file is available for review, including any warnings and errors.

### Add continuous delivery to the YAML definition

Now you'll add continuous delivery to enable automatic deployment.

1. On the pipeline run pane, click the ellipsis symbol (⋯) in the upper right corner
2. In the dropdown menu, click **Edit pipeline**
3. Navigate to the end of the file (line 56) and press **Enter** to add a new empty line
4. On line **57**, add this content to define the **Release** stage:

   ```yaml
   - stage: Deploy
     displayName: Deploy to an Azure Web App
     jobs:
       - job: Deploy
         pool:
           vmImage: "windows-latest"
         steps:
   ```

5. Set the cursor on a new line at the end of the YAML definition
6. In the list of tasks on the right side, search for and select **Azure App Service Deploy**
7. In the **Azure App Service deploy** pane, specify these settings and click **Add**:
   - **Azure subscription**: Select your Azure subscription, click **Authorize**, and authenticate when prompted
   - **App Service name**: Select the web app you deployed earlier
   - **Package or folder**: Update to `$(Build.ArtifactStagingDirectory)/**/Web.zip`
   - Open **Application and Configuration Settings** and in **App settings** add: `-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development`

The added code should look similar to this:

```yaml
- task: AzureRmWebAppDeployment@4
  inputs:
    ConnectionType: "AzureRM"
    azureSubscription: "AZURE SUBSCRIPTION HERE (b999999abc-1234-987a-a1e0-27fb2ea7f9f4)"
    appType: "webApp"
    WebAppName: "eshoponWebYAML369825031"
    packageForLinux: "$(Build.ArtifactStagingDirectory)/**/Web.zip"
    AppSettings: "-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development"
```

8. Validate the task is listed as a child of the **steps** task. If not, select all lines from the added task and press **Tab** twice to indent it properly.

> **Note**: By default, these two stages run independently. To make the build output available to the second stage, you need to add a task to download the deployment artifact.

9. Place the cursor on the first line under the **steps** node of the **deploy** stage and press **Enter** to add a new empty line
10. On the **Tasks** pane, search for and select **Download build artifacts**
11. Specify these parameters:
    - Download Artifacts produced by: **Current Build**
    - Download Type: **Specific Artifact**
    - Artifact Name: **Website**
    - Destination Directory: **$(Build.ArtifactStagingDirectory)**
12. Click **Add**

The added code should look like this:

```yaml
- task: DownloadBuildArtifacts@1
  inputs:
    buildType: "current"
    downloadType: "single"
    artifactName: "Website"
    downloadPath: "$(Build.ArtifactStagingDirectory)"
```

13. If the YAML indentation is off, press **Tab** twice to indent it properly
14. Click **Validate and save**, then click **Save** again to commit the change to the main branch
15. Navigate to **Pipelines** and select **Pipelines** again
16. Open the **eShopOnWeb_MultiStageYAML** Pipeline and click **Run pipeline**
17. Confirm the **Run** from the appearing pane
18. Notice the 2 different stages: **Build .Net Core Solution** and **Deploy to Azure Web App**
19. Wait for the pipeline to complete the Build Stage successfully
20. When the Deploy Stage wants to start, you'll see a **Permissions Needed** prompt
21. Click **View**
22. From the **Waiting for Review** pane, click **Permit**
23. Validate the message and confirm by clicking **Permit**
24. Wait for the Deploy Stage to complete successfully

### Review the deployed site

1. Switch back to the Azure portal and navigate to your Azure web app
2. On the Azure web app blade, click **Overview**  
3. On the overview blade, click **Browse** to open your site in a new browser tab
4. Verify that the deployed site loads as expected, showing the eShopOnWeb E-commerce website

## Configure Environment settings for approvals

YAML Pipelines don't have Release/Quality Gates like Classic Release Pipelines, but you can configure similar functionality using **Environments**.

### Set up Pipeline Environments

1. From your Azure DevOps Project **eShopOnWeb_MultiStageYAML**, navigate to **Pipelines**
2. Under the Pipelines menu on the left, select **Environments**
3. Click **Create Environment**
4. In the **New Environment** pane, add the name **approvals**
5. Under **Resources**, select **None**
6. Click **Create**
7. Once the environment is created, select the **Approvals and Checks** tab
8. From **Add your first check**, select **Approvals**
9. Add your Azure DevOps User Account Name to the **approvers** field
10. Click **Create**

### Update the YAML pipeline for approvals

1. Navigate to **Repos**, browse to the **.ado** folder, and select the **eshoponweb-ci.yml** file
2. Click the **Edit** button to switch to editing mode
3. Navigate to the start of the **Deploy job** (Line 60: `- job: Deploy`)
4. Add a new empty line right below and add:

   ```yaml
   environment: approvals
   ```

5. Since environment is a deployment stage setting, change `- job: Deploy` to `- deployment: Deploy`
6. Under the vmImage line, add a new empty line and paste this YAML snippet:

   ```yaml
   strategy:
     runOnce:
       deploy:
   ```

7. Select the remaining snippet (from the steps onward) and use **Tab** to fix the indentation

The resulting YAML should look like this:

```yaml
- stage: Deploy
  displayName: Deploy to an Azure Web App
  jobs:
    - deployment: Deploy
      environment: approvals
      pool:
        vmImage: "windows-latest"
      strategy:
        runOnce:
          deploy:
            steps:
              - task: DownloadBuildArtifacts@1
                inputs:
                  buildType: "current"
                  downloadType: "single"
                  artifactName: "Website"
                  downloadPath: "$(Build.ArtifactStagingDirectory)"
              - task: AzureRmWebAppDeployment@4
                inputs:
                  ConnectionType: "AzureRM"
                  azureSubscription: "AZURE SUBSCRIPTION HERE"
                  appType: "webApp"
                  WebAppName: "eshoponWebYAML369825031"
                  packageForLinux: "$(Build.ArtifactStagingDirectory)/**/Web.zip"
                  AppSettings: "-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development"
```

8. Click **Commit** and **Commit** again to save the changes
9. Navigate to **Pipelines > Pipelines** and open the **EshopOnWeb_MultiStageYAML** Pipeline
10. Click **Run Pipeline** to trigger a new run
11. The Build Stage will complete as before
12. For the Deploy Stage, you'll see **Waiting (1 check in progress)** and a message about needing approval
13. Click the **Review** button
14. From the **Waiting for review** pane, click **Approve**
15. This allows the Deploy Stage to proceed and successfully deploy to the Azure Web App

> **Note**: While this example only used approvals, other checks such as Azure Monitor, REST API, etc., can be used in a similar way.

## Clean up resources

Remember to delete the resources created in the Azure portal to avoid unnecessary charges:

1. In the Azure portal, navigate to the **az400m03l07-RG** resource group
2. Click **Delete resource group**
3. Type the resource group name to confirm deletion
4. Click **Delete**

## Summary

In this lab, you configured CI/CD pipelines as code with YAML in Azure DevOps. You learned how to:

- Define build and release pipelines using YAML
- Add continuous delivery stages to YAML pipelines
- Configure environments and approvals for deployment stages
- Deploy applications to Azure App Service using YAML pipelines

Many teams prefer YAML pipelines because they can be managed like any other source file, providing better version control and code review capabilities for your CI/CD processes.
