---
lab:
    topic: Agentic
    title: 'Managing Azure DevOps Projects through Azure DevOps MCP Server'
    description: 'This exercise showcases different scenarios on how to use Azure DevOps MCP Server for day-to-day operations in Azure DevOps'
    level: 300
    Duration: 30 minutes
---

# Managing Azure DevOps Projects through Azure DevOps MCP Server

This exercise walks learners through different common DevOps engineering tasks, demonstrating Azure DevOps capabilities via the new MCP Server integration.

This exercise should take approximately **30** minutes to complete.

## Before you start

Before you can start this exercise, ensure you have:

- Access to an [Azure DevOps](aex.dev.azure.com) Organization and Project with Contributor permissions
- [GitHub Copilot](https://github.com/copilot) subscription (any subscription will work, Free, Pro, Business, Enterprise)
- [Node.js](https://nodejs.org/)) framework version 18 or later
- [Visual Studio Code](https://code.visualstudio.com/download) installed

> **Note**: If you don't have sample data in your Azure DevOps Organization and project, you can run the **[Setup_ADODemoEnvironment.ps1](https://raw.githubusercontent.com/MicrosoftLearning/mslearn-devops/refs/heads/main/setup-adodemoenvironment.ps1) PowerShell script** to create a new project with dummy data such as work items, pull requests, pipelines and alike. This would allow you to verify the ADO MCP Server connection and features against actual data.
---

## Setting Up the Azure DevOps MCP Server in VSCode

**Objective:** Install and configure the Azure DevOps MCP Server to enable natural language interactions with Azure DevOps through GitHub Copilot.

> **Note**: The [ADO MCP GitHub repo](https://github.com/microsoft/azure-devops-mcp) describes other ways to get the ADO MCP Server installed, if you can't use the above approach. The described approach below is the most transparent across different platforms, assuming you have the correct permissions in place and no VS Code extension restrictions.

1. Navigate to the [Azure DevOps MCP Server repository](https://github.com/microsoft/azure-devops-mcp) on Github
1. In the [README.md](https://github.com/microsoft/azure-devops-mcp/blob/main/README.md), **select** the **VSCode - Install Azure DevOps MCP Server** ribbon
1. When you get prompted to **This site is trying to open Visual Studio Code**, select **Open**
1. The **MCP Server:ado** tab opens
1. Select **install**
1. From the **GitHub Copilot Chat** window, select **Configure Tools...**
1. In the list of **tools**, confirm you have **ado** in the list
1. Select **ado** to open a list of **tools** available within the **ado MCP Server**; several of these will be used in later exercises.
1. **Open GitHub Copilot Chat**
1. **Test the connection** using a simple prompt:

   ```bash
   List all projects in my Azure DevOps organization
   ```

**Expected Result:**
**GitHub Copilot** should recognize the keyword *azure devops organization* to use the **ado MCP Server** and offer to **run *core_list_projects***, which is described as *Retrieve a list of project in your Azure DevOps organization*
 
1. Select **Allow**
1. You will get **redirected** to a new **browser tab** to **authenticate**; use your **Azure DevOps Organization** credentials.
1. Once successfully authenticated, you can **close the browser tab**  
1. The MCP server should respond with a list of projects

> **Note**: If you see project names, the connection is working successfully!

## Managing Work Items

**Objective:** Learn how to quickly explore and understand an Azure DevOps organization and project context using natural language queries.

### Understand the Current Sprint

1. Continue the conversation
2. Ask: *"What is the current sprint for the `your project name` project?"*
3. **Expected Result:** Sprint name, start/end dates, and sprint goals

> **Note**: for each prompt, notice how the natural language question gets transformed into a **JSON formatted** Input string

**Follow-up queries to try:**

- *"How many days are left in this sprint?"*
- *"What was completed in the previous sprint?"*

> **Note**: notice how GitHub Copilot is relying on different tools `work_list_iterations`, `search_workitem`, `wit_get_work_items_for_iteration` and potentially others, to find the relevant information.

### Create a Bug

With a clear view on the Azure DevOps Project, it is also possible to **add information** to it. 

Let's create a new bug work item, by using the following prompts:

1. Run the following prompt from GitHub Copilot Chat:

```
Create a new bug in the <your devops project>  project
```

2. Provide details when prompted:

```
   - **Title:** "Login page crashes on mobile Safari"
   - **Description:** "Users on iOS Safari experience a crash when tapping the login button. Affects iOS 17+."
   - **Priority:** 2 (High)
   - **Severity:** 2 - High
```

3. **Inspect the input JSON:**, which should look like the following:

```json
{
  "project": "<your ADO Project>",
  "workItemType": "Bug",
  "fields": [
    {
      "name": "System.Title",
      "value": "Login page crashes on mobile Safari"
    },
    {
      "name": "System.Description",
      "value": "Users on iOS Safari experience a crash when tapping the login button. Affects iOS 17+."
    },
    {
      "name": "Microsoft.VSTS.Common.Priority",
      "value": "2"
    },
    {
      "name": "Microsoft.VSTS.Common.Severity",
      "value": "2 - High"
    }
  ]
}
```

4. Select the **down arrow** on the **Allow** button, to see more options. While not running **autonomously**, it is possible to circumvent the *continuous acknowledge step*, by selecting other options, e.g. 

- Allow in this session / this workspace
- Always Allow
- Allow Tools from Azure DevOps MCP Server in this session / workspace

5. Select **Allow in this session**

6. The outcome from this task, is that the **bug got created with a work item ID returned**, as well as a **deeplink** to the actual work item. 

7. Select the **deeplink** to get redirected to the work item in Azure DevOps

8. Next, let's try a [one-shot prompt](https://learn.microsoft.com/en-us/azure/ai-foundry/openai/concepts/prompt-engineering) creation, by **asking Github Copilot** to perform the following:

```
Create a bug titled 'Login page crashes on mobile Android' with high priority in the <your ado project> project. Assign it to myself, and add it to Iteration Sprint 2. Add this in the discussion: "we heard from users that the login page of the app on certain Android devices is crashing". We have a similar issue on Safari on iOS, see work item #<work item ID from the previous step>. Can you link them together? 
```

9. Since this request involves more steps with more requirements, GitHub Copilot transforms the prompt into a task list, similar to the following:

- Get Identity first (1/4) `core_get_identity_ids` tool
- Create Android bug (2/4) `wit_create_work_item` tool
- Add discussion comment (3/4) `wit_add_work_item_comment` tool
- Link to work item ID (4/4) `wit_work_items_link` tool

10. The new work item is getting created. Open it in Azure DevOps Boards, and **notice** how it **got linked** to the previous work item ID from the **Related Work** section of the work item. The reverse link also got established, from the previous work item ID to this new one.

> **Note**: The Related Work link is very powerful, and works across all work item types. For example, "Link bug #[bug ID] to User Story #[User Story ID] would work as well

### Update Work Items

Apart from creating new work items, it is also possible to **update** existing ones.

1. Ask: 

```
Move bug #[ID] to 'Active' state and assign it to <person>`
```

**Expected Result:** Work item updated with new state and assignee

2. Next, **perform batch updates** using a similar prompt as below (adapted to your work items):

```
update all bugs with the word "mobile" in the subject of the work item, with a tag "mobile"
```

**Expected Result:** GitHub Copilot informs you about the number of bugs found, including their work item IDs. Results are presented in a table.

## Code & Pull Request Operations

**Objective:** Perform complete code review workflows including listing, reviewing, commenting, and merging pull requests.

### List Open Pull Requests

Let's start with getting a list of currently Open Pull Requests.

1. Ask GitHub Copilot Chat the following:

```
Show me all open pull requests in the <name of your repo> within the chosen ADO Project
```

2. **Expected Result:** List of PRs with:
   - PR number and title
   - Author
   - Source / Target Branch
   - Review status

> **Note**: feel free to try other similar prompts:
- *Show PRs targeting the main branch*
- *List PRs waiting for my review*
- *Find PRs older than 7 days*

### Review PR Details

1. Ask:
```
show me the details of PR #[ID], highlighting what files got changed as well as the diff for these files
```

**Expected Result:** PR description, linked work items, and reviewers

2. You might get asked by GitHub Copilot to **Fetch web page**, showing a link to the actual Pull Request. This is interesting, since the MCP Server request gets now transformed into a ADO REST API request 

3. Select **Allow and Review**

> **Note**: Depending on your ADO Organization settings or permissions, this step might not be successful, informing you that "file diffs was blocked"

4. Even if **blocked**, GitHub Copilot should still provide a response regarding the PR with more details such as **commit IDs**, **files changed**

### Add Comments to Approve and Complete a PR

1. Continue the PR handling by **asking** Github Copilot Chat this next prompt:
```
add a comment to PR #[ID]
'PR reviewed and closing', 
ok to complete the merge operation
```

**Expected Result:** Vote recorded as "Approved", followed by a PR merged operation

2. From the Azure DevOps **Repos** / **Pull Requests**, navigate to **Completed** and open the completed Pull Request. Notice the comment 'PR reviewed and closing'

## Pipeline & Build Operations

In this last task, let's focus on interacting with Azure DevOps Pipelines. You'll explore how to monitor, trigger, and troubleshoot CI/CD pipelines through natural language commands.

### List Pipeline Definitions

1. Ask:
```
List all pipelines in the <your project> 
```

**Expected Result:** Pipeline names, folder paths, and last run status

### Trigger a Pipeline Run

1. Triggering a pipeline run is possible by **initiating** the following prompt:

```
Run the CI pipeline on the `feature/auth` branch (or main or any other branch name)
```

**Expected Result:** Build queued with a build number/ID

> **Note**: You can add more details to the prompt, which interacts with pipeline variables. For example, you could ask : "Run pipeline with ID [ID] and parameter environment=staging"

### Monitor Build Status

1. Verifying the status of a pipeline run is possible by **triggering the following ask**:
```
What's the status of build #[ID]?
```

**Expected Result:** Current state, duration, and stage progress

### Retrieve Build Logs

1. From here, it is also possible to **ask** for more specific information, related to the pipeline. Ask the following:

```
Get the logs for the failed 'Build' stage in build pipeline #[ID]
```

**Expected Result:** Relevant log output showing the success or failure reason, depending on the state of the pipeline

## Summary

In this exercise, you learned about Azure DevOps MCP Server, and how it can be used from within VS Code with Github Copilot, to interact with different aspects of the project, such as work items, Pull Requests or exchanging information related to pipelines. Know that there are many more operations possible, by checking the **ado tools** list in the Command Palette 

