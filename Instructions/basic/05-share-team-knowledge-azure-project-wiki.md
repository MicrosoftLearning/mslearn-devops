---
lab:
  topic: Basic
  title: "Share Team Knowledge using Azure Project Wiki"
  description: "Learn how to create and configure wikis in Azure DevOps, including managing markdown content and creating Mermaid diagrams."
---

# Share Team Knowledge using Azure Project Wiki

**Estimated time:** 45 minutes

You will learn how to create and configure wikis in Azure DevOps, including managing markdown content and creating Mermaid diagrams. Azure DevOps wikis provide a centralized place for teams to share knowledge, document processes, and maintain project information.

This lab takes approximately **45** minutes to complete.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure DevOps organization:** Create one if you don't have one
- **eShopOnWeb project:** Use the sample project from previous labs or create a new one

## About Azure DevOps Wikis

Azure DevOps provides two types of wikis:

1. **Project wiki** - A wiki that exists separately from your repositories
1. **Code wiki** - A wiki created from content stored in a Git repository

Key features:

- **Markdown support** with rich formatting capabilities
- **Mermaid diagrams** for creating flowcharts and sequence diagrams
- **Image support** with drag-and-drop functionality
- **Version control** with revision history
- **Cross-reference links** to work items, code, and other wikis
- **Collaborative editing** with concurrent user support

## Set up the project and repository

First, ensure you have the eShopOnWeb project ready for this lab.

### Set up Azure DevOps organization (if needed)

If you don't already have an Azure DevOps organization, follow these steps:

1. Use a private browser session to get a new **personal Microsoft Account (MSA)** at `https://account.microsoft.com` (skip if you already have one).
1. Using the same browser session, sign up for a free Azure subscription at `https://azure.microsoft.com/free` (skip if you already have one).
1. Open a browser and navigate to Azure portal at `https://portal.azure.com`, then search at the top of the Azure portal screen for **Azure DevOps**. In the resulting page, select **Azure DevOps organizations**.
1. Next, select the link labelled **My Azure DevOps Organizations** or navigate directly to `https://aex.dev.azure.com`.
1. On the **We need a few more details** page, select **Continue**.
1. In the drop-down box on the left, choose **Default Directory**, instead of **Microsoft Account**.
1. If prompted (_"We need a few more details"_), provide your name, e-mail address, and location and select **Continue**.
1. Back at `https://aex.dev.azure.com` with **Default Directory** selected select the blue button **Create new organization**.
1. Accept the _Terms of Service_ by selecting **Continue**.
1. If prompted (_"Almost done"_), leave the name for the Azure DevOps organization at default (it needs to be a globally unique name) and pick a hosting location close to you from the list.
1. Once the newly created organization opens in **Azure DevOps**, select **Organization settings** in the bottom left corner.
1. At the **Organization settings** screen select **Billing** (opening this screen takes a few seconds).
1. Select **Setup billing** and on the right-hand side of the screen, select your **Azure Subscription** and then select **Save** to link the subscription with the organization.
1. Once the screen shows the linked Azure Subscription ID at the top, change the number of **Paid parallel jobs** for **MS Hosted CI/CD** from 0 to **1**. Then select **SAVE** button at the bottom.

   > **Note**: You may **wait a couple of minutes before using the CI/CD capabilities** so that the new settings are reflected in the backend. Otherwise, you will still see the message _"No hosted parallelism has been purchased or granted"_.

1. In **Organization Settings**, go to section **Pipelines** and select **Settings**.
1. Toggle the switch to **Off** for **Disable creation of classic build pipelines** and **Disable creation of classic release pipelines**.
1. In **Organization Settings**, go to section **Security** and select **Policies**.
1. Toggle the switch to **On** for **Allow public projects**.

### Create and configure the Azure DevOps project (if needed)

1. Open your browser and navigate to your Azure DevOps organization.
1. Select the **New Project** option and use the following settings:
   - name: **eShopOnWeb**
   - visibility: **Private**
   - Advanced: Version Control: **Git**
   - Advanced: Work Item Process: **Scrum**
1. Select **Create**.

   ![Screenshot of the create new project panel.](media/create-project.png)

### Import eShopOnWeb git repository (if needed)

1. Open the previously created **eShopOnWeb** project.
1. Select the **Repos > Files**, **Import a Repository** and then select **Import**.
1. On the **Import a Git Repository** window, paste the following URL `https://github.com/MicrosoftLearning/eShopOnWeb.git` and select **Import**:

   ![Screenshot of the import repository panel.](media/import-repo.png)

1. The repository is organized the following way:

   - **.ado** folder contains Azure DevOps YAML pipelines.
   - **.devcontainer** folder container setup to develop using containers (either locally in VS Code or GitHub Codespaces).
   - **.azure** folder contains Bicep & ARM infrastructure as code templates.
   - **.github** folder container YAML GitHub workflow definitions.
   - **src** folder contains the .NET 8 website used on the lab scenarios.

