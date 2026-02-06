---
lab:
  title: 'AI-assisted work item management in Azure Boards'
  description: 'This lab provides a comprehensive experience of Azure Boards and GitHub Copilot integration. You'll work with realistic work items from an e-commerce platform project (EShopOnWeb), delegate tasks to Copilot's coding agent, use Copilot Chat for planning and analysis, and experience the full feedback loop from work item creation to merged code'
  level: 300
  duration: 45 minutes
---

# AI-assisted work item management in Azure Boards

This lab provides a comprehensive experience of Azure Boards and GitHub Copilot integration. You'll work with realistic work items from an e-commerce platform project (EShopOnWeb), delegate tasks to Copilot's coding agent, use Copilot Chat for planning and analysis, and experience the full feedback loop from work item creation to merged code

By the end of this lab, you will be able to:

- Navigate and organize Azure Boards work items for AI-assisted development using GitHub Copilot
- Use GitHub Copilot Chat to analyze and break down work items
- Connect Azure Boards to a GitHub repository using GitHub App authentication
- Delegate multiple work items to GitHub Copilot's coding agent with refined prompts
- Iterate on AI-generated pull requests using Copilot-assisted code review

This lab takes approximately **45** minutes to complete.

## Before you start

This lab requires access to the following resources:

- Azure DevOps organization access, with permission to manage Projects and work items
- GitHub access, with permission to manage a repository
- GitHub Copilot subscription (**any [paid subscription](https://docs.github.com/en/copilot/get-started/plans#ready-to-choose-a-plan) will work, FREE won't work**)

## Pre-Lab Setup: GitHub Account & Repository

> **Note**: Complete these steps before starting the actual exercise. If you are running this in a prehosted lab environment, some or all of these steps might have been completed for you already. Check with the trainer or lab hosting partner for accurate information.

### Step 1: Validate or Create a GitHub Account

1. Navigate to [github.com](https://github.com)
2. If you don't have an account, select **Sign up** and complete registration
3. If you have a GitHub account, **sign in** and verify you can access your profile
4. **Fork** the **[AI-assisted-Boards](https://github.com/petender/AI-Assisted-Boards)** lab repo which contains the necessary files for this lab into your GitHub account.

### Step 2: Enable or Validate GitHub Copilot Subscription

1. Navigate to [github.com/copilot](https://github.com/copilot)
1. Open **User Navigation Menu / Copilot Settings**
1. If you don't have Copilot enabled:
   - Select **Enable GitHub Copilot**
   - (if needed, choose your subscription (Pro, Pro+, Business, or Enterprise))
   - Complete the subscription process (**Note**: This lab does not work with the Free Copilot subscription)
1. Verify **Copilot coding agent** is Enabled

### Step 3: Set up an Azure DevOps Organization

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

### Step 4: Create an Azure DevOps Project

If you don't already have an Azure DevOps Project, follow these steps:

1. Sign in to Azure DevOps
2. Select **New Project**
3. Name the project **AI-Assisted-Boards**
4. Set visibility to **Private**
5. Choose **Agile** for work item process (Advanced)
6. Select **Create**

### Step 5: Import Sample Work Items

1. **Clone** the forked AI-Assisted-Boards repo from the pre-lab setup step 1 to your local machine. 
1. Then execute the **Import-EShopWorkItems.ps1** PowerShell script, to populate Azure Boards with realistic work items (Epics, Features, User Stories, Bugs). 

> **Note**: The script will prompt for your Azure DevOps credentials, as well as the organization and project to use for the import. It relies on the [Azure CLI extension for Azure DevOps](https://learn.microsoft.com/cli/azure/devops?view=azure-cli-latest), which will get installed if not already set up on your machine.

```powershell
cd c:\AI-Assisted-Boards
.\Import-EShopWorkItems.ps1

```
> **Note**: This scripts uses [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell?view=powershell-7.5). Run the PowerShell install for your system if the script should error when launched.

## Step 6: Verify Azure Boards work items after import
1. Navigate to **Boards → Backlogs**
2. Expand the hierarchy to see: **Epic → Feature → User Story → Task**
3. Navigate to **Boards → Sprints** and confirm Sprints 1-4 are visible
4. Open the **Sprint 1** board to see work items assigned to the current sprint

With all the above steps completed, you are ready to continue with the exercise.

## Task 1: Connect Azure Boards to GitHub

With GitHub Copilot coding agent, GitHub Copilot can work autonomously in the background to complete tasks against GitHub repositories, such as fix bugs, create and interact with PRs, update documentation, write code and much more. To allow Azure DevOps to leverage the power of GitHub Copilot, you need to set up a GitHub connection. 

1. From the GitHub portal, navigate to the [GitHub Marketplace - Azure Boards app](https://github.com/marketplace/azure-boards)
1. Select **Add**
1. Select **Install it for free**
1. Complete the fields with your personal or organization address details
1. Select **Complete Order and begin installation**
1. In the **Install and Authorize Boards** step, choose **Only Select Repositories**
1. Choose the **Forked AI-Assisted-Boards** repository
1. Select **Install and Authorize**
1. **Authenticate** using the GitHub Account credentials
1. When redirected to **Azure DevOps**, **authenticate** with your Azure DevOps credentials
1. In the **Setup your Azure Boards project**, select your DevOps Organization and Project for this lab
1. Select **Continue**
1. From the Azure DevOps project, select **Project Settings** / **GitHub Connections** and confirm the GitHub connection is established

## Task 2: Copilot Chat Analysis of Boards work items

Before delegating work to Copilot's coding agent, use **GitHub Copilot Chat** to analyze your work items and prepare them for AI-assisted development. In the different prompts, we reference existing work items in Azure Boards, which are now accessible by GitHub Copilot.

1. From **the browser**, open `https://github.com/copilot`
1. In the **Copilot Chat** window, select **all repositories** and select **AI-Assisted-Boards**
1. **Copy** the following prompt into the chat window, allowing Copilot to **identify Copilot-ready work items** 

```
I have the following work items in my Sprint 1 backlog:
- Bug: "Search results showing out-of-stock items" - needs to filter/badge out-of-stock products
- Bug: "Product images not loading on slow connections" - lazy loading and placeholders needed
- Task: "Create product filter UI components" - React/Razor filter components
- Task: "Set up Elasticsearch for product search" - infrastructure setup

Which of these are good candidates for GitHub Copilot coding agent delegation? 
Consider: code complexity, clarity of requirements, and need for external resources.
```

**Expected Copilot Response**: Copilot should recommend the bugs and UI task as good candidates (clear, code-focused) while noting the Elasticsearch task may require infrastructure access and manual steps. Note that the response reflects several of the Azure DevOps work items, thanks to the Azure Boards integration.

1. Next, use Copilot Chat to **help write detailed acceptance criteria** for a work item, using the following prompt:

```
I have a bug titled "Search results showing out-of-stock items" with this description:
"Search results include products that are out of stock without indication"

Help me expand this into detailed acceptance criteria suitable for an AI coding agent. 
Include:
- Clear requirements with checkboxes
- Technical hints (file names, classes if you can infer from an ASP.NET Core e-commerce app)
- Testing requirements
```

**Analyze the output**: Validate Copilot's suggested acceptance criteria and its level of detail, including the requested checkboxes and requirements.

1. Now, you will use Copilot Chat to **decompose a larger user story** into smaller, delegatable tasks:

```
I have a user story: "Add social login options (Google, Facebook, Apple)"

For an ASP.NET Core application using ASP.NET Identity, break this down into:
1. Individual tasks that could each be delegated to Copilot coding agent
2. Suggested order of implementation
3. Any tasks that should NOT be delegated to AI (and why)
```

**Review the Breakdown**: Note how Copilot identifies configuration tasks (credentials, secrets) that require human involvement.

## Task 3: Bug Fix Delegation

Apart from analyzing Azure Boards work items, you can also use work items descriptions, to delegate actual work tasks to GitHub Copilot. 

### Scenario Context

Your team has identified a critical bug in Sprint 1: **"Search results showing out-of-stock items"**. This bug causes customer confusion as products that cannot be purchased appear in search results without any indication of their availability status.

### Subtask 1: Locate and Enhance the Bug Work Item

1. From your Azure DevOps project, navigate to **Boards / Work Items**
1. Open the bug: **"Search results showing out-of-stock items"**
1. Update the **Discussion** field using the following acceptance criteria (similar to the response from running a previous prompt):

```markdown
## Problem
Search results include products that are out of stock without any visual indication, causing customers to click through only to find the item unavailable.

## Acceptance Criteria
- [ ] Out-of-stock products should display a visual "Out of Stock" badge
- [ ] Out-of-stock items should appear at the bottom of search results
- [ ] Add a filter option to hide out-of-stock items
- [ ] Unit tests should cover the new filtering logic

## Technical Context
- Search is handled by the CatalogController
- Product availability is stored in the Product.AvailableStock property
- Frontend uses Razor views for product cards

## Testing
- Unit tests for sorting logic
- UI tests for badge visibility
- Integration test for filter functionality
```

1. Select **Save**

### Subtask 2: Delegate to GitHub Copilot

1. Select the **GitHub Copilot** icon on the work item
1. Choose **Create pull request with GitHub Copilot**
1. Select the connected **EShopOnWeb** GitHub repository
1. Select the base branch: `main`
1. Select **Create**

### Subtask 3: Observe and Iterate

While Copilot works, monitor its progress:

**In GitHub**: 

1. From the **AI-Assisted-Boards** repo, navigate to the **Agents** Tab and see the agent process **[WIP]Add visual indication for out-of-stock items in search results** 
1. Watch the details of how Copilot is relying on several built-in agents and MCP Servers to perform the analysis and suggest code examples
> **Note**: to keep the focus on the Boards integration, we did not provide an actual sample app with code to perform code changes as part of this lab.
1. From the **AI-Assisted-Boards** repo, navigate to the **Pull Requests** Tab and open the related Pull Request **[WIP]Add visual indication for out-of-stock items in search results**
1. Notice the **Checklist**, as well as the **Work Item #AB** deeplink, referring to the Azure Boards work item.

** In Azure Boards**

1. From the work item, notice how the **discussion** thread has a *comment** from **GitHub Copilot Coding Agent**, with a brief description about the action, as well as a deeplink to the GitHub Pull Request/PR.

**If Copilot asks a clarifying question** (via PR comment), respond with guidance:

```
For the badge styling, please use the existing Bootstrap class `badge bg-secondary` 
for consistency with other badges in the application.
```

### Subtask 4: Steer Copilot While It Works

While Copilot is actively working on the PR, you can guide its implementation in real-time:

1. **Open the draft PR in GitHub** — you'll see a progress view showing "Copilot is working"
1. **Find the steering text box** — look for the input field labeled "Steer active session while Copilot is working"
1. **Provide real-time guidance** — type instructions to refine the implementation:

**Example steering prompts (choose one):**

```
For the badge styling, use the existing Bootstrap class `badge bg-secondary` for consistency.
```

```
Make sure out-of-stock items appear at the bottom of results, not filtered out completely.
```

```
Add XML documentation comments to the new public methods.
```

Copilot will read your guidance and adjust its approach, pushing additional commits to address your feedback.

> **Tip**: Steering is most effective for clarifications and constraints. For major direction changes, consider stopping the session and updating the work item description instead.

## Task 4: Multi-Work-Item Coordination (15 minutes)

This exercise demonstrates how to coordinate multiple related work items using Copilot. Imagine you have two related bugs in the list of work items, that could be worked on simultaneously:

1. **"Mobile menu overlapping content on iOS Safari"** (CSS/layout issue)
2. **"Social login failing with popup blocker"** (JavaScript/UX issue)

These bugs are independent and can be delegated in parallel.

### Subtask 1: Prepare Both Work Items

**Bug 1 - Mobile Menu:**

1. Add the below guidelines to the **discussions** field of the work item:

```markdown
## Problem
On iOS Safari, the mobile hamburger menu expands over page content instead of pushing content down or using an overlay.

## Acceptance Criteria
- [ ] Menu should use a full-screen overlay approach
- [ ] Clicking outside the menu closes it
- [ ] Menu animation should be smooth (CSS transitions)
- [ ] Works correctly on iOS Safari 15+ and Chrome Mobile

## Technical Context
- Menu is in Views/Shared/_Layout.cshtml
- CSS is in wwwroot/css/site.css
- Likely need z-index and position fixes

## Testing
- Manual testing on iOS Safari required (document steps)
- Visual regression test if available
```

**Bug 2 - Social Logging Failing:**

1. Add the below guidelines to the **discussions** field of the work item:

```markdown
## Problem
Social login buttons trigger popup-based OAuth flows that are blocked by default browser settings.

## Acceptance Criteria
- [ ] Implement redirect-based OAuth flow instead of popup
- [ ] Preserve return URL after OAuth completion
- [ ] Update both Google and Facebook login flows
- [ ] Add user-friendly error message if OAuth fails

## Technical Context
- Current implementation uses popup window
- Need to switch to server-side redirect flow
- ASP.NET Core Identity supports both approaches

## Testing
- Test with popup blocker enabled
- Verify deep link return works correctly
```

### Subtask 2: Delegate Both Work Items

1. Open Bug 1, delegate to Copilot → creates PR #1
2. Open Bug 2, delegate to Copilot → creates PR #2
3. Return to Azure Boards to see both items with Copilot status indicators and Pull Request links added to the discussion thread

### Subtask 3: Use Copilot Chat for Cross-PR Analysis

1. When both PRs are created, use Copilot Chat to identify potential conflicts, by entering the following prompt in the Copilot chat window:

```
I have two pull requests being merged to main:
- PR #2: Mobile menu CSS fixes (z-index, overlay)
- PR #3: OAuth flow changes (redirect instead of popup)

Both might touch _Layout.cshtml. What should I check before merging both?
```
2. Read through the response and notice the level of detail. All the way at the end of the response, Copilot should **suggest** to pull the diffs for PR#2 and PR#3 and identify the code overlap in _Layout.cshtml. 

> **Note**: Since we don't have an actual codebase, it won't be able to validate this, but should give you an idea about its code review powers. 


## Task 5: Merge Copilot-Assisted Code Review

In this last exercise, you act as a senior developer, validating the suggestions and work of Copilot coding agent. Just like any existing PR flow today.

1. Navigate to the pull request for **"Search results showing out-of-stock items"**
2. The last step in the Pull Request shows **Review Requested**
3. Notice the itemline that says **This pull request is still a work in progress**, and Click **Ready for review**
4. This process is called _human-in-the-loop_, where Agentic AI is collaborating with developers
5. Select **Merge Pull Request**
6. Select **Complete Merge**
7. The Pull Request's status changes to **Merged** and gets closed
8. From the **Azure DevOps work item**, notice how the **request for review** is also added to the work item discussion thread.

## Cleanup

Now that you've finished the exercise, you should delete the resources you've created to avoid confusion.

1. **Delete** the **AI-Assisted-Boards** repository from your GitHub account, by navigating to the **repo settings → Danger Zone → Delete this repository**
1. **Delete** the **Azure DevOps Project**, by navigating to **Project settings → Delete project** and confirm by select **Delete**

## Summary

In this exercise, you learned about AI-Assisted work item management in Azure Boards, using GitHub Copilot.  
