# Package Management with Azure Artifacts

**Estimated time:** 35 minutes

You will learn how to work with Azure Artifacts for package management, including creating and connecting to a feed, creating and publishing a NuGet package, importing a NuGet package, and updating a NuGet package. Azure Artifacts facilitates discovery, installation, and publishing of NuGet, npm, and Maven packages in Azure DevOps.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure DevOps organization:** Create one if you don't have one
- **Visual Studio 2022 Community Edition** available from [Visual Studio Downloads page](https://visualstudio.microsoft.com/downloads/). Installation should include:
  - **ASP.NET and web development** workload
  - **Azure development** workload  
  - **.NET Core cross-platform development** workload
- **.NET Core SDK:** [Download and install the .NET Core SDK (2.1.400+)](https://go.microsoft.com/fwlink/?linkid=2103972)
- **Azure Artifacts credential provider:** [Download and install the credential provider](https://go.microsoft.com/fwlink/?linkid=2099625)

## About Azure Artifacts

Azure Artifacts facilitate discovery, installation, and publishing NuGet, npm, and Maven packages in Azure DevOps. It's deeply integrated with other Azure DevOps features such as Build, making package management a seamless part of your existing workflows.

Key benefits:
- **Centralized package management** across your organization
- **Integration with CI/CD pipelines** for automatic package publishing
- **Support for multiple package types** (NuGet, npm, Maven, Python, Universal packages)
- **Upstream sources** to proxy and cache packages from public repositories
- **Security and permissions** to control access to your packages

## Create and configure the team project

First, you'll create an Azure DevOps project for this lab.

1. In your browser, open your Azure DevOps organization
2. Click **New Project**
3. Give your project the name **eShopOnWeb**
4. Leave other fields with defaults
5. Click **Create**

## Import the eShopOnWeb Git Repository

Next, you'll import the sample repository that contains the application code.

1. In your Azure DevOps organization, open the **eShopOnWeb** project
2. Click **Repos > Files**
3. Click **Import a Repository**
4. Select **Import**
5. In the **Import a Git Repository** window, paste this URL: `https://github.com/MicrosoftLearning/eShopOnWeb.git`
6. Click **Import**

The repository is organized this way:
- **.ado** folder contains Azure DevOps YAML pipelines
- **src** folder contains the .NET 8 website used in the lab scenarios

7. Go to **Repos > Branches**
8. Hover on the **main** branch then click the ellipsis on the right
9. Click **Set as default branch**

## Configure the eShopOnWeb solution in Visual Studio

You'll configure Visual Studio to prepare for the lab.

1. Ensure that you are viewing the **eShopOnWeb** team project on the Azure DevOps portal

> **Note**: You can access the project page directly by navigating to the https://dev.azure.com/`<your-Azure-DevOps-account-name>`/eShopOnWeb URL, where the `<your-Azure-DevOps-account-name>` placeholder represents your Azure DevOps Organization name.

2. In the vertical menu on the left side of the **eShopOnWeb** pane, click **Repos**
3. On the **Files** pane, click **Clone**
4. Select the drop-down arrow next to **Clone in VS Code**, and in the dropdown menu, select **Visual Studio**
5. If prompted whether to proceed, click **Open**
6. If prompted, sign in with the user account you used to set up your Azure DevOps organization
7. Within the Visual Studio interface, in the **Azure DevOps** pop-up window, accept the default local path (C:\eShopOnWeb) and click **Clone**
8. This will automatically import the project into Visual Studio
9. Leave Visual Studio window open for use in your lab

## Working with Azure Artifacts

You'll learn how to work with Azure Artifacts using the following steps:
- Create and connect to a feed
- Create and publish a NuGet package
- Import a NuGet package
- Update a NuGet package

### Create and connect to a feed

A feed is a collection of packages. You'll create a feed to store your NuGet packages.

1. In the web browser window displaying your Azure DevOps project, in the vertical navigational pane, select the **Artifacts** icon
2. With the **Artifacts** hub displayed, click **+ Create Feed** at the top of the pane

> **Note**: This feed will be a collection of NuGet packages available to users within the organization and will sit alongside the public NuGet feed as a peer.

3. On the **Create new feed** pane, in the **Name** textbox, type **eShopOnWebShared**
4. In the **Visibility** section, select **People in my organization**
5. In the **Upstream sources** section, select **Include packages from common public sources**
6. Click **Create**

> **Note**: Any user who wants to connect to this NuGet feed must configure their environment.

7. Back on the **Artifacts** hub, click **Connect to Feed**
8. On the **Connect to feed** pane, in the **NuGet** section, select **Visual Studio** and copy the **Source** URL
9. Switch back to the **Visual Studio** window
10. In the Visual Studio window, click **Tools** menu header and, in the dropdown menu, select **NuGet Package Manager** and, in the cascading menu, select **Package Manager Settings**
11. In the **Options** dialog box, click **Package Sources** and click the plus sign to add a new package source
12. At the bottom of the dialog box, in the **Name** textbox, replace **Package source** with **eShopOnWebShared**
13. In the **Source** textbox, paste the URL you copied from Azure DevOps
14. Click **Update** and then **OK**

> **Note**: Visual Studio is now connected to the new feed.

### Create and publish a NuGet package

You'll create a custom NuGet package and publish it to the feed.

1. In the Visual Studio window you used to configure the new package source, in the main menu, click **File**, in the dropdown menu, click **New** and then, in the cascading menu, click **Project**
2. On the **Create a new project** pane of the **New Project** dialog box, in the list of project templates, locate the **Class Library** template, select the **Class Library (.NET Standard)** template, and click **Next**
3. On the **Configure your new project** pane of the **New Project** dialog box, specify the following settings and click **Create**:

   - Project name: **eShopOnWeb.Shared**
   - Location: accept the default value
   - Solution: **Create new solution**
   - Solution name: **eShopOnWeb.Shared**

4. Click **Create**
5. In the Visual Studio interface, in the **Solution Explorer** pane, right-click **Class1.cs**, in the right-click menu, select **Delete**, and, when prompted for confirmation, click **OK**
6. Press **Ctrl+Shift+B** or **right-click on the eShopOnWeb.Shared project** and select **Build** to build the project

> **Note**: Next you'll use MSBuild to generate a NuGet package directly from the project. This approach is common for shared libraries to include all the metadata and dependencies in the package.

7. Switch to the Azure DevOps web portal and navigate to the **Artifacts** section
8. Click on the **eShopOnWebShared** feed
9. Click **Connect to Feed** and select **NuGet.exe** under the **NuGet** section
10. Copy the **Project setup** commands for later use

### Publish the package using dotnet CLI

You'll use the .NET CLI to pack and publish your package.

1. In Visual Studio, right-click on the **eShopOnWeb.Shared** project and select **Open Folder in File Explorer**
2. In the File Explorer window, note the path to the project folder
3. Open a **Command Prompt** or **PowerShell** window as Administrator
4. Navigate to the project folder using the `cd` command
5. Run the following command to create a NuGet package:

   ```
   dotnet pack --configuration Release
   ```

6. This will create a `.nupkg` file in the `bin\Release` folder
7. Navigate to the `bin\Release` folder:

   ```
   cd bin\Release
   ```

8. You need to publish the package to your Azure Artifacts feed. First, add the package source:

   ```
   dotnet nuget add source "YOUR_FEED_URL" --name "eShopOnWebShared" --username "YOUR_USERNAME" --password "YOUR_PAT"
   ```

> **Note**: Replace YOUR_FEED_URL with the feed URL from Azure DevOps, YOUR_USERNAME with your Azure DevOps username, and YOUR_PAT with a Personal Access Token with package read/write permissions.

9. Publish the package:

   ```
   dotnet nuget push *.nupkg --source "eShopOnWebShared"
   ```

10. Switch back to the Azure DevOps web portal displaying the **Artifacts** tab
11. Click **Refresh**
12. In the list of packages, click the **eShopOnWeb.Shared** package
13. On the **eShopOnWeb.Shared** pane, review its metadata

### Import a NuGet package

You'll now import the package you created into another project.

1. Switch back to Visual Studio
2. In the **Solution Explorer**, right-click on the **eShopOnWeb.Shared** solution and select **Add > New Project**
3. Select **Console App (.NET Core)** template and click **Next**
4. Configure the project:
   - Project name: **eShopOnWeb.Shared.Client**  
   - Location: accept the default value
   - Solution: **Add to solution**
5. Click **Create**
6. In the **Solution Explorer**, right-click on the **eShopOnWeb.Shared.Client** project and select **Manage NuGet Packages**
7. In the **NuGet Package Manager** pane, click the **Browse** tab
8. In the **Package source** dropdown, select **eShopOnWebShared**
9. In the search box, type **eShopOnWeb.Shared** and press Enter
10. Select the **eShopOnWeb.Shared** package and click **Install**
11. Accept any license agreements if prompted
12. The package is now installed and can be used in your project

### Update a NuGet package

You'll update the package by modifying the original project and publishing a new version.

1. In the **Solution Explorer**, right-click on the **eShopOnWeb.Shared** project and select **Add > Class**
2. Name the class **ProductHelper** and click **Add**
3. Add some sample code to the class:

   ```csharp
   using System;

   namespace eShopOnWeb.Shared
   {
       public class ProductHelper
       {
           public static string GetProductDisplayName(string name, decimal price)
           {
               return $"{name} - ${price:F2}";
           }
       }
   }
   ```

4. Save the file
5. Right-click on the **eShopOnWeb.Shared** project and select **Properties**
6. On the **Package** tab, increment the **Package version** from 1.0.0 to 1.1.0
7. Save and close the Properties window
8. Build the project by pressing **Ctrl+Shift+B**
9. Open Command Prompt or PowerShell as Administrator again
10. Navigate to the **eShopOnWeb.Shared** project folder
11. Pack the new version:

    ```
    dotnet pack --configuration Release
    ```

12. Navigate to the `bin\Release` folder and publish the new version:

    ```
    dotnet nuget push *.nupkg --source "eShopOnWebShared"
    ```

13. Switch back to the Azure DevOps web portal
14. Refresh the **eShopOnWeb.Shared** package page
15. You should now see version 1.1.0 available

### Update the package in the client project

1. Switch back to Visual Studio
2. In the **Solution Explorer**, right-click on the **eShopOnWeb.Shared.Client** project and select **Manage NuGet Packages**
3. Click the **Updates** tab
4. You should see that **eShopOnWeb.Shared** has an update available
5. Select the package and click **Update**
6. Accept any license agreements if prompted
7. The package is now updated to the latest version

## Summary

In this lab, you learned how to work with Azure Artifacts by:

- **Creating and connecting to a feed** for centralized package management
- **Creating and publishing a NuGet package** using the .NET CLI
- **Importing a NuGet package** into another project
- **Updating a NuGet package** with new versions and functionality

Azure Artifacts provides a powerful platform for managing packages across your organization, integrating seamlessly with your CI/CD pipelines and development workflows. It supports multiple package formats and provides upstream source capabilities to proxy external package repositories.
