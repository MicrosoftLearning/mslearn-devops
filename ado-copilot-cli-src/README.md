# Azure DevOps Copilot CLI security review sample

Follow the [practical lab](https://github.com/MicrosoftLearning/mslearn-devops/blob/main/Instructions/agentic/07-integrate-copilot-cli-ado-security-analysis.md)
to create an Azure DevOps project, import the public lab repository into Azure Repos,
configure authentication and permissions, and run the pipeline.

Keep the `ado-copilot-cli-src` folder at the **repository root**. The pipeline
and review prompt use repository-root-relative paths. The sample requires no
application deployment or Azure subscription.

## Contents

| File or folder | Purpose |
|---|---|
| [azure-pipelines-security.yml](azure-pipelines-security.yml) | Azure Pipelines entry point |
| [src/DocumentPortal](src/DocumentPortal) | .NET 8 class library with reviewable security risks |
| [prompts/security-review.md](prompts/security-review.md) | Read-only review instructions and JSON output contract |
| [scripts/process_security_review.py](scripts/process_security_review.py) | Strict validation, Markdown rendering, and threshold reporting |
| [scripts/test_process_security_review.py](scripts/test_process_security_review.py) | Standard-library regression tests |

The library accepts document names without enforcing root-directory containment,
uses ordinary string equality for webhook signatures, and constructs text audit
entries from unescaped fields. The bearer token is masked in the audit entry.
There is no web endpoint: remote exploitability cannot be established from this
library alone. Do not deploy it or treat its implementation as production guidance.

## Pipeline behavior

The default `copilotSecurityMode` is `advisory`; `copilotFailOnSeverity` is `high`.
Valid security findings, including high/critical findings, **do not fail** an
advisory run. The summary explains the policy and reports the threshold result.
Only **Enforce Copilot security gate** intentionally fails on findings, and only
when `copilotSecurityMode` is `enforce`.

Authentication, build, or malformed report failures still fail either mode.
Confidence must be a JSON integer from 1 through 10; probabilities such as
`0.99` are rejected, not silently converted. The raw JSON is published when
artifact initialization succeeded, even if later validation fails.

For pull request validation, the review base is the merge base with the target
branch. Other runs compare with the previous commit, or the empty tree for the
first commit. The complete sample source is reviewed even when the diff is empty.
Azure Repos PR runs require a branch build-validation policy, not a YAML `pr`
trigger.

The `runAdvancedSecurity` parameter defaults to `false`. Enable it only after
configuring GitHub Advanced Security for Azure DevOps for the repository.
CodeQL and dependency scanning complement the Copilot review; they are not
required for the core lab. Secret scanning and push protection are separate
repository services.

The secret `copilotGithubToken` authenticates **GitHub Copilot**, not repository
checkout. The pipeline build-service identity needs **Read** permission on the
Azure Repos repository. The fine-grained GitHub token needs the account-level
**Copilot Requests** permission; it does not need private GitHub repository access.
Checkout credentials are not persisted, and built-in Copilot MCP servers are
disabled. Read-only tool restrictions reduce risk but are not a substitute for
reviewing untrusted input and isolating the job.

## Local validation

From the repository root, run these commands in PowerShell:

```powershell
python -m unittest discover -s ado-copilot-cli-src\scripts -p "test_*.py"
dotnet build ado-copilot-cli-src\src\DocumentPortal\DocumentPortal.csproj --configuration Release
```

To validate a downloaded report without making a Copilot request:

```powershell
python ado-copilot-cli-src\scripts\process_security_review.py `
  --input .\security-review.json `
  --output .\security-review.md `
  --repository-root . `
  --fail-on high `
  --mode advisory
```

Install Python 3 and .NET 8 locally only if you want to run these optional checks.
The hosted pipeline installs its .NET SDK and Node.js and uses the agent's Python.
