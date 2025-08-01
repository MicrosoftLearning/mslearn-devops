---
lab:
  topic: Intermediate
  title: "Implement CI/CD with GitHub Actions and IaC with Bicep"
  description: "Learn how to implement CI/CD with GitHub Actions and Infrastructure as Code (IaC) using Bicep."
---

# Implement CI/CD with GitHub Actions and IaC with Bicep

In this lab, you will implement continuous integration and continuous deployment (CI/CD) using GitHub Actions and Infrastructure as Code (IaC) with Bicep. You will learn how to automate the deployment of a web application to Azure App Service using a custom GitHub Actions workflow and a Bicep template.

Each task in this lab builds on the previous one, so it's important to complete them in order.

You will learn how to:

- Prepare the Azure subscription for the lab
- Implement Infrastructure as Code (IaC) and CI/CD with GitHub Actions and a Bicep template

This lab takes approximately **40** minutes to complete.

## Before you start

To complete the lab, you need:

- A GitHub user account. If you don't have one, you can [create a new account](https://github.com/join). If you need instructions on how to create a GitHub account, refer to the article [Creating an account on GitHub](https://docs.github.com/get-started/quickstart/creating-an-account-on-github).
- An Azure subscription to which you have at least the Contributor-level access. If you don't already have one, you can [sign up for one](https://azure.microsoft.com/).

## Prepare the Azure subscription for the lab

> **Note:** If you are using a new Azure subscription, some of the Azure resource providers might not be registered. Since the registration process might take a few minutes, to minimize the wait time, you will register them at the beginning of this lab.

> **Note:** In this lab, you will be using Azure Cloud Shell. If this is the first time you are using Azure Cloud Shell in your subscription, you will need to register the corresponding resource provider.

1. Start a web browser and navigate to the Azure portal at `https://portal.azure.com`.
1. If prompted, sign in by using your Microsoft Entra ID account with the Owner access to the Azure subscription available to you.
1. In the web browser tab displaying the Azure portal, in the search text box at the top of the page, enter **`Subscriptions`** and, in the list of results, select **Subscriptions**.
1. On the **Subscriptions** page, select the subscription you want to use in this lab.
1. On the subscriptions page, in the vertical menu on the left side, select **Resource providers**.
1. In the list of resource providers, search for and select **Microsoft.CloudShell**.
1. With the **Microsoft.CloudShell** resource provider selected, in the toolbar, select **Register**.

   > **Note:** Don't wait until the registration completes but proceed directly to the next exercise. The registration might take a couple of minutes.

## Implement Infrastructure as Code (IaC) and CI/CD with GitHub Actions and a Bicep template

In this exercise, you'll implement IaC with CI/CD to Azure App Service web apps with GitHub Actions and a Bicep template.

> **Note:** To simplify the initial setup, you will use a fork of an existing GitHub repo that contains the source code of the .NET app, the GitHub Actions workflow, and the Bicep template.

The exercise consists of the following tasks:

- Fork and review the GitHub repo containing the source code of a web app, a GitHub Actions workflow, and a Bicep template
- Configure the target environment
- Validate the IaC and CI/CD functionality

### Fork and review the GitHub repo containing the source code of a web app, a GitHub Actions workflow, and a Bicep template

