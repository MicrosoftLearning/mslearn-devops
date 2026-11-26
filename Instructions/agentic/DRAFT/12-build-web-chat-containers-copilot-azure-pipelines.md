---
lab:
  topic: Agentic
  title: "Build Web and Chat with Copilot-assisted Azure Pipelines"
  description: Create Web and Chat CI, add a Docker build with Copilot, and troubleshoot a pipeline failure.
  level: 400
  duration: 60 minutes
  islab: true
  primarytopics:
    - Azure DevOps
    - Azure Pipelines
    - Containers
    - GitHub Copilot
    - Agentic DevOps
---

# Build Web and Chat with Copilot-assisted Azure Pipelines

## Exercise scenario

EShopOnWebDN11 is a sample retail application with a .NET 11 Web storefront
for browsing a product catalog. Its separate, containerized ChatApi service
uses a model deployed in Microsoft Foundry to answer customer questions and
recommend products from that catalog.

In this exercise, you learn how to create a Build / CI pipeline for the  EShopOnWebDN11 Web application and the ChatApi container. You also learn how to integrate GitHub Copilot to add Docker packaging and rely on it as AI assistant to correct a pipeline error.

## Before you start

You need:

- Azure DevOps access to create a private project, pipeline and pull requests.
- Available Ubuntu hosted-agent capacity.
- Git, VS Code, PowerShell and Copilot Chat/Agent (paid subscription) access.
- The published mslearn-devops repo as source containing EShopOnWebDN11.

Use VS Code for edits, Copilot and Git commands. Use Azure DevOps in your
browser for repository settings, pipeline runs and pull requests.

## Exercise 1: Establish the traditional build flow

## Task 1: Import the sample into Azure Repos and clone your lab repository

1. In **Azure DevOps in your browser**, create a private Git project named
   **eshop-build-ado-lab**.
1. Open **Repos > Files > Import a repository**. Import
   `https://github.com/MicrosoftLearning/mslearn-devops.git` without authentication.
1. Check that `main` contains `EShopOnWebDN11` and is the default branch.
1. Select **Repos > Files > Clone > Clone in VS Code**. Open the clone in
   an unused local folder.
1. In **VS Code > Terminal > PowerShell**, run:

   ```powershell
   git remote -v
   git switch main
   git pull --ff-only
   git status --short
   ```

## Task 2: Create and run CI for Web and Chat

This YAML defines a manually run CI pipeline on an Azure DevOps hosted Ubuntu
agent. It installs the required SDK and tools, restores dependencies, builds
Web and ChatApi, runs tests, and publishes their output as **BuildOutput**:
a Web ZIP package and the ChatApi files. Docker packaging is added in the next
task.

1. In **VS Code Explorer**, create `.ado/eshop-build-lab.yml` at the repository
   root, paste this baseline and save the file:

   ```yaml
   trigger: none
   pool:
     vmImage: ubuntu-latest
   variables:
     sampleRoot: '$(Build.SourcesDirectory)/EShopOnWebDN11'
   stages:
   - stage: CI
     jobs:
     - job: BuildAndTest
       steps:
       - checkout: self
       - task: UseDotNet@2
         inputs:
           packageType: sdk
           useGlobalJson: true
           workingDirectory: '$(sampleRoot)'
       - task: NodeTool@0
         inputs:
           versionSpec: '22.x'
       - pwsh: |
           $ErrorActionPreference = 'Stop'
           $PSNativeCommandUseErrorActionPreference = $true
           dotnet restore eShopOnWeb.sln -p:Configuration=Release -p:NuGetAudit=true -p:NuGetAuditMode=all -warnaserror
           dotnet build eShopOnWeb.sln -c Release --no-restore -warnaserror
           dotnet test eShopOnWeb.sln -c Release --no-build
           node --test tests/JavaScript/catalog-chat.test.cjs
         workingDirectory: '$(sampleRoot)'
         displayName: Restore, build and test Web and Chat
       - pwsh: |
           $ErrorActionPreference = 'Stop'
           $PSNativeCommandUseErrorActionPreference = $true
           $output = "$(Build.ArtifactStagingDirectory)/BuildOutput"
           dotnet publish src/Web/Web.csproj -c Release --no-build --no-restore -p:UseAppHost=false -o "$output/WebPublish"
           dotnet publish src/ChatApi/ChatApi.csproj -c Release --no-build --no-restore -p:UseAppHost=false -o "$output/ChatApi"
           [IO.Compression.ZipFile]::CreateFromDirectory("$output/WebPublish", "$output/Web.zip")
         workingDirectory: '$(sampleRoot)'
         displayName: Publish Web and Chat
       - task: PublishPipelineArtifact@1
         inputs:
           targetPath: '$(Build.ArtifactStagingDirectory)/BuildOutput'
           artifact: BuildOutput
   ```

