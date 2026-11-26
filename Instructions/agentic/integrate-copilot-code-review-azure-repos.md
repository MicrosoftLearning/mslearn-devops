---
lab:
  topic: Agentic
  title: "Extend Azure Repos contribution flow with Copilot code review"
  description: Practice Azure Repos source control with native Copilot PR review, source inspection, and a learner-controlled merge.
  level: 400
  duration: 45 minutes
  islab: true
  primarytopics:
    - Azure DevOps
    - Azure Repos
    - Source control
    - GitHub Copilot
    - Agentic DevOps
---

# Extend Azure Repos contribution flow with Copilot code review

## Exercise scenario

The traditional
[Version Control with Git in Azure Repos](../../basic/06-version-control-git-azure-repos.md)
lab imports eShopOnWeb, clones the repository, stages and commits changes,
works with branches, and introduces PR policies.

This exercise follows the same source-control flow, now with **native GitHub
Copilot code review on an Azure Repos PR**. You make changes locally in VS Code,
commit and push a feature branch, request Copilot review, and update the same
PR before completing it. This is a solo exercise: no second reviewer or
approving vote is required.

You clarify the filtering intent in eShopOnWeb's real catalog-filter source.
During the exercise, an intentionally incorrect first revision combines
brand/type filters with OR instead of AND. You compare Copilot feedback with
the source code and linked requirement, correct the revision, and request a
fresh review. The final change adds an explanatory source comment while
preserving the original filtering logic.

This exercise focuses on source control and code review. You won't install
an application SDK, run the application, or configure a pipeline. Building
and testing are covered later in the course. Source inspection and AI
feedback aren't proof of application correctness.

By the end of this exercise, you will be able to:

- Clone, inspect, stage, commit, and publish a focused feature branch.
- Configure native Copilot review without confusing it with editor assistance.
- Evaluate AI feedback against actual code and a linked requirement.
- Separate AI feedback from your source inspection and merge decision.
- Link work items, commits, and PRs throughout the contribution flow.

Allow approximately **45 minutes**, excluding administrator setup.

## Before you start

Arrange these prerequisites with your instructor or administrator:

