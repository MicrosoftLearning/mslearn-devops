---
lab:
  topic: Agentic
  title: "DRAFT - Extend Azure Repos contribution flow with Copilot code review"
  description: Extend the eShopOnWeb source-control exercise with native Copilot PR review, focused regression tests, Azure Repos branch policies, and independent human approval.
  level: 400
  duration: 75 minutes
  islab: true
  primarytopics:
    - Azure DevOps
    - Azure Repos
    - Azure Pipelines
    - GitHub Copilot
    - Agentic DevOps
---

# DRAFT - Extend Azure Repos contribution flow with Copilot code review

> **Draft for author review:** Companion to **Architect and optimize multi-stage
> pipelines with AI assistance**. Native GitHub Copilot code review in Azure
> Repos is an **Azure DevOps Services public preview** at the time of writing.
> Validate current enablement, billing, hosted-agent requirements, and UI
> behavior before publication.

## Exercise scenario

The traditional
[Version Control with Git in Azure Repos](../../basic/06-version-control-git-azure-repos.md)
lab imports eShopOnWeb, clones the repository, stages and commits changes,
works with branches, and introduces PR policies.

This exercise retains that source-control context and adds **native GitHub
Copilot code review on an Azure Repos PR**. It isn't the separate Copilot CLI
security-analysis pipeline. Copilot supplies feedback on the proposed change;
Azure Repos policies, regression tests, and an independent reviewer control
whether it can merge.

You strengthen regression coverage for eShopOnWeb's real catalog filter.
During the exercise, an intentionally incorrect first revision combines
brand/type filters with OR instead of AND. You compare Copilot feedback with
failing tests, correct the revision, and obtain fresh review.

The module's stock-filter example illustrates the same contribution flow, but
its example source filenames aren't supplied application paths. This lab uses
the **existing brand/type filter and tests** in the imported eShopOnWeb sample.
Don't add a fictitious `SearchFilter.cs` file.

By the end of this exercise, you will be able to:

- Clone, inspect, stage, commit, and publish a focused feature branch.
- Configure native Copilot review without confusing it with editor assistance.
- Evaluate AI feedback against actual code and regression tests.
- Distinguish automatic review requests, build validation, and human approval.
- Preserve the work-item, revision, review, test, and merge evidence.

Allow approximately **75 minutes**, excluding administrator setup.

## Companion module reading

Read these units in the supplied **Architect and optimize multi-stage pipelines
with AI assistance** module. Its draft publication link is pending editorial
review.

| Module unit | How this lab applies it |
|---|---|
| Unit 2: Design a repository, branch, and pull-request workflow | Local clone, staged commits, published feature branch, linked work, and integration. |
| Unit 3: Review pull requests and resolve conflicts with GitHub Copilot | Native Azure Repos review, interpreting feedback, and requesting a review after new commits. |
| Unit 4: Connect reviewed changes to reusable multi-stage pipelines | Target-branch build validation rather than a YAML `pr` trigger. |
| Unit 5: Evaluate Copilot-generated pipeline YAML | Inspect scope, permissions, dependencies, and failed-test behavior. |
| Unit 6: Govern AI-assisted repository and build workflows | Keep review assistance separate from merge authority and retain evidence. |

This lab adds the setup mechanics for those concepts. It doesn't require
application deployment, GitHub Agentic Workflows, Copilot CLI authentication,
MCP setup, release tags, or classic pipelines.

## Before you start

Arrange these prerequisites with your instructor or administrator:

| Requirement | Details |
|---|---|
| Azure DevOps Services organization | The native review preview isn't an Azure DevOps Server lab. Use an organization approved for the feature and the supplied public source. |
| Preview administration | A Project Collection Administrator enables organizational access; project/repository administrators manage the permitted project and repository settings. |
| Billing approval | An Azure subscription must be linked to the organization. Native Copilot review is billed through that subscription; confirm approval before requesting reviews. |
| Hosted pipeline capacity | Current preview documentation requires Azure Pipelines and supported Microsoft-hosted capacity. Self-hosted agent pools and Managed DevOps Pools aren't currently supported for native review. Capacity is also needed for this lab's validation pipeline. |
| Repository/project permissions | Create a private lab project, import a repository, create a pipeline, and configure branch policies, or have an administrator perform those scoped setup tasks. |
| Human reviewer | A teammate or instructor with a separate Azure DevOps identity, appropriate project access, and permission to review the repository. |
| Workstation | Git, VS Code, PowerShell, and the .NET 8 SDK/runtime required by the imported sample. Use your approved Git Credential Manager/sign-in method. |
| Copilot Chat | An approved client is needed for the bounded explanation task. Chat access alone doesn't enable the Azure Repos service feature. |

