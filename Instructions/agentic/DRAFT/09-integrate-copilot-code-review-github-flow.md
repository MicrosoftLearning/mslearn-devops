---
lab:
  topic: Agentic
  title: "DRAFT - Extend GitHub flow with Copilot code review"
  description: Extend the existing Spoon-Knife repository exercise with bounded Copilot assistance, native PR code review, deterministic checks, and independent human approval.
  level: 300
  duration: 60 minutes
  islab: true
  primarytopics:
    - GitHub
    - GitHub Copilot
    - Source control
    - Agentic DevOps
---

# DRAFT - Extend GitHub flow with Copilot code review

> **Draft for author review:** Companion to **Architect and optimize multi-stage
> pipelines with AI assistance**.
> Validate the GitHub UI, Copilot entitlement, and two-person approval flow in
> a learner-owned repository before publication.

## Exercise scenario

In the traditional
[Implement Flow of Work with GitHub](../../basic/02-implement-manage-repositories-using-github.md)
lab, you fork Spoon-Knife, create an issue and branch, edit HTML/CSS, and merge
a PR. Here you retain that contribution route and add GitHub Copilot.

Copilot helps explain a proposed change, draft a focused summary, and review
the PR. You still inspect actual commits, run a deterministic check, evaluate
feedback, and obtain an independent human approval before merging.

The supplied module uses a fictitious EShopOnWeb search fix to explain this
process. This lab uses Spoon-Knife's existing, small HTML/CSS files so you can
practice the same governance without deploying an application.

By the end of this exercise, you will be able to:

- Distinguish a fork, feature branch, commit, and PR.
- Give Copilot a bounded change/review contract.
- Request native Copilot code review and evaluate its suggestions.
- Update the same PR and obtain review for the revised source.
- Separate AI feedback from required checks and human merge authorization.

Allow approximately **60 minutes**. You don't need to complete the older lab
first; this draft contains the complete core route.

## Companion module reading

Read these units in the supplied **Architect and optimize multi-stage pipelines
with AI assistance** module. Its draft publication link is pending editorial
review.

| Module unit | How this lab applies it |
|---|---|
| Unit 2: Design a repository, branch, and pull-request workflow | Issue, feature branch, inspected commits, PR, and allowed merge method. |
| Unit 3: Review pull requests and resolve conflicts with GitHub Copilot | Native Copilot review, evaluating suggestions, revised commits, and re-review. |
| Unit 4: Connect reviewed changes to reusable multi-stage pipelines | PR-triggered validation and the distinction between source and target branches. |
| Unit 5: Evaluate Copilot-generated pipeline YAML | Review a small workflow's trigger, permissions, and deterministic behavior. |
| Unit 6: Govern AI-assisted repository and build workflows | Human authorization, protected controls, and an evidence record. |

This exercise uses **native Copilot code review**, not GitHub Agentic Workflows.
The [Agentic Workflows companion lab](08-integrate-agentic-workflows-github-security-analysis.md)
teaches that separate automation pattern. GitHub Pages deployment, Projects,
cloud-agent fixes, and MCP configuration aren't required here.

## Before you start

You need:

- A GitHub account permitted to fork a public repository and administer that
  disposable fork, including Actions and branch protection or rulesets.
- Native Copilot code review enabled and available for this account/repository.
  Check the current plan and organization policy with your instructor. Access
  to Copilot Chat alone doesn't establish access to hosted PR code review.
- An approved Copilot Chat client for the bounded assistance task. It doesn't
  need permission to write to the repository.
- A teammate or instructor with a **separate GitHub account**, invited as a
  collaborator with permission to approve PRs in your fork.
- Available GitHub Actions capacity and Copilot usage allowance. AI requests
  and runner time can incur charges.
- A browser. You can edit and commit files in GitHub's web UI; a local Git
  installation is optional.

Use only the supplied public sample. Don't add credentials or business data.
If protection or Copilot review isn't available, ask for a suitable training
repository. Don't disable required controls or substitute a PR summary for a
code review and claim the exercise is complete.

## Task 1: Fork the sample and prepare the collaboration route

