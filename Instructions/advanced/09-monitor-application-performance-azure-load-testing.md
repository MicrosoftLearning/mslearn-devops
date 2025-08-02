---
lab:
  topic: Advanced
  title: "Monitor Application Performance with Azure Load Testing"
  description: "Learn how to use Azure Load Testing to simulate performance testing against live-running web applications with different load scenarios."
---

# Monitor Application Performance with Azure Load Testing

**Estimated time:** 60 minutes

You will learn how to use Azure Load Testing to simulate performance testing against a live-running web application with different load scenarios. Azure Load Testing is a fully managed load-testing service that enables you to generate high-scale load and abstracts the complexity and infrastructure needed to run your load test at scale.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure DevOps organization:** Create one if you don't have one
- **Azure subscription:** Create one or use an existing one
- **Microsoft account or Microsoft Entra account** with Owner role in the Azure subscription and Global Administrator role in the Microsoft Entra tenant
- **Azure CLI:** [Install the Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)

## About Azure Load Testing

Azure Load Testing is a fully managed load-testing service that enables you to generate high-scale load. The service simulates traffic for your applications, regardless of where they're hosted. Key benefits include:

- **Scalable load generation** without infrastructure management
- **Integration with CI/CD pipelines** for automated testing
- **Support for Apache JMeter** test scripts
- **Real-time monitoring** and detailed analytics
- **Multiple load patterns** (constant load, step-up, spike testing)

## Create and configure the team project

First, you'll create an Azure DevOps project for this lab.

1. In your browser, open your Azure DevOps organization
2. Click **New Project**
3. Give your project the name **eShopOnWeb** and choose **Scrum** on the **Work Item process** dropdown
4. Click **Create**

## Import eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code.

1. In your Azure DevOps organization, open the **eShopOnWeb** project
2. Click **Repos > Files**, then **Import**
3. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
4. Click **Import**

The repository structure:

- **.ado** folder contains Azure DevOps YAML pipelines
- **.devcontainer** folder container setup to develop using containers
- **infra** folder contains Bicep & ARM infrastructure as code templates
- **.github** folder contains YAML GitHub workflow definitions
- **src** folder contains the .NET 8 website used in lab scenarios

5. Go to **Repos > Branches**
6. Hover on the **main** branch then click the ellipsis on the right
7. Click **Set as default branch**

## Create Azure resources

You'll create Azure resources needed for this lab using Azure Cloud Shell.

