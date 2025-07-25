---
lab:
  topic: Advanced
  title: "Deploy multi-region web apps and enhance resiliency with Traffic Manager and Azure Chaos Studio"
  description: "Learn how to deploy multi-region web applications, enhance workload resiliency by using Traffic Manager, and test resiliency by using Azure Chaos Studio."
---

# Deploy multi-region web apps and enhance resiliency with Traffic Manager and Azure Chaos Studio

In this lab, you will learn how to deploy web applications to multiple Azure regions, enhance workload resiliency by using Azure Traffic Manager, and test resiliency by using Azure Chaos Studio.

Each task in this lab builds on the previous one, so it's important to complete them in order.

You will learn how to:

- Prepare the Azure subscription for the lab
- Deploy Azure App Service web apps to two Azure regions
- Enhance workload resiliency by using Traffic Manager
- Test workload resiliency by using Azure Chaos Studio
- Remove the resources used in the labs

> **Note:** In this lab, you will deploy two instances of a .NET web app into two Azure regions (East US and West US) and then create a resilient configuration that implements the load balancing functionality of Azure Traffic Manager between the two web app instances. You will then use Azure Chaos Studio to trigger a failure of one of the apps to test the resiliency of the load balancing implementation. You can adapt the regions used to ones closer to your location if preferred.

This lab takes approximately **60** minutes to complete.

## Before you start

To complete the lab, you need:

- A GitHub user account. If you don't have one, you can [create a new account](https://github.com/join). If you need instructions on how to create a GitHub account, refer to the article [Creating an account on GitHub](https://docs.github.com/get-started/quickstart/creating-an-account-on-github).
- An Azure subscription to which you have at least the Contributor-level access. If you don't already have one, you can [sign up for one](https://azure.microsoft.com/).

## Prepare the Azure subscription for the lab

> **Note:** If you are using a new Azure subscription, some of the Azure resource providers might not be registered. Since the registration process might take a few minutes, to minimize the wait time, you will register them at the beginning of this lab.

> **Note:** In this lab, you will be using Azure Chaos Studio. If this is the first time you implement Azure Chaos Studio in your subscription, you must first register the corresponding resource provider.

1. Start a web browser and navigate to the Azure portal at `https://portal.azure.com`.
1. If prompted, sign in by using your Microsoft Entra ID account with the Owner access to the Azure subscription available to you.
1. In the web browser tab displaying the Azure portal, in the search text box at the top of the page, enter **`Subscriptions`** and, in the list of results, select **Subscriptions**.
1. On the subscriptions page, in the vertical menu on the left side, select **Resource providers**.
1. In the list of resource providers, search for and select **Microsoft.Chaos**.
1. With the **Microsoft.Chaos** resource provider selected, in the toolbar, select **Register**.

   > **Note:** Don't wait until the registration complete but proceed directly to the next exercise. The registration might take a couple of minutes.

## Deploy Azure App Service web apps to two Azure regions

In this exercise, you'll deploy two instances of the eShopOnWeb .NET web application to Azure App Service in two different Azure regions (East US and West US). You can adapt these instructions to use regions closer to your location if preferred.

The exercise consists of the following tasks:

- Fork the eShopOnWeb repository
- Deploy the web app to East US
- Deploy the web app to West US

### Fork the eShopOnWeb repository

