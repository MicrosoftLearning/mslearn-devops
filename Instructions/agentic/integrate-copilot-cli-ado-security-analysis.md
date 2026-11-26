---
lab:
  topic: Agentic
  title: Integrate GitHub Copilot CLI into Azure Pipelines for security analysis
  description: Create an Azure DevOps project and configure a pipeline that uses GitHub Copilot CLI to produce a validated, ranked security report without blocking builds on advisory findings.
  level: 400
  duration: 60 minutes
  islab: true
  primarytopics:
    - Azure DevOps
    - GitHub Copilot
    - DevSecOps
    - Agentic DevOps
---

# Integrate GitHub Copilot CLI into Azure Pipelines for security analysis

## Exercise scenario

Your team stores application code in Azure Repos and uses Azure Pipelines for
continuous integration. You want to add an AI-assisted security review that
explains risks, ranks findings, and suggests validation steps. You also want to
distinguish a security finding from a broken review process.

In this exercise, you create a private Azure DevOps project and import a small
.NET document-processing library. Its pipeline checks out the source, builds the
library, runs GitHub Copilot CLI with read-only review instructions, validates
the resulting JSON, and publishes a Markdown report.

The core lab uses **advisory mode**: security findings, even high-severity ones,
do not intentionally fail the pipeline. Authentication, build, and malformed
report errors still fail. An optional task demonstrates a separate enforcement
gate after a valid report has been published.

By the end of this exercise, you will be able to:

- Configure separate identities for Azure Repos checkout and GitHub Copilot.
- Store a narrowly scoped GitHub token as an Azure Pipelines secret.
- Grant a pipeline build identity Read access without broadening its scope.
- Inspect a security report and distinguish findings from execution failures.
- Explain how advisory AI review complements deterministic security scanning.

This exercise should take approximately **60 minutes** to complete.

## Before you start

Ensure you have:

