---
lab:
  topic: Intermediate
  title: "Customize Microsoft Dev Box with Custom Images and Networking"
  description: "Learn how to customize Microsoft Dev Box environments with custom images, private networking, and advanced configurations."
---

# Customize Microsoft Dev Box with Custom Images and Networking

In this lab, you will learn how to customize Microsoft Dev Box environments using custom images built with Azure Image Builder, private networking configurations, and advanced customization features. You will create Azure compute galleries, build custom images, configure virtual network connections, and implement image definitions for team-specific development environments.

You will learn how to:

- Create and configure Azure compute galleries
- Build custom dev box images using Azure Image Builder
- Configure private networking for dev boxes
- Implement image definitions and customization catalogs
- Create customized dev box pools with private networking

This lab takes approximately **30** minutes to complete.

## Before you start

To complete the lab, you need:

- An Azure subscription to which you have at least the Contributor-level access. If you don't already have one, you can [sign up for one](https://azure.microsoft.com/).
- An Microsoft Dev Box environment set up in your Azure subscription. If you haven't set it up yet, refer to the lab [Implement Microsoft Dev Box for Developer Self-Service](../intermediate/02-implement-microsoft-dev-box.md) or follow the instructions [Configure Microsoft Dev Box using the Get Started template](https://learn.microsoft.com/azure/dev-box/quickstart-get-started-template).
- A Microsoft Entra tenant with 3 pre-created user accounts (and, optionally 3 pre-created Microsoft Entra groups) representing 3 different roles involved in Microsoft Dev Box deployments. For the sake of clarity, the user and group names in the lab instructions will be matching the information in the following table:

  | User              | Group                        | Role                  |
  | ----------------- | ---------------------------- | --------------------- |
  | platformegineer01 | DevCenter_Platform_Engineers | Platform engineer     |
  | devlead01         | DevCenter_Dev_Leads          | Development team lead |
  | devuser01         | DevCenter_Dev_Users          | Developer             |

- A Microsoft Entra tenant with appropriate permissions to create users and groups
- A Microsoft Intune subscription associated with the same Microsoft Entra tenant as the Azure subscription
- A GitHub user account. If you don't have one, you can [create a new account](https://github.com/join). If you need instructions on how to create a GitHub account, refer to the article [Creating an account on GitHub](https://docs.github.com/get-started/quickstart/creating-an-account-on-github).

### Fork required GitHub repositories