1. In the **VS Code terminal**, run:

   ```powershell
   git add -- .ado\eshop-build-lab.yml
   git --no-pager diff --cached
   git commit -m "Add Web and Chat build baseline"
   git push origin main
   ```

1. In **Azure DevOps in your browser**, select
   **Pipelines > New pipeline > Azure Repos Git > Existing Azure
   Pipelines YAML file**. Choose `main` and `/.ado/eshop-build-lab.yml`.
   Run it and name the pipeline **eshop-build-lab**.
1. Open the **CI > BuildAndTest** job. Check that build, tests and publish succeed.
1. Return to the run summary. Confirm **BuildOutput** is published.

## Exercise 2: Improve CI with bounded Copilot assistance

## Task 3: Add a Docker build step with Copilot

1. Back in **VS Code's terminal**, create a Git branch:

   ```powershell
   git switch main
   git pull --ff-only origin main
   git switch -c feature/copilot-docker-ci
   git branch --show-current
   ```

   Check the output is `feature/copilot-docker-ci`. Do not create a folder
   with that name.
1. Open **Copilot Chat > Ask**. Attach
   `EShopOnWebDN11/src/ChatApi/Dockerfile` and `.ado/eshop-build-lab.yml`. Enter:

   ```text
   Add a Docker@2 build task in the existing CI job, after Publish Web
   and Chat and before PublishPipelineArtifact.
   Dockerfile: $(sampleRoot)/src/ChatApi/Dockerfile
   Build context: $(Build.ArtifactStagingDirectory)/BuildOutput/ChatApi
   Repository: eshop-chat; tag: $(Build.BuildId); platform: linux/amd64.
   Use command: build, not buildAndPush. No registry or Azure login is needed.
   Add a PowerShell step to save eshop-chat:$(Build.BuildId) as
   $(Build.ArtifactStagingDirectory)/BuildOutput/ChatApi.tar.
   Fail on native command errors. Preserve existing restore, tests and publish.
   Change only .ado/eshop-build-lab.yml. Do not deploy, run model calls,
   edit application files, execute commands, commit or push.
   Show the proposed steps first.
   ```

1. Review the proposal. Switch **Copilot Chat** to **Agent** mode and send:

   ```text
   Apply the proposed Docker build and image-save steps.
   Edit only .ado/eshop-build-lab.yml.
   Do not run commands, commit, push or modify other files.
   ```

   If Copilot requests approval, review the requested action before approving.
   Decline command execution or edits to other files. Depending on your
   settings, file edits may be applied without an approval prompt.
1. In **Source Control**, confirm only `.ado/eshop-build-lab.yml` changed.
   The Copilot Agent edits should add Docker build and image-save steps
   similar to this example. Check that they appear after **Publish Web and
   Chat** and before **PublishPipelineArtifact**, with existing tests unchanged.

   If the generated steps are missing or use incorrect inputs, replace those
   steps with this example to continue. Match the indentation of the existing
   steps under `BuildAndTest`; do not replace the entire pipeline.

   ```yaml
   - task: Docker@2
     displayName: Build Chat container
     inputs:
       command: build
       Dockerfile: '$(sampleRoot)/src/ChatApi/Dockerfile'
       buildContext: '$(Build.ArtifactStagingDirectory)/BuildOutput/ChatApi'
       repository: eshop-chat
       tags: '$(Build.BuildId)'
       arguments: '--pull --platform linux/amd64'
   - pwsh: |
       $ErrorActionPreference = 'Stop'
       $PSNativeCommandUseErrorActionPreference = $true
       docker image save --output "$(Build.ArtifactStagingDirectory)/BuildOutput/ChatApi.tar" "eshop-chat:$(Build.BuildId)"
     displayName: Save Chat image
   ```
