# Share Team Knowledge using Azure Project Wiki

**Estimated time:** 45 minutes

You will learn how to create and configure wikis in Azure DevOps, including managing markdown content and creating Mermaid diagrams. Azure DevOps wikis provide a centralized place for teams to share knowledge, document processes, and maintain project information.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure DevOps organization:** Create one if you don't have one
- **eShopOnWeb project:** Use the sample project from previous labs or create a new one

## About Azure DevOps Wikis

Azure DevOps provides two types of wikis:

1. **Project wiki** - A wiki that exists separately from your repositories
2. **Code wiki** - A wiki created from content stored in a Git repository

Key features:
- **Markdown support** with rich formatting capabilities
- **Mermaid diagrams** for creating flowcharts and sequence diagrams
- **Image support** with drag-and-drop functionality
- **Version control** with revision history
- **Cross-reference links** to work items, code, and other wikis
- **Collaborative editing** with concurrent user support

## Set up the project and repository

First, ensure you have the eShopOnWeb project ready for this lab.

1. In your browser, open your Azure DevOps organization
2. Open the **eShopOnWeb** project (create one if you don't have it)
3. Navigate to **Repos > Files**
4. Ensure you're on the **main** branch
5. Review the content of the main branch

### Download brand image for later use

1. In the **Files** pane, expand the **src** folder and browse to **Web > wwwroot > images** subfolder
2. In the **Images** subfolder, locate the **brand.png** entry
3. Hover over its right end to reveal the vertical ellipsis (three dots) menu
4. Click **Download** to download the **brand.png** file to your local computer

> **Note**: You will use this image in the next exercise.

### Create a Documents folder

1. From within **Repos**, select **Files**
2. Notice the **eShopOnWeb** Repo title on top of the folder structure
3. **Select the ellipsis (3 dots)**, Choose **New > Folder**
4. Provide **`Documents`** as title for the New Folder name
5. As a repo doesn't allow empty folders, provide **`README.md`** as New File name
6. Click **Create** to confirm the creation
7. The README.md file will open in view mode
8. Click the **Commit** button to save the changes
9. In the Commit window, confirm by pressing **Commit**

## Publish code as a wiki

You can publish content from a Git repository as a wiki. This is useful for maintaining documentation alongside your code.

### Publish a branch as wiki

1. In the Azure DevOps vertical menu on the left side, click **Overview**
2. In the **Overview** section, select **Wiki**
3. Select **Publish code as wiki**
4. On the **Publish code as wiki** pane, specify the following settings and click **Publish**:

   | Setting | Value |
   | ------- | ----- |
   | Repository | **eShopOnWeb** |
   | Branch | **main** |
   | Folder | **/Documents** |
   | Wiki name | **`eShopOnWeb (Documents)`** |

This will automatically open the Wiki section with the editor.

### Create wiki content

1. In the Wiki Page **Title** field, enter: `Welcome to our Online Retail Store!`

2. In the body of the Wiki Page, paste the following content:

   ```markdown
   ## Welcome to Our Online Retail Store!
   
   At our online retail store, we offer a **wide range of products** to meet the **needs of our customers**. Our selection includes everything from *clothing and accessories to electronics, home decor, and more*.
   
   We pride ourselves on providing a seamless shopping experience for our customers. Our website offers the following benefits:
   1. user-friendly,
   1. and easy to navigate, 
   1. allowing you to find what you're looking for,
   1. quickly and easily. 
   
   We also offer a range of **_payment and shipping options_** to make your shopping experience as convenient as possible.
   
   ### About the team
   Our team is dedicated to providing exceptional customer service. If you have any questions or concerns, our knowledgeable and friendly support team is always available to assist you. We also offer a hassle-free return policy, so if you're not completely satisfied with your purchase, you can easily return it for a refund or exchange.
   
   ### Physical Stores
   |Location|Area|Hours|
   |--|--|--|
   | New Orleans | Home and DIY  |07.30am-09.30pm  |
   | Seattle | Gardening | 10.00am-08.30pm  |
   | New York | Furniture Specialists  | 10.00am-09.00pm |
   
   ## Our Store Qualities
   - We're committed to providing high-quality products
   - Our products are offered at affordable prices 
   - We work with reputable suppliers and manufacturers 
   - We ensure that our products meet our strict standards for quality and durability. 
   - Plus, we regularly offer sales and discounts to help you save even more.
   
   # Summary
   Thank you for choosing our online retail store for your shopping needs. We look forward to serving you!
   ```

3. This sample text demonstrates several common Markdown syntax features:
   - **Titles and subtitles** (## and ###)
   - **Bold text** (**)
   - **Italic text** (*)
   - **Numbered lists** (1.)
   - **Bullet lists** (-)
   - **Tables** with headers and data

4. Once finished, press the **Save** button in the upper right corner

5. **Refresh** your browser, or select any other DevOps portal option and return to the Wiki section

6. Notice you are now presented with the **eShopOnWeb (Documents)** Wiki, with **Welcome to our Online Retail Store** as the **HomePage**

### Manage published wiki content

1. In the vertical menu on the left side, click **Repos**
2. Ensure the dropdown menu displays the **eShopOnWeb** repo and **main** branch
3. In the repo folder hierarchy, select the **Documents** folder
4. Select the **Welcome-to-our-Online-Retail-Store!.md** file
5. Notice how the Markdown format is visible as raw text, allowing you to edit the file content from here as well

> **Note**: Since the Wiki source files are handled as source code, all traditional source control practices (Clone, Pull Requests, Approvals, etc.) can be applied to Wiki pages.

## Create and manage a project wiki

You can create and manage wikis independently of existing repositories. This provides flexibility for documentation that doesn't need to be version-controlled with your code.

### Create a project wiki with Mermaid diagram

1. In the Azure DevOps portal, navigate to the **Wiki** pane of the **eShopOnWeb** project
2. With the **eShopOnWeb (Documents)** wiki content selected, click the dropdown list header at the top
3. In the dropdown list, select **Create new project wiki**
4. In the **Page title** text box, type: `Project Design`
5. Place the cursor in the body of the page
6. Click the left-most icon in the toolbar (header setting) and select **Header 1**
7. This adds the hash character (**#**) at the beginning of the line
8. After the **#** character, type: `Authentication and Authorization` and press **Enter**
9. Click the header setting icon again and select **Header 2**
10. After the **##** characters, type: `Azure DevOps OAuth 2.0 Authorization Flow` and press **Enter**

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

2. In the preview pane, click **Load diagram** and review the outcome
3. The output should resemble a flowchart that illustrates [OAuth 2.0 authorization flow](https://docs.microsoft.com/azure/devops/integrate/get-started/authentication/oauth)

### Save with revision message

1. In the upper right corner of the editor pane, click the down-facing caret next to the **Save** button
2. In the dropdown menu, click **Save with revision message**
3. In the **Save page** dialog box, type: `Authentication and authorization section with the OAuth 2.0 Mermaid diagram`
4. Click **Save**

### Add an image section

1. Place the cursor at the end of the Mermaid element and press **Enter** to add a new line
2. Click the header setting icon and select **Header 2**
3. After the **##** characters, type: `User Interface` and press **Enter**
4. In the toolbar, click the paper clip icon representing **Insert a file**
5. In the **Open** dialog box, navigate to where you downloaded the **brand.png** file
6. Select the **brand.png** file and click **Open**
7. Review the preview pane and verify that the image displays properly
8. Click the down-facing caret next to **Save** and select **Save with revision message**
9. In the **Save page** dialog box, type: `User Interface section with the eShopOnWeb image`
10. Click **Save**
11. In the upper right corner, click **Close**

## Manage a project wiki

You'll now learn how to manage wiki content, including reverting changes and organizing pages.

### Revert changes using revision history

1. With the **Project Design** wiki selected, in the upper right corner, click the vertical ellipsis symbol
2. In the dropdown menu, click **View revisions**
3. On the **Revisions** pane, click the entry representing the most recent change
4. On the resulting pane, review the comparison between the previous and current version
5. Click **Revert**
6. When prompted for confirmation, click **Revert** again
7. Then click **Browse Page**
8. Back on the **Project Design** pane, verify that the change was successfully reverted

### Add and organize wiki pages

1. On the **Project Design** pane, at the bottom left corner, click **+ New page**
2. In the **Page title** text box, type: `Project Design Overview`
3. Click **Save**, then click **Close**
4. Back in the pane listing the pages within the **Project Design** project wiki, locate the **Project Design Overview** entry
5. Select it with the mouse pointer and drag and drop it above the **Project Design** page entry
6. Confirm the changes by pressing the **Move** button in the appearing window
7. Verify that the **Project Design Overview** entry is listed as the top level page with the home icon designating it as the wiki home page

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
