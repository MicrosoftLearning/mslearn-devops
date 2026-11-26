---
lab:
  topic: Agentic
  title: "Build Web and Chat with Copilot-assisted GitHub Actions"
  description: Create Web and Chat CI, add a Docker build with Copilot, and troubleshoot a workflow failure.
  level: 400
  duration: 60 minutes
  islab: true
  primarytopics:
    - GitHub
    - GitHub Actions
    - Containers
    - GitHub Copilot
    - Agentic DevOps
---

# Build Web and Chat with Copilot-assisted GitHub Actions

## Exercise scenario

EShopOnWebDN11 is a sample retail application with a .NET 11 Web storefront
for browsing a product catalog. Its separate, containerized ChatApi service
uses a model deployed in Microsoft Foundry to answer customer questions and
recommend products from that catalog.

Create CI for EShopOnWebDN11 Web and ChatApi. Use Copilot to add Docker
packaging and correct a workflow error.

## Before you start

You need:

- GitHub access to create a repository, run Actions and open pull requests.
- Available Ubuntu hosted-runner capacity.
- Git, VS Code, PowerShell and Copilot Chat/Agent access.
- The published mslearn-devops source containing EShopOnWebDN11.

Use VS Code for edits, Copilot and Git commands. Use GitHub in your browser
for repository settings, workflow runs and pull requests.

## Part 1: Establish the traditional build flow

## Task 1: Clone the source and create your repository

1. In **VS Code**, open an integrated PowerShell terminal in an unused parent
   directory. Run:

   ```powershell
   git clone --branch main --single-branch https://github.com/MicrosoftLearning/mslearn-devops.git eshop-build-github-lab
   Set-Location eshop-build-github-lab
   git remote rename origin upstream
   code .
   ```

1. In **GitHub in your browser**, create an empty repository named
   **eshop-build-github-lab**. Leave initialization options unselected.
1. In the **VS Code PowerShell terminal**, replace `YOUR-OWNER` and run:

   ```powershell
   git remote add origin https://github.com/YOUR-OWNER/eshop-build-github-lab.git
   git remote -v
   git push --set-upstream origin main
   ```

1. Confirm `origin` points to your repository and `EShopOnWebDN11` is present.

**Expected result:** Your repository is open in VS Code.

## Task 2: Create and run CI for Web and Chat

This YAML defines a manually run GitHub Actions CI workflow on a hosted Ubuntu
runner. It installs the required SDK and tools, restores dependencies, builds
Web and ChatApi, runs tests, and uploads **BuildOutput**: a Web ZIP package and
the ChatApi files. Docker packaging is added in the next task; this workflow
does not deploy to Azure.

1. In **VS Code Explorer**, at the cloned repository root, create `.github`
   and its `workflows` subfolder if they do not already exist. Inside
   `workflows`, create `eshop-build-lab.yml`. Paste and save:

   ```yaml
   name: Web and Chat build lab
   on:
     workflow_dispatch:
   permissions:
     contents: read
   jobs:
     ci:
       runs-on: ubuntu-latest
       env:
         BUILD_OUTPUT: ${{ runner.temp }}/BuildOutput
       steps:
         - uses: actions/checkout@v5
           with:
             persist-credentials: false
         - uses: actions/setup-dotnet@v5
           with:
             global-json-file: EShopOnWebDN11/global.json
         - uses: actions/setup-node@v4
           with:
             node-version: '22'
         - name: Restore, build and test Web and Chat
           shell: pwsh
           working-directory: EShopOnWebDN11
           run: |
             $ErrorActionPreference = 'Stop'
             $PSNativeCommandUseErrorActionPreference = $true
             dotnet restore eShopOnWeb.sln -p:Configuration=Release -p:NuGetAudit=true -p:NuGetAuditMode=all -warnaserror
             dotnet build eShopOnWeb.sln -c Release --no-restore -warnaserror
             dotnet test eShopOnWeb.sln -c Release --no-build
             node --test tests/JavaScript/catalog-chat.test.cjs
         - name: Publish Web and Chat
           shell: pwsh
           working-directory: EShopOnWebDN11
           run: |
             $ErrorActionPreference = 'Stop'
             $PSNativeCommandUseErrorActionPreference = $true
             dotnet publish src/Web/Web.csproj -c Release --no-build --no-restore -p:UseAppHost=false -o "$env:BUILD_OUTPUT/WebPublish"
             dotnet publish src/ChatApi/ChatApi.csproj -c Release --no-build --no-restore -p:UseAppHost=false -o "$env:BUILD_OUTPUT/ChatApi"
             [IO.Compression.ZipFile]::CreateFromDirectory("$env:BUILD_OUTPUT/WebPublish", "$env:BUILD_OUTPUT/Web.zip")
         - uses: actions/upload-artifact@v5
           with:
             name: BuildOutput
             path: ${{ env.BUILD_OUTPUT }}
             if-no-files-found: error
             retention-days: 7
   ```

1. In the **VS Code terminal**, run:

   ```powershell
   git add -- .github\workflows\eshop-build-lab.yml
   git --no-pager diff --cached
   git commit -m "Add Web and Chat CI"
   git push origin main
   ```

1. Navigate to **GitHub > Actions > Web and Chat build lab > Run workflow**.
   Select `main` and run.
1. Open the `ci` job. Check that build, tests and publish succeed.
1. Return to the run summary. Confirm **BuildOutput** is published.

**Expected result:** Web and Chat build, test and publish successfully.

## Part 2: Improve CI with bounded Copilot assistance

## Task 3: Add Docker packaging with Copilot

1. Back in **VS Code's terminal**, create a Git branch:

   ```powershell
   git switch main
   git pull --ff-only origin main
   git switch -c feature/copilot-docker-ci
   git branch --show-current
   ```

   Check the output is `feature/copilot-docker-ci`. Do not create a folder
   with that name.