Don't purchase capacity, link a billing subscription, enable a preview for an
entire organization, or weaken security settings without approval. Ask for an
approved training environment if these prerequisites aren't available.

> **Important:** Use only the supplied non-sensitive sample. This exercise
> deliberately introduces a failing revision on an isolated feature branch.
> Don't deploy it or merge it while validation fails. AI reviews can incur
> charges, and repeated requests consume additional usage.

## Task 1: Import an isolated eShopOnWeb repository

1. In your approved organization, create a **Private**, Git-based project named
   **eshop-copilot-review-lab**. Invite the independent human reviewer.
1. Open **Repos > Files** in its empty default repository and select **Import**.
   Don't initialize the destination with a README first.
1. Import this public Git repository without a GitHub token:

   ```text
   https://github.com/MicrosoftLearning/eShopOnWeb.git
   ```

1. Keep the imported files at the root and set `main` as the default branch
   under **Repos > Branches** if necessary.
1. Confirm these real source paths exist:

   | Path | Purpose |
   |---|---|
   | `src/ApplicationCore/Specifications/CatalogFilterSpecification.cs` | Combines optional brand/type constraints |
   | `tests/UnitTests/ApplicationCore/Specifications/CatalogFilterSpecification.cs` | Existing parameterized regression tests |
   | `tests/UnitTests/UnitTests.csproj` | Test project used for focused validation |
   | `global.json` and `Directory.Packages.props` | Existing SDK/package context |

1. Inspect the source predicate and the test data. A selected brand and a
   selected type must **both** match. A null filter means that particular
   constraint isn't applied.
1. Ignore the imported deployment templates and workflows. Don't create
   pipelines for them or provision application resources.

Unlike the older lab's optional organization setup, this exercise doesn't
require enabling public projects or classic pipelines.

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
1. If your account must opt in, open **User settings > Preview features** and
   enable the Copilot code-review preview. An administrator may have already
   enabled it for eligible users.
1. Confirm billing and the supported hosted-agent configuration with the
   administrator. Leave review effort at the approved default.

You aren't creating a GitHub PAT or adding a `COPILOT_GITHUB_TOKEN` secret.
This hosted Azure Repos feature has its own enablement and billing route.
Installing Copilot in VS Code or configuring the separate CLI lab doesn't
enable it.

**Expected result:** Copilot review is enabled for this repository. You will
verify that **GitHub Copilot** appears in a PR's reviewer list in Task 6.

## Task 3: Clone and establish the validation baseline

1. In **Repos > Files > Clone**, copy the approved HTTPS clone URL.
1. In a VS Code PowerShell terminal, choose a parent directory for a new
   checkout and run these commands individually:

   ```powershell
   $repositoryUrl = Read-Host "Paste the lab repository HTTPS clone URL"
   git clone $repositoryUrl eshop-copilot-review-lab
   Set-Location .\eshop-copilot-review-lab
   git remote -v
   git status
   git switch main
   git pull --ff-only
   dotnet --info
   ```

1. Confirm `origin` points to the **lab Azure Repos repository**. Authenticate
   through your organization's approved flow. Don't copy a token into source
   or change your machine-wide credential helper for this exercise.
1. If Git author identity isn't configured, set the approved name/email for
   **this repository**, using `git config user.name` and `git config user.email`.
   Don't reuse someone else's identity.
1. Establish a clean baseline:

   ```powershell
   dotnet test .\tests\UnitTests\UnitTests.csproj --configuration Release --filter "FullyQualifiedName~Microsoft.eShopWeb.UnitTests.ApplicationCore.Specifications.CatalogFilterSpecification"
   git status --short
   ```

   In the supplied version, seven parameterized cases should pass. Confirm
   tests actually ran; zero matching tests isn't a successful baseline.
   If the baseline fails, resolve the SDK, package restore, or source-version
   mismatch with your instructor before introducing the training regression.

   The upstream sample can report existing package advisory warnings. Record
   them and follow the instructor's policy. Don't suppress warnings, deploy
   the application, or bundle unrelated dependency upgrades into this PR.

