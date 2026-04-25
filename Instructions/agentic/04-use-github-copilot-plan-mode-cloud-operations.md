---
lab:
    topic: Agentic
    title: Use GitHub Copilot Plan mode for cloud operations
    description: In this exercise, you learn how to use GitHub Copilot Plan mode for cloud operations, simulating a migration strategy planning from on-premises business-critical workloads to Azure cloud platform
    level: 300
    duration: 45 minutes
    islab: true
    primarytopics:
    - Azure
    - GitHub Copilot
---

# Use GitHub Copilot Plan mode for cloud operations

In this exercise you take on the role of a cloud architect at **Contoso Financial Services**, a mid-sized regional bank that processes mortgage loan origination for customers across multiple US states. The company's core loan processing platform runs on aging on-premises infrastructure and must be migrated to Azure to meet upcoming regulatory examination deadlines, scale for projected growth, and retire hardware that is approaching end of support.

Your task is not to write infrastructure code. Your task is to use GitHub Copilot's Plan agent to research, question, validate, and structure a migration approach that satisfies a set of conflicting business, technical, compliance, and budget requirements — before a single line of code is written.

The plan you produce at the end of this exercise must be detailed enough to present to a Change Advisory Board (CAB) for approval.

This exercise should take approximately 90 minutes to complete.

## Before you start

Before you can start this exercise, you will need to:

1. Sign in to Visual Studio Code with a GitHub account that has access to GitHub Copilot.
2. Confirm that the **GitHub Copilot Chat** extension is installed and active in Visual Studio Code.
3. Ensure you have an active internet connection.

> **Note:** No Azure subscription is required. The Plan agent generates and refines plans without deploying any resources.

> **Note:** GitHub Copilot Free plan users can access Plan mode, but this exercise involves multiple extended planning sessions that can consume a significant portion of the Free plan's monthly chat quota. To avoid interruptions mid-exercise, a paid GitHub Copilot plan (Pro, Business, or Enterprise) is recommended. You can review available plans at [github.com/features/copilot](https://github.com/features/copilot).

---

## Background: the Contoso Financial situation

Read the following briefing before starting the tasks. You will feed this information to the Plan agent progressively across the exercise — as a real architect would, discovering requirements through conversation rather than having everything defined upfront.

### What Contoso has today (on-premises)

- A three-tier ASP.NET Framework 4.8 web application that handles loan origination workflows.
- A SQL Server 2019 cluster (two nodes, active/passive) running the loan database — approximately 4 TB of data, with 200 GB added per year.
- A Windows Server 2019 file share cluster storing scanned loan documents (PDFs, images) — approximately 12 TB currently, growing at 3 TB per year.
- Two domain controllers running Active Directory Domain Services for staff authentication.
- A dedicated SFTP server exchanging data files daily with three external credit bureaus (Equifax, Experian, TransUnion).
- All servers are hosted in a single data center in Dallas, TX, with no DR site.

### Business requirements

- **Regulatory deadline:** The Office of the Comptroller of the Currency (OCC) has flagged the lack of a disaster recovery site as a finding. A compliant DR solution must be in place within 6 months.
- **Availability target:** The loan origination application must achieve 99.95% availability (including planned maintenance).
- **RTO / RPO:** Recovery Time Objective of 4 hours, Recovery Point Objective of 15 minutes.
- **Data sovereignty:** All data — including backups and logs — must remain within the United States.
- **Compliance:** The platform must be PCI-DSS compliant (loan applications collect payment card data for origination fees) and must support SOC 2 Type II audit evidence collection.
- **Zero disruption:** The loan origination system operates from 7 AM to 10 PM Central Time Monday through Saturday. Migrations must not interrupt production during these hours.
- **Budget cap:** The CFO has approved a maximum of **$45,000 per month** in Azure spend for the fully migrated steady-state environment, inclusive of compute, storage, networking, backup, and monitoring. There is no additional budget for migration tooling beyond what is included in Azure Migrate.

### What the Plan agent does not know yet

The agent has none of this context at the start of the exercise. You will introduce requirements progressively and observe how the plan changes with each new constraint.

---

## Task 1: Establish baseline — start with ambiguity and observe the questions