1. Open **Copilot Chat > Ask**. Attach the workflow and
   `EShopOnWebDN11/src/ChatApi/Dockerfile`. Enter:

   ```text
   Add Docker packaging to the existing ci job after Publish Web and Chat
   and before artifact upload.
   Use the runtime-only Dockerfile EShopOnWebDN11/src/ChatApi/Dockerfile.
   Build context: $env:BUILD_OUTPUT/ChatApi.
   Build with --pull --platform linux/amd64 and tag eshop-chat:${{ github.run_id }}.
   Save the image as $env:BUILD_OUTPUT/ChatApi.tar.
   Use PowerShell and fail on native command errors.
   Preserve tests, publish steps and contents: read.
   Change only .github/workflows/eshop-build-lab.yml.
   Do not push an image, deploy, run commands, commit or push Git changes.
   Show the proposed steps first.
   ```

1. Review the proposal. Switch **Copilot Chat** to **Agent** mode and send:

   ```text
   Apply the proposed Docker build and image-save steps.
   Edit only .github/workflows/eshop-build-lab.yml.
   Do not run commands, commit, push or modify other files.
   ```

   If Copilot requests approval, review the action before approving.
   Decline command execution or edits to other files. File edits may be
   applied without an approval prompt, depending on your settings.
1. In **Source Control**, confirm only the workflow changed. The Agent edits
   should add steps similar to this example after **Publish Web and Chat**
   and before artifact upload. Check that existing tests remain unchanged.

   If the generated steps are missing or use incorrect inputs, replace those
   steps with this example. Match the indentation of the existing `ci` steps;
   do not replace the entire workflow.

   ```yaml
   - name: Build Chat container
     shell: pwsh
     run: |
       $ErrorActionPreference = 'Stop'
       $PSNativeCommandUseErrorActionPreference = $true
       docker build --pull --platform linux/amd64 --file EShopOnWebDN11/src/ChatApi/Dockerfile --tag "eshop-chat:${{ github.run_id }}" "$env:BUILD_OUTPUT/ChatApi"
   - name: Save Chat image
     shell: pwsh
     run: |
       $ErrorActionPreference = 'Stop'
       $PSNativeCommandUseErrorActionPreference = $true
       docker image save --output "$env:BUILD_OUTPUT/ChatApi.tar" "eshop-chat:${{ github.run_id }}"
   ```
1. In the **VS Code terminal**, commit and push:

   ```powershell
   git add -- .github\workflows\eshop-build-lab.yml
   git --no-pager diff --cached
   git commit -m "Add Copilot-assisted Docker packaging"
   git push --set-upstream origin feature/copilot-docker-ci
   ```

1. In **GitHub > Actions > Web and Chat build lab > Run workflow**, select
   `feature/copilot-docker-ci` from the branch list and run.
   Check the Docker build and image-save steps succeed.
1. In **GitHub > Pull requests**, create a PR from that branch into `main`.
   Leave it open for the next task.

**Expected result:** CI builds the Chat image and includes `ChatApi.tar` in
BuildOutput.

## Task 4: Diagnose a Docker build error

1. Back in **VS Code**, change only the Dockerfile path in the Docker build
   command to `EShopOnWebDN11/src/ChatApi/Dockerfile-Missing`.
1. Commit and push the change from the integrated terminal.
1. In **GitHub > Actions**, run the workflow on `feature/copilot-docker-ci`.
   Open the failed Docker step and copy its relevant error lines.
1. Back in **Copilot Chat > Ask**, attach the workflow and sanitized error.
   Enter:

   ```text
   Diagnose this Docker build failure. Identify the failing input and the
   smallest correction. Do not remove the Docker step, suppress errors,
   change tests or run commands.
   ```

1. Check the diagnosis against the actual Dockerfile path. Switch **Copilot
   Chat** to **Agent** and ask it to restore
   `EShopOnWebDN11/src/ChatApi/Dockerfile` in the workflow only, without running
   commands or changing other inputs.
1. Inspect, commit and push the fix. Run the feature-branch workflow again
   in **GitHub Actions** and confirm success.

**Expected result:** Copilot helped correct the failure without bypassing it.

## Task 5: Enable automatic CI and merge

1. In **VS Code > Copilot Chat > Agent**, ask Copilot to update only the
   workflow's `on` section: add a `push` trigger for `main`, filtered to
   `EShopOnWebDN11/**` and this workflow file. Keep `workflow_dispatch` and
   all build steps. Do not let Agent run commands, commit or push.
1. In **Source Control**, check that the updated `on` section matches this
   example. If needed, replace only that section with:

   ```yaml
   on:
     workflow_dispatch:
     push:
       branches:
         - main
       paths:
         - 'EShopOnWebDN11/**'
         - '.github/workflows/eshop-build-lab.yml'
   ```

1. In the **VS Code terminal**, commit and push the workflow update.
1. In **GitHub**, review and merge the PR after applicable checks pass.
1. Navigate to **Actions**. Check that the merge starts an automatic run and
   that .NET tests, Docker packaging and artifact upload succeed.

**Expected result:** Main-branch changes automatically build Web and Chat.

## Exercise Summary

In this lab, you:

- Created a GitHub Actions CI workflow to build, test and publish the .NET 11 Web and Chat applications.
- Packaged the published ChatApi files as a Docker image and saved it as a build artifact.
- Used GitHub Copilot to generate workflow steps and troubleshoot a Docker build error.
- Merged the workflow changes and verified automatic CI on `main`.

## Clean up

1. In **GitHub**, disable the workflow if keeping the repository.
1. Delete only the dedicated lab repository and local clone if no longer needed.
1. Do not delete Azure resources; this lab created none.