| Requirement | Details |
|---|---|
| Azure DevOps Services organization | Use an organization approved for native Copilot code review and the supplied public source. This exercise doesn't target Azure DevOps Server. |
| Feature administration | A Project Collection Administrator enables organizational access; project/repository administrators manage the permitted project and repository settings. |
| Billing approval | An Azure subscription must be linked to the organization. Native Copilot review is billed through that subscription; confirm approval before requesting reviews. |
| Repository/project permissions | Create a private lab project, import a repository, create work items and PRs, and configure branch policies, or have an administrator perform the scoped setup tasks. |
| Workstation | A browser, [Git](https://git-scm.com/downloads), [VS Code](https://code.visualstudio.com/), and PowerShell. Use your approved Git Credential Manager/sign-in method. |
| Copilot Chat | An approved client is needed for the bounded explanation task. Chat access alone doesn't enable the Azure Repos service feature. |

Don't link a billing subscription, enable the feature for an
entire organization, or weaken security settings without approval. Ask for an
approved training environment if these prerequisites aren't available.

> **Important:** Use only the supplied non-sensitive sample. This exercise
> deliberately introduces an incorrect revision on an isolated feature branch.
> Don't deploy the application or merge the intentionally incorrect revision.
> AI reviews can incur
> charges, and repeated requests consume additional usage.

## Task 1: Import an isolated eShopOnWeb repository

1. In your Azure DevOps organization, create a **Private**, Git-based project named
   **eshop-copilot-review-lab**.
1. Open **Repos > Files** in its empty default repository and select **Import**.
   Don't initialize the destination with a README first.
1. Import this public Git repository without a GitHub token:

   ```text
   https://github.com/MicrosoftLearning/eShopOnWeb.git
   ```

1. Keep the imported files at the root and set `main` as the default branch
   under **Repos > Branches** if necessary.
1. Confirm **`src/ApplicationCore/Specifications/CatalogFilterSpecification.cs`**
   exists. This file combines the optional brand and type filters.
1. Inspect its `Query.Where` expression, which decides which catalog items
   are included. A selected brand and a selected type must **both** match.
   A null filter means that particular constraint isn't applied.
1. Ignore the imported deployment templates and workflows. Don't create
   pipelines for them or provision application resources.

**Expected result:** A private Azure Repos copy contains the existing
eShopOnWeb sample. Changes won't update its public GitHub source.

## Task 2: Enable native Copilot review at the approved scopes

Have the appropriate administrator perform each step:

1. Under **Organization settings > Repos > Repositories**, allow repositories
   to use **GitHub Copilot code review**. Don't select an organization-wide
   **Enable all** option just for this lab.
1. Under **Project settings > Repos > Repositories**, configure the project's
   Copilot review access/defaults as required by the organization.
1. Select the lab repository's **Settings** tab and enable Copilot code review
   for that repository, or confirm it is already enabled through inherited
   project settings.
1. Confirm billing approval with the administrator. Leave review effort at
   the approved default.

You aren't creating a GitHub PAT or adding a `COPILOT_GITHUB_TOKEN` secret.
This hosted Azure Repos feature has its own enablement and billing route.
Installing Copilot in VS Code doesn't enable hosted PR review.

**Expected result:** Copilot review is enabled for this repository. You will
verify that **GitHub Copilot** appears in a PR's reviewer list in Task 6.

## Task 3: Open the repository in VS Code and add review guidance

1. In **Repos > Files > Clone**, select **Clone in VS Code** and approve the
   prompts. Select a local parent folder for the cloned repository, then
   open the cloned repository when VS Code prompts you.
1. In that VS Code window, select **Terminal > New Terminal**. Use
   PowerShell at the cloned repository root and run these commands individually:

   ```powershell
   git remote -v
   git status
   git switch main
   git pull --ff-only
   ```
1. Confirm `origin` points to the **lab Azure Repos repository**. Authenticate
   through your organization's approved flow. Don't copy a token into source
   or change your machine-wide credential helper for this exercise.
1. If Git author identity isn't configured, set the approved name/email for
   **this repository**, using `git config user.name` and `git config user.email`.
   Don't reuse someone else's identity.
1. Confirm the working tree is clean:

   ```powershell
   git status --short
   ```

   No output means there are no uncommitted changes. If files are listed,
   inspect them before continuing. Don't discard or include unrelated work.

1. In VS Code, confirm the branch indicator shows **main**. In **Explorer**,
   create an **`.azuredevops`** folder at the repository root if needed, then
   create **`copilot-instructions.md`** inside it. Paste the following
   content and save:

   ```markdown
   # Catalog-filter review guidance

   Review the proposed change against its linked work item.
   Selected brand and type constraints must both apply.
   Null means that specific filter is omitted, not that every item matches.
   Inspect how the expression handles omitted, single, and combined filters.
   Prefer concrete findings that cite the changed expression and requirement.
   Don't invent application behavior or claim the application was executed.
   Feedback doesn't authorize a merge; the learner decides after source inspection.
   ```

   Azure Repos repository review instructions are read
   from the **target branch**. Put this setup guidance on `main` before the
   feature PR; adding it only to that PR doesn't apply it to that review.
   Instructions guide the model, not enforce branch policy.

1. In VS Code's integrated terminal, stage only the review guidance, inspect
   it, then commit and push it to the lab repository:

   ```powershell
   git add -- .azuredevops\copilot-instructions.md
   git --no-pager diff --cached
   git commit -m "Add catalog-filter Copilot review guidance"
   git push origin main
   ```

   This initial setup goes on `main` before branch policies are configured.
   If policies already exist, use a reviewed setup PR instead; don't bypass
   or disable them.
1. In your browser, open **Repos > Files** on **main** and confirm the
   instructions file is present.

**Expected result:** The cloned repository is open in VS Code, and the target
branch contains Copilot review guidance.

## Task 4: Configure a solo PR contribution route

1. Open **Repos > Branches > main > Branch policies**.
1. Leave **Minimum number of reviewers** disabled and don't add required
   reviewers. This solo lab doesn't require an approving vote.
1. Enable **Check for linked work items** and **Check for comment resolution**
   as **Required**. These policies keep the change linked to its requirement
   and require PR conversations to be resolved before completion.

1. Inspect **Bypass policies when pushing** and **Bypass policies when
   completing pull requests** with the administrator. The feature author
   must not use a bypass to complete this lab.
1. Leave **Automatically request Copilot code review** off for the first
   run so you can practice the explicit request. Don't change an inherited
   organization policy; if automatic requests are required, inspect that
   review instead of submitting a duplicate request.

The settings have different purposes:

| Control | Effect |
|---|---|
| Copilot request or automatic-review policy | Obtains AI feedback |
| Required linked-work policy | Connects the PR to its Azure Boards requirement |
| Required comment-resolution policy | Requires review conversations to be resolved |

Configure only the policies listed here; don't add other validation requirements
for this exercise. Custom instructions guide AI feedback, not enforce correctness.

**Expected result:** Changes use a linked PR with resolved conversations, but
no second reviewer is needed. You decide when to complete the PR after source
inspection. Follow your team's approval policies outside this isolated lab.

## Task 5: Create linked work and publish a reviewable first revision

1. In **Boards > Work Items**, create an item titled
   **Clarify catalog-filter intent**. Use an available type,
   such as Product Backlog Item, User Story, or Issue.
1. Include these acceptance criteria and note the work-item ID:

   ```text
   Preserve the existing brand/type filter behavior:
   - With neither filter selected, neither constraint excludes items.
   - Each selected filter is respected.
   - When both filters are selected, both must match.
   - A combination with no matching item returns no items.
   Add a concise source comment explaining that both selected filters must
   match and that a null filter omits only its own constraint.
   Keep the existing filtering expression and unrelated code unchanged
   in the final revision. Evaluate Copilot feedback before merge.
   ```

1. Return to VS Code's integrated PowerShell terminal. With a clean local
   working tree, create the feature branch:

   ```powershell
   git switch main
   git pull --ff-only origin main
   git switch -c feature-fix
   ```

   Confirm the VS Code branch indicator now shows **feature-fix**.
1. In VS Code Copilot Chat, select **Ask** mode. Supply the work-item criteria,
   and the existing Query.Where expression, then use:

   ```text
   Explain how the optional brand/type filters combine.
   Explain && as AND, || as OR, and what HasValue means in this expression.
   Suggest a concise comment explaining the existing filtering intent.
   Identify what I should inspect in the diff against the linked requirement.
   Propose a concise commit message and PR description.
   Don't edit files, commit, push, approve, or merge.
   Keep the scope to the existing catalog-filter specification.
   Don't run commands or claim the application was executed.
   State assumptions rather than inventing application behavior.
   ```

   Compare the response with the actual code. This is planning assistance,
   not the hosted PR review you'll request in Task 6.
1. In VS Code, open
   **`src/ApplicationCore/Specifications/CatalogFilterSpecification.cs`**.
   Add the following comment immediately above `Query.Where`.
   **For this review exercise only**, also change the `&&` joining the two
   optional-filter clauses to `||`. Leave each clause's internal `||` unchanged:

   ```csharp
   // Both selected filters must match; null omits only its own constraint.
   Query.Where(i => (!brandId.HasValue || i.CatalogBrandId == brandId) ||
       (!typeId.HasValue || i.CatalogTypeId == typeId));
   ```

   The comment describes the requirement, but the changed operator contradicts
   it. This deliberate mismatch gives you a focused change to discuss in review.
   Don't correct the operator until Task 7.
1. Inspect the changes:

   ```powershell
   git --no-pager diff
   git add -- src\ApplicationCore\Specifications\CatalogFilterSpecification.cs
   git diff --cached --check
   git --no-pager diff --cached
   git commit -m "Exercise catalog-filter code review"
   git push -u origin feature-fix
   ```

   Normally you correct known mistakes before publishing a change for review.
   This controlled exercise deliberately publishes an incorrect revision
   **only to an isolated feature branch**, so you can evaluate native review.
   Confirm the diff contains only the comment and joining-operator change.
   Don't proceed if unrelated files are staged.

1. In your browser, open **Repos > Pull requests > New pull request**.
   Confirm the source is **feature-fix** and the target is **main** in your
   lab repository. Enter **Clarify catalog-filter intent**
   as the title and adapt Copilot's proposal or paste this description:

   ```text
   ## Summary
   Document how the optional brand/type filters combine.

   ## Review exercise
   The first revision intentionally changes the joining operator from AND to OR.
   This contradicts the linked requirement and the new source comment.
   The predicate will be corrected in this PR after the initial Copilot review.
   Review evidence is limited to source inspection; the application wasn't run.
   Do not complete this PR yet.
   ```

1. Use the PR's **Work items** control to select the item created earlier.
   Verify its ID and title. This establishes the Azure Boards link; don't
   use a GitHub-style closing keyword as a substitute.
1. Select **Create** to publish an **Active** PR, not complete it.
   Creating the PR doesn't request Copilot review unless an administrator
   has configured automatic review. You'll request it in Task 6.
1. Inspect the PR's **Files** tab. Only the catalog-filter source file should
   have feature changes. Record the current source commit.

**Expected result:** One linked PR contains the explanatory comment and a
deliberately incorrect operator change, ready for Copilot review.

## Task 6: Request Copilot review and evaluate the feedback

1. On the active, mergeable PR, find **GitHub Copilot** under **Reviewers** and
   select **Request**. Use the approved default effort.
1. Wait for **Review completed**. Inspect the review entry, line comments,
   and any suggested changes.
1. Compare the feedback with the original expression, changed expression,
   and linked requirement. Use these examples to reason through the source;
   you aren't executing the application:

   | Selected filters and item | Required decision | Why the proposed OR is incorrect |
   |---|---|---|
   | Brand 1 and type 2; item has brand 1 and type 3 | Exclude the item | OR includes it because the brand matches, ignoring the selected type. |
   | Brand 1, type omitted; item has brand 2 | Exclude the item | The omitted-type clause is true, so OR includes the item despite the brand mismatch. |

   Ask Copilot Chat for an explanation if helpful:

   ```text
   Explain how the proposed OR condition differs from the original AND
   condition for null, single, and combined catalog filters.
   Trace the examples supplied here against both expressions.
   Identify the smallest correction that preserves the linked requirement.
   Don't edit files, commit, push, approve, or merge.
   ```

   In VS Code, use **Ask** mode and provide the approved public snippets and
   requirements. The editor/chat
   conversation isn't automatically the context of the hosted PR review.

1. Add a human-authored PR comment recording a Copilot observation, your
   **accept/revise/reject** decision, and evidence from the expression and
   linked requirement.
   If Copilot gives no actionable feedback, record that result honestly.
   Still explain the known mismatch using the source examples above.
1. Notice that Copilot supplies comments, not an approving vote. Its review
   isn't proof of application correctness. Native Azure Repos Copilot review
   doesn't approve or request changes and doesn't satisfy reviewer policies.

If Git reports a merge conflict, reconcile `main` into the feature branch
with your instructor and inspect the resulting diff before requesting review.
The PR must be active and mergeable. A merge conflict means Git can't
automatically combine the source changes; it isn't a Copilot review finding.

**Expected result:** You can explain the operator mistake and assess AI feedback
without treating it as merge permission or guaranteed defect detection.

## Task 7: Correct the change in VS Code and request a new review

1. Return to VS Code, confirm you're still on **feature-fix**, and restore
   the expression's joining operator to `&&`, preserving the explanatory
   source comment. The corrected snippet should be:

   ```csharp
   // Both selected filters must match; null omits only its own constraint.
   Query.Where(i => (!brandId.HasValue || i.CatalogBrandId == brandId) &&
       (!typeId.HasValue || i.CatalogTypeId == typeId));
   ```

1. Inspect the correction using `git --no-pager diff`. Trace the examples from
   Task 6 through the corrected expression and compare it with the linked
   requirement. Confirm you restored only the joining operator, not the
   internal OR operators that allow individual filters to be omitted.
1. Stage only the intended correction, inspect it, and publish:

   ```powershell
   git add -- src\ApplicationCore\Specifications\CatalogFilterSpecification.cs
   git diff --cached --check
   git --no-pager diff --cached
   git commit -m "Preserve combined catalog constraints"
   git push origin feature-fix
   ```

1. Refresh the **existing PR** in your browser. Verify it contains the new
   commit and iteration; don't create another PR. Add a short PR comment
   explaining how the restored AND operator respects both selected filters.
   State that your conclusion comes from source inspection, not execution.
1. In **Reviewers**, select **Request** next to **GitHub Copilot** again.
   Azure Repos Copilot review doesn't automatically re-review new
   commits. Replying to a comment also doesn't trigger a model response.
1. Evaluate any new comments and resolve conversations with evidence.
1. Confirm the local commit matches the PR's latest source commit using
   `git rev-parse HEAD`, and that `git status --short` shows no unintended
   changes. Compare the updated source with the work-item criteria.
1. In the PR's **Files** tab, compare the latest source with **main**, rather
   than only comparing the two feature-branch revisions. The final diff should
   add only the explanatory comment. The operator change disappears from this
   diff because you restored the original expression. The commits and review
   conversations still record how the proposed change was corrected.

**Expected result:** The final PR diff adds an explanatory source comment and
leaves the original filtering expression unchanged. You have evaluated a new
Copilot review and documented your own reasoning before completion.

## Task 8: Complete integration and preserve evidence

1. Record the work-item ID, PR URL, latest source commit, Copilot feedback,
   and your source-inspection decision in the PR or linked work item.
1. Confirm required policies are satisfied without a bypass, then complete
   the PR using an allowed merge method.
1. Use **Complete associated work items** only when the acceptance criteria
   are satisfied. Verify the actual work-item state after completion.
1. Record the integrated `main` commit; a squash/rebase merge can differ from
   the feature-branch commit.
1. Update the local checkout:

   ```powershell
   git switch main
   git pull --ff-only
   git fetch --prune
   git status
   ```

1. Delete the completed remote feature branch only after confirming no
   unmerged work remains. Don't force-delete a local branch just because Git
   doesn't recognize a squash merge.

Explain the task boundaries:

| Task | Assistance or control |
|---|---|
| Explain a diff and propose a correction | Copilot Chat assists; you inspect the proposal |
| Provide first-pass PR feedback | Native Copilot review assists; you validate its evidence |
| Explain the demonstrated operator mistake | You compare the expression with the linked requirement and review examples |
| Enforce the contribution route | Azure Repos permissions and policies |
| Accept the revised change | Your inspection of the final diff and authorized PR completion |

## Troubleshooting

| Symptom | Next action |
|---|---|
| GitHub Copilot doesn't appear in Reviewers | Confirm organization/project/repository access, inherited settings, billing, and current feature availability with the administrator. Editor access isn't service enablement. |
| Native review can't start or remains queued | Confirm feature enablement and billing with the administrator, then consult the current service requirements and limits. |
| Review is unavailable for the PR | Confirm it is Active, has no merge conflicts, and meets the documented size/change limits. |
| Review doesn't repeat after a push | Select **Request** again for the new iteration. Duplicate requests for the same completed PR version may be limited. |
| Copilot posts no actionable comments | Record the result and explain the operator mismatch using the source and linked requirement. No comments isn't proof of correctness. |
| Final PR diff no longer shows the operator change | This is expected after restoring the original expression. Confirm only the explanatory comment remains added. |
| Completion is blocked by a required approval | This solo lab requires no approvals. Check the lab branch's reviewer policies with its administrator. If an inherited policy requires approval, use an approved training repository rather than bypassing it. |

## Clean up

1. Retain the PR, work-item, review comments, and source-inspection reasoning
   required for assessment.
1. Ask the administrator to disable Copilot review **for this lab repository**
   if it was enabled only for the exercise. Don't disable shared organization
   access or unlink a shared billing subscription.
1. Keep policies intact on retained/shared repositories.
1. If the private project was created solely for this lab, optionally delete
   the exact **eshop-copilot-review-lab** project after saving required evidence.
   Deletion removes its repositories and work items; never delete a
   shared eShopOnWeb project.

## Review

You extended the same eShopOnWeb/Azure Repos source-control route with native
Copilot feedback. You created a feature branch, inspected and committed a
focused change, linked a PR to its requirement, evaluated review comments,
and updated the same PR before merging. The final change documents the
existing filtering intent without changing the expression. Copilot assisted
with explanation and first-pass review; it didn't prove application correctness,
fix the source, or complete the PR on your behalf.

Further reading:

- [Native Copilot code review in Azure Repos](https://learn.microsoft.com/azure/devops/repos/git/copilot-code-reviews?view=azure-devops)
- [Configure Azure Repos Copilot review instructions](https://learn.microsoft.com/azure/devops/repos/git/configure-copilot-code-review-instructions?view=azure-devops)
- [Azure Repos branch policies](https://learn.microsoft.com/azure/devops/repos/git/branch-policies?view=azure-devops)