1. Switch to the browser window displaying your GitHub account and ensure that you're still authenticated (if not, sign in by using your GitHub user account).
1. Open another tab in the same browser window and navigate to the [eShopOnWeb](https://github.com/MicrosoftLearning/eShopOnWeb) repo, which hosts the .NET version of a sample web site, a GitHub Actions workflow, and a Bicep template.
1. On the **eShopOnWeb** repo page, select **Fork**.
1. On the **Create a new fork** page, ensure that the **Owner** drop-down list entry displays your GitHub user name, accept the default entry **eShopOnWeb** in the **Repository name** text box, and confirm the **Copy the main branch only** checkbox is checked, and then select **Create fork**.

   > **Note:** Your browser session will be automatically redirected to the newly forked repo.

1. On the **eShopOnWeb** page, confirm the drop-down list displays the current branch **main**.
1. Review the repo structure and note that it includes the following components:

   - the **.github/workflows** directory containing several YAML-based workflow, including one named **eshoponweb-cicd.yml**
   - the **infra** directory containing the Bicep template named **webapp.bicep**
   - the **src/Web** directory containing the .NET code of the source web app

1. Open the **.github/workflows** directory and then select the **eshoponweb-cicd.yml** file to view its content. Note that this GitHub Actions workflow contains the **buildandtest** and **deploy** jobs, which consist of the following steps:

   - buildandtest
     - checkout the repository
     - prepare the runner for the desired .NET version SDK
     - build, test, and publish the .NET project
     - upload the published website code artifacts
     - upload the bicep template as an artifact for the next job
   - deploy
     - download the published artifacts created in previous job
     - download the bicep template uploaded in the previous job
     - login to the target Azure subscription using a service principal
     - deploy an Azure App Service web app by using the bicep template
     - publish the website artifacts into the Azure App Service web app

   > **Note:** Do not focus on details of each job. It is much more important at this point to simply understand the purpose of the workflow.

1. Note that the process of provisioning Azure resources targets a single resource group which is defined at the beginning of the workflow as an environment variable `RESOURCE-GROUP`.

   > **Note:** You will need to create the resource group before you run the workflow.

1. Note that the workflow relies on a secret to authenticate to the target Azure subscription during the Set up Azure CLI step, as evidenced by the statement `creds: ${{ secrets.AZURE_CREDENTIALS }}`.

   > **Note:** You will need to set up this secret before you run the workflow.

1. In addition, note that this workflow can be configured to be triggered manually, as indicated by the `on: workflow_dispatch:` syntax.

### Configure the target environment

> **Note:** You will start by creating the resource groups. You will run the workflow twice in order to deploy two instances of the website in two different Azure regions (East US and West US in this example). You can adapt these to use regions closer to your location if preferred.

1. Switch to the web browser tab displaying the Azure portal at `https://portal.azure.com`.
1. In the Azure portal, in the search text box at the top of the page, enter **`Resource groups`** and select **Resource groups** in the list of results.
1. On the **Resource groups** page, select **+ Create**.
1. In the **Resource groups** text box, enter **`rg-eshoponweb-westus`**.
1. In the **Region** drop-down list, select **(US) West US**.
1. Select **Review + create** and then, on the **Review + create**, select **Create**.
1. On the **Resource groups** page, select **+ Create**.
1. In the **Resource groups** text box, enter **`rg-eshoponweb-eastus`**.
1. In the **Region** drop-down list, select **(US) East US**.
1. Select **Review + create** and then, on the **Review + create**, select **Create**.

   > **Note:** Next, you will create a service principal that will be used to authenticate from the GitHub Actions workflow to the target Azure subscription and assign to it the role of Contributor in the subscription.

1. In the Azure portal, select the **Cloud Shell** icon to the right of the search text box.
1. If necessary, select **Bash** in the drop-down menu in the upper-left corner of the Cloud Shell pane.
1. In the Bash session within the Cloud Shell pane, run the following command to store the value of your Azure subscription ID in a variable:

   ```cli
   SUBSCRIPTION_ID=$(az account show --query id --output tsv)
   echo $SUBSCRIPTION_ID
   ```

1. Copy the value of the Subscription ID returned by the second command and record it. You'll need it later in this exercise.
1. In the Bash session within the Cloud Shell pane, run the following command to create a Microsoft Entra ID service principal and assign to it the role of Contributor in the scope of the subscription:

   ```cli
   az ad sp create-for-rbac --name "devopsfoundationslabsp" --role contributor --scopes /subscriptions/$SUBSCRIPTION_ID --json-auth
   ```

1. Copy the entire JSON-formatted output of the command and record it. You'll need it shortly. The output should have the format that resembles the following text:

   ```json
   {
     "clientId": "cccccccc-cccc-cccc-cccc-cccccccccccc",
     "clientSecret": "xxxxx~xxxxxxxxxxxx-xxxxxxxxxxxxx_xxxxxxx",
     "subscriptionId": "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy",
     "tenantId": "zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz",
     "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
     "resourceManagerEndpointUrl": "https://management.azure.com/",
     "activeDirectoryGraphResourceId": "https://graph.windows.net/",
     "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
     "galleryEndpointUrl": "https://gallery.azure.com/",
     "managementEndpointUrl": "https://management.core.windows.net/"
   }
   ```

1. Switch to the web browser window displaying the forked **eShopOnWeb** GitHub repo page and, in the toolbar, select **Settings**.
1. In the vertical menu on the left side, in the **Security** section, select **Secrets and variables** and, in the drop-down list, select **Actions**.
1. In the **Actions secrets and variables** pane, select **New repository secret**.
1. In the **Actions secrets / New secret** pane, in the **Name** text box, enter **`AZURE_CREDENTIALS`**.
1. In the **Secret** text box, paste the JSON-formatted text you recorded earlier in this task and select **Add secret**.
1. Switch back to the web browser displaying the Bash session within the Cloud Shell pane and run the following command to generate the name of the first App Service web app you'll be deploying:

   ```cli
   echo devops-webapp-westeurope-$RANDOM$RANDOM
   ```

1. Copy the value returned by the command and record it. You'll use it later in this exercise.
1. In the Bash session within the Cloud Shell pane, run the following command to generate the name of the second App Service web app you'll be deploying:

   ```cli
   echo devops-webapp-eastus-$RANDOM$RANDOM
   ```

1. Copy the value returned by the command and record it. You'll use it later in this exercise.

### Validate the IaC and CI/CD functionality

1. Switch to the web browser window displaying the forked **eShopOnWeb** GitHub repo page and, if needed, on the **eShopOnWeb** page, click in the **Code** tab and, in the drop-down list confirm that the current branch is **main**.
1. In the web browser window displaying the **main** branch of the forked **eShopOnWeb** GitHub repo page, navigate to the **.github/workflows** folder and select **eshoponweb-cicd.yml**.
1. In the **.github/workflows/eshoponweb-cicd.yml** pane, select the pencil icon to edit the workflow.
1. In the **Edit** pane, replace line 4 with the following text:

   ```yaml
   on: workflow_dispatch
   ```

   > **Note**: Ensure that you use proper indentation.

1. In the **Edit** pane, replace line 8 with the following text:

   ```yaml
   RESOURCE-GROUP: rg-eshoponweb-westus
   ```

1. In the **Edit** pane, replace the `YOUR-SUBS-ID` placeholder in line 11 with the value of the Azure subscription ID you recorded earlier in this exercise:
1. In the **Edit** pane, replace the `eshoponweb-webapp-NAME` placeholder in line 11 with the name of the **first** Azure App Service web app you generated earlier in this exercise.
1. In the **.github/workflows/eshoponweb-cicd.yml** pane, select **Commit changes** and then select **Commit changes** again.
1. In the web browser window displaying the **main** branch of the forked **eShopOnWeb** GitHub repo page, navigate to the **infra** folder and select **webapp.bicep**.
1. In the **infra/webapp.bicep** pane, select the pencil icon to edit the workflow.
1. In the **Edit** pane, replace line 2 with the following text:

   ```bicep
   param sku string = 'S1' // The SKU of App Service Plan
   ```

1. In the **infra/webapp.bicep** pane, select **Commit changes** and then select **Commit changes** again.
1. In the web browser window displaying the forked **eShopOnWeb** GitHub repo page, select **Actions**.
1. If you're prompted to enable GitHub Actions, select **I understand my workflows, go ahead and enable them**.
   > **Note**: This is expected, since, by default GitHub will disable workflows in a forked repo for your own protection.
1. In the **All workflows** section on the left side, select **eShopOnWeb Build and Test**.
1. In the **eShopOnWeb Build and Test** pane, select **Run workflow**, in the drop-down list confirm that **Branch: main** is selected and select **Run workflow** again.

   > **Note**: This should trigger a workflow run.

1. Select the **eShopOnWeb Build and Test** workflow run.

   > **Note**: If needed, refresh the page to see the latest workflow run.

1. In the **eShopOnWeb Build and Test #1** pane, select **buildandtest**.
1. Monitor the progress of the workflow and verify that all steps of the **buildandtest** job complete successfully.
1. Once this job completes, in the **Summary** section, select **deploy**.
1. Monitor the progress of the workflow and verify that all steps of the **deploy** job complete successfully.

   > **Note**: In case any of the steps fail, from the same page that displays the workflow progress, in the upper right corner, select **Re-run all jobs** and then, in the **Re-run all jobs** pane, select **Re-run jobs**.

1. Switch to the web browser window displaying the forked **eShopOnWeb** GitHub repo page and, if needed, on the **eShopOnWeb** page, in the drop-down list confirm that the current branch is **main**.
1. In the web browser window displaying the **main** branch of the forked **eShopOnWeb** GitHub repo page, navigate to the **.github/workflows** folder and select **eshoponweb-cicd.yml**.
1. In the **.github/workflows/eshoponweb-cicd.yml** pane, select the pencil icon to edit the workflow.
1. In the **Edit** pane, replace line 8 with the following text:

   ```yaml
   RESOURCE-GROUP: rg-eshoponweb-eastus
   ```

1. In the **Edit** pane, replace the `location` variable in line 9 with the region nearest to your location.
1. In the **Edit** pane, replace the `eshoponweb-webapp-NAME` placeholder in line 11 with the name of the **second** Azure App Service web app you generated earlier in this exercise.
1. In the **.github/workflows/eshoponweb-cicd.yml** pane, select **Commit changes** and then select **Commit changes** again.
1. In the web browser window displaying the forked **eShopOnWeb** GitHub repo page, select **Actions**.
1. In the **All workflows** section on the left side, select **eShopOnWeb Build and Test**.
1. In the **eShopOnWeb Build and Test** pane, select **Run workflow**, in the drop-down list confirm that **Branch: main** is selected and select **Run workflow** again.

   > **Note**: This should trigger a workflow run.

1. Select the **eShopOnWeb Build and Test** workflow run.
1. In the **eShopOnWeb Build and Test #2** pane, select **buildandtest**.
1. Monitor the progress of the workflow and verify that all steps of the **buildandtest** job complete successfully.
1. Once this job completes, in the **Summary** section, select **deploy**.
1. Monitor the progress of the workflow and verify that all steps of the **deploy** job complete successfully.

   > **Note**: In case any of the steps fail, from the same page that displays the workflow progress, in the upper right corner, select **Re-run all jobs** and then, in the **Re-run all jobs** pane, select **Re-run jobs**.

1. In the web browser window displaying the Azure portal, in the search text box at the top of the page, enter **`App Services`** and select **App Services** in the list of results.
1. On the **App Services** page, in the list of App Services, select the **devops-webapp-westeurope-** app service you created earlier in this exercise.
1. On the **devops-webapp-westeurope-** page, in the **Essentials** section, verify that the **Default domain** value is displayed and select it to open the web app in a new browser tab.
1. In the new browser tab, verify that the web app is displayed and that it's functional. You can also verify the second web app in the **East US** region in the same way.
   > **Note**: Leave the deployed Azure resources running. You will need them in the next lab.

## Clean up resources

Now that you finished the exercise, you should delete the cloud resources you created to avoid unnecessary resource usage.

1. In your browser navigate to the Azure portal [https://portal.azure.com](https://portal.azure.com); signing in with your Azure credentials if prompted.
1. Navigate to the resource group you created and view the contents of the resources used in this exercise.
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name and confirm that you want to delete it.

> **CAUTION:** Deleting a resource group deletes all resources contained within it. If you chose an existing resource group for this exercise, any existing resources outside the scope of this exercise will also be deleted.

You don't need to clean up your GitHub repo or project, as they will remain available for you to use as a reference and portfolio item.

If you want to delete the repo, you can do so by following this documentation: [Deleting a repository](https://docs.github.com/repositories/creating-and-managing-repositories/deleting-a-repository).
