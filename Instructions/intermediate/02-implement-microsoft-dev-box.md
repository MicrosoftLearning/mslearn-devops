---
lab:
  topic: Intermediate
  title: "Implement Microsoft Dev Box for Developer Self-Service"
  description: "Learn how to implement basic Microsoft Dev Box environments for developer self-service scenarios."
---

# Implement Microsoft Dev Box for Developer Self-Service

In this lab, you will learn how to implement Microsoft Dev Box environments to provide developer self-service capabilities. You will create a dev center, configure dev box definitions, set up projects and pools, and evaluate the developer experience using Microsoft-hosted networking.

You will learn how to:

- Create and configure a Microsoft Dev Box environment
- Set up dev box definitions and projects
- Configure dev box pools with Microsoft-hosted networking
- Manage permissions for different roles
- Evaluate the developer experience

This lab takes approximately **30** minutes to complete.

## Before you start

To complete the lab, you need:

- An Azure subscription to which you have at least the Contributor-level access. If you don't already have one, you can [sign up for one](https://azure.microsoft.com/).
- A Microsoft Entra tenant with appropriate permissions to create users and groups
- A Microsoft Intune subscription associated with the same Microsoft Entra tenant as the Azure subscription
- A GitHub user account. If you don't have one, you can [create a new account](https://github.com/join). If you need instructions on how to create a GitHub account, refer to the article [Creating an account on GitHub](https://docs.github.com/get-started/quickstart/creating-an-account-on-github).

## Prepare the lab environment

> **Note:** In this lab, you will create Microsoft Entra users and groups to simulate different roles in a Microsoft Dev Box deployment. If you already have suitable test users and groups in your tenant, you can skip the user creation steps and adapt the instructions accordingly.

### Create Microsoft Entra users and groups

1. Start a web browser and navigate to the Microsoft Entra admin center at `https://entra.microsoft.com`.
1. If prompted, sign in by using a Microsoft Entra account with Global Administrator permissions in your tenant.
1. In the Microsoft Entra admin center, in the left navigation pane, expand **Identity** and select **Groups**.
1. On the **Groups | All groups** page, select **+ New group**.
1. On the **New Group** page, specify the following settings and select **Create**:

   | Setting     | Value                                 |
   | ----------- | ------------------------------------- |
   | Group type  | **Security**                          |
   | Group name  | **DevCenter_Platform_Engineers**      |
   | Description | **Platform Engineers for Dev Center** |

1. Repeat the previous steps to create two additional groups:

   - **DevCenter_Dev_Leads** (Development team leads)
   - **DevCenter_Dev_Users** (Developers)

1. In the Microsoft Entra admin center, in the left navigation pane, expand **Identity** and select **Users**.
1. On the **Users | All users** page, select **+ New user** and then **Create new user**.
1. On the **New user** page, specify the following settings and select **Create**:

   | Setting                | Value                                |
   | ---------------------- | ------------------------------------ |
   | User principal name    | **platformegineer01@yourdomain.com** |
   | Display name           | **Platform Engineer 01**             |
   | Auto-generate password | **Enabled**                          |
   | Account enabled        | **Enabled**                          |

   > **Note:** Replace `yourdomain.com` with your actual domain name. Record the auto-generated password for later use.

1. Repeat the previous steps to create two additional users:

   - **devlead01@yourdomain.com** (Development Lead 01)
   - **devuser01@yourdomain.com** (Developer User 01)

1. Add the users to their respective groups:
   - Add **platformegineer01** to **DevCenter_Platform_Engineers**
   - Add **devlead01** to **DevCenter_Dev_Leads**
   - Add **devuser01** to **DevCenter_Dev_Users**

### Fork required GitHub repository