1. Before enabling feature-branch policies, add
   **`.azuredevops/copilot-instructions.md`** to the lab repository's `main`:

   ```markdown
   # Catalog-filter review guidance

   Review the proposed change against its linked work item.
   Selected brand and type constraints must both apply.
   Null means that specific filter is omitted, not that every item matches.
   Check regression cases for unfiltered, single-filter, combined-filter,
   and no-match behavior. Prefer concrete findings with code/test evidence.
   Don't invent stock fields, deployment behavior, or test results.
   Feedback doesn't authorize a merge or replace independent human approval.
   ```

   In the current Azure Repos preview, repository review instructions are read
   from the **target branch**. Put this setup guidance on `main` before the
   feature PR; adding it only to that PR doesn't apply it to that review.
   Instructions guide the model, not enforce branch policy.

1. Add **`.ado/catalog-filter-validation.yml`** to `main`:

   ```yaml
   trigger: none

   pool:
     vmImage: ubuntu-latest

   steps:
   - checkout: self
     persistCredentials: false
   - task: UseDotNet@2
     displayName: Use .NET 8 SDK
     inputs:
       packageType: sdk
       version: '8.x'
   - script: >
       dotnet test tests/UnitTests/UnitTests.csproj
       --configuration Release
       --filter "FullyQualifiedName~Microsoft.eShopWeb.UnitTests.ApplicationCore.Specifications.CatalogFilterSpecification"
       --logger "trx;LogFileName=catalog-filter.trx"
     displayName: Test catalog filter
   - task: PublishTestResults@2
     displayName: Publish catalog-filter results
     condition: succeededOrFailed()
     inputs:
       testResultsFormat: VSTest
       testResultsFiles: '**/catalog-filter.trx'
       failTaskOnFailedTests: true
       failTaskOnMissingResultsFile: true
       testRunTitle: Catalog filter regression tests
   ```

1. Inspect, stage, commit, and push only these setup files to the disposable
   repository's `main`. If policies already exist, use a reviewed setup PR
   instead; don't bypass or disable them.
1. Create a pipeline using **Existing Azure Pipelines YAML file**, `main`,
   and **`.ado/catalog-filter-validation.yml`**. Name it
   **catalog-filter-validation**.

   The source selector may display **Azure Repos Git**; that is the UI label.
   The repository service is **Azure Repos**.

1. Run it manually once and confirm the same baseline tests pass. If checkout
   fails, verify the actual build-service identity's repository **Read**
   permission and resource authorization. Don't grant repository write access
   or widen job authorization scope to make checkout work.

**Expected result:** Local and hosted baseline tests pass, target-branch review
guidance exists, and the pipeline is ready for a branch build-validation policy.

## Task 4: Configure independent acceptance controls

1. Open **Repos > Branches > main > Branch policies**.
1. Require at least **one reviewer**. Clear **Allow requestors to approve
   their own changes** and enable **Prohibit the most recent pusher from
   approving their own changes** where available.
1. Under new pushes, select **Reset all approval votes** so revised source
   requires a fresh human approval. Don't allow completion over wait/reject
   votes for this exercise.
1. Require linked work items and comment resolution.
1. Add **Build validation** using **catalog-filter-validation**:

   - Trigger: **Automatic**.
   - Policy requirement: **Required**.
   - No path filter for this lab.
   - Expire the result immediately when `main` changes, where offered.

1. Inspect **Bypass policies when pushing** and **Bypass policies when
   completing pull requests** with the administrator. The feature author
   must not use a bypass to complete this lab.
1. Leave **Automatically request Copilot code review** off for the first
   run so you can practice the explicit request. Don't change an inherited
   organization policy; if automatic requests are required, inspect that
   review instead of submitting a duplicate request.

The three controls have different purposes:

| Control | Effect |
|---|---|
| Copilot request or automatic-review policy | Obtains AI feedback |
| Required build-validation policy | Runs deterministic validation of the PR merge revision |
| Human reviewer and linked-work policies | Establish independent approval and traceability |

`trigger: none` disables push-based CI, **not** branch-policy validation.
Adding a YAML `pr` section wouldn't configure Azure Repos PR validation.
No push-triggered integration build is configured for after the merge.

**Expected result:** Copilot feedback alone can't satisfy the lab's acceptance
controls, and a passing test run alone can't authorize a merge.

## Task 5: Create linked work and publish a reviewable first revision

