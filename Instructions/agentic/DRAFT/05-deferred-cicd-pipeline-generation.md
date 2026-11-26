# Deferred CI/CD prompts from cloud-operations lab 05

> **AUTHORING EXTRACT - NOT AN ACTIVE LAB.** Preserved on November 25, 2026 for a future CI/CD exercise.

The original task is retained below, including its original numbering. It expects the Bicep template from lab 05's Task 2. Before reuse, define the new lab's inputs and validate its platform-specific approvals, identity, artifact selection and recovery behavior. Generated pipeline syntax does not establish that a pipeline or rollback works. This extract is not automatically assigned to the Build module; its infrastructure deployment prompts also need review against the Release module boundary.

---

## Task 3: CI/CD Pipeline Generation for Azure DevOps and/or GitHub Actions

> **Note**: No access to an Azure DevOps Organization or GitHub Actions is required to complete this task. You generate the pipeline syntax, but won't run the actual pipeline.

**Objective:** Use GitHub Copilot to generate multi-stage deployment pipelines for both Azure DevOps and GitHub Actions, including environment approvals and an Infrastructure as Code validation stage.

---

### Step 4.1 — Generate an Azure DevOps Pipeline

1. In Copilot Chat, prompt:

    ```
    Generate an Azure DevOps multi-stage YAML pipeline for deploying the Bicep template
    from this lab across two environments: staging and production.
    Requirements:
    - Trigger on changes to the main branch under the infra/ folder
    - Stage 1 (Validate): Run az bicep build and az deployment group what-if
      against the staging resource group
    - Stage 2 (Deploy Staging): Deploy the Bicep template to rg-iaclab-staging
      using an Azure service connection called "sc-iaclab-staging"
    - Stage 3 (Deploy Production): Deploy to rg-iaclab-production using
      "sc-iaclab-production" with a manual approval gate before execution
    - Use variable groups: "vg-iaclab-staging" and "vg-iaclab-production"
    - All stages run on ubuntu-latest hosted agents
    ```

2. From the Chat response view, inside the YAML snippet, select **apply in editor** from the chat response view. 
3. Then, select **New untitled editor** and **saving** the new file as `azure-pipelines.yml`

4. Ask Copilot to add a rollback stage:

    ```
    Add a Stage 4 (Rollback) that only triggers if Stage 3 (Deploy Production) fails.
    It should re-deploy the last successful Bicep artifact from the staging drop.
    ```

---

### Step 4.2 — Generate a GitHub Actions Equivalent

1. With `azure-pipelines.yml` open in the editor, prompt:

    ```
    Translate this Azure DevOps pipeline into an equivalent GitHub Actions workflow.
    Use:
    - OIDC-based Azure authentication (azure/login action with federated credentials)
    - GitHub Environments named "staging" and "production"
      (production requires a reviewer approval)
    - Reusable workflow jobs where possible
    - Secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID from GitHub Secrets
    ```

2. Save as `.github/workflows/deploy-infra.yml`.

3. Ask Copilot to add a compliance check:

    ```
    Add a job before the staging deployment that runs az policy state list
    and fails the workflow if any non-compliant resources are found
    in the staging resource group.
    ```

---