The most powerful capability of Plan mode is not generating output — it is knowing what to ask. In this task, you deliberately start with an underspecified prompt and observe how the Plan agent surfaces the questions that a real architect must answer before any design can proceed.

1. Create a new empty folder on your machine and open it as your workspace in Visual Studio Code. The Plan agent reads workspace context, so a workspace must be open before you start.

2. Open the Chat view in Visual Studio Code by pressing `Ctrl+Alt+I`.

3. Select **Plan** from the agents dropdown.

4. Select an up-to-date language model from the model picker. For best results with complex multi-turn planning sessions, choose a recent model such as **Claude Sonnet** or **GPT-4o**. Older or smaller models may produce less thorough clarifying questions and shallower plans.

5. Submit the following intentionally vague prompt:

    ```text
    /plan We need to migrate our on-premises banking application to Azure.
    The application handles loan origination and we want to make sure it's
    available and secure. Help us plan the migration.
    ```

6. Review the clarifying questions the Plan agent presents as interactive panels. For each question, read the answer options and select the one that best matches the Contoso Financial scenario described in the background section. The agent will present approximately five questions covering areas such as current architecture, database platform, compliance requirements, migration approach, and availability targets.

    > **Note:** The exact questions, their order, and the available answer options may differ from what is described here, depending on the model version and how the agent interprets your initial prompt. Read through each question and select the answer that best fits the Contoso Financial scenario — you do not need to match any specific option exactly. The exercise is designed to work regardless of which answers you choose.

    > **Tip:** Do not worry about selecting the perfect answer — the goal of this step is to observe *what the agent asks*, not to configure the plan precisely. You will provide detailed requirements in Task 2.

7. After you answer all the questions, the Plan agent displays a **summary card** showing each question and your selected answer. Use the copy button on the summary card to copy the full Q&A text, then paste it into a new file named `requirements-discovery.md` in your workspace under a heading `## Questions surfaced by Plan agent`. You will use this file throughout the exercise.

    > **Important:** If the agent skipped the interactive questions and jumped straight to recommending specific Azure services, submit this follow-up prompt to surface what information it needs:
    >
    > ```text
    > Before generating any recommendations, what information do you need from me
    > to produce a reliable migration plan for a regulated financial services environment?
    > ```

8. After pasting the summary, add a section `## Gaps not surfaced` in `requirements-discovery.md`. Note any critical topics from the background briefing that the agent did **not** ask about (for example: data sovereignty, budget cap, OCC regulatory deadline, SFTP integrations with credit bureaus).

---

## Task 2: Feed requirements progressively and observe plan evolution

Now you answer the agent's questions in stages — simulating how requirements are discovered through stakeholder interviews. Observe how the plan changes with each new piece of information.


### Stage A: Provide the technical baseline

1. In the same chat session, Plan Agent asks a clarification question, similar to `What does your current on-premises stack look like?`
2. Submit the following response:

    ```text
    Here is our current environment:

    - Three-tier ASP.NET Framework 4.8 web application (loan origination workflows)
    - SQL Server 2019 two-node active/passive cluster, ~4 TB database, growing 200 GB/year
    - Windows Server 2019 file share cluster, ~12 TB of scanned loan documents, growing 3 TB/year
    - Two Active Directory domain controllers for staff authentication
    - SFTP server exchanging daily data files with Equifax, Experian, and TransUnion
    - Single data center in Dallas, TX — no DR site exists

    The application runs 7 AM to 10 PM Central Time, Monday through Saturday.
    Migrations must not interrupt production during those hours.
    ```