1. In the **VS Code terminal**, commit and push:

   ```powershell
   git add -- .ado\eshop-build-lab.yml
   git --no-pager diff --cached
   git commit -m "Add Copilot-assisted Chat Docker build"
   git push --set-upstream origin feature/copilot-docker-ci
   ```

1. In **Azure DevOps > Pipelines > eshop-build-lab > Run pipeline**, select
   `feature/copilot-docker-ci` and run. Check Docker build and image save succeed.
1. In **Azure DevOps**, select
   **Repos > Pull requests > New pull request**. Choose
   `feature/copilot-docker-ci` as the source and `main` as the target.
   Create the PR and leave it open for the next task.

Copilot helped adding a working Docker build to CI, and the pipeline saved the Chat container image alongside the Web output.

## Task 4: Diagnose a Docker build error with Copilot

1. Back in **VS Code**, open `.ado/eshop-build-lab.yml` on
   `feature/copilot-docker-ci`. In the Docker task only, change the
   `Dockerfile` input from `$(sampleRoot)/src/ChatApi/Dockerfile` to
   `$(sampleRoot)/src/ChatApi/Dockerfile-Missing`. Save the file,
   then use the integrated Source Control pane to commit and push the change
   to the existing PR.
1. In **Azure DevOps > Pipelines**, run on `feature/copilot-docker-ci`.
   Check that tests pass but Docker fails because the file cannot be found.
1. In the failed run, open the Docker task log and copy the relevant error.
1. Back in **VS Code > Copilot Chat > Ask**, supply the sanitized
   error and current YAML. Ask for the cause and smallest correction.
   Prohibit removing the Docker task, suppressing failures or changing tests.
1. Check the diagnosis against the actual file path, then permit
   Copilot **Agent** mode to restore only the Dockerfile path. Inspect the diff in
   **Source Control** and commit and push manually from the integrated terminal.
1. In **Azure DevOps > Pipelines**, rerun on the feature branch. Confirm success.

You used real logs and Copilot assistance to repair a Docker configuration error and verified the fix with a successful pipeline run.

## Task 5: Enable automatic CI and merge the change

1. In **VS Code > Copilot Chat**, on the existing feature branch,
   ask Copilot to propose a top-level `trigger` restricted to pushes to `main`
   affecting `EShopOnWebDN11/*` or `.ado/eshop-build-lab.yml`. Preserve required
   build steps. Inspect the change in **Source
   Control**, then commit and push the pipeline update from the integrated
   PowerShell terminal.
1. In **Azure DevOps**, review and complete the PR after applicable checks pass.
1. In Azure DevOps, navigate to **Pipelines > eshop-build-lab** and confirm an
   **automatic** CI run starts for the integrated `main` commit.
1. Open that run's logs. Confirm .NET tests and the Docker build succeed and
   **BuildOutput** is published.

You performed a merge to `main`, which then automatically builds Web, Chat and the
Docker image. 

## Exercise Summary

In this lab, you:

- Created an Azure Pipelines CI pipeline to build, test and publish the .NET 11 Web and Chat applications.
- Packaged the published ChatApi files as a Docker image and saved it as a build artifact.
- Used GitHub Copilot to generate pipeline steps and troubleshoot a Docker build error.
- Merged the pipeline changes and verified automatic CI on `main`.

## Clean up

1. In **Azure DevOps**, disable the pipeline if keeping the project.
1. Delete only the dedicated lab project and local clone if no longer needed.
1. Do not delete Azure resources; this lab created none.

