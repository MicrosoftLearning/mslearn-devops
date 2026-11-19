---
lab:
  topic: Agentic
  title: "Extend GitHub flow with Copilot code review"
  description: Practice GitHub source control with bounded Copilot assistance, native PR code review, and a learner-controlled merge.
  level: 300
  duration: 45 minutes
  islab: true
  primarytopics:
    - GitHub
    - GitHub Copilot
    - Source control
    - Agentic DevOps
---

# Extend GitHub flow with Copilot code review

## Exercise scenario

You clone the public Spoon-Knife sample to your local machine and push it to
a new repository in your personal GitHub account. In your own repository,
you create an issue and branch, edit HTML/CSS, and merge a PR with GitHub
Copilot assistance. You aren't contributing changes to the source repository.

Copilot helps explain a proposed change, prepare a focused summary, and review
the PR. You still inspect actual commits, preview the page locally, evaluate
feedback, and decide when to merge. This is a solo exercise: no second
reviewer or approving review is required.

You'll update Spoon-Knife's `index.html` and `styles.css` to improve its
collaboration page, including image alternative text and responsive styling.
No application deployment or GitHub Actions workflow configuration is required.

By the end of this exercise, you will be able to:

- Distinguish a local clone, remote repository, feature branch, commit, and PR.
- Give Copilot a bounded change/review contract.
- Request native Copilot code review and evaluate its suggestions.
- Update the same PR and obtain review for the revised source.
- Separate AI feedback from manual verification and your merge decision.

Allow approximately **45 minutes**. You don't need to complete the older lab
first; this lab contains the complete core route.

## Before you start

You need:

- A personal GitHub account permitted to create and administer a public lab
  repository, including branch protection or rulesets.
- Native Copilot code review enabled and available for this account/repository.
  Check the current plan and organization policy with your instructor. Access
  to Copilot Chat alone doesn't establish access to hosted PR code review.
- An approved Copilot Chat client for the bounded assistance task. It doesn't
  need permission to write to the repository.