1. Leave the web browser window open.
1. Go to **Repos > Branches**.
1. Hover on the **main** branch then select the ellipsis on the right of the column.
1. Select **Set as default branch**.

### Download brand image for later use

1. In the **Files** pane, expand the **src** folder and browse to **Web > wwwroot > images** subfolder
1. In the **Images** subfolder, locate the **brand.png** entry
1. Hover over its right end to reveal the vertical ellipsis (three dots) menu
1. Select **Download** to download the **brand.png** file to your local computer

> **Note**: You will use this image in the next exercise.

### Create a Documents folder

1. From within **Repos**, select **Files**
1. Notice the **eShopOnWeb** Repo title on top of the folder structure
1. **Select the ellipsis (3 dots)**, Choose **New > Folder**
1. Provide **`Documents`** as title for the New Folder name
1. As a repo doesn't allow empty folders, provide **`README.md`** as New File name
1. Select **Create** to confirm the creation
1. The README.md file will open in view mode
1. Select the **Commit** button to save the changes
1. In the Commit window, confirm by pressing **Commit**

## Publish code as a wiki

You can publish content from a Git repository as a wiki. This is useful for maintaining documentation alongside your code.

### Publish a branch as wiki

1. In the Azure DevOps vertical menu on the left side, select **Overview**
1. In the **Overview** section, select **Wiki**
1. Select **Publish code as wiki**
1. On the **Publish code as wiki** pane, specify the following settings and select **Publish**:

   | Setting    | Value                        |
   | ---------- | ---------------------------- |
   | Repository | **eShopOnWeb**               |
   | Branch     | **main**                     |
   | Folder     | **/Documents**               |
   | Wiki name  | **`eShopOnWeb (Documents)`** |

This will automatically open the Wiki section with the editor.

> **Note**: If the editor doesn't open automatically, select **+ New page** at the bottom of the file explorer.

### Create wiki content

1. In the Wiki Page **Title** field, enter: `Welcome to our Online Retail Store!`

1. In the body of the Wiki Page, paste the following content:

   ```markdown
   ## Welcome to Our Online Retail Store!

   At our online retail store, we offer a **wide range of products** to meet the **needs of our customers**. Our selection includes everything from _clothing and accessories to electronics, home decor, and more_.

   We pride ourselves on providing a seamless shopping experience for our customers. Our website offers the following benefits:

   1. user-friendly,
   1. and easy to navigate,
   1. allowing you to find what you're looking for,
   1. quickly and easily.

   We also offer a range of **_payment and shipping options_** to make your shopping experience as convenient as possible.

   ### About the team

   Our team is dedicated to providing exceptional customer service. If you have any questions or concerns, our knowledgeable and friendly support team is always available to assist you. We also offer a hassle-free return policy, so if you're not completely satisfied with your purchase, you can easily return it for a refund or exchange.

   ### Physical Stores

   | Location    | Area                  | Hours           |
   | ----------- | --------------------- | --------------- |
   | New Orleans | Home and DIY          | 07.30am-09.30pm |
   | Seattle     | Gardening             | 10.00am-08.30pm |
   | New York    | Furniture Specialists | 10.00am-09.00pm |

   ## Our Store Qualities

   - We're committed to providing high-quality products
   - Our products are offered at affordable prices
   - We work with reputable suppliers and manufacturers
   - We ensure that our products meet our strict standards for quality and durability.
   - Plus, we regularly offer sales and discounts to help you save even more.

   # Summary

   Thank you for choosing our online retail store for your shopping needs. We look forward to serving you!
   ```