1. Open a new browser tab and navigate to [https://github.com/microsoft/devcenter-catalog](https://github.com/microsoft/devcenter-catalog).
1. Sign in to GitHub with your account if prompted.
1. Select **Fork** to create a fork of the repository in your GitHub account.

## Implement a Microsoft Dev Box environment

In this exercise, you will leverage a set of features provided by Microsoft to implement a Microsoft Dev Box environment. This approach focuses on minimizing the effort involved in building a functional developer self-service solution using Microsoft-hosted networking.

The exercise consists of the following tasks:

- Create a dev center
- Review the dev center settings
- Create a dev box definition
- Create a project
- Create a dev box pool
- Configure permissions
- Evaluate a dev box

### Create a dev center

In this task, you will create an Azure dev center that will be used throughout this lab. A dev center is a platform engineering service that centralizes the creation and management of scalable, pre-configured development and deployment environments, optimizing collaboration and resource utilization for software development teams.

1. Start a web browser and navigate to the Azure portal at `https://portal.azure.com`.
1. When prompted to authenticate, sign in by using your Microsoft Entra user account.
1. In the Azure portal, in the **Search** text box, search for and select **`Dev centers`**.
1. On the **Dev centers** page, select **+ Create**.
1. On the **Basics** tab of the **Create a dev center** page, specify the following settings and then select **Next: Settings**:

   | Setting                                                                 | Value                                                        |
   | ----------------------------------------------------------------------- | ------------------------------------------------------------ |
   | Subscription                                                            | The name of the Azure subscription you are using in this lab |
   | Resource group                                                          | The name of a **new** resource group **rg-devcenter-basic**  |
   | Name                                                                    | **devcenter-basic**                                          |
   | Location                                                                | **(US) East US**                                             |
   | Attach a quick start catalog - Azure deployment environment definitions | Enabled                                                      |
   | Attach a quick start catalog - Dev box customization tasks              | Disabled                                                     |

1. On the **Settings** tab of the **Create a dev center** page, specify the following settings and then select **Review + Create**:

   | Setting                                    | Value   |
   | ------------------------------------------ | ------- |
   | Enable catalogs per project                | Enabled |
   | Allow Microsoft hosted network in projects | Enabled |
   | Enable Azure Monitor agent installation    | Enabled |

   > **Note:** By design, resources from catalogs attached to the dev center are available to all projects within it. The setting **Enable catalogs per project** makes it possible to attach additional catalogs to arbitrarily selected projects as well.

   > **Note:** Dev boxes can be connected either to a virtual network in your own Azure subscription or a Microsoft hosted one, depending on whether they need to communicate with resources in your environment. If there is no such need, by enabling the setting **Allow Microsoft hosted network in projects**, you introduce the option to connect dev boxes to a Microsoft hosted network, effectively minimizing the management and configuration overhead.

   > **Note:** The setting **Enable Azure Monitor agent installation** automatically triggers installation of the Azure Monitor agent on all dev boxes in the dev center.

1. On the **Review + Create** tab, wait for the validation to complete and then select **Create**.

   > **Note:** Wait for the project to be provisioned. The project creation might take about 1 minute.

1. On the **Deployment is completed** page, select **Go to resource**.

### Review the dev center settings

In this task, you will review the basic configuration settings of the dev center you created in the previous task.

1. In the web browser displaying the Azure portal, on the **devcenter-basic** page, in the vertical navigation menu on the left side, expand the **Environment configuration** section and select **Catalogs**.
1. On the **devcenter-basic | Catalogs** page, notice that the dev center is configured with the **quickstart-environment-definitions** catalog, which points to the GitHub repository `https://github.com/microsoft/devcenter-catalog.git`.
1. Verify that the **Status** column contains the **Sync successful** entry. If that is not the case, use the following sequence of steps to re-create the catalog:

   1. Select the checkbox next to the autogenerated catalog entry **quickstart-environment-definitions** and then, in the toolbar, select **Delete**.
   1. On the **devcenter-basic | Catalogs** page, select **+ Add**.
   1. In the **Add catalog** pane, in the **Name** text box, enter **`quickstart-environment-definitions-fix`**, in the **Catalog location** section, select **GitHub**, in the **Authentication type**, select **GitHub app**, leave the checkbox **Automatically sync this catalog** checkbox enabled, and then select **Sign in with GitHub**.
   1. In the **Sign in with GitHub** window, enter the GitHub credentials and select **Sign in**.

      > **Note:** These GitHub credentials provide you with access to a GitHub repo created as a fork of <https://github.com/microsoft/devcenter-catalog>

   1. When prompted, in the **Authorize Microsoft DevCenter** window, select **Authorize Microsoft DevCenter**.
   1. Back in the **Add catalog** pane, in the **Repo** drop-down list, select **devcenter-catalog**, in the **Branch** drop-down list, accept the **Default branch** entry, in the **Folder path**, enter **`Environment-Definitions`** and then select **Add**.
   1. Back on the **devcenter-basic | Catalogs** page, verify that the sync completes successfully by monitoring the entry in the **Status** column.

1. On the **devcenter-basic | Catalogs** page, select the **quickstart-environment-definitions-fix** entry.
1. On the **quickstart-environment-definitions-fix** page, review the list of predefined environment definitions.

   > **Note:** Each entry represents a definition of an Azure deployment environment defined in a respective subfolder of the **Environment-Definitions** folder of the GitHub repository `https://github.com/microsoft/devcenter-catalog.git`.

   > **Note:** A deployment environment is a collection of Azure resources defined in a template referred to as an environment definition. Developers can use these definitions to deploy infrastructure that will serve to host their solutions. For more information regarding Azure deployment environments, refer to the Microsoft Learn article [What is Azure Deployment Environments?](https://learn.microsoft.com/azure/deployment-environments/overview-what-is-azure-deployment-environments)

### Create a dev box definition

In this task, you will create a dev box definition. Its purpose is to define the operating system, tools, settings, and resources that serve as a blueprint for creating consistent and tailored development environments (referred to as dev boxes).

1. In the web browser displaying the Azure portal, on the **devcenter-basic** page, in the vertical navigation menu on the left side, expand the **Dev box configuration** section and select **Dev box definitions**.
1. On the **devcenter-basic | Dev box definitions** page, select **+ Create**.
1. On the **Create dev box definition** page, specify the following settings and then select **Create**:

   | Setting            | Value                                                                                                       |
   | ------------------ | ----------------------------------------------------------------------------------------------------------- |
   | Name               | **devbox-definition-basic**                                                                                 |
   | Image              | **Visual Studio 2022 Enterprise on Windows 11 Enterprise + Microsoft 365 Apps 24H2 \| Hibernate supported** |
   | Image version      | **Latest**                                                                                                  |
   | Compute            | **8 vCPU, 32 GB RAM**                                                                                       |
   | Storage            | **256 GB SSD**                                                                                              |
   | Enable hibernation | Enabled                                                                                                     |

   > **Note:** Wait for the dev box definition to be created. This should take less than 1 minute.

### Create a dev center project

In this task, you will create a dev center project. A dev center project typically corresponds with a development project within your organization. For example, you might create a project for the development of a line of business application, and another project for the development of the company website. All projects in a dev center share the same dev box definitions, network connection, catalogs, and compute galleries. You might consider creating multiple dev center projects if you have multiple development projects that have separate project administrators and access permissions requirements.

1. In the web browser displaying the Azure portal, on the **devcenter-basic** page, in the vertical navigation menu on the left side, expand the **Manage** section and select **Projects**.
1. On the **devcenter-basic | Projects** page, select **+ Create**.
1. On the **Basics** tab of the **Create a project** page, specify the following settings and then select **Next: Dev box management**:

   | Setting        | Value                                                        |
   | -------------- | ------------------------------------------------------------ |
   | Subscription   | The name of the Azure subscription you are using in this lab |
   | Resource group | **rg-devcenter-basic**                                       |
   | Dev center     | **devcenter-basic**                                          |
   | Name           | **devcenter-project-basic**                                  |
   | Description    | **Basic Dev Center Project**                                 |

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

### Create a dev box pool

In this task, you will create a dev box pool in the dev center project you created in the previous task. Dev box pools are used by dev box users to create dev boxes. A dev box pool links a dev box definition with a network connection. In this lab, you will use Microsoft-hosted connections, which minimize the management and configuration overhead. The network connection determines where a dev box is hosted and its access to other cloud and on-premises resources. In addition, to reduce the cost of running dev boxes, you can configure a dev box pool to shut them down daily at a predefined time.

1. In the web browser displaying the Azure portal, on the **devcenter-project-basic** page, in the vertical navigation menu on the left side, expand the **Manage** section and select **Dev box pools**.
1. On the **devcenter-project-basic | Dev box pools** page, select **+ Create**.
1. On the **Basics** tab of the **Create a dev box pool** page, specify the following settings and then select **Create**:

   | Setting                                                                                                           | Value                                    |
   | ----------------------------------------------------------------------------------------------------------------- | ---------------------------------------- |
   | Name                                                                                                              | **devbox-pool-basic**                    |
   | Definition                                                                                                        | **devbox-definition-basic**              |
   | Network connection                                                                                                | **Deploy to a Microsoft hosted network** |
   | Region                                                                                                            | **(US) East US**                         |
   | Enable single sign-on                                                                                             | Enabled                                  |
   | Dev box Creator Privileges                                                                                        | **Local Administrator**                  |
   | Enable auto-stop on schedule                                                                                      | Enabled                                  |
   | Stop time                                                                                                         | **07:00 PM**                             |
   | Time zone                                                                                                         | Your current time zone                   |
   | Enable hibernate on disconnect                                                                                    | Enabled                                  |
   | Grace period in minutes                                                                                           | **60**                                   |
   | I confirm that my organization has Azure Hybrid Benefits licenses, which will apply to all dev boxes in this pool | Enabled                                  |

   > **Note:** Wait for the dev box pool to be created. This might take about 2 minutes.

### Configure permissions

In this task, you will assign suitable Microsoft dev box-related permissions to the three Microsoft Entra security principals which have been provisioned in your lab environment. These security principals correspond to typical roles in platform engineering scenarios:

| User              | Group                        | Role                  |
| ----------------- | ---------------------------- | --------------------- |
| platformegineer01 | DevCenter_Platform_Engineers | Platform engineer     |
| devlead01         | DevCenter_Dev_Leads          | Development team lead |
| devuser01         | DevCenter_Dev_Users          | Developer             |

Microsoft dev box relies on Azure role-based access control (Azure RBAC) to control access to project-level functionality. Platform engineers should have full control to create and manage dev centers, their catalogs, and projects. This effectively requires the owner or contributor role, depending on whether they also need the ability to delegate permissions to others. Development team leads should be assigned the dev center Project Admin role, which grants the ability to perform administrative tasks on Microsoft Dev Box projects. Dev box users need the ability to create and manage their own dev boxes, which are associated with the Dev Box User role.

> **Note:** You will start by assigning permissions to the Microsoft Entra group intended to contain platform engineer user accounts.

1. In the web browser displaying the Azure portal, navigate to the **devcenter-basic** page and, in the vertical navigation menu on the left side, select **Access control (IAM)**.
1. On the **devcenter-basic | Access control (IAM)** page, select **+ Add** and, in the drop-down list, select **Add role assignment**.
1. On the **Role** tab of the **Add role assignment** page, select the **Privileged administrator role** tab, in the list of roles, select **Owner** and finally select **Next**.
1. On the **Members** tab of the **Add role assignment** page, ensure that the **User, group, or service principal** option is selected and click **+ Select members**.
1. In the **Select members** pane, search for and select **`DevCenter_Platform_Engineers`** and then click **Select**.
1. Back on the **Members** tab of the **Add role assignment** page, select **Next**.
1. On the **Conditions** tab of the **Add role assignment** page, in the **What user can do** section, select the option **Allow user to assign all roles (highly privileged)** and then select **Next**.
1. On the **Review + assign** tab of the **Add role assignment** page, select **Review + assign**.

   > **Note:** Next you will assign permissions to the Microsoft Entra group intended to contain development team lead user accounts.

1. Back on the **devcenter-basic | Access control (IAM)** page, in the vertical navigation menu on the left side, expand the **Manage** section, select **Projects**, and, in the list of projects, select **devcenter-project-basic**.
1. On the **devcenter-project-basic** page, in the vertical navigation menu on the left side, select **Access control (IAM)**.
1. On the **devcenter-project-basic | Access control (IAM)** page, select **+ Add** and, in the drop-down list, select **Add role assignment**.
1. On the **Role** tab of the **Add role assignment** page, ensure that the **Job function roles** tab is selected, in the list of roles, select **DevCenter Project Admin** and select **Next**.
1. On the **Members** tab of the **Add role assignment** page, ensure that the **User, group, or service principal** option is selected and click **+ Select members**.
1. In the **Select members** pane, search for and select **`DevCenter_Dev_Leads`** and then click **Select**.
1. Back on the **Members** tab of the **Add role assignment** page, select **Next**.
1. On the **Review + assign** tab of the **Add role assignment** page, select **Review + assign**.

   > **Note:** Finally, you will assign permissions to the Microsoft Entra group intended to contain developer user accounts.

1. Back on the **devcenter-project-basic | Access control (IAM)** page, select **+ Add** and, in the drop-down list, select **Add role assignment**.
1. On the **Role** tab of the **Add role assignment** page, ensure that the **Job function roles** tab is selected, in the list of roles, select **DevCenter Dev Box Users** and select **Next**.
1. On the **Members** tab of the **Add role assignment** page, ensure that the **User, group, or service principal** option is selected and click **+ Select members**.
1. In the **Select members** pane, search for and select **`DevCenter_Dev_Users`** and then click **Select**.
1. Back on the **Members** tab of the **Add role assignment** page, select **Next**.
1. On the **Review + assign** tab of the **Add role assignment** page, select **Review + assign**.

### Evaluate a dev box

In this task, you will evaluate a dev box functionality by using a Microsoft Entra developer user account.

1. Start a web browser incognito/in-private and navigate to the Microsoft Dev Box developer portal at `https://aka.ms/devbox-portal`.
1. When prompted to sign in, provide the credentials of the **devuser01** user account.
1. On the **Welcome, devuser01** page of the Microsoft Dev Box developer portal, select **+ New dev box**.
1. In the **Add a dev box** pane, in the **Name** text box, enter **`devuser01box01`**
1. Review other information presented in the **Add a dev box** pane, including the project name, dev box pool specifications, hibernation support status, and the scheduled shutdown timing. In addition, note the option to apply customizations and the notification that dev box creation might take up to 65 minutes.

   > **Note:** Dev box names must be unique within a project.

1. In the **Add a dev box** pane, select **Create**.

   > **Note:** Do not wait for the dev box to be created. You can continue with the cleanup section while the dev box is being provisioned in the background.

1. Once the dev box is fully provisioned and running, connect to it by selecting the option to **Connect via app**.

   > **Note:** Connectivity to a dev box can be established by using a Remote Desktop Windows app, a Remote Desktop client (mstsc.exe), or directly within a web browser window.

1. In the pop-up window titled **This site is trying to open Microsoft Remote Connection Center**, select **Open**. This will automatically initiate a Remote Desktop session to the dev box.
1. When prompted for credentials, authenticate by providing the user name and the password of the **devuser01** account.
1. Within the Remote Desktop session to the dev box, verify that its configuration includes an installation of Visual Studio 2022 and Microsoft 365 apps.

   > **Note:** You can shut down the dev box directly from the Microsoft Dev Box developer portal as a dev user by first selecting the ellipsis symbol in the **Your dev box** interface and then selecting **Shut down** from the cascading menu. Alternatively, as a platform engineer or development team leads, you can control dev box lifecycle from the **Dev box pools** section of the corresponding dev center project.

## Clean up resources

Now that you finished the exercise, you should delete the cloud resources you created to avoid unnecessary resource usage.

1. In your browser navigate to the Azure portal [https://portal.azure.com](https://portal.azure.com); signing in with your Azure credentials if prompted.
1. Navigate to the resource group you created and view the contents of the resources used in this exercise.
1. On the toolbar, select **Delete resource group**.
1. Enter the resource group name and confirm that you want to delete it.

You don't need to clean up your GitHub repo or project, as they will remain available for you to use as a reference and portfolio item.

If you want to delete the repo, you can do so by following this documentation: [Deleting a repository](https://docs.github.com/repositories/creating-and-managing-repositories/deleting-a-repository).
