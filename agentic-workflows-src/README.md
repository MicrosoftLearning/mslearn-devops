# GitHub Agentic Workflows security review sample

Follow the [practical lab](../Instructions/agentic/DRAFT/08-integrate-agentic-workflows-github-security-analysis.md)
to create an isolated GitHub fork, configure Copilot authentication, and run an
advisory security review with GitHub Agentic Workflows.

Keep the `agentic-workflows-src` folder at the **repository root**. The lab's
workflow uses repository-root-relative paths.

## Contents

| File or folder | Purpose |
|---|---|
| [src/DocumentPortal](src/DocumentPortal) | .NET 8 class library with reviewable security risks |
| [src/DocumentPortal/DocumentService.cs](src/DocumentPortal/DocumentService.cs) | Document-path handling, audit-entry construction, and webhook-signature comparison |

The sample deliberately contains reviewable risks. Do not deploy it or treat
its implementation as production guidance. It has no web endpoint; remote
exploitability cannot be established from this library alone.

## Workflow behavior

The lab supplies the Markdown workflow definition. A deterministic GitHub
Actions job builds the library before the agent reads source at the recorded
commit. The agent requests one advisory report issue through a bounded safe
output. A human validates each observation against the cited source.

The build does not validate the report's technical accuracy. Findings do not
act as a merge gate or security certification.

## Local validation

If you have .NET 8 installed, run this optional check from the repository root
in PowerShell:

```powershell
dotnet build agentic-workflows-src\src\DocumentPortal\DocumentPortal.csproj --configuration Release
```

The lab's GitHub-hosted job installs its own SDK; a local SDK is not required
to complete the exercise.