1. This sample text demonstrates several common Markdown syntax features:

   - **Titles and subtitles** (## and ###)
   - **Bold text** (\*\*)
   - **Italic text** (\*)
   - **Numbered lists** (1.)
   - **Bullet lists** (-)
   - **Tables** with headers and data

1. Once finished, press the **Save** button in the upper right corner

1. **Refresh** your browser, or select any other DevOps portal option and return to the Wiki section

1. Notice you are now presented with the **eShopOnWeb (Documents)** Wiki, with **Welcome to our Online Retail Store** as the **HomePage**

### Manage published wiki content

1. In the vertical menu on the left side, select **Repos**
1. Ensure the dropdown menu displays the **eShopOnWeb** repo and **main** branch
1. In the repo folder hierarchy, select the **Documents** folder
1. Select the **Welcome-to-our-Online-Retail-Store!.md** file
1. Notice how the Markdown format is visible as raw text, allowing you to edit the file content from here as well

> **Note**: Since the Wiki source files are handled as source code, all traditional source control practices (Clone, Pull Requests, Approvals, etc.) can be applied to Wiki pages.

## Create and manage a project wiki

You can create and manage wikis independently of existing repositories. This provides flexibility for documentation that doesn't need to be version-controlled with your code.

### Create a project wiki with Mermaid diagram

1. In the Azure DevOps portal, navigate to the **Wiki** pane of the **eShopOnWeb** project
1. With the **eShopOnWeb (Documents)** wiki content selected, select the dropdown list header at the top
1. In the dropdown list, select **Create new project wiki**
1. In the **Page title** text box, type: `Project Design`
1. Place the cursor in the body of the page
1. Select the left-most icon in the toolbar (header setting) and select **Header 1**
1. This adds the hash character (**#**) at the beginning of the line
1. After the **#** character, type: `Authentication and Authorization` and press **Enter**
1. Select the header setting icon again and select **Header 2**
1. After the **##** characters, type: `Azure DevOps OAuth 2.0 Authorization Flow` and press **Enter**

### Add a Mermaid diagram

Mermaid is a diagramming and charting tool that renders Markdown-inspired text definitions to create diagrams dynamically.

1. **Copy and paste** the following code to insert a Mermaid diagram:

   ```text
   ::: mermaid
   sequenceDiagram
    participant U as User
    participant A as Your app
    participant D as Azure DevOps
    U->>A: Use your app
    A->>D: Request authorization for user
    D-->>U: Request authorization
    U->>D: Grant authorization
    D-->>A: Send authorization code
    A->>D: Get access token
    D-->>A: Send access token
    A->>D: Call REST API with access token
    D-->>A: Respond to REST API
    A-->>U: Relay REST API response
   :::
   ```

> **Note**: For details about Mermaid syntax, refer to [About Mermaid](https://mermaid-js.github.io/mermaid/#/)

1. In the preview pane, select **Load diagram** and review the outcome
1. The output should resemble a flowchart that illustrates [OAuth 2.0 authorization flow](https://docs.microsoft.com/azure/devops/integrate/get-started/authentication/oauth)

### Save with revision message

1. In the upper right corner of the editor pane, select the down-facing caret next to the **Save** button
1. In the dropdown menu, select **Save with revision message**
1. In the **Save page** dialog box, type: `Authentication and authorization section with the OAuth 2.0 Mermaid diagram`
1. Select **Save**

### Add an image section

1. Place the cursor at the end of the Mermaid element and press **Enter** to add a new line
1. Select the header setting icon and select **Header 2**
1. After the **##** characters, type: `User Interface` and press **Enter**
1. In the toolbar, select the paper clip icon representing **Insert a file**
1. In the **Open** dialog box, navigate to where you downloaded the **brand.png** file
1. Select the **brand.png** file and select **Open**
1. Review the preview pane and verify that the image displays properly
1. Select the down-facing caret next to **Save** and select **Save with revision message**
1. In the **Save page** dialog box, type: `User Interface section with the eShopOnWeb image`
1. Select **Save**
1. In the upper right corner, select **Close**

## Manage a project wiki

You'll now learn how to manage wiki content, including reverting changes and organizing pages.

### Revert changes using revision history

1. With the **Project Design** wiki selected, in the upper right corner, select the vertical ellipsis symbol
1. In the dropdown menu, select **View revisions**
1. On the **Revisions** pane, select the entry representing the most recent change
1. On the resulting pane, review the comparison between the previous and current version
1. Select **Revert**
1. When prompted for confirmation, select **Revert** again
1. Then select **Browse Page**
1. Back on the **Project Design** pane, verify that the change was successfully reverted

### Add and organize wiki pages

1. On the **Project Design** pane, at the bottom left corner, select **+ New page**
1. In the **Page title** text box, type: `Project Design Overview`
1. Select **Save**, then select **Close**
1. Back in the pane listing the pages within the **Project Design** project wiki, locate the **Project Design Overview** entry
1. Select it with the mouse pointer and drag and drop it above the **Project Design** page entry
1. Verify that the **Project Design Overview** entry is listed as the top level page with the home icon designating it as the wiki home page

## Best practices for wiki management

- **Use clear, descriptive titles** for pages and sections
- **Organize content hierarchically** with proper heading levels
- **Link between pages** using wiki syntax `[[Page Name]]`
- **Include images and diagrams** to enhance understanding
- **Use tables** for structured data presentation
- **Maintain consistency** in formatting and style
- **Review and update content regularly** to keep it current
- **Use revision messages** to track changes meaningfully

## Summary

In this lab, you learned how to:

- **Create and publish code as a wiki** from a Git repository
- **Manage markdown content** with rich formatting
- **Create Mermaid diagrams** for visual documentation
- **Add and organize images** in wiki pages
- **Manage project wikis** independently of code repositories
- **Use revision history** to track and revert changes
- **Organize wiki pages** with hierarchical structure

Azure DevOps wikis provide a powerful platform for team knowledge sharing, combining the flexibility of markdown with the structure of organized documentation. They integrate seamlessly with your development workflow while providing the collaboration features needed for effective team communication.