3. Review how the plan evolves. Pay attention to whether the agent:
    - Identifies the SQL Server 2019 version as a migration consideration (it is compatible with Azure SQL Managed Instance, but the agent should flag feature compatibility checks, linked server dependencies, and the choice between Azure SQL MI versus SQL Server on Azure VM).
    - Flags the SFTP integration as a dependency that needs to be preserved or re-routed.
    - Raises the 12 TB document store as a candidate for Azure Blob Storage rather than a VM-based file share.
    - Notes that a single data center with no DR directly conflicts with availability targets (which you haven't stated yet).

4. In `requirements-discovery.md`, under a new heading `## Plan after Stage A`, write two to three sentences summarizing the approach the agent recommended and any risks or questions it raised.

### Stage B: Add availability and recovery requirements

1. Submit the following follow-up:

    ```text
    Availability and recovery requirements:
    - The loan origination application must achieve 99.95% uptime including planned maintenance.
    - Recovery Time Objective: 4 hours.
    - Recovery Point Objective: 15 minutes.
    - The OCC has flagged the lack of a DR site as a regulatory finding.
      A compliant DR solution must be operational within 6 months.
    ```

2. Review the updated plan. Look for whether the agent:
    - Recommends a specific Azure region pair that keeps data within the US (for example, East US 2 and West US 2, or East US and West US).
    - Adjusts the SQL Server strategy to meet the 15-minute RPO (for example, recommending Azure SQL Managed Instance Business Critical tier, or SQL Server on VM with Always On availability groups and log shipping).
    - Identifies that 99.95% availability requires zone-redundant deployments, not just regional failover.
    - Suggests Azure Site Recovery for VM workloads and discusses its RPO capabilities.

3. If the agent does not address zone redundancy, submit:

    ```text
    Does 99.95% availability require zone-redundant deployments within the primary
    region in addition to a secondary region for DR? What Azure service tiers support
    this for SQL Server and for the web application tier?
    ```

4. Add a section `## Plan after Stage B` to `requirements-discovery.md` and note how the recommended architecture changed.

### Stage C: Introduce compliance constraints

1. Submit the following follow-up:

    ```text
    Compliance requirements:
    - PCI-DSS: loan origination collects payment card data for origination fees.
    - SOC 2 Type II: we must be able to produce audit evidence for availability,
      security, and confidentiality controls.
    - Data sovereignty: all data including backups, logs, and replicas must remain
      within the United States. No data may transit or be stored in any non-US Azure region.
    ```

2. Review the updated plan. Look for whether the agent:
    - Recommends network segmentation to isolate the cardholder data environment (CDE) from the rest of the application — for example, a dedicated subnet with restrictive NSG rules and no direct internet access.
    - Mentions Azure Policy or Azure Blueprints to enforce data residency at the subscription level.
    - Recommends Azure Defender for SQL or Microsoft Defender for Cloud for PCI-DSS control evidence.
    - Addresses encryption at rest and in transit for cardholder data.
    - Raises Log Analytics and Microsoft Sentinel as components needed for SOC 2 audit logging.

3. Submit the following validation prompt:

    ```text
    Validate the current plan against PCI-DSS Requirement 1 (network segmentation)
    and Requirement 10 (audit logging). Are there any gaps in what has been planned so far?
    ```

4. Add a section `## Plan after Stage C` to `requirements-discovery.md` and note the compliance gaps the agent surfaced.

---

## Task 3: Introduce the budget constraint and force trade-off analysis

This is where Plan mode's value becomes most visible. You now introduce a hard budget cap and observe how the agent reasons about trade-offs between what the requirements demand and what the budget allows.

1. In the same chat session, submit the following:

    ```text
    Budget constraint: the CFO has approved a maximum of $45,000 per month
    in Azure steady-state spend. This is inclusive of compute, storage,
    networking, backup, and monitoring. There is no additional budget for
    migration tooling beyond Azure Migrate, which is included in the subscription.

    Given what you have planned so far, does this budget support the recommended
    architecture? If not, what trade-offs must be evaluated?
    ```

2. Read the agent's response carefully. A well-formed plan response should reason through the cost implications of the recommended architecture — for example:
    - SQL Managed Instance Business Critical (zone-redundant) can cost $8,000–$15,000/month depending on vCores — is that within budget given the other components?
    - Azure Site Recovery costs per protected VM — how many VMs are there and what is the estimated cost?
    - Blob Storage for 12 TB of documents with geo-redundant storage (GRS) — what is the monthly storage cost?
    - Application Gateway with WAF tier for PCI-DSS versus Standard tier — what is the cost difference?

    > **Note:** The Plan agent does not have real-time Azure pricing data. It should indicate this and recommend using the [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/){:target="_blank"} at `https://azure.microsoft.com/pricing/calculator/` to validate estimates. If the agent states specific prices with certainty, treat those as approximations and verify them in the calculator.

3. If the agent does not proactively identify a potential budget conflict, submit:

    ```text
    Estimate the approximate monthly cost of the architecture you have planned.
    Identify the top three cost drivers. For each one, suggest a lower-cost
    alternative and explain what requirement or risk is affected by the trade-off.
    ```

4. Review the trade-off options the agent proposes. Based on its suggestions, choose one trade-off to accept and one to reject, then submit a follow-up explaining your decisions:

    ```text
    We will accept [trade-off option A from the agent's response] because [reason].
    We will not accept [trade-off option B] because the [requirement] is non-negotiable.
    Update the plan accordingly.
    ```

    > **Tip:** This kind of decision conversation — where you push back on specific trade-offs with business justification — is exactly what Plan mode is designed for. The agent should update the plan to reflect your decisions without losing the context of earlier requirements.

5. In `requirements-discovery.md`, add a section `## Budget trade-offs accepted` and `## Budget trade-offs rejected` and document your reasoning. This section will become part of the CAB submission.

---

## Task 4: Validate architecture against all requirements

Before breaking the plan into workstreams, you run a structured validation pass to ensure the current plan is internally consistent and covers all stated requirements.

1. Submit the following prompt to trigger a full validation:

    ```text
    We have now established all requirements. Please perform a structured validation
    of the current plan against each of the following requirements and flag any
    gaps, conflicts, or unresolved risks:

    1. 99.95% availability including planned maintenance
    2. RTO 4 hours, RPO 15 minutes
    3. OCC DR finding resolved within 6 months
    4. All data remains in the United States
    5. PCI-DSS compliance for cardholder data environment
    6. SOC 2 Type II audit evidence capability
    7. No production disruption during operating hours (Mon-Sat, 7 AM - 10 PM CT)
    8. SFTP integration with Equifax, Experian, TransUnion preserved
    9. Active Directory authentication preserved for staff
    10. Monthly Azure spend does not exceed $45,000
    ```

2. Review the validation output. For each requirement, the agent should indicate one of:
    - **Covered** — the plan addresses this requirement with specific components.
    - **Partially covered** — the plan addresses this requirement but a gap or assumption remains.
    - **Not covered** — the plan does not address this requirement.
    - **Conflict** — this requirement conflicts with another requirement or with a trade-off decision made in Task 3.

3. For any requirement marked **Partially covered**, **Not covered**, or **Conflict**, submit follow-up prompts to resolve the gap before moving to the next task. For example:

    ```text
    The SFTP integration with the credit bureaus was not addressed in the plan.
    What Azure service should replace or wrap the on-premises SFTP server?
    Consider that the credit bureaus connect inbound to our SFTP server using
    static IP allowlisting — our new solution must present a static public IP.
    ```

4. Continue iterating until all ten requirements are marked **Covered** in the plan.

5. In `requirements-discovery.md`, add a section `## Validation results` and record the final status of each requirement.

---

## Task 5: Break the plan into workstreams and produce a CAB-ready artifact

A single monolithic plan is difficult to review, approve, and assign to teams. In this task, you break the validated plan into focused workstreams and produce a structured artifact suitable for a Change Advisory Board submission.

### Identify workstreams

1. Submit the following prompt:

    ```text
    Break the validated migration plan into independent workstreams that can be
    assigned to separate teams. Each workstream should have: a name, a brief scope
    description, the team responsible, key dependencies on other workstreams,
    an estimated duration, and the business requirements it satisfies.
    ```

2. Review the workstreams the agent identifies. A well-structured response should surface workstreams similar to the following (the exact content will vary based on the plan the agent generated across earlier tasks):

    - **Identity and connectivity** — Migrating AD DS, setting up Azure AD Connect or Entra Connect, establishing ExpressRoute or VPN connectivity.
    - **Data platform** — Migrating SQL Server 2019, validating compatibility with Azure SQL MI versus SQL Server on Azure VM, and confirming RPO/RTO targets are achievable with the chosen replication strategy.
    - **Document storage** — Migrating the 12 TB file share to Azure Blob Storage, including tiering policy and access migration.
    - **Application tier** — Migrating the ASP.NET application, configuring App Service or IIS on VM, integrating with Azure AD.
    - **External integrations** — Re-routing SFTP exchange with credit bureaus through Azure SFTP or a managed file transfer service.
    - **Security and compliance** — Deploying the CDE segmentation, Defender for Cloud, Log Analytics, and policy baselines.
    - **DR validation** — Testing and documenting the DR runbook to satisfy the OCC finding.

3. If any of the workstreams above are missing from the agent's response, prompt for them specifically.

### Generate a focused sub-plan for the highest-risk workstream

4. Identify which workstream carries the highest risk based on the agent's dependency mapping and duration estimates. Submit the following prompt, replacing `[workstream name]` with the workstream you identified:

    ```text
    Generate a detailed implementation plan for the [workstream name] workstream only.
    This plan will be handed to the responsible team for implementation.
    Include: pre-migration prerequisites, implementation steps in sequence,
    rollback criteria and rollback steps for each phase, validation gates that
    must pass before proceeding to the next phase, and post-migration verification.
    ```

5. Review the sub-plan. Confirm that it includes explicit rollback criteria — conditions under which the team must stop and revert — rather than only rollback steps. Rollback criteria are the decision rules (for example, "if replication lag exceeds 30 minutes for more than 15 consecutive minutes, halt the cutover").

6. If rollback criteria are missing, submit:

    ```text
    Add rollback criteria for each phase — specific, measurable conditions that
    trigger a rollback decision, not just the steps to execute a rollback.
    ```

### Produce the CAB submission summary

7. Submit the following prompt to generate the final artifact:

    ```text
    Produce a Change Advisory Board submission summary for the full Contoso Financial
    migration. Structure it with the following sections:

    1. Executive summary (3-5 sentences, non-technical)
    2. Business justification and regulatory drivers
    3. Scope of change
    4. Architecture overview (describe in text; do not generate diagrams)
    5. Risk assessment with likelihood and impact ratings for each identified risk
    6. Compliance coverage (PCI-DSS, SOC 2, OCC DR finding)
    7. Workstream summary with estimated durations and dependencies
    8. Budget summary and budget governance approach
    9. Rollback strategy at the program level
    10. Approval conditions — what must be true before any workstream begins production migration
    ```

8. Review the CAB summary. Evaluate it against the following quality criteria:
    - The executive summary is understandable to a non-technical reader (CFO, Chief Risk Officer).
    - Every risk in the risk assessment maps back to a specific requirement or architectural decision.
    - The compliance section cites specific PCI-DSS requirements and how the plan addresses them.
    - The budget summary reflects the trade-offs made in Task 3.
    - The approval conditions are specific and verifiable — not vague statements like "ensure security is in place."

9. For any section that does not meet the quality criteria, submit a targeted refinement prompt. For example:

    ```text
    The risk assessment risk ratings are not justified. For each risk, explain
    why you assigned that likelihood and impact rating based on the specifics
    of the Contoso environment.
    ```

10. Save the final CAB summary: in the Chat view, select all text of the agent's CAB summary response, copy it, and save it to a new file in your workspace named `cab-submission-draft.md`.

---

## Task 6: Encode standards and choose the handoff strategy

With the CAB-ready plan complete, you now set up the workspace for the implementation teams and choose the appropriate handoff path.

1. In your workspace, create the folder `.github` and inside it create `copilot-instructions.md`.

2. Based on the architecture decisions and trade-offs established during the exercise, populate `copilot-instructions.md` with the standards the implementation teams must follow. At minimum, include:

    ```markdown
    ## Contoso Financial — Azure Infrastructure Standards

    ### Naming conventions
    - Pattern: {resource-type}-{workload}-{environment}-{region}-{instance}
    - Examples: sql-loanorigination-prod-eus2-001, st-loandocs-prod-eus2-001
    - Environments: prod, dr, dev, test

    ### Mandatory resource tags
    All resources must include: CostCenter, Environment, Owner, Workstream, ComplianceScope

    ### Tooling
    - Infrastructure as Code: Bicep only (no ARM templates, no Terraform)
    - Configuration management: PowerShell DSC for Windows Server workloads
    - Secret management: Azure Key Vault; no credentials in source code or parameter files

    ### Security baseline
    - All NSG rules must include a Description property
    - No public IP addresses except on Application Gateway and the managed SFTP endpoint
    - Just-in-time VM access must be enabled for all IaaS virtual machines
    - Azure Defender must be enabled for SQL, Storage, and Key Vault

    ### Compliance
    - PCI-DSS CDE workloads must be deployed only to the dedicated CDE subnet
    - Log retention minimum: 365 days in Log Analytics, 7 years in cold storage
    - All deployment changes must be reviewed by at least two engineers before applying to prod

    ### Budget governance
    - Monthly budget alert at $40,000 (action group: email operations lead)
    - Hard budget alert at $44,000 (action group: email CFO and CTO)
    - Each workstream team is responsible for estimating and tracking its resource costs
    ```

3. Save the file.

4. In the Chat view, start a new chat session with **Plan** selected. Submit the following prompt and verify the agent incorporates your custom instructions:

    ```text
    /plan Create the Bicep parameter file structure for the Contoso Financial
    data platform workstream. It needs to support prod and dr environments
    in East US 2 and West US 2 respectively.
    ```

5. Confirm that the agent's plan reflects the standards from `copilot-instructions.md` — for example, using the defined naming pattern, including the required tags, and referencing Key Vault for secrets rather than inline parameter values.

6. Review the following handoff options and select the most appropriate one for the Contoso Financial migration:

    | Handoff option | Characteristics |
    |----------------|-----------------|
    | **Same session (Agent)** | Immediate implementation in your local workspace; you review edits inline |
    | **Copilot CLI (background)** | Implementation runs in a Git worktree; you continue other work while it runs |
    | **Cloud agent (pull request)** | Copilot opens a pull request; team reviews, CI validates, and approves before merge |

7. In `cab-submission-draft.md`, add a section at the bottom:

    ```markdown
    ## Implementation handoff strategy

    Selected handoff: <!-- your choice -->

    Justification: <!-- 2-3 sentences explaining why this option fits Contoso's
    change management requirements, team structure, and compliance needs -->
    ```

    > **Tip:** Given Contoso's requirements — two-engineer review, CI pipeline validation, PCI-DSS change audit trail, and the OCC regulatory scrutiny — the cloud agent (pull request) approach aligns most directly with the change management and audit evidence requirements.

> **Note:** At the end of the Plan agent cycle, GitHub Copilot may suggest proceeding with actual implementation — generating Bicep templates, running deployments, or switching to the Agent mode to execute the plan. This is **not** part of this lab exercise. You may explore that as an optional extension, but be aware that deploying Azure resources will incur costs for the duration they are running. If you choose to proceed, ensure you understand the resources being deployed and clean them up promptly when done.
>
> If you are interested in hands-on implementation exercises using GitHub Copilot's multi-agent capabilities, the broader learning path includes dedicated exercises that focus on that topic.

---



## Clean up

Now that you've finished the exercise, remove the local files to keep your workspace clean.

1. Delete `.github/copilot-instructions.md` and the `.github` folder if it is now empty.
2. You may keep `requirements-discovery.md` and `cab-submission-draft.md` as reference documents if you want to review them later.
3. Close any open chat sessions in the Chat view.

> **Note:** No Azure resources were deployed during this exercise. There is nothing to clean up in Azure.

---

## Summary

Before finishing, review `requirements-discovery.md` and consider the following questions — you do not need to submit answers, but thinking through them reinforces the key learning from this exercise:

- How many of the questions the Plan agent asked in Task 1 would a real stakeholder interview have surfaced? Which ones would likely have been missed without the agent's prompting?
- At which point in the exercise did the plan change most significantly? What does that tell you about the relative importance of that requirement?
- The budget constraint in Task 3 forced trade-off decisions. In a real engagement, who in the organization owns those decisions — the architect, the CFO, the CRO, or a committee?
- How does the CAB summary produced in Task 5 differ in quality from what you would have produced if you had started with a specific "create Bicep files" prompt?