1. Navigate to the [Azure Portal](https://portal.azure.com) and sign in
2. In the toolbar, click the **Cloud Shell** icon located directly to the right of the search text box
3. If prompted to select either **Bash** or **PowerShell**, select **Bash**

> **Note**: If this is the first time you are starting Cloud Shell and you are presented with the "You have no storage mounted" message, select the subscription you are using in this lab, and select **Create storage**.

4. From the **Bash** prompt, run the following command to create a resource group (replace `<region>` with the name of the Azure region closest to you such as 'eastus'):

   ```bash
   RESOURCEGROUPNAME='az400m08l14-RG'
   LOCATION='<region>'
   az group create --name $RESOURCEGROUPNAME --location $LOCATION
   ```

5. Create a Windows App service plan:

   ```bash
   SERVICEPLANNAME='az400l14-sp'
   az appservice plan create --resource-group $RESOURCEGROUPNAME \
       --name $SERVICEPLANNAME --sku B3
   ```

6. Create a web app with a unique name:

   ```bash
   WEBAPPNAME=az400eshoponweb$RANDOM$RANDOM
   az webapp create --resource-group $RESOURCEGROUPNAME --plan $SERVICEPLANNAME --name $WEBAPPNAME
   ```

> **Note**: Record the name of the web app. You will need it later in this lab.

## Configure CI/CD Pipelines with YAML

You'll configure CI/CD Pipelines as code with YAML in Azure DevOps.

### Add a YAML build and deploy definition

1. Navigate to the **Pipelines** pane in the **Pipelines** hub
2. Click **New pipeline** (or Create Pipeline if this is the first one you create)
3. On the **Where is your code?** pane, click **Azure Repos Git (YAML)** option
4. On the **Select a repository** pane, click **eShopOnWeb**
5. On the **Configure your pipeline** pane, scroll down and select **Starter Pipeline**
6. **Select** all lines from the Starter Pipeline, and delete them
7. **Copy** the full template pipeline from below:

   ```yml
   #Template Pipeline for CI/CD
   # trigger:
   # - main

   resources:
     repositories:
       - repository: self
         trigger: none

   stages:
     - stage: Build
       displayName: Build .Net Core Solution
       jobs:
         - job: Build
           pool:
             vmImage: ubuntu-latest
           steps:
             - task: DotNetCoreCLI@2
               displayName: Restore
               inputs:
                 command: "restore"
                 projects: "**/*.sln"
                 feedsToUse: "select"

             - task: DotNetCoreCLI@2
               displayName: Build
               inputs:
                 command: "build"
                 projects: "**/*.sln"

             - task: DotNetCoreCLI@2
               displayName: Publish
               inputs:
                 command: "publish"
                 publishWebProjects: true
                 arguments: "-o $(Build.ArtifactStagingDirectory)"

             - task: PublishBuildArtifacts@1
               displayName: Publish Artifacts ADO - Website
               inputs:
                 pathToPublish: "$(Build.ArtifactStagingDirectory)"
                 artifactName: Website

     - stage: Deploy
       displayName: Deploy to an Azure Web App
       jobs:
         - job: Deploy
           pool:
             vmImage: "windows-2019"
           steps:
             - task: DownloadBuildArtifacts@1
               inputs:
                 buildType: "current"
                 downloadType: "single"
                 artifactName: "Website"
                 downloadPath: "$(Build.ArtifactStagingDirectory)"
   ```

8. Set the cursor on a new line at the end of the YAML definition at the indentation of the previous task level
9. Click **Show Assistant** from the right hand side of the portal
10. In the list of tasks, search for and select the **Azure App Service Deploy** task
11. In the **Azure App Service deploy** pane, specify the following settings and click **Add**:

    - In the **Azure subscription** drop-down list, select your Azure subscription
    - Validate **App Service Type** points to Web App on Windows
    - In the **App Service name** dropdown list, select the name of the web app you deployed earlier (az400eshoponweb...)
    - In the **Package or folder** text box, **update** the Default Value to `$(Build.ArtifactStagingDirectory)/**/Web.zip`
    - Expand **Application and Configuration Settings**, and in the App settings text box, add: `-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development`

12. Confirm the settings from the Assistant pane by clicking the **Add** button

The snippet of code added should look similar to this:

```yml
- task: AzureRmWebAppDeployment@4
  inputs:
    ConnectionType: "AzureRM"
    azureSubscription: "SERVICE CONNECTION NAME"
    appType: "webApp"
    WebAppName: "az400eshoponWeb369825031"
    packageForLinux: "$(Build.ArtifactStagingDirectory)/**/Web.zip"
    AppSettings: "-UseOnlyInMemoryDatabase true -ASPNETCORE_ENVIRONMENT Development"
```

13. Before saving the updates, give it a clear name. On top of the yaml-editor window, rename **azure-pipelines-#.yml** to **m08l14-pipeline.yml**
14. Click **Save**, on the **Save** pane, click **Save** again to commit the change directly into the main branch
15. Navigate to **Pipelines** and select **Pipelines** again. Select **All** to open all pipeline definitions
16. Select the pipeline and confirm to run it by clicking **Run** and confirm by clicking **Run** once more
17. Notice the 2 different Stages: **Build .Net Core Solution** and **Deploy to Azure Web App**
18. Wait for the pipeline to complete successfully

### Review the deployed site

1. Switch back to the Azure portal and navigate to the Azure web app blade
2. On the Azure web app blade, click **Overview** and click **Browse** to open your site in a new browser tab
3. Verify that the deployed site loads as expected, showing the eShopOnWeb E-commerce website

## Deploy and Setup Azure Load Testing

You'll deploy an Azure Load Testing Resource and configure different Load Testing scenarios.

> **Important**: Azure Load Testing is a **paid service**. You will incur costs for running load tests. Make sure to clean up resources after completing the lab to avoid additional costs. See the [Azure Load Testing pricing page](https://azure.microsoft.com/pricing/details/load-testing) for more information.

### Deploy Azure Load Testing

1. From the Azure Portal, navigate to **Create Azure Resource**
2. In the search field, enter **Azure Load Testing**
3. Select **Azure Load Testing** (published by Microsoft) from the search results
4. Click **Create** to start the deployment process
5. Provide the necessary details for the resource deployment:
   - **Subscription**: select your Azure Subscription
   - **Resource Group**: select the Resource Group you used for deploying the Web App Service
   - **Name**: `eShopOnWebLoadTesting`
   - **Region**: Select a region close to your region

> **Note**: Azure Load Testing service is not available in all Azure Regions.

6. Click **Review and Create**, to validate your settings
7. Click **Create** to confirm and deploy the Azure Load Testing resource
8. Wait for the deployment to complete successfully
9. Click **Go to Resource** to navigate to the **eShopOnWebLoadTesting** Azure Load Testing resource

### Create Azure Load Testing tests

You'll create different Azure Load Testing tests using different load configuration settings.

#### Create first load test (Virtual Users)

1. From the **eShopOnWebLoadTesting** Azure Load Testing Resource blade, navigate to **Tests** under **Tests**
2. Click the **+ Create** menu option, and select **Create a URL-based test**
3. Complete the following parameters and settings:

   - **Test URL**: Enter the URL from the Azure App Service you deployed (az400eshoponweb...azurewebsites.net), **including https://**
   - **Specify Load**: Virtual Users
   - **Number of Virtual Users**: 50
   - **Test Duration (minutes)**: 5
   - **Ramp-up time (minutes)**: 1

4. Click **Review and Create**, then **Create**
5. The test will run for 5 minutes

#### Create second load test (Requests per Second)

1. From the top menu, click **Create**, **Create a URL-based test**
2. Complete the following parameters and settings:

   - **Test URL**: Enter the URL from the Azure App Service (including https://)
   - **Specify Load**: Requests per Second (RPS)
   - **Requests per second (RPS)**: 100
   - **Response time (milliseconds)**: 500
   - **Test Duration (minutes)**: 5
   - **Ramp-up time (minutes)**: 1

3. Click **Review + create**, then **Create**
4. The test will run for about 5 minutes

### Validate Azure Load Testing results

With both tests complete, you'll validate the outcome of the Azure Load Testing TestRuns.

1. From **Azure Load Testing**, navigate to **Tests**
2. Select either of the test definitions to open a detailed view by **clicking** on one of the tests
3. Select the **TestRun_mm/dd/yy-hh:hh** from the resulting list
4. From the detailed **TestRun** page, identify the actual outcome of the simulation:

   - Load / Total Requests
   - Duration
   - Response Time (90th percentile response time)
   - Throughput in requests per second

5. Review the dashboard graph line and chart views below
6. Take time to **compare the results** of both simulated tests and **identify the impact** of more users on the App Service performance

## Automate Load Test with CI/CD in Azure Pipelines

You'll add load testing automation to a CI/CD pipeline by exporting configuration files and configuring Azure Pipelines.

### Identify Azure DevOps Service Connection details

You'll grant the required permissions to the Azure DevOps Service Connection.

1. From the **Azure DevOps Portal**, navigate to the **eShopOnWeb** Project
2. From the bottom left corner, select **Project Settings**
3. Under the **Pipelines** section, select **Service Connections**
4. Notice the Service Connection with the name of your Azure Subscription
5. **Select the Service Connection**. From the **Overview** tab, navigate to **Details** and select **Manage service connection roles**
6. This redirects you to the Azure Portal, opening the resource group details in the access control (IAM) blade

### Grant permissions to the Azure Load Testing resource

Azure Load Testing uses Azure RBAC to grant permissions for performing specific activities on your load testing resource. You'll grant the **Load Test Contributor** role to the Azure DevOps service connection.

1. Select **+ Add** and **Add role assignment**
2. In the **Role tab**, select **Load Test Contributor** in the list of job function roles
3. In the **Members tab**, select **Select members**, find and select your user account and click **Select**
4. In the **Review + assign tab**, select **Review + assign** to add the role assignment

You can now use the service connection in your Azure Pipelines workflow to access your Azure load testing resource.

### Export load test input files and Import to Azure Repos

To run a load test with Azure Load Testing in a CI/CD workflow, you need to add the load test configuration settings and input files in your source control repository.

1. In the **Azure portal**, go to your **Azure Load Testing** resource
2. On the left pane, select **Tests** to view the list of load tests, then select **your test**
3. Select the **ellipsis (...)** next to the test run, then select **Download input file**
4. The browser downloads a zipped folder that contains the load test input files
5. Use any zip tool to extract the input files. The folder contains:

   - _config.yaml_: the load test YAML configuration file
   - _quick_test.jmx_: the JMeter test script

6. Navigate to the **Azure DevOps Portal** and the **eShopOnWeb** DevOps Project
7. Select **Repos**. In the source code folder structure, notice the **tests** subfolder
8. Notice the ellipsis (...), and select **New > Folder**
9. Specify **jmeter** as folder name, and **placeholder.txt** for the file name
10. Click **Commit** to confirm the creation of the placeholder file and jmeter folder
11. From the **Folder structure**, navigate to the new created **jmeter** subfolder
12. Click the **ellipsis(...)** and select **Upload File(s)**
13. Using the **Browse** option, navigate to the location of the extracted zip-file, and select both **config.yaml** and **quick_test.jmx**
14. Click **Commit** to confirm the file upload into source control
15. Within Repos, browse to the **/tests/jmeter** subfolder
16. Open the Load Testing **config.yaml** file. Click **Edit** to allow editing
17. Replace the **displayName** and **testId** attributes with the value **ado_load_test**
18. Click **Commit** to save the changes

### Update the CI/CD workflow YAML definition file

1. Open the [Azure Load Testing task extension](https://marketplace.visualstudio.com/items?itemName=AzloadTest.AzloadTesting) in the Azure DevOps Marketplace, and select **Get it free**
2. Select your Azure DevOps organization, and then select **Install** to install the extension
3. From the Azure DevOps Portal, navigate to **Pipelines** and select the pipeline created earlier. Click **Edit**
4. In the YAML script, navigate to **line 56** and press ENTER/RETURN to add a new empty line (right before the Deploy Stage)
5. At line 57, select the Tasks Assistant and search for **Azure Load Testing**
6. Complete the graphical pane with the correct settings:

   - Azure Subscription: Select the subscription which runs your Azure Resources
   - Load Test File: '$(Build.SourcesDirectory)/tests/jmeter/config.yaml'
   - Load Test Resource Group: The Resource Group which holds your Azure Load Testing Resources
   - Load Test Resource Name: `eShopOnWebLoadTesting`
   - Load Test Run Name: ado_run
   - Load Test Run Description: load testing from ADO

7. Click **Add** to inject the parameters as a YAML snippet
8. Fix indentation if needed (add 2 spaces or tab to position the snippet correctly)

The YAML code should look like this:

```yml
- task: AzureLoadTest@1
  inputs:
    azureSubscription: "AZURE DEMO SUBSCRIPTION"
    loadTestConfigFile: "$(Build.SourcesDirectory)/tests/jmeter/config.yaml"
    resourceGroup: "az400m08l14-RG"
    loadTestResource: "eShopOnWebLoadTesting"
    loadTestRunName: "ado_run"
    loadTestRunDescription: "load testing from ADO"
```

9. Below the inserted YAML snippet, add a new empty line
10. Add a snippet for the Publish task to show the results of the Azure Load testing task:

```yml
- publish: $(System.DefaultWorkingDirectory)/loadTest
  artifact: loadTestResults
```

11. Fix indentation if needed
12. **Save** the changes
13. Once saved, click **Run** to trigger the pipeline
14. Confirm the branch (main) and click **Run** to start the pipeline run
15. From the pipeline status page, click the **Build** stage to open the verbose logging details
16. Wait for the pipeline to arrive at the **AzureLoadTest** task
17. While the task is running, browse to the **Azure Load Testing** in the Azure Portal and see how the pipeline creates a new RunTest named **adoloadtest1**
18. Navigate back to the Azure DevOps CI/CD Pipeline Run view, where the **AzureLoadTest task** should complete successfully

### Add failure/success criteria to Load Testing Pipeline

You'll use load test fail criteria to get alerted when the application doesn't meet your quality requirements.

1. From Azure DevOps, navigate to the eShopOnWeb Project, and open **Repos**
2. Within Repos, browse to the **/tests/jmeter** subfolder
3. Open the Load Testing **config.yaml** file. Click **Edit** to allow editing
4. Replace `failureCriteria: []` if present, otherwise append the following snippet:

   ```yaml
   failureCriteria:
     - avg(response_time_ms) > 300
     - percentage(error) > 50
   ```

5. Save the changes by clicking **Commit** and Commit once more
6. Navigate back to **Pipelines** and run the **eShopOnWeb** pipeline again
7. After a few minutes, it will complete with a **failed** status for the **AzureLoadTest** task
8. Open the verbose logging view for the pipeline, and validate the details of the **AzureLoadtest**

The output should show something similar to:

```text
-------------------Test Criteria ---------------
Results			 :1 Pass 1 Fail

Criteria					 :Actual Value	      Result
avg(response_time_ms) > 300                       1355.29               FAILED
percentage(error) > 50                                                  PASSED

##[error]TestResult: FAILED
```

9. Notice how the last line says **##[error]TestResult: FAILED**. Since we defined a **FailCriteria** having an avg response time of > 300, the task is flagged as failed when the response time exceeds this threshold

> **Note**: In a real-life scenario, you would validate the performance of your App Service, and if performance is below a certain threshold, you could trigger additional deployments or scaling actions.

## Summary

In this lab, you learned how to:

- **Deploy a web app to Azure App Service** using Azure Pipelines
- **Deploy and configure Azure Load Testing** with different test scenarios
- **Integrate load testing into CI/CD pipelines** for automated performance validation
- **Define success/failure criteria** for load tests to ensure application quality
- **Analyze load test results** to understand application performance characteristics

Azure Load Testing provides a powerful platform for performance testing that integrates seamlessly with your CI/CD workflows, helping ensure your applications can handle expected load before deployment to production.

## Cleanup

Remember to delete the Azure resources created in this lab to avoid unnecessary charges:

1. Delete the **az400m08l14-RG** resource group from the Azure Portal
2. This will remove all associated resources including the App Service, App Service Plan, and Load Testing resource