- Available Copilot usage allowance. AI requests can incur charges.
- A browser, [Git installed locally](https://git-scm.com/downloads), and
  [Visual Studio Code](https://code.visualstudio.com/). Make file changes in
  VS Code and use its integrated terminal to commit and push. Use GitHub in
  your browser for repository settings, issues, PRs, and Copilot code review.

## Task 1: Clone the sample and create your personal lab repository

1. Open a terminal on your local machine in a directory where you want to
   keep the lab files. Use an unused folder name; don't overwrite existing work.
   Clone the sample's `main` branch:

   ```bash
   git clone --branch main --single-branch https://github.com/octocat/Spoon-Knife.git copilot-review-spoon-knife
   cd copilot-review-spoon-knife
   git remote rename origin upstream
   ```

   This creates a local copy. The `upstream` remote identifies the source
   repository; don't push to it.
1. In GitHub, select **New repository**. Choose your **personal account** as
   the owner, name the repository **copilot-review-spoon-knife**, and select
   **Public**. Leave the README, `.gitignore`, and license initialization
   options unselected so the repository is empty, then select **Create repository**.
1. In your terminal, add your new repository as `origin` and push the cloned
   code. Replace `YOUR-OWNER` with your personal GitHub username:

   ```bash
   git remote add origin https://github.com/YOUR-OWNER/copilot-review-spoon-knife.git
   git remote -v
   ```

   Confirm `origin` points to your personal repository and only `upstream`
   points to `octocat/Spoon-Knife`. Then push, authenticating with your
   personal GitHub account if prompted:

   ```bash
   git push --set-upstream origin main
   ```

1. Refresh your personal repository in GitHub. Confirm the sample files are
   present and `main` is the default branch. Enable **Issues** under
   **Settings > General > Features** if needed.
1. From the cloned repository's directory, open it in VS Code:

   ```bash
   code .
   ```

   If `code` isn't available, open VS Code and select **File > Open Folder**
   to open **copilot-review-spoon-knife**.
1. In VS Code's **Explorer**, inspect `index.html`, `styles.css`, and the
   existing `forkit.gif` image. Select **Terminal > New Terminal**. Run the
   remaining Git commands in this integrated terminal at the repository root.

## Task 2: Add Copilot review guidance in VS Code

Add repository instructions so Copilot has context for its code review.
Do this on `main` before starting feature work. In a repository with existing protection, use
its normal reviewed configuration PR instead of bypassing controls.

1. In VS Code, confirm the branch indicator at the bottom left shows **main**.
   In **Explorer**, create a folder named **`.github`** at the repository root,
   then create **`copilot-instructions.md`** inside it. Paste the following
   content and save the file:

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
   Suggestions don't authorize a merge; the learner decides after manual verification.
   ```

1. In the integrated terminal, stage the instructions file, inspect the staged
   changes, and commit and push it to your personal repository:

   ```bash
   git add .github/copilot-instructions.md
   git --no-pager diff --cached
   git commit -m "Add Copilot review guidance"
   git push origin main
   ```

   These initial instructions go on `main` before branch protection is
   configured. The HTML/CSS changes will use a feature branch and PR.
1. In your browser, confirm **`.github/copilot-instructions.md`** appears on
   your repository's `main` branch.

**Expected result:** Your repository contains context for Copilot code review.
These instructions guide feedback; they don't enforce acceptance criteria
or merge rules.

## Task 3: Protect the integration branch

1. In your browser, under the lab repository's **Settings > Branches**,
   add a branch protection rule for `main`,
   or create an equivalent active branch ruleset.
1. Enable **Require a pull request before merging**, but leave **Require
   approvals** unchecked (or set required approvals to **0** in a ruleset).
   Require conversation resolution where available. GitHub doesn't allow
   authors to approve their own PRs, so this solo lab doesn't require an
   approving review.
1. Inspect the effective bypass settings. Apply the rule to administrators
   where supported and don't grant yourself a lab bypass.

Custom instructions aren't branch protection. Copilot can read instructions
from the PR's head branch, so an author could propose changing them too.
Independently protected repository settings enforce the merge conditions.

**Expected result:** Changes must go through a PR, but no second reviewer is
needed. This lab doesn't configure automated status checks.
This training configuration doesn't demonstrate independent team approval;
follow your team's approval policies outside this personal lab repository.

## Task 4: Create the issue and feature branch

1. In your browser, create an issue in your lab repository titled
   **Improve the collaboration page** with these
   acceptance criteria:

   ```text
   - Show a clear collaboration heading and a welcoming paragraph.
   - Keep the existing forkit.gif image and its octocat identifier.
   - Give that informative image meaningful alternative text.
   - Keep the image within a narrow viewport without changing its aspect ratio.
   - Limit feature changes to index.html and styles.css.
   - Preview the page locally and evaluate Copilot feedback before merge.
   ```

1. Note the actual issue number. Don't assume it is `#1`.
1. Return to VS Code's integrated terminal. Update local `main` and create
   the feature branch:

   ```bash
   git switch main
   git pull --ff-only origin main
   git switch -c feature-fix
   ```

   Confirm the VS Code branch indicator now shows **feature-fix**.
1. In your Copilot Chat client, select **Ask Mode** and supply the public issue criteria and
   relevant HTML/CSS, then use this bounded prompt:

   ```text
   Explain a minimal HTML/CSS change for these acceptance criteria.
   Identify what I should inspect in the source and verify in a local browser.
   Propose a concise commit message and PR description.
   Don't edit files, commit, push, approve, or merge.
   State assumptions and keep the scope to index.html and styles.css.
   ```

1. Compare the response with the actual files. Record an assumption you
   verified or corrected. The response is a proposal, not proof of the diff.

**Expected result:** You have a feature branch, a linked requirement, and a
bounded AI-assisted change plan. No AI action has authorized a repository write.

## Task 5: Publish an intentionally incomplete first revision

This first revision deliberately omits meaningful image alternative text so
you can practice reviewing and updating the same PR. Copilot may identify the
omission, but its feedback isn't guaranteed. Don't merge this revision.

1. In VS Code on **feature-fix**, edit `index.html`. Replace only the content between
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

1. Save both files. In the integrated terminal, stage and inspect the
   changes, then commit and push the **existing feature-fix branch**:

   ```bash
   git add index.html styles.css
   git --no-pager diff --cached
   git commit -m "Improve collaboration page layout"
   git push --set-upstream origin feature-fix
   ```

   Only the two intended HTML/CSS files should be staged. You can adapt the
   proposed commit message to describe what was actually changed.
1. In your browser, open your lab repository and select **Compare & pull
   request** for **feature-fix** (or **Pull requests > New pull request**).
   Confirm
   **base repository: your lab repository**, **base: main**, and **compare: feature-fix**.
1. On the **Open a pull request** page, enter a title such as
   **Improve the collaboration page**. In the description box below it, adapt
   Copilot's earlier proposal or paste this template:

   ```text
   ## Summary
   Update the collaboration heading, paragraph, and responsive image styling.

   Fixes #ISSUE_NUMBER

   ## Manual verification plan (not yet completed)
   - Inspect the HTML/CSS against the issue's acceptance criteria.
   - Open index.html locally in a browser and resize the window.
   - Confirm the image fits without distortion.

   ## Known incomplete requirement
   This first revision intentionally omits image alternative text.
   It will be corrected in this PR after the initial Copilot review.
   Do not merge yet.
   ```

   Replace **`ISSUE_NUMBER`** with the number of the issue you created in
   Task 4. For example, use `Fixes #3` if your issue is number 3. This links
   the PR to that issue and closes it automatically when the PR merges into
   the default branch; it doesn't close the issue when you open the PR.
   Keep the verification items as a plan, not a claim that testing is complete.
1. Select **Create pull request** to publish it ready for review. This opens
   the PR; it doesn't merge the changes or request Copilot review yet.
   You'll request Copilot review in Task 6.
1. Inspect **Files changed**. Only `index.html` and `styles.css` should be
   feature changes. Record the current head commit.

**Expected result:** One PR contains the two intended file changes and is ready
for Copilot review. Opening it doesn't merge it. The alternative-text
acceptance criterion is intentionally incomplete.

## Task 6: Request native Copilot code review

1. On the PR, find **Reviewers** and select **Request** next to **Copilot**, or
   choose Copilot from the reviewer selector if that is how your UI presents it.
   This is a **code review**, not **Generate PR summary**.
1. Wait for the review and inspect its completed review entry, comments, and
   any suggested changes.
1. Record the revision reviewed and evaluate the feedback against the issue,
   the actual diff, and the repository review guidance.
1. Add a short human-authored PR comment recording:

   | Observation | Decision | Evidence |
   |---|---|---|
   | One actionable Copilot suggestion, if present | Accept, revise, or reject | Link to the comment and the relevant code or requirement |
   | One remaining manual verification task | Source inspection or browser preview | Explain why AI feedback alone isn't enough |

   Copilot may find the missing alternative text, report another issue, or
   produce no actionable findings. Don't invent a comment or weaken the
   exercise to obtain a particular model response. If it finds nothing,
   explicitly record that. The supplied first revision has no `alt` attribute;
   compare it with the issue criteria and include the correction in Task 7
   whether or not Copilot mentions it.

**Expected result:** Copilot has reviewed the PR, and you have evaluated its
feedback against the requested change. Review comments are advisory; they
don't prove that the page meets every requirement or prevent an incorrect merge.

## Task 7: Apply a reviewed correction and request fresh review

1. Return to VS Code, confirm you're still on **feature-fix**, and edit
   `index.html` to update the image to:

   ```html
   <img src="forkit.gif" id="octocat"
        alt="Octocat inviting contributors to collaborate" />
   ```

   If applying a Copilot suggestion, inspect it first and ensure it preserves
   the supplied image and identifier. Don't accept unrelated changes.

1. Save the file, then commit and push to the same branch from the integrated
   terminal:

   ```bash
   git add index.html
   git --no-pager diff --cached
   git commit -m "Add meaningful alternative text to collaboration image"
   git push origin feature-fix
   ```

   In your browser, refresh the **existing PR**. It gains the new commit;
   don't create a second PR.
1. Open your local `index.html` in a browser to inspect the image and text
   without deployment. Resize the window and confirm the image fits without
   distortion. Run `git status --short` and `git rev-parse HEAD` in VS Code's
   terminal to confirm there are no uncommitted changes and the local commit
   matches the PR's latest commit.
1. Check that the alternative text meaningfully describes the informative
   image. A non-empty string alone doesn't establish that.
1. Use **Re-request review** beside Copilot in **Reviewers**. A new push doesn't
   guarantee automatic Copilot re-review unless that behavior is configured.
1. Evaluate new feedback and resolve substantive conversations with evidence.
   Replying to a Copilot comment isn't a request for another model response.
1. Confirm the updated diff meets the issue criteria and that you are ready
   to merge. No approving review is required. If you make another commit,
   repeat the relevant manual verification before merging.

**Expected result:** The same PR contains the correction, evaluated AI
feedback, and your manual verification. You can proceed to merge
without another person's approval.

## Task 8: Merge and preserve the contribution record

1. Before merging, record the issue link, PR link, latest source commit,
   and Copilot review.
1. Select an allowed merge method and complete the merge without bypassing
   the rules. A squash merge can create a different commit on `main`; record
   that integrated commit too.
1. Verify the updated HTML/CSS is on your lab repository's `main`. Confirm the linked
   issue closed; if not, check the closing keyword, repository, and issue
   number before closing it manually with the PR link.
1. Delete **feature-fix** in your lab repository after confirming it contains no
   unmerged work.

Summarize the transition in the PR:

| Traditional task | Copilot assistance | Responsibility retained |
|---|---|---|
| Interpret a requirement and plan an edit | Explain context and propose a narrow change | Confirm acceptance criteria and scope |
| Describe commits and a PR | Prepare summaries | Verify summaries against actual changes |
| Perform a first-pass code review | Native PR findings and suggested changes | Validate feedback and decide which changes to accept |
| Verify and authorize integration | Help identify review targets | Manual source inspection, browser preview, and the learner's merge decision |

## Troubleshooting

| Symptom | Next action |
|---|---|
| Copilot isn't available as a reviewer | Confirm native code-review entitlement, policy, and repository settings with the instructor. A generated summary isn't an equivalent substitute. |
| Copilot returns no actionable comments | Record that result. Compare the code with the issue criteria and correct the missing alternative text; don't assume the code is correct. |
| Merging is blocked by a required approval | This solo lab requires no approvals. Check that the personal lab rule has approvals unchecked or set to 0. If an inherited policy requires approval, use an approved training repository rather than bypassing that policy. |
| Copilot feedback refers to an earlier commit | Request another Copilot review of the updated PR and inspect the latest diff. |

## Clean up

1. Save required issue, PR, and review links for assessment.
1. Close any remaining lab PRs/issues and delete completed feature branches
   only after checking that no work needs preserving.
1. Optionally delete the exact **YOUR-OWNER/copilot-review-spoon-knife** repository
   if it was created solely for the lab. Keep upstream and shared repositories
   intact. No Azure resource or PAT was created by this exercise.
1. Remove your local lab clone only if it is no longer needed and contains
   no unpushed work.

## Review

You extended the original Spoon-Knife GitHub flow rather than replacing it.
Copilot helped interpret and review changes, while branches, inspected
commits, manual verification, and your merge decision retained control of integration.

Further reading:

- [Original source-control lab](../../basic/02-implement-manage-repositories-using-github.md)
- [GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)
- [Using Copilot code review and requesting re-review](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-code-review)
- [Repository custom instructions](https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/add-custom-instructions/add-repository-instructions)
- [Managing branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/managing-a-branch-protection-rule)