| Requirement | Details |
|---|---|
| Azure DevOps organization | Sign in at [Azure DevOps](https://dev.azure.com). You need permission to create a project, import a repository, create pipelines, and manage repository security. Project Administrators can import repositories; otherwise the Git project-level Create repository permission is required. Ask an administrator to perform security steps if necessary. |
| Hosted pipeline capacity | The organization needs an available Microsoft-hosted Linux parallel job. New organizations may need to [request the free hosted-job grant or purchase capacity](https://learn.microsoft.com/azure/devops/pipelines/licensing/concurrent-jobs). |
| GitHub account with Copilot access | The account must be permitted to use Copilot CLI and have available AI usage allowance. Organization policies may restrict CLI use or token creation. |
| Fine-grained PAT permission | You must be allowed to create a user-owned fine-grained GitHub personal access token with the account-level Copilot Requests permission. |
| Browser | Use a web browser to access Azure DevOps and GitHub. Local Git, PowerShell, and VS Code are not required for the core lab. |

You do **not** need an Azure subscription, a running application, a local
Copilot CLI installation, or GitHub Advanced Security for the core lab. The
hosted pipeline installs Node.js, the .NET SDK, and the pinned Copilot CLI.

> **Important**: This sample deliberately contains reviewable security risks.
> Do not deploy it or use it as a production implementation. Copilot sends
> prompts and relevant source context to its service. Use only the supplied
> non-sensitive sample and follow your organization's AI policies. Each review
> can consume AI usage allowance and incur charges.

## Task 1: Create the project and import the starter repository

Use Azure Repos' built-in import to bring the public lab repository into your
private project. No local clone, file copy, or initial Git push is needed.

1. Open [Azure DevOps](https://dev.azure.com) in your browser and select
   your organization.
1. On the organization Projects page, select **New project**.
1. Enter **ado-copilot-security-lab** as the project name.
1. Set **Visibility** to **Private**, select **Git** for version control if the
   option is displayed, and select **Create**.
1. Open the project and select **Repos > Files**.
1. In the default **ado-copilot-security-lab** repository's empty Files page,
   select **Import** under **Import a repository**. Do not initialize it with
   a README first; import requires a new or empty destination repository.
1. In the import dialog, select **Git** as the repository type if prompted.
1. Enter this **Clone URL**:

   ```text
   https://github.com/MicrosoftLearning/mslearn-devops.git
   ```

1. Leave **Requires authentication** unselected. The source repository is
   public, so no GitHub token or service connection is needed for this import.
1. Select **Import** and wait for the import to finish. Refresh **Repos >
   Files** if necessary.
1. Confirm the selected repository is **ado-copilot-security-lab** and select
   branch **main**.

> **Note**: Import copies the entire repository and its Git history, not just
> one folder. It creates an independent Azure Repos copy; changes made in your
> project do not update the public GitHub repository, and later GitHub changes
> are not synchronized automatically. You will use only `ado-copilot-cli-src`
> for this exercise.

**Expected result:** Your private project contains an Azure Repos repository
named **ado-copilot-security-lab**, populated from the public lab repository.

## Task 2: Verify the imported security sample

1. In **Repos > Files**, keep the **main** branch selected.
1. Open the **ado-copilot-cli-src** folder. If it is missing, confirm that
   the import completed successfully and that you selected the **main** branch
   of the correct repository.
1. Inspect the following files:

   | Path below `ado-copilot-cli-src` | Purpose |
   |---|---|
   | `azure-pipelines-security.yml` | Pipeline definition |
   | `src/DocumentPortal/DocumentService.cs` | Sample library with reviewable security risks |
   | `prompts/security-review.md` | Review scope, trust boundary, and JSON output contract |
   | `scripts/process_security_review.py` | Report validation and rendering |
   | `scripts/test_process_security_review.py` | Processor regression tests |

1. Keep the folder at the repository root without renaming or moving it. The
   pipeline's paths are relative to the repository root, **not** to the YAML
   file's directory.
1. Confirm the pipeline you will select is
   **`ado-copilot-cli-src/azure-pipelines-security.yml`**. Ignore other pipeline
   definitions, lab folders, and infrastructure samples in the imported
   repository. Do not deploy those resources for this exercise.

**Expected result:** The security sample and its pipeline are available in
Azure Repos. No local setup or source changes were needed.

## Task 3: Create the GitHub token for Copilot

1. In a separate browser tab, sign in to the **GitHub account with Copilot
   access**.
1. Select your profile picture, then **Settings > Developer settings >
   Personal access tokens > Fine-grained tokens > Generate new token**.
1. Enter **ado-copilot-security-lab** as the token name.
1. Choose a short expiration that covers the lab, such as **7 days** if
   permitted by your account's policy.
1. Under **Resource owner**, select **your personal account**, not an
   organization.
1. Under **Repository access**, leave **Public repositories** selected
   (the UI may label this **Public repositories (read-only)**). Do not select
   **All repositories** or grant access to private GitHub repositories.

   Your source is in **Azure Repos**. This setting controls GitHub repository
   access only. The pipeline checks out the code using its Azure DevOps
   identity, then Copilot reviews the checked-out files. No private GitHub
   repository access is required.

1. Under **Permissions**, select the **Account** tab, select **Add permissions**,
   and add **Copilot Requests** with **Read-only** access. Do not add repository
   write permissions.
1. Select **Generate token** and copy the value for the next task. A fine-grained
   token normally begins with `github_pat_`.

> **Important**: Do not use a classic PAT (`ghp_`), an Azure DevOps PAT, or
> `System.AccessToken` for Copilot authentication. Do not paste the token into
> source, YAML, a chat, or a screenshot. Create a dedicated token for this lab
> and revoke it after the exercise.

If **Copilot Requests** is unavailable, confirm that the resource owner is
your personal account. If policies prevent token creation or Copilot CLI use,
stop and contact your administrator; do not bypass those policies.

**Expected result:** You have a short-lived token for GitHub Copilot requests
without granting access to private GitHub repositories.

## Task 4: Create the pipeline and store the secret

1. Return to **Azure DevOps > ado-copilot-security-lab**.
1. Select **Pipelines > Pipelines > New pipeline** (or **Create Pipeline** for
   the first pipeline).
1. Under **Where is your code?**, select **Azure Repos Git**.
1. Select the **ado-copilot-security-lab** repository.
1. Under **Configure your pipeline**, select **Existing Azure Pipelines YAML
   file**. Do not select a starter pipeline.
1. Select branch **main** and path
   **`/ado-copilot-cli-src/azure-pipelines-security.yml`**, then **Continue**.
1. On the Review page, inspect the variables:

   ```yaml
   variables:
     copilotCliVersion: '1.0.89'
     copilotSecurityMode: 'advisory'
     copilotFailOnSeverity: 'high'
   ```

   Keep `advisory` for the core exercise. Keep GitHub Advanced Security disabled:
   the `runAdvancedSecurity` parameter defaults to `false`.

1. On the Review page, select **Variables > New variable**.
1. Set **Name** to **copilotGithubToken**, paste the GitHub token into **Value**,
   and select **Keep this value secret**.
1. Leave **Let users override this value when running this pipeline**
   unselected. Save the variable and close the Variables panel.
1. Confirm that the review step maps the secret as an environment variable:

   ```yaml
   env:
     COPILOT_GITHUB_TOKEN: $(copilotGithubToken)
   ```

   The secret belongs in the pipeline Variables panel, not as a literal YAML
   value. Only the Copilot review step receives it.

1. Open the drop-down next to **Save and run** and select **Save** if available.
   If only **Save and run** is available, use it after saving the secret. That
   first run also creates the build-service identity; checkout may fail until
   you finish Task 5.
1. From the pipeline's **More actions (...)** menu, select **Rename/move**, if
   available, and rename it **copilot-security-review**.

**Expected result:** The pipeline uses the imported YAML and stores
`copilotGithubToken` as a secret. No token is visible in the YAML.

## Task 5: Grant the pipeline identity Read access

Your personal ability to browse the repository does not prove that the
pipeline can check it out. Checkout uses a **build-service identity**.

1. In the project's lower-left corner, select **Project settings**.
1. Under **Pipelines**, select **Settings** and inspect
   **Limit job authorization scope to current project for non-release pipelines**.
1. Determine which build identity applies:

   | Effective setting | Identity to select |
   |---|---|
   | Enabled at the project or organization level | `ado-copilot-security-lab Build Service (<your-organization>)` |
   | Disabled at both levels | `Project Collection Build Service (<your-organization>)` |

   An organization-level setting can enforce project scope. Ask an
   organization administrator to confirm the effective setting if necessary.
   **Do not disable the scope restriction to make checkout work.**

1. In **Project settings**, under **Repos**, select **Repositories**.
1. Select repository **ado-copilot-security-lab**, then its **Security** tab.
1. Search the identities list for the build-service identity from the table
   and select it. If necessary, use the identity search field to add/select it.

   If the project build identity is not available yet, go to **Pipelines >
   Pipelines > copilot-security-review > Run pipeline**, queue one run on
   `main`, and return to the repository Security page after the job starts.
   The project-scoped identity is created when a pipeline first runs.

1. Set **Read** to **Allow** for that identity. This is the permission needed
   for source checkout; do not grant Contribute or administrator access.
1. Verify there is no applicable **Deny**. If Read is denied through a group,
   ask an administrator to resolve that specific restriction. A direct Allow
   generally does not override an inherited group Deny.
1. Return to your pipeline. If Azure DevOps displays **This pipeline needs
   permission to access a resource**, select **View** and **Permit** for the
   lab repository only. Resource authorization and repository Read permission
   are separate checks.

**Expected result:** The pipeline's actual build identity can read the source
repository. Your GitHub token has not been used for checkout.

## Task 6: Run the advisory security review

1. Select **Pipelines > Pipelines > copilot-security-review > Run pipeline**.
1. Select branch **main** and leave **Run GitHub Advanced Security tasks**
   unchecked (`false`).
1. Select **Run** and open the new run. Allow several minutes for setup and
   the model request.
1. Open the job and inspect these tasks:

   | Task | What to verify |
   |---|---|
   | Checkout | Fetch and checkout succeed without `TF401019`. |
   | Use .NET 8 SDK / Use Node.js 22 | Required runtimes are available. |
   | Test security report processor | Regression tests pass. |
   | Build security scenario | The sample class library builds successfully. |
   | Install pinned GitHub Copilot CLI | The log shows the pinned CLI version. |
   | Review branch security with Copilot | Copilot completes without an authentication error. Its report is redirected to a file, so a short log is normal. |
   | Validate and render security review | The JSON satisfies the contract and the log states the threshold result and advisory policy. |
   | Publish Copilot security review | The artifact is uploaded. |
   | Enforce Copilot security gate | **Skipped**, because the selected mode is `advisory`. |

**Expected result:** A successful run publishes a report. A high-severity
finding does **not** intentionally fail advisory mode. If the run fails, use
Task 8 to distinguish an execution failure from a security finding.

## Task 7: Interpret the report and its limitations

1. Open the run's **Summary** and locate the uploaded **Copilot security
   review** Markdown summary.
1. Under **Pipeline policy**, confirm that the report states:

   > Advisory mode: security findings do not fail the pipeline.

1. Under **Published artifacts** (or the artifact link on the run), select
   **copilot-security-review**. Browse or download it and inspect:

   | File | Contents |
   |---|---|
   | `security-review.json` | Raw model response; keep it as evidence. |
   | `security-review.md` | Validated, ranked report for human review. |
   | `review-base.txt` | Git revision used as the comparison base. |
   | `changed-files.txt` | Files changed between the review base and HEAD. |

1. Compare each finding with
   `ado-copilot-cli-src/src/DocumentPortal/DocumentService.cs` in **Repos > Files**.
   Confirm that the named file and line numbers exist and that the evidence
   supports the claim.
1. Review **severity**, **confidence**, **impact**, **recommendation**, and
   **validation**. Confidence uses integer scores **1 through 10**.
1. Look for these potential observations, without treating this list as an
   exact answer key:

   - Document names can escape the intended directory because the library
     combines a caller-provided name with the root without a containment check.
   - Ordinary string comparison does not guarantee constant-time signature
     verification.
   - Unescaped audit fields can produce ambiguous or injected text entries.

   The sample masks the bearer token in audit entries. The library has
   no web entry point or logging sink, so remote exploitability and downstream
   log injection cannot be assumed.

1. Read the **Limitations** and **Likely GHAS overlap** sections. These labels
   describe expected scanner overlap, not evidence that CodeQL or another
   scanner ran. Copilot output is nondeterministic: wording, number of findings,
   and confidence can vary. A successful report is not proof that the code is
   secure.
1. Select one evidence-backed finding and create a work item in **Boards >
   Work Items > New Work Item**. Choose a type available in your project's
   process, such as Issue or Bug. Include the run link, source location,
   suggested remediation, and proposed verification tests. Do not include
   credentials or assume the proposed fix is correct without review.

**Expected result:** You can explain an evidence-backed risk and propose a
human-reviewed next step without confusing it with a pipeline setup failure.

## Task 8: Diagnose setup and report-processing failures

Use the **first failed task** to identify the cause. A later error can be a
consequence of an earlier failure.

| Symptom | Meaning and next action |
|---|---|
| Checkout reports `TF401019` or Git exit code 128 | Recheck the actual build identity's repository Read permission and any resource authorization in Task 5. Your personal access does not substitute for pipeline access. |
| No hosted parallelism or run stays queued | Ask the organization administrator to verify hosted-job capacity. |
| Review reports `No authentication information found` | Open **Pipelines > copilot-security-review > Edit > Variables**. Confirm the secret is named exactly `copilotGithubToken`, has a value, and matches the YAML environment mapping. Do not print it to diagnose the problem. |
| Review reports unauthorized, forbidden, expired token, or unavailable usage | Verify the token's expiration, personal resource owner, Copilot Requests permission, the account's Copilot access, organization CLI policy, and available usage. Generate a replacement secret if necessary. |
| Validation reports an invalid confidence, missing file, invalid lines, malformed JSON, or incorrect ranking | The model response did not satisfy the output contract. Inspect the raw JSON artifact and the review prompt. Verify confidence is an integer from 1 through 10 and source locations are repository-root-relative. Correct the cause and rerun; do not bypass validation. |
| Report contains a high finding but the run succeeds | Expected in **advisory** mode. Findings are evidence for review, not an automatic failure. |
| Enforce gate fails after a report was published | Expected only in **enforce** mode when at least one finding meets the severity threshold. |

When validation fails, `security-review.json` can still be published, but
`security-review.md` is not produced. If checkout or artifact initialization
failed, no review artifact is expected.

## Optional task: Demonstrate the enforcement gate

Do this only after completing a successful advisory run. It adds another
model request and may incur usage.

1. In **Repos > Files**, open
   `ado-copilot-cli-src/azure-pipelines-security.yml` and select **Edit**.
1. Change only:

   ```yaml
   copilotSecurityMode: 'enforce'
   ```

1. Commit the change to a **new branch** named **security-gate-demo**. Do not
   merge it into `main`.
1. Run **copilot-security-review** manually using **security-gate-demo**.
1. Inspect the result. If Copilot reports a `high` or `critical` finding and
   validation succeeds, the report is published first and **Enforce Copilot
   security gate** then fails intentionally. If no finding meets the threshold,
   that gate is skipped. Model variability means failure is not guaranteed.
1. Return to branch **main** for normal advisory runs.

For production, do not make nondeterministic AI findings the sole merge
authority without measuring precision and coverage. If adding PR validation
for Azure Repos, configure **Repos > Branches > main > Branch policies > Build
validation**; a YAML `pr` trigger does not configure Azure Repos PR validation.

## Optional task: Add deterministic security scanning

With administrator approval and appropriate licensing, enable GitHub Advanced
Security for Azure DevOps for the sample repository. Then queue a run with
**Run GitHub Advanced Security tasks** selected. Review CodeQL and dependency
scanning results separately from Copilot's report. This option can have
additional billing and prerequisites and is not required for the core lab.

The sample declares no third-party package dependencies, so do not expect it
to demonstrate a vulnerable dependency. Secret scanning and push protection
are repository services, not extra steps in this pipeline.

See [Configure GitHub Advanced Security for Azure DevOps](https://learn.microsoft.com/azure/devops/repos/security/configure-github-advanced-security-features)
and [Set up code scanning](https://learn.microsoft.com/azure/devops/repos/security/github-advanced-security-code-scanning).

## Clean up

1. In GitHub, open **Settings > Developer settings > Personal access tokens >
   Fine-grained tokens** and revoke/delete the **ado-copilot-security-lab**
   token.
1. In Azure DevOps, open the pipeline's **Edit > Variables**, delete
   **copilotGithubToken**, and save.
1. Disable or delete the lab pipeline to prevent additional review requests.
   Delete the optional **security-gate-demo** branch if you created it.
1. If the project was created solely for this exercise, select **Project
   settings > Overview > Delete** and confirm the exact lab project name.
   Keep shared projects and organization resources intact.
1. If you optionally cloned the repository for local inspection, remove that
   checkout only if it is no longer needed. This browser-based lab created no
   Azure application resources to delete.

## Review

In this exercise, you imported a sample into Azure Repos, configured a
least-privilege GitHub token and an Azure DevOps build identity, and ran a
read-only Copilot CLI security review. You validated the model's output before
publishing it and kept advisory findings separate from intentional enforcement
and execution failures.

For further reading:

- [Sample files and local validation commands](../../ado-copilot-cli-src/README.md)
- [Authenticate GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli)
- [Securely access repositories from pipelines](https://learn.microsoft.com/azure/devops/pipelines/security/secure-access-to-repos)
