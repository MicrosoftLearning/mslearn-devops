# EShopOnWebDN11: agentic course sample

This is an independent .NET 11 course copy of
[MicrosoftLearning/eShopOnWeb](https://github.com/MicrosoftLearning/eShopOnWeb),
based on commit `4306a451e8e376ab4c11bb68ceb894f55b3947f8`.
The upstream [MIT license](LICENSE) and attribution are preserved. This folder
contains ordinary source files, not a nested Git repository or a submodule.
The existing course samples and lab instructions have not been changed.

## .NET 11 quick start

Clone **mslearn-devops**, then open its **EShopOnWebDN11** folder in VS Code.
Install the .NET 11 SDK; [global.json](global.json) selects stable SDK
`11.0.100` with roll-forward to later .NET 11 feature bands.

From this folder in PowerShell:

```powershell
dotnet restore .\eShopOnWeb.sln
dotnet build .\eShopOnWeb.sln --configuration Release --no-restore
dotnet test .\eShopOnWeb.sln --configuration Release --no-build
dotnet publish .\src\Web\Web.csproj --configuration Release --no-build -o .\artifacts\Website
```

In two terminals, both initially at this folder:

```powershell
# Terminal 1: storefront
dotnet run --project .\src\Web\Web.csproj --configuration Release --no-build --launch-profile Web
```

```powershell
# Terminal 2: API required by the Blazor admin application
dotnet run --project .\src\PublicApi\PublicApi.csproj --configuration Release --no-build --launch-profile PublicApi
```

Browse to `https://localhost:5001/`, `https://localhost:5001/admin`, and
`https://localhost:5099/swagger`. If necessary, trust your local development
certificate with `dotnet dev-certs https --trust`.

Development configuration uses seeded **in-memory** catalog and identity
databases, so no SQL Server or Azure credentials are required. Data resets when
each process restarts, and the storefront and API have separate in-memory
stores. This mode is for isolated training only. For SQL Server, override
`UseOnlyInMemoryDatabase` to `false` in both applications, configure their
connection strings outside source control, and apply the EF migrations below.
Production configuration retains the upstream Azure SQL/Key Vault route.

## Catalog chat: local application layer

The optional catalog assistant is integrated into the storefront at `/Chat`.
It uses the storefront's current in-memory catalog, not the separate admin API
database. No additional database, search index, embeddings, or conversation
store is required. It supports read-only product questions and comparisons;
stock, delivery, returns, orders, and payments are outside its scope.

Application structure:

- [Web](src/Web): Razor chat UI, same-origin antiforgery-protected endpoint,
  fresh catalog context, streaming proxy, and authoritative product cards.
- [ChatApi](src/ChatApi): separate .NET 11 backend that calls an existing
  Foundry GPT deployment using the OpenAI-compatible v1 HTTP API and
  `Azure.Identity`. The .NET SSE parser handles streamed responses. This avoids
  the retired Azure AI Inference SDK and preview authentication-warning
  suppressions.
- [ChatShared](src/ChatShared): typed HTTP contracts, request limits, streaming
  protocol, product-reference validation, and optional shared observability setup.

The model receives only names, descriptions, brands, types, IDs, and prices.
Product-card images, links, and prices are built by Web from catalog data.
Unknown product references, interrupted responses, and backend errors fail
explicitly; the app does not substitute simulated AI answers. Product text and
conversation history are treated as untrusted input. AI text can still be
inaccurate; the UI displays this limitation.

### Configure and run

Use an **existing** Foundry GPT deployment. Local configuration stays outside
source control, in .NET user secrets or environment variables. Do not put API
keys, tokens, or passwords in application settings. From the sample folder:

```powershell
azd auth login
dotnet user-secrets set "Foundry:Endpoint" "https://YOUR-RESOURCE.openai.azure.com/openai/v1/" --project .\src\ChatApi\ChatApi.csproj
dotnet user-secrets set "Foundry:DeploymentName" "YOUR-DEPLOYMENT-NAME" --project .\src\ChatApi\ChatApi.csproj
dotnet user-secrets set "ShopChat:Enabled" "true" --project .\src\Web\Web.csproj
```

`Foundry:Endpoint` also accepts the project endpoint in the form
`https://YOUR-RESOURCE.services.ai.azure.com/api/projects/YOUR-PROJECT`.
The client uses the same resource host with `/openai/v1/chat/completions`.
The deployment name must match the Azure deployment, not just its model family.
Your signed-in identity needs permission to invoke that deployed model.

If your sign-in's default tenant differs from the resource's tenant, set the
target explicitly and sign in to that tenant:

```powershell
azd auth login --tenant-id "TARGET-TENANT-GUID"
dotnet user-secrets set "Foundry:TenantId" "TARGET-TENANT-GUID" --project .\src\ChatApi\ChatApi.csproj
```

Alternatively, select `Foundry:Credential` = `AzureCli` and use `az login` for
the target tenant. `AzureDeveloperCli` is the default; credential failures do
not silently switch providers. Environment-variable equivalents include
`Foundry__Endpoint`, `Foundry__DeploymentName`, `Foundry__TenantId`, and
`ShopChat__Enabled`.
Restart the relevant application after changing its settings.

After building the solution, run these in two terminals:

```powershell
dotnet run --project .\src\ChatApi\ChatApi.csproj --configuration Release --no-build --launch-profile ChatApi
```

```powershell
dotnet run --project .\src\Web\Web.csproj --configuration Release --no-build --launch-profile Web
```

Browse to `https://localhost:5001/Chat`, or follow **Ask the catalog assistant**
from the storefront. ChatApi listens at `http://localhost:5100/`; its `/health`
endpoint checks application readiness, not live model access. PublicApi is
needed only if you also want to use the existing Blazor admin.

Try **Find a mug**, **Products under 10**, **Compare mugs**, and follow-up
questions. Conversations are held only in the page and reset on reload or
**New chat**. The request contains at most 11 alternating messages and 24,000
history characters; questions are limited to 1,000 characters. Each application
allows 12 chat requests per minute, with a 90-second request timeout and a
2,048-token model completion budget. The catalog context is limited to 50
products and 32,000 characters; exceeding these bounds fails explicitly.

Chat is disabled by default, so existing storefront deployments still work
without Foundry. To disable it locally, set `ShopChat:Enabled` to `false`.
Anonymous ChatApi is restricted to loopback Development hosting. Hosted ChatApi
requires Entra authentication and a managed identity for Foundry. Remote Web-to-
ChatApi connections require HTTPS and the dedicated API's token scope.
Use the full-workload templates below; do not expose anonymous chat publicly.
Lab instruction rewrites remain separate.

### Chat validation

The solution tests include isolated Web-to-ChatApi integration tests with a
mocked Foundry HTTP transport, plus product-reference tests. These tests make
no Azure calls. Frontend stream/history tests use Node's built-in test runner;
no npm packages are needed:

```powershell
node --test .\tests\JavaScript\catalog-chat.test.cjs
```

## Course build and deployment definitions

These definitions expect the **mslearn-devops repository root** to contain
`EShopOnWebDN11`. All application build paths explicitly select this folder
rather than building unrelated course projects.

- Azure Repos: select
  [EShopOnWebDN11/.ado/eshoponweb-ci-pr.yml](.ado/eshoponweb-ci-pr.yml) or
  [EShopOnWebDN11/.ado/eshoponweb-ci.yml](.ado/eshoponweb-ci.yml) when creating
  a pipeline. Both install the SDK from this sample's `global.json`, build in
  Release, execute all .NET and chat frontend tests, and publish Web and ChatApi. CI initially
  has `trigger: none`; Azure Repos PR validation must use a branch build policy.
  The CI pipeline publishes `Website/Web.zip`, a separate `ChatApi` artifact,
  and the full `Bicep` folder (including `webapp.bicep`).
- Azure release: [eshoponweb-cd-webapp-code.yml](.ado/eshoponweb-cd-webapp-code.yml)
  consumes those artifacts. Name the build pipeline `eshoponweb-ci`, configure
  the deployment variables and an approved Azure service connection, and
  authorize the pipeline resource. It deploys a **Linux** .NET 11 App Service.
- GitHub: files inside this sample's `.github/workflows` are **templates**;
  GitHub only discovers workflows in the repository-root `.github/workflows`.
  In the learner's own repository, copy
  [dotnetcore.yml](.github/workflows/dotnetcore.yml) for CI or
  [eshoponweb-cicd.yml](.github/workflows/eshoponweb-cicd.yml) for manual
  build/deployment there. Do not overwrite an existing workflow. Their build
  paths remain rooted in `EShopOnWebDN11`.
- GitHub deployment uses Azure OIDC, not a committed client secret. Configure
  a federated identity for the learner repository's `Development` environment
  and set its variables `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`,
  `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION`, and
  `AZURE_WEBAPP_NAME`. Configure required environment approvals where available.
  The manual workflow builds by default; explicitly select `deploy` only in an
  approved, chargeable training environment.

Both release definitions check the built-in Linux .NET 11 runtime before
provisioning. If App Service does not list it, deployment fails explicitly;
these templates do not silently change runtimes or switch to containers.
They deploy the **storefront only**, with the upstream Development/in-memory
training settings. Deploying the admin/API scenario in Azure additionally
requires an API App Service and matching server/client base URLs; it is not
included in these storefront templates. Do not use the demo identity,
Development environment, or in-memory database as a production configuration.

Other recipes now select this sample's paths and .NET 11 SDK/images:
Docker CI uses current Azure CLI/Docker commands; Compose CI uses Compose v2,
builds only application images, and versions them with the CI run ID. Their CD
recipes consume that run ID rather than a mutable `latest` image. App Service
containers and ACI consistently listen on port 8080.

Sonar uses the current version-4 Cloud extension; install/configure that extension
and its service connection. The retained Mend task and RichCodeNavIndexer require
their external services and have not been executed here. The Windows CM recipe
provisions a VM only, not the .NET application. The legacy SQL/Key Vault blueprint
remains in `infra/main.bicep`, but is not selected by `azure.yaml`.

The historical App Service Compose CD file was already nonworking and referenced
a missing Bicep template. It now fails explicitly before provisioning and directs
you to the supported single-container or full chat recipe. No lab instructions
were changed.

### Full Web + ChatApi + Foundry deployment

Use [eshoponweb-chat-cicd.yml for Azure DevOps](.ado/eshoponweb-chat-cicd.yml)
or [eshoponweb-chat-cicd.yml for GitHub](.github/workflows/eshoponweb-chat-cicd.yml).
Copy the GitHub template to the learner repository-root `.github/workflows`;
the sample's nested workflow folder is not automatically discovered.
Both are manual, build-only by default. Enabling `deploy` incurs Azure charges.

```text
Browser -> HTTPS App Service (Web, seeded in-memory catalog)
                 |
                 | Entra token from Web's user-assigned managed identity
                 v
           HTTPS Container Apps (ChatApi, linux/amd64, non-root)
                 |
                 | ChatApi's managed identity: model inference permission
                 v
           Foundry account / project / gpt-5.4-mini deployment
```

There is no additional catalog database, search service, or embedding pipeline.
ACR stores the ChatApi image; Log Analytics receives Container Apps logs.
The default creates learner-owned Foundry resources. App Service uses the
Linux .NET 11 built-in runtime, with an explicit availability check; there is no
silent runtime downgrade. Production ASP.NET settings disable developer error
pages, but this is still a **training application**, with demo identity and
restart-reset catalog data, not a production commerce system.

Pipeline flow:

1. **CI:** restore with vulnerability warnings treated as errors, build, all
   .NET/frontend tests, explicit direct/transitive package audit, compile every
   Bicep file, publish both applications, package `Website/Web.zip`, and build/save
   the Linux ChatApi image from the already-published/tested output. CI also
   starts it non-root and verifies health plus anonymous-inference rejection
   without requesting a model token.
2. **Infrastructure:** [chat-foundation.bicep](infra/chat-foundation.bicep)
   provisions hosting, private ACR, two identities, scoped roles, and either
   [new Foundry](infra/chat-foundry.bicep) or inference access to an existing account.
   The registry is created before attempting to publish/deploy its image.
3. **CD:** load the tested image artifact (verify its image ID), push it to ACR,
   deploy [ChatApi](infra/chat-container.bicep) by registry digest, configure
   [Web's authenticated backend](infra/chat-web-config.bicep), verify the ZIP
   hash, and deploy it without rebuilding.
4. **Verification:** require anonymous ChatApi inference to return 401, then
   submit a real storefront catalog prompt with its antiforgery token. Require
   a completed Foundry answer with valid catalog products priced below 10.
   Authentication/model failures fail the deployment; health alone is not success.

Shared [PowerShell scripts](scripts) require PowerShell 7.4+, .NET 11, Node 22,
Azure CLI/Bicep and a Linux Docker engine. Hosted Ubuntu runners provide the
base tools; the SDK is installed using this sample's `global.json`.
Build/deployment agents are Ubuntu Linux x64 and Azure images target
`linux/amd64`; using the ARM SDK locally does not change that deployment target.
Source Dockerfiles use the build host's native SDK and publish portable managed
assemblies without an apphost, avoiding SDK emulation on ARM development machines.
Source-container builds accept a `NUGET_SOURCE` build argument (and Compose
environment variable) for an organization-approved package proxy. The default
remains public NuGet for learners/hosted agents. Containers do not inherit a
developer's Windows NuGet configuration. Supply only a non-secret source URL;
do not put feed credentials in build arguments.
CI artifacts contain no user-secrets or API keys. Approval checks should be
configured on the `Training` environment. Both infrastructure and application
deployment jobs use that environment, so approvals may be requested at both
boundaries. Serialize Azure DevOps deployments with an environment exclusive-lock
check; GitHub has a non-cancelling concurrency group.

#### One-time Entra API registration

An instructor/learner with app-registration permission must create a dedicated
single-tenant API registration **in the Azure subscription's tenant**. This is
separate from the federated identity used by the pipeline. No client secret is
required or created:

```powershell
az login --tenant "YOUR-SUBSCRIPTION-TENANT-GUID"
.\scripts\New-ChatApiRegistration.ps1 -DisplayName "eshop-chat-api-UNIQUE" -TenantId "YOUR-SUBSCRIPTION-TENANT-GUID"
```

Run this once. It creates the registration/service principal, sets
`api://<application-client-id>` and v2 access tokens, and leaves assignment
requirements disabled. Keep the printed `CHAT_API_CLIENT_ID`.
If tenant policy prohibits learner registrations, use an instructor-created
registration with these settings instead. **The helper has only been prepared;
it is not automatically run by CI/CD.**

ChatApi validates signed tokens, tenant issuer, expiry and API audience, then
allowlists only Web's managed-identity client ID (`azp`). Delegated user tokens
are rejected. This [application ACL pattern](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-client-creds-grant-flow#access-control-lists)
supports role-less app-only tokens, avoiding Graph app-role grants in every lab
pipeline. Tenant membership or possession of an arbitrary Azure token does not
authorize a caller. Keep **Assignment required = No** for this dedicated API
unless you separately implement/manage application-role assignments.

#### Deployment configuration

Use an **isolated training resource group**, never the current course's live
resources. The templates own their generated resources and Web app settings.
The deployment principal needs Contributor and role-assignment permissions
(for example Role Based Access Control Administrator) at the training group.
Precreate the group/grants if the principal lacks subscription-level group-
creation rights. Register the Microsoft.Web, Microsoft.App, Microsoft.ManagedIdentity,
Microsoft.ContainerRegistry, Microsoft.OperationalInsights and
Microsoft.CognitiveServices providers in the subscription.

GitHub: configure OIDC for the learner repository's `Training` environment and
set these environment variables (repository/environment **variables**, not
client-secret credentials):

| Variable | Meaning |
| --- | --- |
| `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` | Federated deployment identity/subscription |
| `AZURE_RESOURCE_GROUP`, `AZURE_LOCATION` | Isolated target group and supported hosting region |
| `CHAT_API_CLIENT_ID` | Dedicated chat API registration application/client ID |
| `DEPLOYMENT_PRINCIPAL_ID` | Pipeline enterprise service principal **object ID**, not client ID |
| `FOUNDRY_LOCATION` | Optional model-capable region; defaults to hosting region |
| `FOUNDRY_DEPLOYMENT_NAME` | Optional new deployment name; defaults to `gpt-5.4-mini` |

Azure DevOps: configure a workload-identity-federated Azure service connection
and replace the corresponding placeholder variables in the full-workload YAML.
Authorize the pipeline and configure the `Training` environment checks.
No Graph application permissions are needed by the deployment identity.

New Foundry defaults: model `gpt-5.4-mini`, version `2026-03-17`,
`GlobalStandard`, capacity 30. Availability, quota, region and deployment policy
must support those values; adjust the Foundry Bicep parameters for the lab as
needed. A quota/model failure is surfaced, not replaced with another model.
The project/account API matches the tested Foundry starter; no starter Python,
React, storage or search resources are copied.

To reuse Foundry, select `useExistingFoundry=true` and additionally configure:

- `EXISTING_FOUNDRY_RESOURCE_GROUP`
- `EXISTING_FOUNDRY_ACCOUNT_NAME`
- `EXISTING_FOUNDRY_ENDPOINT` (HTTPS resource, `/openai/v1`, or project endpoint)
- `FOUNDRY_DEPLOYMENT_NAME` (the existing deployment name)

The deployment verifies that model's provisioning state and grants ChatApi
Cognitive Services OpenAI User at the existing account. The pipeline therefore
needs account read and role-assignment permissions at that scope, in the same
subscription/tenant. It does not recreate or modify the existing model/project.
Do not point this configuration at an account you are not authorized to use.

App settings generated by Bicep select `Foundry:Credential=ManagedIdentity`
and explicitly identify ChatApi's user-assigned identity. Web uses its own
identity and `ShopChat:AuthenticationScope=api://<chat-api-client-id>/.default`.
Local CLI authentication and anonymous loopback development remain available.
Azure hosting outside Development cannot disable ChatApi authentication or use
CLI credentials. Only health probes are anonymous.

Foundry inference, App Service, ACR, Container Apps and logs can incur costs.
Remove the isolated training resources when finished; retain a reused Foundry
account. The Entra registration is separate from resource-group deletion.
Hosted rate limits apply per application instance, so scaling changes the
aggregate allowance.

## Migration notes

- All application and test projects inherit `net11.0`; ASP.NET Core and EF
  Core packages are aligned to `11.0.0`.
- JWT dependencies are aligned with the .NET 11 authentication packages.
- Redundant framework package references were removed. The unused design-time
  scaffolding package was removed because the configured feed did not provide
  its .NET 11 stable release; it is not required to build or run this sample.
- Obsolete WebAssembly debugging middleware/settings were removed.
- Identity validation-script URLs now match the .NET 11 static asset layout.
- The API test host uses an assembly-specific endpoint marker to avoid
  conflicting generated `Program` types. Order test fixtures allocate separate
  owned value objects, as required by EF Core 11.
- AutoMapper and its discontinued DI extension were removed to remediate
  GHSA-rvv3-g6hj-g44x, GHSA-gpwp-5797-mjff, and GHSA-6vhm-j9h7-f9gh without
  introducing a new mapping-library license. The catalog endpoints now use
  explicit DTO construction, preserving all fields and picture-URI composition.
- Blazor interop helpers log and propagate JavaScript failures and use void
  calls where JavaScript returns no value. Login redirects use framework
  navigation; the layout relies on the existing cascading authentication
  views rather than polling authentication state. Catalog reload callbacks
  rely on Blazor's automatic event rendering.

## Validation

Validated locally with SDK `11.0.100` on Windows ARM64:

- Release solution build and all 112 .NET tests (54 unit, 3 repository, 37 functional,
  and 18 API integration tests).
- All 4 frontend tests: multi-chunk streaming, interrupted responses, cancellation,
  and conversation/reset behavior.
- Live local Web/ChatApi against an existing Foundry `gpt-5.4-mini` deployment:
  catalog listing, all four products priced below 10, mug comparison, follow-up
  context, missing stock/shipping information, and unrelated-question redirection.
  Browser checks also covered product images, Stop/New chat, and mobile layout.
- Storefront/PublicApi/ChatApi publish, plus framework-dependent Linux x64 storefront publish.
- Published Web and ChatApi processes completed a live Foundry request and returned
  the correct mug and authoritative price below 10.
- Published HTTPS storefront and API, login, authorized catalog create/delete,
  static assets, and healthy application health checks.
- Browser login and Blazor admin catalog loading.
- YAML syntax/parent-repository build paths and compilation of the updated
  App Service and azd Bicep templates.
- A fresh Release restore and direct/transitive NuGet vulnerability audit of
  all 12 managed projects reported zero known vulnerable packages after
  AutoMapper removal. Vulnerability warnings were not suppressed.

### Repeat dependency security validation

From this sample folder in PowerShell:

```powershell
$env:Configuration = 'Release'
dotnet restore .\eShopOnWeb.sln --force --no-cache -p:Configuration=Release -p:NuGetAudit=true -p:NuGetAuditMode=all
Get-ChildItem .\src, .\tests -Recurse -Filter *.csproj | ForEach-Object {
    dotnet package list --project $_.FullName --include-transitive --vulnerable --no-restore
}
```

Inspect every project's result; the package-list command can exit successfully
even when it reports vulnerabilities. Audit results depend on the configured
NuGet advisory feed and can change as new advisories are published. Enable
GitHub Dependabot alerts/security updates after pushing as an independent
check. A scan of the entire course repository may also report dependencies
from unchanged legacy samples; those are outside this sample's remediation.
This dependency audit does not certify application or deployment security.

Hosted Azure Pipelines/GitHub Actions runs and an actual deployment of the new
chat infrastructure have not been performed. The registration helper and all
cloud-writing scripts were prepared only, not executed. Local deployment-
contract validation includes all Bicep entrypoints, PowerShell/YAML parsing,
GitHub workflow linting, published training-mode Web startup, and non-root
Linux/amd64 ChatApi container health plus rejection of anonymous inference.
Container validation uses the Linux Docker engine.
Source Web/PublicApi images built successfully for Linux x64 using an approved
package proxy. Native Linux ARM execution verified the storefront's seeded mug
and all 12 API catalog products. Local x64 emulation on this ARM workstation
encountered QEMU/EF runtime failures; it is not a substitute for a native x64
hosted deployment run. No emulation-specific runtime workarounds were added.

The historical reference-application documentation follows.

# Microsoft eShopOnWeb ASP.NET Core Reference Application

Sample ASP.NET Core reference application, powered by Microsoft, demonstrating a single-process (monolithic) application architecture and deployment model. If you're new to .NET development, read the [Getting Started for Beginners](https://github.com/dotnet-architecture/eShopOnWeb/wiki/Getting-Started-for-Beginners) guide.

A list of Frequently Asked Questions about this repository can be found [here](https://github.com/dotnet-architecture/eShopOnWeb/wiki/Frequently-Asked-Questions).

## Overview Video

[Steve "ardalis" Smith](https://twitter.com/ardalis) recorded [a live stream providing an overview of the eShopOnWeb reference app](https://www.youtube.com/watch?v=vRZ8ucGac8M&ab_channel=Ardalis) in October 2020. 

## eBook

This reference application is meant to support the free .PDF download ebook: [Architecting Modern Web Applications with ASP.NET Core and Azure](https://aka.ms/webappebook), updated to **ASP.NET Core 8.0**. [Also available in ePub/mobi formats](https://dotnet.microsoft.com/learn/web/aspnet-architecture).

You can also read the book in online pages at the .NET docs here: 
https://docs.microsoft.com/dotnet/architecture/modern-web-apps-azure/

[<img src="https://dotnet.microsoft.com/blob-assets/images/e-books/aspnet.png" height="300" />](https://dotnet.microsoft.com/learn/web/aspnet-architecture)

The **eShopOnWeb** sample is related to the [eShopOnContainers](https://github.com/dotnet/eShopOnContainers) sample application which, in that case, focuses on a microservices/containers-based application architecture. However, **eShopOnWeb** is much simpler in regards to its current functionality and focuses on traditional Web Application Development with a single deployment.

The goal for this sample is to demonstrate some of the principles and patterns described in the [eBook](https://aka.ms/webappebook). It is not meant to be an eCommerce reference application, and as such it does not implement many features that would be obvious and/or essential to a real eCommerce application.

> ### VERSIONS
> #### This course copy runs ASP.NET Core 11.0.
> #### Upstream version history and tags belong to the source repository.

## Topics (eBook TOC)

- Introduction
- Characteristics of Modern Web Applications
- Choosing Between Traditional Web Apps and SPAs
- Architectural Principles
- Common Web Application Architectures
- Common Client Side Technologies
- Developing ASP.NET Core MVC Apps
- Working with Data in ASP.NET Core Apps
- Testing ASP.NET Core MVC Apps
- Development Process for Azure-Hosted ASP.NET Core Apps
- Azure Hosting Recommendations for ASP.NET Core Web Apps

## Running the sample using Azd template

The store's home page should look like this:

![eShopOnWeb home page screenshot](https://user-images.githubusercontent.com/782127/88414268-92d83a00-cdaa-11ea-9b4c-db67d95be039.png)

The Azure Developer CLI (`azd`) is a developer-centric command-line interface (CLI) tool for creating Azure applications.

You need to install it before running and deploying with Azure Developer CLI.

### Windows

```powershell
powershell -ex AllSigned -c "Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression"
```

### Linux/MacOS

```
curl -fsSL https://aka.ms/install-azd.sh | bash
```

And you can also install with package managers, like winget, choco, and brew. For more details, you can follow the documentation: https://aka.ms/azure-dev/install.

After logging in with the following command, you will be able to use the azd cli to quickly provision and deploy the application.

```
azd auth login
```

Then, from this sample folder, execute `azd init` to initialize the existing project.
```
azd init
```

The azd default deploys the database-free chat workload: .NET 11 Web on Linux
App Service, ChatApi on Container Apps, private ACR, managed identities, and a
new Foundry project/model. The catalog is in memory and resets on restart.
Neither SQL nor Key Vault is deployed.

Prerequisites: .NET 11 SDK, PowerShell 7.4+, Node.js, Azure CLI, azd, and a running
Linux Docker engine. Sign both Azure CLI and azd into the subscription tenant.
The provisioning identity needs resource deployment and role-assignment
permissions. Interactive deployment also requires permission to create an Entra
application; alternatively configure an instructor-provided API registration:
`azd env set CHAT_API_CLIENT_ID "<API-CLIENT-ID>"`.

```powershell
az login --tenant "<TENANT-ID>"
azd auth login --tenant-id "<TENANT-ID>"
azd env new "<ENVIRONMENT-NAME>" --subscription "<SUBSCRIPTION-ID>" --location "<REGION>"
azd up
```

The hooks validate/build/test the application, provision `rg-{env name}`, push
the tested ChatApi image, configure managed-identity authentication, and deploy
Web through azd. A post-deployment smoke test checks anonymous ChatApi rejection
and an actual catalog-grounded Foundry response. Errors stop deployment.
Re-running `azd up` produces fresh local build artifacts. Use `azd up` for the
initial deployment so the build and registration hook runs before provisioning.
App Service deployments default to the lower-cost Basic B1 plan, including the
Web-only, Docker, Azure DevOps, GitHub, and azd recipes. Existing templates that
already used B1 are unchanged. Regional subscription quota must permit a new B1
instance. B1 does not support deployment slots or automatic scaling; none of
these recipes requires either feature. Set `WEB_APP_SKU` before azd provisioning
only when a different App Service tier is intentionally required.
Native App Service templates explicitly start `dotnet Web.dll`. The .NET 11
publish output also contains BlazorAdmin runtime configuration, so automatic
startup discovery would otherwise select the default Azure welcome page.

The default creates a dedicated Entra registration once and saves its client ID
in ignored `.azure` state. If registration setup fails after creation, finish
configuring the reported registration and set `CHAT_API_CLIENT_ID`; do not
create duplicates. Azd supplies the provisioning principal ID. For noninteractive
service-principal provisioning, also set `DEPLOYMENT_PRINCIPAL_TYPE=ServicePrincipal`
and authenticate both Azure CLI and azd as that principal.

To reuse Foundry, set `USE_EXISTING_FOUNDRY=true`,
`EXISTING_FOUNDRY_RESOURCE_GROUP`, `EXISTING_FOUNDRY_ACCOUNT_NAME`,
`EXISTING_FOUNDRY_ENDPOINT`, and `FOUNDRY_DEPLOYMENT_NAME` before provisioning.
New-model region/quota availability must match `FOUNDRY_LOCATION` (defaults to
the selected region).

`azd down` removes the Azure resource group and its chargeable workloads.
It does **not** remove the separate Entra registration; delete that registration
separately when it is no longer needed. Retain the local environment state until
cleanup is complete.

### Optional observability lab

Observability is off by default. Before the first `azd up`, enable it with:

```powershell
azd env set ENABLE_OBSERVABILITY true
```

This adds a workspace-based Application Insights resource to the existing
Log Analytics workspace. Web and ChatApi use Azure Monitor OpenTelemetry,
distinct service roles, and managed-identity-authenticated ingestion.
Local/key-based ingestion is disabled; each workload identity receives
**Monitoring Metrics Publisher** on that Application Insights resource only.
No connection-string credential or client secret is required.

Request/dependency traces carry `deployment.environment`, `source.commit` and
`release.id`. For this azd build, the release ID is the source commit, not a
pipeline run ID. The observability-enabled azd hook rejects uncommitted
application/deployment changes to keep that attribution meaningful.
Each `eshop.chat` dependency span records `chat.outcome` and
`chat.failure_reason`, including failures after HTTP streaming has started.
Prompt, answer, product and token payloads are not added to those spans.
The lab records all traces for its small traffic sample and disables Live
Metrics; review sampling, retention, privacy and cost before production use.

[Monitoring assets](observability) include workspace-schema KQL, a workbook
generator and a runbook template. The
[alert template](infra/chat-observability-alert.bicep) creates a separate,
learner-deployed three-failures-in-five-minutes alert. It is not enabled merely
by switching on instrumentation. No data is unknown, and an alert resolving
does not prove that chat is healthy.

Follow [Observe Web and Chat with Copilot](../Instructions/agentic/observe-web-chat-with-copilot.md)
for the standalone exercise. Existing build and deployment labs do not need
to enable observability.

You can also run the sample directly locally (See below).

## Running the sample locally
Most of the site's functionality works with just the web application running. However, the site's Admin page relies on Blazor WebAssembly running in the browser, and it must communicate with the server using the site's PublicApi web application. You'll need to also run this project. You can configure Visual Studio to start multiple projects, or just go to the PublicApi folder in a terminal window and run `dotnet run` from there. After that from the Web folder you should run `dotnet run --launch-profile Web`. Now you should be able to browse to `https://localhost:5001/`. The admin part in Blazor is accessible to `https://localhost:5001/admin`  

Note that if you use this approach, you'll need to stop the application manually in order to build the solution (otherwise you'll get file locking errors).

After cloning or downloading the sample you must setup your database. 
To use the sample with a persistent database, you will need to run its Entity Framework Core migrations before you will be able to run the app.

You can also run the samples in Docker (see below).

### Configuring the sample to use SQL Server

1. This course copy uses in-memory databases in Development. For a persistent
   SQL Server database, override this setting in both the Web and PublicApi
   applications:

    ```json
   {
       "UseOnlyInMemoryDatabase": false
   }
    ```

1. Ensure your connection strings in `appsettings.json` point to a local SQL Server instance.
1. Ensure the tool EF was already installed. You can find some help [here](https://docs.microsoft.com/ef/core/miscellaneous/cli/dotnet)

    ```
    dotnet tool restore
    ```

1. Open a command prompt in the Web folder and execute the following commands:

    ```
    dotnet restore
    dotnet tool restore
    dotnet ef database update -c catalogcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj
    dotnet ef database update -c appidentitydbcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj
    ```

    These commands will create two separate databases, one for the store's catalog data and shopping cart information, and one for the app's user credentials and identity data.

1. Run the application.

    The first time you run the application, it will seed both databases with data such that you should see products in the store, and you should be able to log in using the demouser@microsoft.com account.

    Note: If you need to create migrations, you can use these commands:

    ```
    -- create migration (from Web folder CLI)
    dotnet ef migrations add InitialModel --context catalogcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj -o Data/Migrations

    dotnet ef migrations add InitialIdentityModel --context appidentitydbcontext -p ../Infrastructure/Infrastructure.csproj -s Web.csproj -o Identity/Migrations
    ```

## Running the sample in the dev container

The upstream repository documents a dev container, but its ignored
`.devcontainer` files are not distributed in this course copy. Use the local
.NET 11 quick start above or the included Dockerfiles instead.

## Running the sample using Docker

You can run the Web sample by running these commands from the root folder (where the .sln file is located):

```
docker-compose build
docker-compose up
```

You should be able to make requests to localhost:5106 for the Web project, and localhost:5200 for the Public API project once these commands complete. If you have any problems, especially with login, try from a new guest or incognito browser instance.

You can also run the applications by using the instructions located in their `Dockerfile` file in the root of each project. Again, run these commands from the root of the solution (where the .sln file is located).

## Community Extensions

We have some great contributions from the community, and while these aren't maintained by Microsoft we still want to highlight them.

[eShopOnWeb VB.NET](https://github.com/VBAndCs/eShopOnWeb_VB.NET) by Mohammad Hamdy Ghanem