1. In **Boards > Work Items**, create an item titled
   **Strengthen catalog-filter regression coverage**. Use an available type,
   such as Product Backlog Item, User Story, or Issue.
1. Include these acceptance criteria and note the work-item ID:

   ```text
   Preserve the existing brand/type filter behavior:
   - No filters returns all supplied test items.
   - Each selected filter is respected.
   - When both filters are selected, both must match.
   - A combination with no matching item returns no items.
   Add combined-filter regression cases, keep unrelated code unchanged,
   and obtain current tests and independent human approval before merge.
   ```

1. With a clean local working tree, create the feature branch:

   ```powershell
   git switch main
   git pull --ff-only
   git switch -c feature-fix
   ```

1. In the existing test file
   **`tests/UnitTests/ApplicationCore/Specifications/CatalogFilterSpecification.cs`**,
   add these rows to the existing `MatchesExpectedNumberOfItems` theory:

   ```csharp
   [InlineData(1, 2, 1)]
   [InlineData(2, 2, 1)]
   ```

1. For the training regression only, open the **production** file
   **`src/ApplicationCore/Specifications/CatalogFilterSpecification.cs`**.
   Change just the `&&` joining the two optional-filter clauses to `||`:

   ```csharp
   Query.Where(i => (!brandId.HasValue || i.CatalogBrandId == brandId) ||
       (!typeId.HasValue || i.CatalogTypeId == typeId));
   ```

1. Run the same focused test command from Task 3. Confirm tests fail because
   the filter returns incorrect counts, not because of environment setup.
1. Inspect the changes:

   ```powershell
   git diff
   git add -- src\ApplicationCore\Specifications\CatalogFilterSpecification.cs tests\UnitTests\ApplicationCore\Specifications\CatalogFilterSpecification.cs
   git diff --cached --check
   git diff --cached
   git commit -m "Exercise catalog-filter regression review"
   git push -u origin feature-fix
   ```

   Normally you fix failing tests before publishing. This controlled exercise
   deliberately publishes the failing revision **only to an isolated feature
   branch**, so you can compare native review with the blocked build policy.
   Don't proceed if unrelated files are staged.

1. In **Repos > Pull requests**, create an **Active**, non-draft PR from
   **feature-fix** into **main** in the lab repository.
1. Describe the added test cases and mark the first revision as an intentional
   training regression that must not merge. Link the work item using the PR's
   **Work items** control; don't assume a GitHub closing keyword creates the
   Azure Boards link.
1. Confirm the build-validation policy queues a run and reports failing
   catalog-filter tests. Record the PR iteration/source commit and run link.

**Expected result:** One linked PR has a known behavioral regression, failing
deterministic validation, and an unsatisfied independent-review requirement.

## Task 6: Request Copilot review and evaluate the feedback

1. On the active, mergeable PR, find **GitHub Copilot** under **Reviewers** and
   select **Request**. Use the approved default effort.
1. Wait for **Review completed**. Inspect the review entry, line comments,
   and any suggested changes.
1. Compare the feedback with the two predicates, test data, and failing test
   results. Ask Copilot Chat for an explanation if helpful:

   ```text
   Explain how the proposed OR condition differs from the original AND
   condition for null, single, and combined catalog filters.
   Compare with these test inputs and expected counts.
   Identify the smallest correction that preserves the linked requirement.
   Don't edit files, commit, push, approve, or merge.
   ```

   Provide the approved public snippets and requirements. The editor/chat
   conversation isn't automatically the context of the hosted PR review.

1. Add a human-authored PR comment recording a Copilot observation, your
   **accept/revise/reject** decision, and the source/test evidence.
   If Copilot gives no actionable feedback, record that result honestly.
   The failing tests still establish the regression.
1. Verify Copilot's **Comment** review hasn't supplied a human approval or
   turned the failing build into a pass. Native Azure Repos Copilot review
   doesn't approve or request changes and doesn't satisfy reviewer policies.

If Git reports a merge conflict, reconcile `main` into the feature branch
and revalidate before requesting Copilot review. During the current preview,
the PR must be active and have a successful test merge; a textual conflict
and a failing application test are different conditions.

**Expected result:** You can explain the regression and assess AI feedback
without treating it as merge permission or guaranteed defect detection.

## Task 7: Correct, revalidate, and request a new review

1. On **feature-fix**, restore the production predicate's joining operator to
   `&&`, preserving both new regression-test rows.
