---
lab:
  topic: Intermediate
  title: "Enable Continuous Integration with Azure Pipelines"
  description: "Learn how to define build pipelines in Azure DevOps using YAML for Pull Request validation and Continuous Integration implementation."
---

# Enable Continuous Integration with Azure Pipelines

In this lab, you'll learn how to define build pipelines in Azure DevOps using YAML. The pipelines will be used in two scenarios: as part of Pull Request validation process and as part of the Continuous Integration implementation.

You will learn how to:

- Include build validation as part of a Pull Request.
- Configure CI pipeline as code with YAML.
- Set up branch policies for code protection.
- Work with Pull Requests and automated builds.

This lab takes approximately **30** minutes to complete.

## Before you start

To complete the lab, you need:

- **Microsoft Edge** or an [Azure DevOps supported browser.](https://docs.microsoft.com/azure/devops/server/compatibility)
- An Azure DevOps organization. If you don't already have one, create one by following the instructions at [Create an organization or project collection](https://docs.microsoft.com/azure/devops/organizations/accounts/create-organization).

### Set up Azure DevOps organization (if needed)

If you don't already have an Azure DevOps organization, follow these steps:

1. Use a private browser session to get a new **personal Microsoft Account (MSA)** at `https://account.microsoft.com` (skip if you already have one).
1. Using the same browser session, sign up for a free Azure subscription at `https://azure.microsoft.com/free` (skip if you already have one).
1. Open a browser and navigate to Azure portal at `https://portal.azure.com`, then search at the top of the Azure portal screen for **Azure DevOps**. In the resulting page, click **Azure DevOps organizations**.
1. Next, click on the link labelled **My Azure DevOps Organizations** or navigate directly to `https://aex.dev.azure.com`.
1. On the **We need a few more details** page, select **Continue**.
1. In the drop-down box on the left, choose **Default Directory**, instead of **Microsoft Account**.
1. If prompted (_"We need a few more details"_), provide your name, e-mail address, and location and click **Continue**.
1. Back at `https://aex.dev.azure.com` with **Default Directory** selected click the blue button **Create new organization**.
1. Accept the _Terms of Service_ by clicking **Continue**.
1. If prompted (_"Almost done"_), leave the name for the Azure DevOps organization at default (it needs to be a globally unique name) and pick a hosting location close to you from the list.
1. Once the newly created organization opens in **Azure DevOps**, select **Organization settings** in the bottom left corner.
1. At the **Organization settings** screen select **Billing** (opening this screen takes a few seconds).
1. Select **Setup billing** and on the right-hand side of the screen, select your **Azure Subscription** and then select **Save** to link the subscription with the organization.
1. Once the screen shows the linked Azure Subscription ID at the top, change the number of **Paid parallel jobs** for **MS Hosted CI/CD** from 0 to **1**. Then select **SAVE** button at the bottom.

   > **Note**: You may **wait a couple of minutes before using the CI/CD capabilities** so that the new settings are reflected in the backend. Otherwise, you will still see the message _"No hosted parallelism has been purchased or granted"_.

1. In **Organization Settings**, go to section **Pipelines** and click **Settings**.
1. Toggle the switch to **Off** for **Disable creation of classic build pipelines** and **Disable creation of classic release pipelines**.
1. In **Organization Settings**, go to section **Security** and click **Policies**.
1. Toggle the switch to **On** for **Allow public projects**.

### Create and configure the Azure DevOps project (if needed)

1. Open your browser and navigate to your Azure DevOps organization.
1. Select the **New Project** option and use the following settings:
   - name: **eShopOnWeb**
   - visibility: **Private**
   - Advanced: Version Control: **Git**
   - Advanced: Work Item Process: **Scrum**
1. Select **Create**.

### Import eShopOnWeb git repository (if needed)

1. Open the previously created **eShopOnWeb** project.
1. Select the **Repos > Files**, **Import a Repository** and then select **Import**.
1. On the **Import a Git Repository** window, paste the following URL `https://github.com/MicrosoftLearning/eShopOnWeb.git` and select **Import**:

1. The repository is organized the following way:

   - **.ado** folder contains Azure DevOps YAML pipelines.
   - **.devcontainer** folder container setup to develop using containers (either locally in VS Code or GitHub Codespaces).
   - **infra** folder contains Bicep & ARM infrastructure as code templates used in some lab scenarios.
   - **.github** folder contains YAML GitHub workflow definitions.
   - **src** folder contains the .NET website used in the lab scenarios.

1. Leave the web browser window open.
1. Go to **Repos > Branches**.
1. Hover on the **main** branch then click the ellipsis on the right of the column.
1. Click on **Set as default branch**.

## Include build validation as part of a Pull Request

In this section, you will include build validation to validate a Pull Request.

### Import the YAML build definition

In this task, you will import the YAML build definition that will be used as a Branch Policy to validate the pull requests.

Let's start by importing the build pipeline named [eshoponweb-ci-pr.yml](https://github.com/MicrosoftLearning/eShopOnWeb/blob/main/.ado/eshoponweb-ci-pr.yml).

1. Go to **Pipelines > Pipelines**
1. Click on **Create Pipeline** or **New Pipeline** button
1. Select **Azure Repos Git (YAML)**
1. Select the **eShopOnWeb** repository
1. Select **Existing Azure Pipelines YAML File**
1. Select the **main** branch and the **/.ado/eshoponweb-ci-pr.yml** file, then click on **Continue**

   The build definition consists of the following tasks:

   - **DotNet Restore**: With NuGet Package Restore you can install all your project's dependency without having to store them in source control.
   - **DotNet Build**: Builds a project and all of its dependencies.
   - **DotNet Test**: .Net test driver used to execute unit tests.
   - **DotNet Publish**: Publishes the application and its dependencies to a folder for deployment to a hosting system. In this case, it's **Build.ArtifactStagingDirectory**.

1. On the **Review your pipeline YAML** pane, click the down-facing caret symbol next to the **Run** button, click **Save**.
1. Your pipeline will take a name based on the project name. Let's **rename** it for identifying the pipeline better. Go to **Pipelines > Pipelines** and click on the recently created pipeline. Click on the ellipsis and **Rename/Move** option. Name it **eshoponweb-ci-pr** and click on **Save**.

### Branch Policies

In this task, you will add policies to the main branch and only allow changes using Pull Requests that comply with the defined policies. You want to ensure that changes in a branch are reviewed before they are merged.

1. Go to **Repos > Branches** section.
1. On the **Mine** tab of the **Branches** pane, hover the mouse pointer over the **main** branch entry to reveal the ellipsis symbol on the right side.
1. Click the ellipsis and, in the pop-up menu, select **Branch Policies**.
1. On the **main** tab of the repository settings, enable the option for **Require minimum number of reviewers**. Add **1** reviewer and check the box **Allow requestors to approve their own changes**(as you are the only user in your project for the lab)
1. On the **main** tab of the repository settings, in the **Build Validation** section, click **+** (Add a new build policy) and in the **Build pipeline** list, select **eshoponweb-ci-pr** then click **Save**.

### Working with Pull Requests

In this task, you will use the Azure DevOps portal to create a Pull Request, using a new branch to merge a change into the protected **main** branch.

1. Navigate to the **Repos** section in the eShopOnWeb navigation and click **Branches**.
1. Create a new branch named **Feature01** based on the **main** branch.
1. Click **Feature01** and navigate to the **/eShopOnWeb/src/Web/Program.cs** file as part of the **Feature01** branch
1. Click the **Edit** button in the top-right
1. Make the following change on the first line:

   ```csharp
   // Testing my PR
   ```

1. Click on **Commit > Commit** (leave default commit message).
1. A message will pop-up, proposing to create a Pull Request (as your **Feature01** branch is now ahead in changes, compared to **main**). Click on **Create a Pull Request**.
1. In the **New pull request** tab, leave defaults and click on **Create**.
1. The Pull Request will show some pending requirements, based on the policies applied to the target **main** branch.

   - At least 1 user should review and approve the changes.
   - Build validation, you will see that the build **eshoponweb-ci-pr** was triggered automatically

1. After all validations are successful, on the top-right click on **Approve**. Now from the **Set auto-complete** dropdown you can click on **Complete**.
1. On the **Complete Pull Request** tab, click on **Complete Merge**

## Configure CI Pipeline as Code with YAML

In this section, you will configure CI Pipeline as code with YAML.

### Import the YAML build definition for CI

In this task, you will add the YAML build definition that will be used to implement the Continuous Integration.

Let's start by importing the CI pipeline named [eshoponweb-ci.yml](https://github.com/MicrosoftLearning/eShopOnWeb/blob/main/.ado/eshoponweb-ci.yml).

1. Go to **Pipelines > Pipelines**.
1. Click on **New Pipeline** button.
1. Select **Azure Repos Git (YAML)**.
1. Select the **eShopOnWeb** repository.
1. Select **Existing Azure Pipelines YAML File**.
1. Select the **main** branch and the **/.ado/eshoponweb-ci.yml** file, then click on **Continue**.

   The CI definition consists of the following tasks:

   - **DotNet Restore**: With NuGet Package Restore you can install all your project's dependency without having to store them in source control.
   - **DotNet Build**: Builds a project and all of its dependencies.
   - **DotNet Test**: .Net test driver used to execute unit tests.
   - **DotNet Publish**: Publishes the application and its dependencies to a folder for deployment to a hosting system. In this case, it's **Build.ArtifactStagingDirectory**.
   - **Publish Artifact - Website**: Publish the app artifact (created in the previous step) and make it available as a pipeline artifact.
   - **Publish Artifact - Bicep**: Publish the infrastructure artifact (Bicep file) and make it available as a pipeline artifact.

1. Click on **Run** and wait for the pipeline to execute successfully.

### Enable Continuous Integration

The default build pipeline definition doesn't enable Continuous Integration.

1. Click on the **Edit pipeline** option under the ellipsis menu near **Run new** button in the top-right
1. Now, you need to replace the **# trigger:** and **# - main** lines with the following code:

   ```YAML
   trigger:
     branches:
       include:
       - main
     paths:
       include:
       - src/web/*
   ```

   This will automatically trigger the build pipeline if any change is made to the main branch and the web application code (the src/web folder).

   Since you enabled Branch Policies, you need to pass by a Pull Request in order to update your code.

1. Click the **Validate and save** button to validate and save the pipeline definition.
1. Select **Create a new branch for this commit**.
1. Keep the default branch name and **Start a pull request** checked.
1. Click on **Save**.
1. Your pipeline will take a name based on the project name. Let's **rename** it for identifying the pipeline better. Go to **Pipelines > Pipelines** and click on the recently created pipeline. Click on the ellipsis and **Rename/Move** option. Name it **eshoponweb-ci** and click on **Save**.
1. Go to **Repos > Pull Requests**.
1. Click on the **"Update eshoponweb-ci.yml for Azure Pipelines"** pull request.
1. After all validations are successful, on the top-right click on **Approve**. Now you can click on **Complete**.
1. On the **Complete Pull Request** tab, Click on **Complete Merge**

### Test the CI pipeline

In this task, you will create a Pull Request, using a new branch to merge a change into the protected **main** branch and automatically trigger the CI pipeline.

1. Navigate to the **Repos** section, and click on **Branches**.
1. Create a new branch named **Feature02** based on the **main** branch.
1. Click the new **Feature02** branch.
1. Navigate to the **/eShopOnWeb/src/Web/Program.cs** file and click **Edit** in the top-right.
1. Remove the first line:

   ```csharp
   // Testing my PR
   ```

1. Click on **Commit > Commit** (leave default commit message).
1. A message will pop-up, proposing to create a Pull Request (as your **Feature02** branch is now ahead in changes, compared to **main**).
1. Click on **Create a Pull Request**.
1. In the **New pull request** tab, leave defaults and click on **Create**.
1. The Pull Request will show some pending requirements, based on the policies applied to the target **main** branch.
1. After all validations are successful, on the top-right click on **Approve**. Now from the **Set auto-complete** dropdown you can click on **Complete**.
1. On the **Complete Pull Request** tab, Click on **Complete Merge**
1. Go back to **Pipelines > Pipelines**, you will notice that the build **eshoponweb-ci** was triggered automatically after the code was merged.
1. Click on the **eshoponweb-ci** build then select the last run.
1. After its successful execution, click on **Related > Published** to check the published artifacts:
   - Bicep: the infrastructure artifact.
   - Website: the app artifact.

## Clean up resources

You don't need to clean up your Azure DevOps organization or project, as they will remain available for you to use as a reference and portfolio item. Azure DevOps provides free tier usage that includes basic features for small teams.

If you want to delete the project, you can do so by following these steps:

1. In your browser navigate to the Azure DevOps portal at `https://aex.dev.azure.com`.
1. Navigate to the **eShopOnWeb** project you created.
1. On the project settings page, go to **Overview** and click **Delete** at the bottom of the page.
1. Type the project name to confirm deletion and click **Delete**.

> **CAUTION:** Deleting a project deletes all work items, repositories, builds, and other project artifacts. If you used an existing project for this exercise, any existing resources outside the scope of this exercise will also be deleted.