1. Open a new browser tab and navigate to [https://github.com/MicrosoftLearning/contoso-co-eShop](https://github.com/MicrosoftLearning/contoso-co-eShop).
1. Sign in to GitHub with your account if prompted.
1. Select **Fork** to create a fork of the repository in your GitHub account.

> **Note:** This repository contains image definition files that will be used for customization.

## Customize a Microsoft Dev Box environment

In this exercise, you will customize the functionality of the Microsoft Dev Box environment. This approach focuses on the extent of changes you can apply when implementing a custom developer self-service solution using Azure compute galleries, custom images, and private networking.

The exercise consists of the following tasks:

- Create an Azure compute gallery and attach it to the dev center
- Configure authentication and authorization for Azure Image Builder
- Create a custom image by using Azure Image Builder
- Create an Azure dev center network connection
- Adding image definitions to an Azure dev center project
- Create a customized dev box pool
- Evaluate a customized dev box

### Create an Azure compute gallery and attach it to the dev center

In this task, you will create an Azure compute gallery and attach it to a dev center. A gallery is a repository residing in an Azure subscription, which helps you build structure and organization around custom images. After you attach a compute gallery to a dev center and populate it with images, you will be able to create dev box definitions based on images stored in the compute gallery.

1. Start a web browser and navigate to the Azure portal at `https://portal.azure.com`.
1. When prompted to authenticate, sign in by using your Microsoft account.
1. In the Azure portal, in the **Search** text box, search for and select **`Azure compute galleries`**.
1. On the **Azure compute galleries** page, select **+ Create**.
1. On the **Basics** tab of the **Create Azure compute gallery** page, specify the following settings and then select **Next: Sharing method**:

   | Setting        | Value                                                        |
   | -------------- | ------------------------------------------------------------ |
   | Subscription   | The name of the Azure subscription you are using in this lab |
   | Resource group | The name of a **new** resource group **rg-devcenter-custom** |
   | Name           | **compute_gallery_custom**                                   |
   | Region         | **(US) East US**                                             |

1. On the **Sharing method** tab of the **Create Azure compute gallery** page, ensure that the **Role based access control (RBAC)** option is selected and then select **Review + Create**:
1. On the **Review + Create** tab, wait for the validation to complete and then select **Create**.

   > **Note:** Wait for the project to be provisioned. The Azure compute gallery creation should take less than 1 minute.

1. In the Azure portal, search for and select **`Dev centers`**.
1. On the **Dev centers** page, select **+ Create**.
1. On the **Basics** tab of the **Create a dev center** page, specify the following settings and then select **Next: Settings**:

   | Setting                                                                 | Value                                                        |
   | ----------------------------------------------------------------------- | ------------------------------------------------------------ |
   | Subscription                                                            | The name of the Azure subscription you are using in this lab |
   | Resource group                                                          | **rg-devcenter-custom**                                      |
   | Name                                                                    | **devcenter-custom**                                         |
   | Location                                                                | **(US) East US**                                             |
   | Attach a quick start catalog - Azure deployment environment definitions | Enabled                                                      |
   | Attach a quick start catalog - Dev box customization tasks              | Enabled                                                      |

1. On the **Settings** tab of the **Create a dev center** page, specify the following settings and then select **Review + Create**:

   | Setting                                    | Value   |
   | ------------------------------------------ | ------- |
   | Enable catalogs per project                | Enabled |
   | Allow Microsoft hosted network in projects | Enabled |
   | Enable Azure Monitor agent installation    | Enabled |

1. On the **Review + Create** tab, wait for the validation to complete and then select **Create**.

   > **Note:** Wait for the dev center to be provisioned. This might take about 1 minute.

1. On the **Deployment is completed** page, select **Go to resource**.
1. On the **devcenter-custom** page, in the vertical navigation menu on the left side, expand the **Dev box configuration** section and select **Azure compute galleries**.
1. On the **devcenter-custom | Azure compute galleries** page, select **+ Add**.
1. In the **Add Azure compute gallery** pane, in the **Gallery** drop-down list, select **compute_gallery_custom** and then select **Add**.

   > **Note:** If you receive an error message: "_This dev center does not have a system assigned or user assigned identity. Galleries cannot be added until an identity has been assigned._" you will need to assign a system assigned identity to the dev center.
   > To do so, in the Azure portal, on the **devcenter-custom** page, in the vertical navigation menu on the left side, select **Identity** under Settings, in the **System assigned** tab, set the **Status** switch to **On**, and then select **Save**.

### Configure authentication and authorization for Azure Image Builder

In this task, you will create a user-assigned managed identity that will be used by Azure Image Builder to add images to the Azure compute gallery you created in the previous task. You will also configure the required permissions by creating a custom role based access control (RBAC) role and assigning it to the managed identity. This will allow you to use Azure Image Builder in the next task to build a custom image.

1. In the Azure portal, select the **Cloud Shell** toolbar icon to open the Cloud Shell pane and, if needed, select **Switch to PowerShell** to start a PowerShell session and, in the **Switch to PowerShell in Cloud Shell** dialog box, select **Confirm**.

   > **Note:** If this is the first time you are opening Cloud Shell, in the **Welcome to Azure Cloud Shell** dialog box, select **PowerShell**, in the **Getting Started** pane, select the option **No Storage Account required** and, in the **Subscription** drop-down list, select the name of the Azure subscription you are using in this lab.

1. In the PowerShell session of the Cloud Shell pane, run the following commands to ensure that all required resource providers are registered:

   ```powershell
   Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
   Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
   Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
   Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
   Register-AzResourceProvider -ProviderNamespace Microsoft.Network
   ```

1. Run the following command to install the required PowerShell modules (when prompted, type **A** and press the **Enter** key):

   ```powershell
   'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}
   ```

1. Run the following commands to set up variables that will be referenced throughout the image build process:

   ```powershell
   $currentAzContext = Get-AzContext
   # the target Azure subscription ID
   $subscriptionID=$currentAzContext.Subscription.Id
   # the target Azure resource group name
   $imageResourceGroup='rg-devcenter-custom'
   # the target Azure region
   $location='eastus'
   # the reference name assigned to the image created by using the Azure Image Builder service
   $runOutputName="aibWinImgCustom"
   # image template name
   $imageTemplateName="templateWinVSCodeCustom"
   # the Azure compute gallery name
   $computeGallery = 'compute_gallery_custom'
   ```

1. Run the following commands to create a user-assigned managed identity (VM Image Builder uses the user identity you provide to store images in the target Azure Compute Gallery):

   ```powershell
   # Install the Azure PowerShell module to support AzUserAssignedIdentity
   Install-Module -Name Az.ManagedServiceIdentity
   # Generate a pseudo-random integer to be used for resource names
   $timeInt=$(get-date -UFormat "%s")

   # Create an identity
   $identityName='identityAIBCustom' + $timeInt
   New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Location $location
   $identityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
   $identityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId
   ```

1. Run the following commands to grant the newly created user-assigned managed identity the permissions required to store images in the **rg-devcenter-custom** resource group:

   ```powershell
   # Set variables
   $imageRoleDefName = 'Custom Azure Image Builder Image Def Custom' + $timeInt
   $aibRoleImageCreationUrl = 'https://raw.githubusercontent.com/azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json'
   $aibRoleImageCreationPath = 'aibRoleImageCreation.json'

   # Customize the role definition file
   Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing
   ((Get-Content -path $aibRoleImageCreationPath -Raw) -Replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
   ((Get-Content -path $aibRoleImageCreationPath -Raw) -Replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
   ((Get-Content -path $aibRoleImageCreationPath -Raw) -Replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

   # Create a role definition
   New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json

   # Assign the role to the VM Image Builder user-assigned managed identity within the scope of the **rg-devcenter-custom** resource group
   New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
   ```

### Create a custom image by using Azure Image Builder

In this task, you will use Azure Image Builder to create a custom image based on an existing Azure Resource Manager (ARM) template that defines a Windows 11 Enterprise image with automatically installed Chocolatey and Visual Studio Code. Azure VM Image Builder considerably simplifies the process of defining and provisioning VM images. It relies on an image configuration that you specify to configure an automated imaging pipeline. Subsequently, developers will be able to use such images to provision their dev boxes.

1. In the PowerShell session of the Cloud Shell pane, run the following commands to create an image definition to be added to the Azure compute gallery you created in the first task of this exercise:

   ```powershell
   # ensure that the image definition security type property is set to 'TrustedLaunch'
   $securityType = @{Name='SecurityType';Value='TrustedLaunch'}
   $features = @($securityType)
   # Image definition name
   $imageDefName = 'imageDefDevBoxVSCodeCustom'

   # Create the image definition
   New-AzGalleryImageDefinition -GalleryName $computeGallery -ResourceGroupName $imageResourceGroup -Location $location -Name $imageDefName -OsState generalized -OsType Windows -Publisher 'Contoso' -Offer 'vscodedevbox' -Sku '1-0-0' -Feature $features -HyperVGeneration 'V2'
   ```

   > **Note:** A dev box image must satisfy a number of requirements including the use of Generation 2, Hyper-V v2, and Windows 10 or 11 Enterprise version 20H2 or later. For their full list, refer to the Microsoft Learn article [Configure Azure Compute Gallery for Microsoft Dev Box](https://learn.microsoft.com/azure/dev-box/how-to-configure-azure-compute-gallery).

1. Run the following commands to create an empty file named template.json that will contain an ARM template defining a Windows 11 Enterprise image with automatically installed Chocolatey and Visual Studio Code:

   ```powershell
   Set-Location -Path ~
   $templateFile = 'template.json'
   Set-Content -Path $templateFile -Value ''
   ```

1. In the PowerShell session of Cloud Shell, use the nano text editor to add the following content to the newly created file:

   > **Note:** To open the nano text editor, run the command `nano ./template.json`. To save changes and exit the nano text editor, press **Ctrl+X**, then **Y**, and finally **Enter**.

   ```json
   {
     "$schema": "http://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
     "contentVersion": "1.0.0.0",
     "parameters": {
       "imageTemplateName": {
         "type": "string"
       },
       "api-version": {
         "type": "string"
       },
       "svclocation": {
         "type": "string"
       }
     },
     "variables": {},
     "resources": [
       {
         "name": "[parameters('imageTemplateName')]",
         "type": "Microsoft.VirtualMachineImages/imageTemplates",
         "apiVersion": "[parameters('api-version')]",
         "location": "[parameters('svclocation')]",
         "dependsOn": [],
         "tags": {
           "imagebuilderTemplate": "win11multi",
           "userIdentity": "enabled"
         },
         "identity": {
           "type": "UserAssigned",
           "userAssignedIdentities": {
             "<imgBuilderId>": {}
           }
         },
         "properties": {
           "buildTimeoutInMinutes": 100,
           "vmProfile": {
             "vmSize": "Standard_D2s_v3",
             "osDiskSizeGB": 127
           },
           "source": {
             "type": "PlatformImage",
             "publisher": "MicrosoftWindowsDesktop",
             "offer": "Windows-11",
             "sku": "win11-21h2-ent",
             "version": "latest"
           },
           "customize": [
             {
               "type": "PowerShell",
               "name": "CreateBuildPath",
               "inline": [
                 "mkdir c:\\buildArtifacts",
                 "echo Azure-Image-Builder-Was-Here  > c:\\buildArtifacts\\azureImageBuilder.txt"
               ]
             },
             {
               "type": "PowerShell",
               "name": "InstallChocolatey",
               "inline": [
                 "Set-ExecutionPolicy Bypass -Scope Process -Force",
                 "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
                 "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
               ]
             },
             {
               "type": "PowerShell",
               "name": "InstallVSCode",
               "inline": ["choco install vscode -y"]
             }
           ],
           "distribute": [
             {
               "type": "SharedImage",
               "galleryImageId": "/subscriptions/<subscriptionID>/resourceGroups/<rgName>/providers/Microsoft.Compute/galleries/<sharedImageGalName>/images/<imageDefName>",
               "runOutputName": "<runOutputName>",
               "artifactTags": {
                 "source": "azureVmImageBuilder",
                 "baseosimg": "windows11"
               },
               "replicationRegions": ["<region1>", "<region2>"]
             }
           ]
         }
       }
     ]
   }
   ```

1. Run the following commands to replace placeholders in the template.json with the values specific to your Azure environment:

   ```powershell
   $replRegion2 = 'eastus2'
   $templateFilePath = '.\template.json'
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<subscriptionID>', $subscriptionID | Set-Content -Path $templateFilePath
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<rgName>', $imageResourceGroup | Set-Content -Path $templateFilePath
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<runOutputName>', $runOutputName | Set-Content -Path $templateFilePath
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<imageDefName>', $imageDefName | Set-Content -Path $templateFilePath
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<sharedImageGalName>', $computeGallery | Set-Content -Path $templateFilePath
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<region1>', $location | Set-Content -Path $templateFilePath
   (Get-Content -Path $templateFilePath -Raw ) -Replace '<region2>', $replRegion2 | Set-Content -Path $templateFilePath
   ((Get-Content -Path $templateFilePath -Raw) -Replace '<imgBuilderId>', $identityNameResourceId) | Set-Content -Path $templateFilePath
   ```

1. Run the following command to submit the template to the Azure Image Builder service (the service processes the submitted template by downloading any dependent artifacts, such as scripts, and storing them in a staging resource group, which name includes the **IT\_** prefix, for building a custom virtual machine image):

   ```powershell
   New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -Api-Version "2020-02-14" -imageTemplateName $imageTemplateName -svclocation $location
   ```

1. Run the following command to invoke the image build process:

   ```powershell
   Invoke-AzResourceAction -ResourceName $imageTemplateName -ResourceGroupName $imageResourceGroup -ResourceType Microsoft.VirtualMachineImages/imageTemplates -ApiVersion "2020-02-14" -Action Run -Force
   ```

1. Run the following command to determine the image provisioning state:

   ```powershell
   Get-AzImageBuilderTemplate -ImageTemplateName $imageTemplateName -ResourceGroupName $imageResourceGroup | Select-Object -Property Name, LastRunStatusRunState, LastRunStatusMessage, ProvisioningState
   ```

   > **Note:** The following output will indicate that the build process has completed successfully:

   ```powershell
   Name                    LastRunStatusRunState LastRunStatusMessage ProvisioningState
   ----                    --------------------- -------------------- -----------------
   templateWinVSCodeCustom Succeeded                                  Succeeded
   ```

1. Alternatively, to monitor the build progress, use the following procedure:

   1. In the Azure portal, search for and select **`Image templates`**.
   1. On the **Image templates** page, select **templateWinVSCodeCustom**.
   1. On the **templateWinVSCodeCustom** page, in the **Essentials** section, note the value of the **Build run state** entry.

   > **Note:** The build process might take about 30 minutes. For the sake of time, you can proceed to the next task while the build is in progress and return to verify the completion later.

1. Once the build completes, in the Azure portal, search for and select **`Azure compute galleries`**.
1. On the **Azure compute galleries** page, select **compute_gallery_custom**.
1. On the **compute_gallery_custom** page, ensure that the **Definitions** tab is selected and, in the list of definitions, select **imageDefDevBoxVSCodeCustom**.
1. On the **imageDefDevBoxVSCodeCustom** page, select the **Versions** tab and verify that the **1.0.0 (latest version)** entry appears on the list with the **Provisioning State** set to **Succeeded**.
1. Select the **1.0.0 (latest version)** entry.
1. On the **1.0.0 (compute_gallery_custom/imageDefDevBoxVSCodeCustom/1.0.0)** page, review the VM image version settings.

### Create an Azure dev center network connection

In this task, you will configure Azure dev center networking to be used in a scenario that requires private connectivity to resources hosted within an Azure virtual network. Unlike Microsoft hosted network that you might have used in previous labs, virtual network connections also support hybrid scenarios (providing connectivity to on-premises resources) and Microsoft Entra hybrid join of Azure dev boxes (in addition to support for Microsoft Entra join).

1. In the web browser displaying the Azure portal, in the **Search** text box, search for and select **`Virtual networks`**.
1. On the **Virtual networks** page, select **+ Create**.
1. On the **Basics** tab of the **Create virtual network** page, specify the following settings and then select **Next**:

   | Setting        | Value                                                        |
   | -------------- | ------------------------------------------------------------ |
   | Subscription   | The name of the Azure subscription you are using in this lab |
   | Resource group | **rg-devcenter-custom**                                      |
   | Name           | **vnet-custom**                                              |
   | Location       | **(US) East US**                                             |

1. On the **Security** tab of the **Create virtual network** page, review the existing settings without changing their default values and then select **Next**.
1. On the **IP addresses** tab of the **Create virtual network** page, review the existing settings without changing their default values and then select **Review + Create**.
1. On the **Review + Create** tab of the **Create virtual network** page, select **Create**.

   > **Note:** Wait for the virtual network to be created. This should take less than 1 minute.

1. In the Azure portal, in the **Search** text box, search for and select **`Network connections`**.
1. On the **Network connections** page, select **+ Create**.
1. On the **Basics** tab of the **Create a network connection** page, specify the following settings and then select **Review + Create**:

   | Setting         | Value                                                        |
   | --------------- | ------------------------------------------------------------ |
   | Subscription    | The name of the Azure subscription you are using in this lab |
   | Resource group  | **rg-devcenter-custom**                                      |
   | Name            | **network-connection-vnet-custom**                           |
   | Virtual network | **vnet-custom**                                              |
   | Subnet          | **default**                                                  |

1. On the **Review + Create** tab of the **Create virtual network** page, select **Create**.

   > **Note:** Wait for the network connection to be created. This might take about 1 minute.

1. In the Azure portal, search for and select **`Dev centers`** and, on the **Dev centers** page, select **devcenter-custom**.
1. On the **devcenter-custom** page, in the vertical navigation menu on the left side, expand the **Dev box configuration** section and select **Networking**.
1. On the **devcenter-custom | Networking** page, select **+ Add**.
1. In the **Add network connection** pane, in the **Network connection** drop-down list, select **network-connection-vnet-custom** and then select **Add**.

   > **Note:** Do not wait for network connection to be added, but instead proceed to the next task. Adding a network connection might take about 1 minute.

### Adding image definitions to an Azure dev center project

In this task, you will add image definitions to an Azure dev center project. Image definitions combine an Azure Marketplace or a custom image with configurable tasks that define additional modifications to be applied to the underlying image. An image definition can be used to build a new image (containing all changes, including those applied by tasks) or to create dev box pools directly. Creating a reusable image minimizes time required for dev box provisioning.

To configure imaging for Microsoft Dev Box team customizations, project-level catalogs must be enabled (which you configured when creating the dev center). In this task, you will configure catalog sync settings for the project. This will involve attaching a catalog that contains image definition files.

1. In the web browser displaying the Azure portal, on the **devcenter-custom** page, in the vertical navigation menu on the left side, expand the **Manage** section and select **Projects**.
1. On the **devcenter-custom | Projects** page, select **+ Create**.
1. On the **Basics** tab of the **Create a project** page, specify the following settings and then select **Next: Dev box management**:

   | Setting        | Value                                                        |
   | -------------- | ------------------------------------------------------------ |
   | Subscription   | The name of the Azure subscription you are using in this lab |
   | Resource group | **rg-devcenter-custom**                                      |
   | Dev center     | **devcenter-custom**                                         |
   | Name           | **devcenter-project-custom**                                 |
   | Description    | **Custom Dev Center Project**                                |

1. On the **Dev box management** tab of the **Create a project** page, specify the following settings and then select **Next: Catalogs**:

   | Setting                 | Value |
   | ----------------------- | ----- |
   | Enable dev box limits   | Yes   |
   | Dev boxes per developer | **2** |

1. On the **Catalogs** tab of the **Create a project** page, specify the following settings and then select **Review + Create**:

   | Setting                            | Value   |
   | ---------------------------------- | ------- |
   | Deployment environment definitions | Enabled |
   | Image definitions                  | Enabled |

1. On the **Review + Create** tab of the **Create a project** page, select **Create**:

   > **Note:** Wait for the project to be created. This should take less than 1 minute.

1. On the **Deployment is completed** page, select **Go to resource**.
1. On the **devcenter-project-custom** page, in the vertical navigation menu on the left side, expand the **Settings** section and select **Catalogs**.
1. On the **devcenter-project-custom | Catalogs** page, select **+ Add**.
1. In the **Add catalog** pane, in the **Name** text box, enter **`image-definitions-custom`**, in the **Catalog source** section, select **GitHub**, in the **Authentication type**, select **GitHub app**, leave the checkbox **Automatically sync this catalog** checkbox enabled, and then select **Sign in with GitHub**.
1. If prompted, in the **Sign in with GitHub** window, enter your GitHub credentials and select **Sign in**.
1. If you see a message stating "We could not find any GitHub repos associated with the account" with a link to **configure your repositories**, complete the following additional steps to set up the Microsoft DevCenter GitHub App:

   1. Select the **configure your repositories** link. This will open a new browser tab or window directed to GitHub.
   1. On the GitHub **Install Microsoft DevCenter** page, you will be prompted to install the app on your personal account.
   1. In the **Install on your personal account** section, choose one of the following options:
      - Select **All repositories** to grant access to all current and future repositories in your account.
      - Select **Only select repositories** to choose specific repositories. If you choose this option, use the **Select repositories** dropdown to select the **contoso-co-eShop** repository (or any other repositories you want to make available to Azure DevCenter).
   1. Review the permissions that will be granted under **with these permissions** section, which typically includes "Read access to code and metadata".
   1. Select **Install** to complete the GitHub App installation.
   1. You will be redirected back to the Azure portal. If the redirect doesn't happen automatically, close the GitHub tab and return to the Azure portal.
   1. Back in the Azure portal, on the **Add catalog** page, select **Refresh** or refresh the page to reload the repository list.

   > **Note:** You need to fork the https://github.com/MicrosoftLearning/contoso-co-eShop repository to your GitHub account before you can complete this step.

1. If prompted, in the **Authorize Microsoft DevCenter** window, select **Authorize Microsoft DevCenter**.
1. Back in the **Add catalog** pane, in the **Repo** drop-down list, select **contoso-co-eShop**, in the **Branch** drop-down list, accept the **Default branch** entry, in the **Folder path**, enter **`.devcenter/catalog/image-definitions`** and then select **Add**.
1. Back on the **devcenter-project-custom | Catalogs** page, verify that the sync completes successfully by monitoring the entry in the **Status** column.
1. Select the **Sync successful** link in the **Status** column, review the resulting notification pane, verify 3 items were added to the catalog, and close the pane by selecting the **x** symbol in the upper right corner.
1. Back on the **devcenter-project-custom | Catalogs** page, select **image-definitions-custom** and verify that it contains three entries named **ContosoBaseImageDefinition**, **backend-eng**, and **frontend-eng**.
1. In the Azure portal, navigate back to the **devcenter-project-custom** page, in the vertical navigation menu on the left side, expand the **Manage** section, select **Image definitions**, and verify that the page displays the same 3 image definitions you identified earlier in this task.

### Create a customized dev box pool

In this task, you will use the newly provisioned image definitions to create a dev box pool. The pool will also utilize the network connection you set up earlier in this exercise.

1. In the Azure portal displaying the **devcenter-project-custom | Image definitions** page, in the vertical navigation menu on the left side, in the **Manage** section, select **Dev box pools**.
1. On the **devcenter-project-custom | Dev box pools** page, select **+ Create**.
1. On the **Basics** tab of the **Create a dev box pool** page, specify the following settings and then select **Create**:

   | Setting                                                                                                           | Value                              |
   | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
   | Name                                                                                                              | **devbox-pool-custom**             |
   | Definition                                                                                                        | **frontend-eng**                   |
   | Network connection                                                                                                | **network-connection-vnet-custom** |
   | Enable single sign-on                                                                                             | Enabled                            |
   | Dev box Creator Privileges                                                                                        | **Local Administrator**            |
   | Enable auto-stop on schedule                                                                                      | Enabled                            |
   | Stop time                                                                                                         | **07:00 PM**                       |
   | Time zone                                                                                                         | Your current time zone             |
   | Enable hibernate on disconnect                                                                                    | Enabled                            |
   | Grace period in minutes                                                                                           | **60**                             |
   | I confirm that my organization has Azure Hybrid Benefits licenses, which will apply to all dev boxes in this pool | Enabled                            |

   > **Note:** Wait for the dev box pool to be created. This might take about 2 minutes.

### Evaluate a customized dev box

In this task, you will evaluate the customized dev box functionality by creating a dev box using the custom image and private networking.

> **Note:** For this task, you will need the developer user account credentials from the previous lab or you can create a new user account following the steps in the prepare lab environment section.

1. First, you need to assign permissions to allow developers to use the new dev box pool. In the Azure portal, navigate to the **devcenter-project-custom** page.
1. In the vertical navigation menu on the left side, select **Access control (IAM)**.
1. On the **devcenter-project-custom | Access control (IAM)** page, select **+ Add** and, in the drop-down list, select **Add role assignment**.
1. On the **Role** tab of the **Add role assignment** page, ensure that the **Job function roles** tab is selected, in the list of roles, select **DevCenter Dev Box Users** and select **Next**.
1. On the **Members** tab of the **Add role assignment** page, ensure that the **User, group, or service principal** option is selected and click **+ Select members**.
1. In the **Select members** pane, search for and select **`DevCenter_Dev_Users`** and then click **Select**.
1. Back on the **Members** tab of the **Add role assignment** page, select **Next**.
1. On the **Review + assign** tab of the **Add role assignment** page, select **Review + assign**.
1. Start a web browser incognito/in-private and navigate to the Microsoft Dev Box developer portal at `https://aka.ms/devbox-portal`.
1. When prompted to sign in, provide the credentials of the **devuser01** user account.
1. On the **Welcome, devuser01** page of the Microsoft Dev Box developer portal, select **+ New dev box**.
1. In the **Add a dev box** pane, specify the following settings:

   | Setting | Value                        |
   | ------- | ---------------------------- |
   | Name    | **devuser01custombox01**     |
   | Project | **devcenter-project-custom** |
   | Pool    | **devbox-pool-custom**       |

1. Review other information presented in the **Add a dev box** pane, including the pool specifications, hibernation support status, and the scheduled shutdown timing. Note the customization options available.
1. In the **Add a dev box** pane, select **Create**.

   > **Note:** The dev box creation process may take 30-65 minutes. For the sake of time in this lab, you don't need to wait for the complete provisioning, but you should observe that the dev box is being created with the custom image and private network configuration.

1. Observe the provisioning status and note that the dev box is being created using:
   - The custom **frontend-eng** image definition
   - Private network connection **network-connection-vnet-custom**
   - Custom configurations from the image definition catalog

## Clean up resources

Now that you finished the exercise, you should delete the cloud resources you created to avoid unnecessary resource usage.

1. In your browser navigate to the Azure portal [https://portal.azure.com](https://portal.azure.com); signing in with your Azure credentials if prompted.
1. Navigate to the resource group you created and view the contents of the resources used in this exercise.
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name and confirm that you want to delete it.

You don't need to clean up your GitHub repo or project, as they will remain available for you to use as a reference and portfolio item.

If you want to delete the repo, you can do so by following this documentation: [Deleting a repository](https://docs.github.com/repositories/creating-and-managing-repositories/deleting-a-repository).