1. Open another tab in the same browser window and navigate to the [eShopOnWeb](https://github.com/MicrosoftLearning/eShopOnWeb) repo, which hosts the .NET version of a sample web site.
1. On the **eShopOnWeb** repo page, select **Fork**.
1. On the **Create a new fork** page, ensure that the **Owner** drop-down list entry displays your GitHub user name, accept the default entry **eShopOnWeb** in the **Repository name** text box, and confirm the **Copy the main branch only** checkbox is checked, and then select **Create fork**.

### Deploy the web app to East US

1. Switch back to the Azure portal tab.
1. In the Azure portal, open the Azure Cloud Shell by selecting the Cloud Shell icon in the top navigation bar.
1. If prompted to select either **Bash** or **PowerShell**, select **Bash**.

   > **Note:** If this is the first time you are starting **Cloud Shell** and you are presented with the **You have no storage mounted** message, select the subscription you are using in this lab, and select **Create storage**.

1. From the **Bash** session in the **Cloud Shell** pane, run the following commands to clone your forked eShopOnWeb repository:

   > **Note:** Replace `<YOUR_GITHUB_USERNAME>` in the command below with your actual GitHub username. For example, if your GitHub username is `johnsmith`, the command would be:
   >
   > ```bash
   > git clone https://github.com/johnsmith/eShopOnWeb.git
   > ```
   ```bash
   git clone https://github.com/<YOUR_GITHUB_USERNAME>/eShopOnWeb.git
   cd eShopOnWeb
   ```

1. Run the following commands to create the resource group and deploy the web app to East US:

   ```bash
   # Create resource group for East US
   az group create --name rg-eshoponweb-eastus --location eastus

   # Deploy the Bicep template for East US
   az deployment group create \
     --resource-group rg-eshoponweb-eastus \
     --template-file infra/webapp.bicep \
     --parameters webAppName=eshoponweb-eastus-$(uuidgen)-$(date +%s) \
                  sku=F1 \
                  linuxFxVersion="DOTNETCORE|8.0"
   ```

1. Wait for the deployment to complete. This might take a few minutes.

### Deploy the web app to West US

1. Run the following commands to deploy the web app to West US:

   ```bash
   # Create resource group for West US
   az group create --name rg-eshoponweb-westus --location westus

   # Deploy the Bicep template for West US
   az deployment group create \
     --resource-group rg-eshoponweb-westus \
     --template-file infra/webapp.bicep \
     --parameters webAppName=eshoponweb-westus-$(date +%s%N) \
                  sku=F1 \
                  linuxFxVersion="DOTNETCORE|8.0"
   ```

1. Wait for the deployment to complete. This might take a few minutes.

   > **Note:** Record the names of both web apps as you'll need them for the Traffic Manager configuration.

## Enhance workload resiliency by using Traffic Manager

In this exercise, you'll implement a resilient configuration that distributes requests between the two .NET web app instances in two different Azure regions by using Azure Traffic Manager.

> **Note:** For the purpose of our lab, we will consider the deployment of .NET-based web app eShopOnWeb in the East US region as the primary instance. While in this case such consideration is purely arbitrary (and used for demonstration purposes only), there might be scenarios where it might be beneficial to prioritize one of the endpoints.

The exercise consists of the following tasks:

- Implement a Traffic Manager profile
- Validate Traffic Manager functionality

### Implement a Traffic Manager profile

1. In the web browser tab displaying the Azure portal, in the search text box at the top of the page, enter **`Traffic Manager profiles`** and, in the list of results, select **Traffic Manager profiles**.
1. On the **Load Balancing Services \| Traffic Manager** page, select **+ Create**.
1. On the **Create Traffic Manager profile** page, do the following actions:

   - In the **Name** text box, enter **`devopsfoundationstmprofile`**.

     > **Note:** The name of the Traffic Manager profile must be globally unique. If you receive an error message indicating that the name is already in use, try a different name and make sure to record it. You will need it throughout this lab.

   - In the **Routing method** drop-down list, select **Priority**.

   > **Note:** We choose the priority routing method to reflect the somewhat arbitrary assumption that all of requests should be handled by the Azure App Service web app in the East US.

   - Verify that your Azure subscription appears in the **Subscription** drop-down list
   - Select the **Create new** link below the **Resource Group** drop-down list, in the **Name** text box, enter **`rg-devops-foundations`**, and then select **OK**.
   - In the **Resource group location** drop-down list, select **East US** (or the same Azure region you chose when deploying the East US web app).

1. Select **Create** to start the provisioning process.

   > **Note:** Wait for the deployment to complete. This should complete within a minute.

1. On the **Load Balancing Services \| Traffic Manager** page, if necessary, select **Refresh** and then select **devopsfoundationstmprofile**.
1. On the **devopsfoundationstmprofile** page, in the **Essentials** section, copy the value of the **DNS name** setting, and record it. You'll need it throughout this lab.
1. On the **devopsfoundationstmprofile** page, in the left navigation menu, in the **Settings** section, select **Configuration**.
1. Review the content of the **devopsfoundationstmprofile \| Configuration** page. Note that, by default, **DNS time to live (TTL)** is set to **60** seconds. Change the value to **5** seconds.

   > **Note:** Lowering the value of TTL will accelerate the failover time.

   > **Note:** In addition to the value of TTL, probing interval, probe timeout, and tolerated number of failures affect the amount of time that an endpoint failure is detected.

1. On the **devopsfoundationstmprofile \| Configuration** page, in the **Protocol** drop-down list, select **HTTPS** and, in the **Port** text box, enter **443**.

   > **Note:** Both of the Azure App Service web apps that will be configured as endpoints are accessible via HTTPS on the default TCP port 443.

1. On the **devopsfoundationstmprofile \| Configuration** page, select **Save**.
1. On the **devopsfoundationstmprofile** page, in the left navigation menu, in the **Settings** section, select **Endpoints**.
1. On the **devopsfoundationstmprofile | Endpoints** page, select **+ Add**.

   > **Note:** You will first add an endpoint representing the Azure App Service web app.

1. In the **Add endpoint** pane, perform the following actions:

   - Ensure that **Azure endpoint** appears in the **Type** drop-down list.
   - In the **Name** text box, enter **`DevOps Foundations web app - East US`**.
   - Ensure that the **Enable Endpoint** checkbox is selected.
   - In the **Target resource type** drop-down list, select **App Service**.
   - In the **Target resource** drop-down list, in the **rg-eshoponweb-eastus** section, select the name of the App Service web app you deployed to the East US Azure region.
   - In the **Priority** text box, enter **1**.

   > **Note:** A lower priority value designates a higher precedence. In this case, all requests will be sent to the web app instance in the East US region, as long as that instance remains available.

   - Ensure that the **Health Checks** are enabled.

1. Select **Add**.

1. Back on the **devopsfoundationstmprofile | Endpoints** page, select **+ Add**.

   > **Note:** Next, you will add an endpoint representing the other Azure App Service web app deployed to the West Europe Azure region.

1. In the **Add endpoint** pane, perform the following actions:

   - Ensure that **Azure endpoint** appears in the **Type** drop-down list.
   - In the **Name** text box, enter **`DevOps Foundations web app - West US`**.
   - Ensure that the **Enable Endpoint** checkbox is selected.
   - In the **Target resource type** drop-down list, select **App Service**.
   - In the **Target resource** drop-down list, in the **rg-eshoponweb-westus** section, select the name of the App Service web app you deployed to the West US Azure region.
   - In the **Priority** text box, enter **2**.
   - Ensure that the **Health Checks** are enabled.

1. Select **Add**.
1. Back on the **devopsfoundationstmprofile | Endpoints** page, verify that both endpoints are listed with the **Online** entry in the **Monitor status** column.

   > **Note:** You might need to wait a couple of minutes and select **Refresh** before the status entry is up-to-date.

### Validate Traffic Manager functionality

1. Start a web browser window and navigate to the DNS name associated with the Traffic Manager profile.
1. Verify that the web browser displays the familiar page of the web site hosted by the Azure App Service web app you deployed earlier in this lab.
1. Close the newly opened web browser window.
1. Switch over to the web browser window displaying the Azure portal.
1. In the Azure portal, select the **Azure Cloud Shell** icon to the right of the search text box.
1. If necessary, select **Bash** in the drop-down menu in the upper-left corner of the Cloud Shell pane.
1. In the Bash session within the Cloud Shell pane, run the following command to resolve the DNS name of the Traffic Manager profile you created in the previous task to one of two corresponding endpoints (replace the placeholder `{tm_profile}` with the DNS name of the Traffic Manager profile, for example, `devopsfoundationstmprofile.trafficmanager.net`), but make sure to remove the leading `https:\\`:

   ```cli
   nslookup {tm_profile}
   ```

1. Rerun the same command a few times, waiting for a bit more than 5 seconds between each invocation (to eliminate the possibility of DNS caching) and note that the output in each case references the DNS name of the web app in the East US Azure region.

## Test workload resiliency by using Azure Chaos Studio

In this exercise, you'll test workload resiliency by using Azure Chaos Studio.

> **Note:** This exercise illustrates the use of Azure Chaos Studio. The purpose of Azure Chaos Studio is to assist with measuring, understanding, and building application and service resilience. This is accomplished by intentionally disrupting workloads in order to identify resiliency gaps and implement corresponding mitigation proactively, rather than reactively.

The exercise consists of the following tasks:

- Configure Azure Chaos Studio environment
- Implement an experiment
- Validate the experiment

### Configure Azure Chaos Studio environment

1. In the web browser tab displaying the Azure portal, in the search text box at the top of the page, enter **`Chaos Studio`** and, in the list of results, select **Chaos Studio**.
1. On the **Chaos Studio** page, select **Targets**.
1. On the **Chaos Studio \| Targets** page, select the Azure App Service web app instance in the **rg-eshoponweb-eastus** resource group in the East US region you deployed earlier in this lab.
1. In the toolbar, select the **Enable targets** drop-down list header and, in the drop-down list select **Enable service-direct targets (All resources)**.
1. On the **Enable service direct targets** page, ensure that the correct App Service web app instance is listed, select **Review + Enable**, and then select **Enable**.

   > **Note:** Wait for the target to be enabled. This should take less than a minute.

### Implement an experiment

1. In the Azure portal, in the search text box at the top of the page, enter **`Chaos Studio`** and, in the list of results, select **Chaos Studio**.
1. On the **Chaos Studio** page, select **Experiments**.
1. On the **Experiments** page, select **+ Create** and then, in the drop-down list, select **New experiment**.
1. On the **Basics** tab of the **Create an experiment** page, perform the following actions:

   - Verify that your Azure subscription appears in the **Subscription** drop-down list.
   - Select the **Create new** link below the **Resource Group** drop-down list, in the **Name** text box, enter **`rg-devops-foundations`**, and then select **OK**.
   - In the **Experiment details** section, in the **Name** text box, enter **`DevOps_Foundations_Labs_Experiment_01`**.
   - In the **Region** drop-down list, select the **West US** Azure region.

   > **Note:** You could potentially choose any Azure region, but considering that you are testing failures to a resource in the East US region, selecting a different region like West US is recommended.

1. On the **Basics** tab of the **Create an experiment** page, select **Next: Permissions >**.
1. On the **Permissions** tab, accept the default option **System-assigned identity** and then select **Next: Experiment designer >**.
1. On the **Experiment designer** tab, do the following actions:

   - In the **Step** text box, enter **`Step 1: Failover an App Service web app`**.
   - In the **Branch** text box, enter **`Branch 1: Emulate an App Service failure`**.
   - Select **+ Add action** and, in the drop-down list, select **Add fault**.

1. On the **Fault details** tab of the **Add fault** pane, in the **Faults** drop-down list, select **Stop App Service** and set the value of **Duration (minutes)** to 10.
1. On the **Fault details** tab of the **Add fault** pane, select **Next: Target resources >**.
1. On the **Target resources** tab of the **Add fault** pane, ensure that the option **Manually select from a list** is selected, select the App Service web app you added as a target to the Chaos Studio environment, and then select **Add**.
1. Back on the **Experiment designer** tab of the **Create an experiment** page, select **Review + create**.
1. On the **Review + create** tab of the **Create an experiment** page, select **Create**.

   > **Note:** Wait for the experiment to be created. This should take less than a minute.

   > **Note:** For the experiment to succeed, you need to also grant the newly created managed service account permissions sufficient to stop the Azure App Service web app. We will leverage for this purpose the built-in Azure Contributor role, but you could create a custom role if you want to follow the principle of least privilege.

1. In the Azure portal, in the search text box at the top of the page, enter **`App Services`** and select **App Services** in the list of results.
1. On the **App Services** page, select the Azure App Service web app in the East US region you deployed earlier in this lab.
1. On the web app page, in the vertical menu on the left side, select **Access control (IAM)**.
1. On the web app's **Access control (IAM)** page, select **+ Add** and, in the drop-down list, select **Add role assignment**.
1. On the **Role** tab of the **Add role assignment** page, select **Privileged administrator roles**, in the list of roles, select **Contributor**, and then select **Next**.
1. On the **Members** tab of the **Add role assignment** page, set the **Assigned access to** option to **Managed identity** and then select **+ Select Members**
1. In the **Select managed identities** pane, in the **Managed identities** drop-down list, select **Chaos Experiment**, in the list of managed identities, select the one you created earlier in this task, and then select **Select**.
1. Back on the **Members** tab of the **Add role assignment** page, select **Review + assign** and then again select **Review + assign**.

### Validate the experiment

1. In the Azure portal, navigate back to the **Chaos Studio** page and, in the vertical menu on the left side, select **Experiments**.
1. In the list of experiments, select **DevOps_Foundations_Labs_Experiment_01**.
1. On the **DevOps_Foundations_Labs_Experiment_01** page, select **Start** and, when prompted for confirmation, select **OK**.
1. Wait until the status of the experiment changes to **Running**.
1. On the **DevOps_Foundations_Labs_Experiment_01** page, in the **History** section, select the **Details** link in the entry representing the current experiment execution.
1. On the **DevOps_Foundations_Labs_Experiment_01** experiment details page, review the listing containing the step, branch, and action associated with the experiment.

   > **Note:** You might need to select **Refresh** toolbar entry to update the status of the listing.

1. Select the **Action** entry to display the **Fault details** pane.
1. In the **Running targets** section, select the entry representing the Azure App Service web app.
1. On the web app page, in the **Essential** section, note that the status of the web app is listed as **Stopped**.

   > **Note:** You might need to select **Refresh** toolbar entry to update the status of the Web App.

   > **Note:** Now let's verify whether Traffic Manager is successfully redirecting requests targeting its profile to the endpoint representing the App Service web app in the West US region.

1. Start a web browser and navigate to the DNS name associated with the Traffic Manager profile.
1. Verify that the web browser displays the familiar page of the web site hosted by the Azure App Service web app you deployed earlier in this lab.
1. Switch over to the web browser window displaying the Azure portal.
1. In the Azure portal, select the **Azure Cloud Shell** icon to the right of the search text box.
1. In the Bash session within the Cloud Shell pane, run the following command to resolve the DNS name of the Traffic Manager profile you created in the previous exercise to one of two corresponding endpoints (replace the placeholder `<tm_profile>` with the DNS name of the Traffic Manager profile, but make sure to remove the leading `https://`):

   ```cli
   nslookup <tm_profile>
   ```

1. Rerun the same command a few times, waiting for a bit more than 5 seconds between each invocation (to eliminate the possibility of DNS caching) and verify that the output in each case references the DNS name of the web app in the West US Azure region.

> **Note:** While this example might seem a bit simplistic, the primary objective of the exercise was to illustrate the process of implementing Azure Chaos Studio-based testing and its primary components. You would use the equivalent approach if an Azure App Service web app was a part of more complex environment, where the impact of its failure might be much more challenging to predict.

## Clean up resources

Now that you finished the exercise, you should delete the cloud resources you created to avoid unnecessary resource usage.

1. Navigate to the Azure portal and go to **Resource groups**.
1. Select the **rg-devops-foundations** resource group (containing the Traffic Manager profile).
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name and confirm that you want to delete it.
1. Repeat the same process for the **rg-eshoponweb-eastus** and **rg-eshoponweb-westus** resource groups.

> **CAUTION:** Deleting a resource group deletes all resources contained within it. If you chose an existing resource group for this exercise, any existing resources outside the scope of this exercise will also be deleted.

You don't need to clean up any resources for the GitHub repository, as it will remain available for you to use as a reference and portfolio item.

If you want to delete the repo, you can do so by following this documentation: [Deleting a repository](https://docs.github.com/repositories/creating-and-managing-repositories/deleting-a-repository).