1. Open [octocat/Spoon-Knife](https://github.com/octocat/Spoon-Knife), select
   **Fork**, and create **copilot-review-spoon-knife** under your approved
   account or organization. Copy only `main` if offered.
1. If you already have a Spoon-Knife fork, inspect it first. Use an
   instructor-approved fresh copy or a clean existing fork; don't overwrite
   unrelated work to recreate the exercise.
1. Confirm the repository URL belongs to **your owner**, and that `main` is
   the default branch. Enable **Issues** under **Settings > General**.
1. Inspect `index.html`, `styles.css`, and the existing `forkit.gif` image.
   A fork is your server-side repository; it isn't a local clone.
1. Invite your teammate or instructor under **Settings > Collaborators**
   (or the organization repository's access settings). Have them accept.
1. Agree that this lab requires **one independent human approval**, even if
   your Copilot configuration can submit an approving review.

**Expected result:** You own an isolated fork and have a human reviewer.
All PRs in this lab will target `main` **in this fork**, never `octocat/main`.

## Task 2: Bootstrap review guidance and a deterministic check

As the repository owner, configure the lab's initial controls on `main`
before starting feature work. In a repository with existing protection, use
its normal reviewed configuration PR instead of bypassing controls.

1. On `main`, use **Add file > Create new file** to create
   **`.github/copilot-instructions.md`**:

   ```markdown
   # Review guidance for the Spoon-Knife collaboration page

   Evaluate proposed HTML/CSS against the linked issue's acceptance criteria.
   Keep the existing forkit.gif image and the octocat element identifier.
   The image conveys the page's collaboration message and needs meaningful
   alternative text. It must fit a narrow viewport without distortion.
   Keep changes limited to the requested page update.

   Prefer concrete, evidence-backed findings over generic style suggestions.
   State missing context rather than inventing requirements.
   Don't claim a visual or accessibility test ran unless evidence is supplied.
   Suggestions don't authorize a merge or replace independent human approval.
   ```

1. Commit the setup file to your fork's `main`.
1. Create **`.github/workflows/pr-validation.yml`** on `main`:

   ```yaml
   name: PR validation

   on:
     pull_request:
       branches:
         - main
       types: [opened, synchronize, reopened, ready_for_review]

   permissions:
     contents: read

   jobs:
     page-check:
       name: Check page image
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262
           with:
             persist-credentials: false
         - uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065
           with:
             python-version: '3.12'
         - name: Check the collaboration image
           run: |
             python - <<'PY'
             from html.parser import HTMLParser
             from pathlib import Path

             class Page(HTMLParser):
                 def __init__(self):
                     super().__init__()
                     self.images = []

                 def handle_starttag(self, tag, attrs):
                     if tag == "img":
                         attributes = dict(attrs)
                         if attributes.get("id") == "octocat":
                             self.images.append(attributes)

             page = Page()
             page.feed(Path("index.html").read_text(encoding="utf-8"))
             if len(page.images) != 1:
                 raise SystemExit("Expected exactly one octocat image.")
             image = page.images[0]
             if image.get("src") != "forkit.gif":
                 raise SystemExit("Keep the supplied forkit.gif image.")
             if not image.get("alt", "").strip():
                 raise SystemExit("The collaboration image needs meaningful alternative text.")
             print("Image source and non-empty alternative-text checks passed.")
             PY
   ```

1. Commit the workflow and enable Actions in the fork if prompted.
1. Explain the definition before continuing:

   - `pull_request.branches: [main]` filters the **target**, not the source.
   - A push to a branch without a PR doesn't trigger this workflow.
   - Opening a PR or pushing another commit to its source triggers validation.
   - Checkout normally uses a temporary test-merge revision.
   - No `push` trigger means this workflow doesn't run again just because the
     PR merged into `main`.
   - `contents: read` and nonpersisted checkout credentials provide no
     repository write operation or deployment authority.

The check verifies image identity and the presence of alternative text.
It **doesn't** judge the quality of that text, validate all HTML/CSS, or prove
responsive behavior. Those remain explicit review tasks.

**Expected result:** Your default branch contains review guidance and a
small deterministic PR check. No PAT, AI action, or custom agent is needed
for native Copilot review.

## Task 3: Protect the integration branch

1. Under **Settings > Branches**, add a branch protection rule for `main`,
   or create an equivalent active branch ruleset.
1. Require a PR before merging and **one approving review**. Enable dismissal
   of stale approvals when new commits are pushed and require conversation
   resolution where available.
1. Inspect the effective bypass settings. Apply the rule to administrators
   where supported and don't grant yourself a lab bypass.
1. Keep **Copilot approvals disabled** for this exercise so the required
   approval must come from your human reviewer. If an organization policy
   prevents this, have the instructor provide a configuration that enforces
   the separate human requirement; don't assume any approval is human.
1. Don't require **Check page image** yet if it isn't selectable. You will
   add that exact status check after the first PR run registers it.

Custom instructions aren't branch protection. Copilot can read instructions
from the PR's head branch, so an author could propose changing them too.
Independently protected repository settings enforce the merge conditions.

**Expected result:** A feature author can't legitimately merge their own work
without independent approval. The setup commits aren't a model for bypassing
rules during normal feature development.

## Task 4: Create the issue and feature branch

1. Create an issue titled **Improve the collaboration page** with these
   acceptance criteria:

   ```text
   - Show a clear collaboration heading and a welcoming paragraph.
   - Keep the existing forkit.gif image and its octocat identifier.
   - Give that informative image meaningful alternative text.
   - Keep the image within a narrow viewport without changing its aspect ratio.
   - Limit feature changes to index.html and styles.css.
   - Obtain current validation and an independent human approval before merge.
   ```

1. Note the actual issue number. Don't assume it is `#1`.
1. From current `main`, create a branch named **feature-fix**.
1. In your approved Copilot Chat client, supply the public issue criteria and
   relevant HTML/CSS, then use this bounded prompt:

   ```text
   Explain a minimal HTML/CSS change for these acceptance criteria.
   Identify what I should inspect manually and what a small automated check
   can verify. Draft a concise commit message and PR description.
   Don't edit files, commit, push, approve, or merge.
   State assumptions and keep the scope to index.html and styles.css.
   ```

1. Compare the response with the actual files. Record an assumption you
   verified or corrected. The response is a draft, not proof of the diff.

**Expected result:** You have a feature branch, a linked requirement, and a
bounded AI-assisted change plan. No AI action has authorized a repository write.

## Task 5: Publish an intentionally incomplete first revision

This first revision deliberately omits one acceptance criterion so you can
observe the difference between AI feedback and a deterministic failed check.
Don't merge it or deploy it.

1. On **feature-fix**, edit `index.html`. Replace only the content between
   `<body>` and `</body>`, retaining those tags and the existing document head:

   ```html
   <h1>Collaborate with Octocat</h1>
   <img src="forkit.gif" id="octocat" />
   <p>Ready to team up? Let's collaborate, @octocat!</p>
   ```

1. Still on **feature-fix**, replace `styles.css` with:

   ```css
   * {
     box-sizing: border-box;
   }

   body {
     margin: 0;
     padding: 1rem;
     font-family: "Segoe UI", Tahoma, sans-serif;
     background-color: #f8f9fa;
     color: #333;
   }

   #octocat {
     display: block;
     width: 384px;
     max-width: 100%;
     height: auto;
     margin: 2rem auto;
   }

   h1,
   p {
     max-width: 40rem;
     margin: 1.5rem auto;
     text-align: center;
   }

   p {
     font-size: 1.25rem;
     line-height: 1.5;
   }
   ```

1. Inspect each diff and commit to the **existing feature-fix branch**, not
   `main` or a second automatically created branch. Adapt the proposed commit
   message so it describes what was actually changed.
1. Create a non-draft PR with **base repository: your fork**, **base: main**,
   and **compare: feature-fix**.
1. Use the inspected PR description draft. Include **`Fixes #<issue-number>`**,
   the test plan, and a note that the first revision intentionally leaves
   the alternative-text criterion incomplete.
1. Inspect **Files changed**. Only `index.html` and `styles.css` should be
   feature changes. Record the current head commit.

**Expected result:** One PR contains the two intended file changes. Opening
it doesn't merge it, and its **Check page image** validation should fail.

## Task 6: Request native Copilot code review

1. On the PR, find **Reviewers** and select **Request** next to **Copilot**, or
   choose Copilot from the reviewer selector if that is how your UI presents it.
   This is a **code review**, not **Generate PR summary**.
1. Wait for the review and inspect its completed review entry, comments, and
   any suggested changes.
1. Record the revision reviewed and evaluate the feedback against the issue,
   the actual diff, and the deterministic check.
1. Add a short human-authored PR comment recording:

   | Observation | Decision | Evidence |
   |---|---|---|
   | One actionable Copilot suggestion, if present | Accept, revise, or reject | Link to the comment and the relevant code or requirement |
   | One remaining verification task | Human check or automated check | Explain why AI feedback alone isn't enough |

   Copilot may find the missing alternative text, report another issue, or
   produce no actionable findings. Don't invent a comment or weaken the
   exercise to obtain a particular model response. If it finds nothing,
   explicitly record that and use the failing check as the evidence to fix.

1. Open the failed **Check page image** log. Confirm that the failure concerns
   missing alternative text, not workflow setup or authentication.
1. As the repository owner, update the `main` protection/ruleset to require
   the registered **Check page image** status check. Select GitHub Actions as
   the expected source if offered.
1. Confirm merging is blocked while required validation fails and human
   approval is missing. Don't click a bypass option.

**Expected result:** You have native Copilot feedback, a deterministic failure,
and protected merge requirements. None of those is interchangeable with the
others.

## Task 7: Apply a reviewed correction and request fresh review

1. Edit `index.html` on **feature-fix** and update the image to:

   ```html
   <img src="forkit.gif" id="octocat"
        alt="Octocat inviting contributors to collaborate" />
   ```

   If applying a Copilot suggestion, inspect it first and ensure it preserves
   the supplied image and identifier. Don't accept unrelated changes.

1. Commit to the same branch. Confirm the **existing PR** gains the new
   commit and a fresh validation run, rather than a second PR being created.
1. Verify **Check page image** passes for the updated PR revision.
1. Manually inspect the image and text at the revised commit. For a local
   visual check without deployment, download the feature branch as a ZIP
   from **Code > Download ZIP**, extract it, and open `index.html` in a browser.
   Resize the window and confirm the image fits without distortion.
   Confirm the downloaded branch still matches the recorded PR head.
1. Check that the alternative text meaningfully describes the informative
   image. A non-empty string alone doesn't establish that.
1. Use **Re-request review** beside Copilot in **Reviewers**. A new push doesn't
   guarantee automatic Copilot re-review unless that behavior is configured.
1. Evaluate new feedback and resolve substantive conversations with evidence.
   Replying to a Copilot comment isn't a request for another model response.
1. Ask your teammate/instructor to review the updated diff, check results, and
   issue criteria, then approve using their own account.
1. Confirm the human approval is current. If you make another commit, repeat
   the relevant checks and obtain fresh approval under the configured policy.

**Expected result:** The revised PR has current deterministic validation,
evaluated AI feedback, manual verification, and independent human approval.

## Task 8: Merge and preserve the contribution record

1. Before merging, record the issue link, PR link, latest source commit,
   validation run, Copilot review, and human approval.
1. Select an allowed merge method and complete the merge without bypassing
   the rules. A squash merge can create a different commit on `main`; record
   that integrated commit too.
1. Verify the updated HTML/CSS is on your fork's `main`. Confirm the linked
   issue closed; if not, check the closing keyword, repository, and issue
   number before closing it manually with the PR link.
1. Delete **feature-fix** in your fork after confirming it contains no
   unmerged work.
1. Confirm no new **PR validation** run was triggered solely by the merge.
   This lab configures PR validation, not a post-merge `push` build.

Summarize the transition in the PR:

| Traditional task | Copilot assistance | Responsibility retained |
|---|---|---|
| Interpret a requirement and plan an edit | Explain context and propose a narrow change | Confirm acceptance criteria and scope |
| Describe commits and a PR | Draft summaries | Verify summaries against actual changes |
| Perform a first-pass code review | Native PR findings and suggested changes | Validate feedback and decide which changes to accept |
| Check and authorize integration | Help explain evidence | Deterministic checks and independent human approval |

## Troubleshooting

| Symptom | Next action |
|---|---|
| Copilot isn't available as a reviewer | Confirm native code-review entitlement, policy, Actions availability, and repository settings with the instructor. A generated summary isn't an equivalent substitute. |
| Copilot returns no actionable comments | Record that result. Fix the demonstrated deterministic failure and continue the human review; don't assume the code is correct. |
| Required status check isn't selectable | Let the first PR run complete, then select its actual registered check name and source. Don't enter an invented name. |
| Validation doesn't start | Check that the target is this fork's `main`, Actions is enabled, and the workflow exists. A push without a PR isn't a configured trigger. |
| You can't approve your own PR | Expected. Use the invited independent reviewer, not a bypass or a second identity controlled to simulate independence. |
| A new commit invalidates approval | Expected with stale-approval dismissal. Revalidate and request fresh review. |

## Clean up

1. Save required issue, PR, review, and check links for assessment.
1. Close any remaining lab PRs/issues and delete completed feature branches
   only after checking that no work needs preserving.
1. Remove a temporary collaborator if their access was granted only for this
   exercise and your instructor approves.
1. Optionally delete the exact **YOUR-OWNER/copilot-review-spoon-knife** fork
   if it was created solely for the lab. Keep upstream and shared repositories
   intact. No Azure resource or PAT was created by this exercise.
1. Delete a downloaded sample ZIP and extracted copy if no longer needed.

## Review

You extended the original Spoon-Knife GitHub flow rather than replacing it.
Copilot helped interpret and review changes, while branches, inspected
commits, current checks, and human approval retained control of integration.

Further reading:

- [Original source-control lab](../../basic/02-implement-manage-repositories-using-github.md)
- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Using Copilot code review and requesting re-review](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-code-review)
- [Repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [Managing branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule)