1. Run the focused tests again. In the supplied version, **nine** cases should
   now pass. Inspect the diff and any generated files before staging.
1. Stage only the intended correction, inspect it, and publish:

   ```powershell
   git add -- src\ApplicationCore\Specifications\CatalogFilterSpecification.cs
   git diff --cached --check
   git diff --cached
   git commit -m "Preserve combined catalog constraints"
   git push
   ```

1. Verify the same PR has a new iteration and a fresh policy-driven test run.
   Confirm the current run passes and publishes the nine test results.
1. In **Reviewers**, select **Request** next to **GitHub Copilot** again.
   The current Azure Repos preview doesn't automatically re-review new
   commits. Replying to a comment also doesn't trigger a model response.
1. Evaluate any new comments and resolve conversations with evidence.
1. Ask the independent human reviewer to assess the **current** iteration,
   work item, test results, and evaluated Copilot feedback, then approve.
1. Check that the final PR diff is limited to the intended coverage change.
   Because the production predicate is restored to the original behavior,
   it can disappear from the final diff. That is expected; don't retain an
   unnecessary code change just to make the PR look larger.

**Expected result:** The PR has preserved application behavior, added focused
regression coverage, fresh validation, a revised AI review, and human approval.

## Task 8: Complete integration and preserve evidence

1. Record the work-item ID, PR URL, latest source/merge revision, test run,
   Copilot review, and human approval in the PR or linked work item.
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
| Detect the demonstrated regression | Focused tests provide deterministic results |
| Enforce the contribution route | Azure Repos permissions and policies |
| Accept the revised change | Independent human approval and authorized completion |

## Troubleshooting

| Symptom | Next action |
|---|---|
| GitHub Copilot doesn't appear in Reviewers | Confirm organization/project/repository access, inherited settings, user preview opt-in, billing, and current feature availability with the administrator. Editor access isn't service enablement. |
| Native review can't start or remains queued | Check supported Microsoft-hosted pipeline capacity and current preview restrictions. Don't move it to an unsupported self-hosted pool. |
| Review is unavailable for the PR | Confirm it is active, not a draft, has no merge conflicts, and meets the documented preview size/change limits. |
| Review doesn't repeat after a push | Select **Request** again for the new iteration. Duplicate requests for the same completed PR version may be limited. |
| Copilot posts no actionable comments | Record the result; use actual tests and human review. No comments isn't proof of correctness. |
| Build isn't triggered by the PR | Check the target `main` build-validation policy and its selected pipeline. A YAML `pr` trigger isn't the Azure Repos solution. |
| Local/hosted tests fail before the training change | Fix SDK/runtime, restore, source-version, or authorization problems first. Don't claim a setup failure demonstrates the intended regression. |
| Author approval doesn't satisfy the policy | Expected with independent approval configured. Use the separate reviewer, not self-approval or bypass. |

## Clean up

1. Retain the PR, work-item, review, and test evidence required for assessment.
1. Disable the lab validation pipeline if no longer used.
1. Ask the administrator to disable Copilot review **for this lab repository**
   if it was enabled only for the exercise. Don't disable shared organization
   access or unlink a shared billing subscription.
1. Remove temporary collaborator access only with the instructor's approval.
1. Keep policies intact on retained/shared repositories. Unlike the older
   source-control lab, this draft doesn't direct you to weaken `main` so later
   exercises can push directly.
1. If the private project was created solely for this lab, optionally delete
   the exact **eshop-copilot-review-lab** project after saving required evidence.
   Deletion removes its repositories, work items, and builds; never delete a
   shared eShopOnWeb project.

## Review

You extended the same eShopOnWeb/Azure Repos source-control route with native
Copilot feedback. AI helped interpret and review the change, while focused
tests, linked work, protected policies, and a human reviewer retained the
acceptance authority.

Further reading:

- [Original Azure Repos source-control lab](../../basic/06-version-control-git-azure-repos.md)
- [GitHub-hosted source-control companion lab](09-integrate-copilot-code-review-github-flow.md)
- [Native Copilot code review in Azure Repos](https://learn.microsoft.com/azure/devops/repos/git/copilot-code-reviews?view=azure-devops)
- [Configure Azure Repos Copilot review instructions](https://learn.microsoft.com/azure/devops/repos/git/configure-copilot-code-review-instructions?view=azure-devops)
- [Azure Repos branch policies](https://learn.microsoft.com/azure/devops/repos/git/branch-policies?view=azure-devops)
