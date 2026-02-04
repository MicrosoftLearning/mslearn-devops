---
lab:
  topic: Intermediate
  title: "Package Management with Azure Artifacts"
  description: "Build and manage internal NuGet packages for a microservices architecture using Azure Artifacts, simulating a real-world enterprise scenario."
---

# Package Management with Azure Artifacts: Building an Internal Shared Library

## Scenario Overview

You are a DevOps Engineer at **Contoso Retail**, a mid-sized e-commerce company transitioning from a monolithic application to a microservices architecture. The development team has identified common functionality duplicated across multiple services—logging, authentication helpers, API response models, and utility functions.

Your manager has assigned you the following task:

> "We need to stop copying code between our microservices. Create a shared library that our teams can consume through Azure Artifacts. Start with our common API response models and logging utilities. Make sure the library is versioned properly and can be easily updated across all services."

In this lab, you will:

- Set up an Azure Artifacts feed for your organization's internal packages
- Create a .NET 10 shared library with realistic utility code
- Push your code to Azure Repos for version control
- Implement semantic versioning and publish the package
- Consume the package in a simulated microservice
- Create CI/CD pipelines to automate package publishing and consumption
- Update the package and manage version dependencies

This lab takes approximately **40** minutes to complete.

## Before you start

You need:

- **Microsoft Edge** or an [Azure DevOps supported browser](https://docs.microsoft.com/azure/devops/server/compatibility)
- **Azure DevOps organization:** Create one if you don't have one
- **Visual Studio Code** with the [C# Dev Kit extension](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csdevkit)
- **.NET 10 SDK:** [Download and install the .NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- **Azure Artifacts credential provider:** [Download and install the credential provider](https://go.microsoft.com/fwlink/?linkid=2099625)

## Understanding Azure Artifacts in Enterprise Scenarios

Azure Artifacts is essential for organizations adopting microservices or maintaining multiple applications that share common code. Key enterprise benefits include:

- **Code reusability:** Share common libraries across teams without copy-paste
- **Version control:** Manage package versions with semantic versioning
- **Security:** Control who can publish and consume packages
- **Auditability:** Track package usage and dependencies across projects
- **CI/CD integration:** Automatically publish packages from build pipelines

In a typical enterprise scenario, you might have:

| Feed | Purpose | Example Packages |
|------|---------|------------------|
| `contoso-shared` | Cross-cutting concerns | Logging, authentication, utilities |
| `contoso-domain` | Business domain models | Order models, customer models |
| `contoso-infra` | Infrastructure code | Database helpers, message bus clients |

## Task 1: Set Up the Azure DevOps Project

First, create the Azure DevOps project that will host your shared library.

1. Open your Azure DevOps organization in a browser
1. Select **+ New Project**
1. Configure the project:
   - **Name:** `Contoso.Microservices`
   - **Description:** `Internal shared libraries and microservice projects for Contoso Retail`
   - **Visibility:** Private
   - **Version control:** Git
   - **Work item process:** Agile
1. Select **Create**

## Task 2: Create the Azure Artifacts Feed

Set up a dedicated feed for your organization's internal packages.

1. In your Azure DevOps project, select **Artifacts** from the left navigation
1. Select **+ Create Feed**
1. Configure the feed:
   - **Name:** `contoso-internal`
   - **Visibility:** `Members of your Microsoft Entra Tenant` (select your organization)
   - **Upstream sources:** Select **Include packages from common public sources**
   
   > **Why include upstream sources?** This allows developers to restore both internal packages AND public NuGet packages from the same feed, simplifying configuration.
   
   - **Scope:** `Project: Contoso.Microservices`
1. Select **Create**
1. After creation, select **Connect to Feed**
1. Select **dotnet** under the NuGet section
1. Copy the **Artifacts URL** (value parameter in the displayed nuget.config xml snippet). It will look like:
   ```
   https://pkgs.dev.azure.com/<your-org>/Contoso.Microservices/_packaging/contoso-internal/nuget/v3/index.json
   ```

1. Click the **Back** arrow to return to the main Artifacts feed page.

> **Note**: By default, the "<DevOps Project> Build Service" User has **Artifact Feed Collaborator (Feed and Upstream Reader)** permissions. As we will run a Build Pipeline later on to not only _use_, but also _publish_ packages, the permissions need to be updated.

1. From the **Artifacts** / **Feeds** page (The one that says _Connect to the feed to get started_), select **Feed Settings** (the little cog wheel) and navigate to the **Permissions** tab
1. Select the **Contoso.MicroServices Build Service (ADO Organization)** User
1. Click **Edit**
1. Change the permission from Feed and Upstream Reader to **Feed Publisher (Contributor)**
1. **Save** the changes

## Task 3: Create the Shared Library Project

Create a .NET 10 class library with realistic shared utilities.

### Initialize the Solution Structure

1. Open a terminal and create the project directory:
   ```powershell
   mkdir C:\ContosoMicroservices
   cd C:\ContosoMicroservices
   ```

1. Create a new solution and class library:
   ```powershell
   dotnet new sln --name Contoso.Shared
   dotnet new classlib --name Contoso.Shared.Core --framework net10.0
   dotnet sln add Contoso.Shared.Core
   dotnet new gitignore
   ```

1. Open the project in VS Code:
   ```powershell
   code .
   ```

### Add Package Metadata

1. Open the `Contoso.Shared.Core/Contoso.Shared.Core.csproj` file and replace its content with:

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    
    <!-- Package metadata -->
    <PackageId>Contoso.Shared.Core</PackageId>
    <Version>1.0.0</Version>
    <Authors>Contoso DevOps Team</Authors>
    <Company>Contoso Retail</Company>
    <Description>Core shared utilities for Contoso microservices including API response models, logging helpers, and common extensions.</Description>
    <PackageTags>contoso;shared;utilities;microservices</PackageTags>
    <RepositoryType>git</RepositoryType>
  </PropertyGroup>

</Project>
```

### Create the API Response Models

In enterprise applications, standardizing API responses ensures consistency across all microservices. The `ApiResponse<T>` class below wraps all responses with success/failure status, correlation IDs for distributed tracing, and standardized error information.

1. Delete the default `Class1.cs` file in the `Contoso.Shared.Core` folder
1. Create a new folder called `Models` inside `Contoso.Shared.Core`
1. Create a new file `Models/ApiResponse.cs` with the following code:

```csharp
namespace Contoso.Shared.Core.Models;

public class ApiResponse<T>
{
    public bool Success { get; set; }
    public T? Data { get; set; }
    public ApiError? Error { get; set; }
    public string CorrelationId { get; set; } = Guid.NewGuid().ToString();
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;

    public static ApiResponse<T> Ok(T data, string? correlationId = null)
    {
        return new ApiResponse<T>
        {
            Success = true,
            Data = data,
            CorrelationId = correlationId ?? Guid.NewGuid().ToString()
        };
    }

    public static ApiResponse<T> Fail(string errorCode, string message, string? correlationId = null)
    {
        return new ApiResponse<T>
        {
            Success = false,
            Error = new ApiError(errorCode, message),
            CorrelationId = correlationId ?? Guid.NewGuid().ToString()
        };
    }
}

public record ApiError(string Code, string Message)
{
    public string? Details { get; init; }
    public Dictionary<string, string[]>? ValidationErrors { get; init; }
}
```

### Create the Logging Extensions

The `LogContext` class provides structured logging context that enables consistent log entries and distributed tracing across microservices. It captures correlation IDs, service names, and optional user/tenant information for multi-tenant applications.

1. Create a new folder called `Logging` inside `Contoso.Shared.Core`
1. Create a new file `Logging/LogContext.cs`:

```csharp
namespace Contoso.Shared.Core.Logging;

public class LogContext
{
    public string CorrelationId { get; set; } = Guid.NewGuid().ToString();
    public required string ServiceName { get; set; }
    public string? Operation { get; set; }
    public string? UserId { get; set; }
    public string? TenantId { get; set; }

    public Dictionary<string, object?> ToDictionary()
    {
        return new Dictionary<string, object?>
        {
            ["CorrelationId"] = CorrelationId,
            ["ServiceName"] = ServiceName,
            ["Operation"] = Operation,
            ["UserId"] = UserId,
            ["TenantId"] = TenantId,
            ["Timestamp"] = DateTime.UtcNow.ToString("O")
        };
    }
}
```

### Create String Extension Utilities

These extension methods provide common string operations used across services: `Truncate` for display purposes, `Mask` for hiding sensitive data like emails or credit cards, and `ToSlug` for URL-friendly strings.

1. Create a new folder called `Extensions` inside `Contoso.Shared.Core`
1. Create a new file `Extensions/StringExtensions.cs`:

```csharp
namespace Contoso.Shared.Core.Extensions;

public static class StringExtensions
{
    public static string Truncate(this string value, int maxLength, string suffix = "...")
    {
        if (string.IsNullOrEmpty(value)) return value;
        if (maxLength <= 0) return string.Empty;
        if (value.Length <= maxLength) return value;

        return string.Concat(value.AsSpan(0, maxLength - suffix.Length), suffix);
    }

    public static string Mask(this string value, int visibleChars = 4, char maskChar = '*')
    {
        if (string.IsNullOrEmpty(value)) return value;
        if (value.Length <= visibleChars * 2) return new string(maskChar, value.Length);

        var start = value[..visibleChars];
        var end = value[^visibleChars..];
        var masked = new string(maskChar, value.Length - (visibleChars * 2));

        return $"{start}{masked}{end}";
    }

    public static string ToSlug(this string value)
    {
        if (string.IsNullOrEmpty(value)) return value;

        return value
            .ToLowerInvariant()
            .Replace(" ", "-")
            .Replace("_", "-");
    }
}
```

### Build the Project

1. In the terminal, build the solution:
   ```powershell
   dotnet build
   ```
1. Verify there are no build errors

### Push the Code to Azure Repos

Now that the shared library is created, push it to Azure Repos for version control. This enables team collaboration and will be the foundation for CI/CD automation later.

1. In Azure DevOps, navigate to **Repos** in your `Contoso.Microservices` project
1. Since the repo is empty, you'll see setup instructions. Copy the **Clone URL** (HTTPS), it looks like:
   ```
   https://dev.azure.com/<your-org>/Contoso.Microservices/_git/Contoso.Microservices
   ```

1. In your terminal, initialize Git and push the code, updating the URL with **your DevOps organization name**:
   ```powershell
   cd C:\ContosoMicroservices
   git init
   git add .
   git commit -m "Initial commit: Contoso.Shared.Core library"
   git remote add origin https://dev.azure.com/<your-org>/Contoso.Microservices/_git/Contoso.Microservices
   git push -u origin main
   ```

   > **Note:** You may be prompted to authenticate. Use your Azure DevOps credentials.

1. In Azure DevOps, refresh the **Repos** page to verify your code is now visible

## Task 4: Create a CI Pipeline to Publish Packages

In a DevOps environment, packages are published automatically through CI pipelines rather than manually. This ensures consistency, traceability, and proper version control.

### Create the Pipeline File

1. In VS Code, create a new file `azure-pipelines.yml` in the solution root (`C:\ContosoMicroservices`):

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - Contoso.Shared.Core/**

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  projectPath: 'Contoso.Shared.Core/Contoso.Shared.Core.csproj'

stages:
- stage: Build
  displayName: 'Build and Pack'
  jobs:
  - job: BuildJob
    displayName: 'Build Library'
    steps:
    - task: UseDotNet@2
      displayName: 'Use .NET 10 SDK'
      inputs:
        packageType: 'sdk'
        version: '10.x'

    - task: DotNetCoreCLI@2
      displayName: 'Restore packages'
      inputs:
        command: 'restore'
        projects: '$(projectPath)'

    - task: DotNetCoreCLI@2
      displayName: 'Build'
      inputs:
        command: 'build'
        projects: '$(projectPath)'
        arguments: '--configuration $(buildConfiguration) --no-restore'

    - task: DotNetCoreCLI@2
      displayName: 'Pack NuGet package'
      inputs:
        command: 'pack'
        packagesToPack: '$(projectPath)'
        configuration: '$(buildConfiguration)'
        packDirectory: '$(Build.ArtifactStagingDirectory)'

    - publish: '$(Build.ArtifactStagingDirectory)'
      artifact: 'nuget-package'
      displayName: 'Publish artifact'

- stage: Publish
  displayName: 'Publish to Azure Artifacts'
  dependsOn: Build
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - job: PublishJob
    displayName: 'Push to Feed'
    steps:
    - download: current
      artifact: 'nuget-package'

    - task: NuGetAuthenticate@1
      displayName: 'Authenticate to Azure Artifacts'

    - task: DotNetCoreCLI@2
      displayName: 'Push to contoso-internal feed'
      inputs:
        command: 'push'
        packagesToPush: '$(Pipeline.Workspace)/nuget-package/*.nupkg'
        nuGetFeedType: 'internal'
        publishVstsFeed: 'Contoso.Microservices/contoso-internal'
```

This pipeline triggers when changes are pushed to the `main` branch in the `Contoso.Shared.Core` folder. It builds, packs, and publishes the NuGet package to your Azure Artifacts feed automatically.

> **Key benefit:** The `NuGetAuthenticate@1` task handles authentication automatically—no Personal Access Tokens needed for pipeline publishing!

### Commit and Push to Trigger the Pipeline

1. Add the pipeline file and push:
   ```powershell
   cd C:\ContosoMicroservices
   git add azure-pipelines.yml
   git commit -m "Add CI pipeline for package publishing"
   git push
   ```

### Create the Pipeline in Azure DevOps

1. In Azure DevOps, navigate to **Pipelines**
1. Select **Create Pipeline** (or **New Pipeline**)
1. Select **Azure Repos Git**
1. Select the **Contoso.Microservices** repository
1. The `/azure-pipelines.yml` will get loaded automatically
1. Click **Run**

1. Watch the pipeline execute through both stages:
   - **Build and Pack**: Compiles the library and creates the NuGet package
   - **Publish to Azure Artifacts**: Pushes the package to your feed

1. After completion, navigate to **Artifacts** > **contoso-internal**
1. Verify that `Contoso.Shared.Core` version `1.0.0` appears in the feed

> **DevOps Best Practice:** By publishing packages through pipelines, you get full traceability—every package version is linked to a specific commit and build.

## Task 5: Consume the Package in a Microservice

Now that the package is published through the pipeline, create a microservice that consumes it.

### Create the Order Service Project

1. In the terminal, navigate to the solution folder and create a new Web API project:
   ```powershell
   cd C:\ContosoMicroservices
   dotnet new webapi --name Contoso.OrderService --framework net10.0 --use-controllers
   dotnet sln add Contoso.OrderService
   ```

### Configure NuGet to Use Azure Artifacts

Create a `nuget.config` file so both local development and CI/CD pipelines can restore packages from your Azure Artifacts feed.

1. Create `nuget.config` in the solution root (`C:\ContosoMicroservices`):
(This xml can also be found in the Artifacts Feed / Connect to feed / Nuget / dotnet - Project Setup section)

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <configuration>
     <packageSources>
       <clear />
       <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
       <add key="contoso-internal" value="https://pkgs.dev.azure.com/<your-org>/Contoso.Microservices/_packaging/contoso-internal/nuget/v3/index.json" />
     </packageSources>
   </configuration>
   ```

   > **Note:** Replace `<your-org>` with your Azure DevOps organization name.

### Install the Shared Package

> **Important:** Before proceeding, verify that the pipeline from Task 4 completed successfully and the package exists in your feed:
> 1. In Azure DevOps, navigate to **Artifacts** > **contoso-internal**
> 2. Confirm you see `Contoso.Shared.Core` version `1.0.0` listed
> If the package is not there, check the pipeline run in **Pipelines** for any errors.

1. Install the Azure Artifacts credential provider if you haven't already (this enables authentication for local development):
   - Download the latest release from [https://github.com/microsoft/artifacts-credprovider/releases](https://github.com/microsoft/artifacts-credprovider/releases)
   - Download `Microsoft.Net.Providers.CredentialProvider.zip` (for .NET) 
   - Extract the zip file to `%USERPROFILE%\.nuget\plugins` (create the folder if it doesn't exist)
   
   Alternatively, if the PowerShell command works in your environment:
   ```powershell
   iex "& { $(irm https://aka.ms/install-artifacts-credprovider.ps1) }"
   ```

1. Add the package reference to the Order Service. Open `Contoso.OrderService/Contoso.OrderService.csproj` in VS Code and add the following line to the existing `ItemGroup` tag:

   ```xml
     <PackageReference Include="Contoso.Shared.Core" Version="1.0.0" />
   ```

1. Next, in the same `Contoso.OrderService.csproj`, add a project reference to Contoso.Shared.Core, by adding the following new ItemGroup section below the PackageReference ItemGroup section:

    ```xml
      <ItemGroup>
      <ProjectReference Include="..\Contoso.Shared.Core\Contoso.Shared.Core.csproj" />
    </ItemGroup>
    ```

1. Restore and build the project:
   ```powershell
   cd C:\ContosoMicroservices
   dotnet restore --interactive
   dotnet build
   ```

   > **Note:** The first time you restore, you'll be prompted to authenticate with Azure DevOps in a browser window. Select your account and allow access. The credential provider caches your credentials for future use.

### Use the Shared Library

Now that the shared package is installed, create a controller that uses it. The controller below demonstrates how consuming services use the shared library. Note how `ApiResponse<T>` provides consistent response formatting, while the `Mask` and `Truncate` extension methods handle sensitive data and display formatting.

1. Delete `Controllers/WeatherForecastController.cs` and `WeatherForecast.cs` from the project
1. Create a new file `Controllers/OrdersController.cs` with the following code:

```csharp
using Contoso.Shared.Core.Models;
using Contoso.Shared.Core.Extensions;
using Microsoft.AspNetCore.Mvc;

namespace Contoso.OrderService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    [HttpGet("{id}")]
    public ActionResult<ApiResponse<OrderDto>> GetOrder(int id)
    {
        if (id <= 0)
        {
            return BadRequest(ApiResponse<OrderDto>.Fail(
                "INVALID_ORDER_ID",
                "Order ID must be a positive number"));
        }

        if (id == 999)
        {
            return NotFound(ApiResponse<OrderDto>.Fail(
                "ORDER_NOT_FOUND",
                $"Order with ID {id} was not found"));
        }

        var order = new OrderDto
        {
            OrderId = id,
            CustomerName = "John Doe",
            CustomerEmail = "john.doe@example.com".Mask(3),
            TotalAmount = 299.99m,
            Status = "Processing",
            Description = "This is a sample order with a very long description that should be truncated".Truncate(50)
        };

        return Ok(ApiResponse<OrderDto>.Ok(order));
    }

    [HttpGet]
    public ActionResult<ApiResponse<List<OrderDto>>> GetOrders()
    {
        var orders = new List<OrderDto>
        {
            new() { OrderId = 1, CustomerName = "John Doe", TotalAmount = 299.99m, Status = "Completed" },
            new() { OrderId = 2, CustomerName = "Jane Smith", TotalAmount = 149.50m, Status = "Processing" }
        };

        return Ok(ApiResponse<List<OrderDto>>.Ok(orders));
    }
}

public class OrderDto
{
    public int OrderId { get; set; }
    public string CustomerName { get; set; } = string.Empty;
    public string? CustomerEmail { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = string.Empty;
    public string? Description { get; set; }
}
```

1. Build and run the project:

   ```powershell
   cd c:\ContosoMicroServices\Contoso.OrderService
   dotnet run
   ```

1. Test the API using the Swagger UI (open the **http://localhost:port>** URL shown in the terminal):
   - Navigate to `/api/orders/1` - should return a success response
   - Notice how the email is masked and description is truncated using the shared extensions
   - Navigate to `/api/orders/999` - should return a ORDER_NOT_FOUND error

## Task 6: Update the Package (Simulating a Bug Fix)

Your team reported that the `Mask` extension method doesn't handle edge cases properly. Let's fix the bug, update the version, and publish the update through the pipeline.

### Make the Fix

The updated method adds a `minMaskedChars` parameter to ensure short strings are properly masked rather than exposing too much data.

1. In VS Code, open `Contoso.Shared.Core/Extensions/StringExtensions.cs`
1. Update the `Mask` method:

```csharp
public static string Mask(this string value, int visibleChars = 4, char maskChar = '*', int minMaskedChars = 3)
{
    if (string.IsNullOrEmpty(value)) return value;
    if (visibleChars < 0) visibleChars = 0;
    
    if (value.Length <= visibleChars * 2 + minMaskedChars)
    {
        return new string(maskChar, Math.Max(value.Length, minMaskedChars));
    }

    var start = value[..visibleChars];
    var end = value[^visibleChars..];
    var maskedLength = Math.Max(value.Length - (visibleChars * 2), minMaskedChars);
    var masked = new string(maskChar, maskedLength);

    return $"{start}{masked}{end}";
}
```

> **What does this fix?** The original v1.0.0 `Mask` method had an edge case issue with short strings. For example, with the default `visibleChars=4`, a short email like "ab@c.io" (7 characters) would show 4 characters at the start and 4 at the end—exposing the entire string! The fix adds a `minMaskedChars` parameter that ensures at least 3 characters are always masked. Now short strings get fully masked (e.g., `*******`) rather than revealing sensitive data.

### Update the Version

Following [Semantic Versioning](https://semver.org/), this is a patch release (bug fix with no breaking changes).

1. Open the `Contoso.Shared.Core/Contoso.Shared.Core.csproj` file
1. Update the version and add release notes:

> **Note**: Make sure you only overwrite the `<PropertyGroup>` section, keeping the `<Project>` tags in place.

```xml
<PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    
    <PackageId>Contoso.Shared.Core</PackageId>
    <Version>1.0.1</Version>
    <Authors>Contoso DevOps Team</Authors>
    <Company>Contoso Retail</Company>
    <Description>Core shared utilities for Contoso microservices including API response models, logging helpers, and common extensions.</Description>
    <PackageTags>contoso;shared;utilities;microservices</PackageTags>
    <RepositoryType>git</RepositoryType>
    <PackageReleaseNotes>
      v1.0.1: Fixed edge case in Mask extension, added minMaskedChars parameter
    </PackageReleaseNotes>
</PropertyGroup>
```

### Publish Through the Pipeline

1. Commit and push the changes to trigger the pipeline:
   ```powershell
   cd C:\ContosoMicroservices
   git add .
   git commit -m "Fix: Handle edge cases in Mask extension (v1.0.1)"
   git push
   ```

1. In Azure DevOps, navigate to **Pipelines** and watch the build run
1. After the pipeline completes, go to **Artifacts** > **contoso-internal**
1. Click on **Contoso.Shared.Core** to open the package details
1. Select the **Versions** tab to see all available versions - you should see both `1.0.0` and `1.0.1`

### Update the Order Service

1. Update the package reference in the Order Service. Open `Contoso.OrderService/Contoso.OrderService.csproj` and change the version:
   ```xml
   <PackageReference Include="Contoso.Shared.Core" Version="1.0.1" />
   ```

1. Restore and build:
   ```powershell
   cd C:\ContosoMicroservices
   dotnet restore
   dotnet build
   ```
> **Note**: If you see an error message when running this step, saying "error NU1102: unable to find package" the solution is to clear the Nuget local cache and run dotnet restore again, using the below commands (More information on this error is documented **[here](https://learn.microsoft.com/en-us/nuget/consume-packages/managing-the-global-packages-and-cache-folders)**).

  ```powershell
   cd C:\ContosoMicroservices
   dotnet nuget locals http-cache --clear
   dotnet restore
   ```


1. Verify the updated package is working by running the Order Service:
   ```powershell
   cd C:\ContosoMicroservices\Contoso.OrderService
   dotnet run
   ```

1. Open the api app (URL shown in the terminal) and test the `/api/orders/1` endpoint. The response should still show the masked email, confirming the updated package works correctly with the new edge case handling.

1. Stop the running application (press `Ctrl+C` in the terminal)

## Task 7: Create a Pipeline for the Order Service

Complete the DevOps workflow by creating a pipeline for the Order Service. This demonstrates how consuming applications restore packages from Azure Artifacts during CI/CD.

### Create the Pipeline File

1. Create a new file `azure-pipelines-orderservice.yml` in the solution root:

```yaml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - Contoso.OrderService/**

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  projectPath: 'Contoso.OrderService/Contoso.OrderService.csproj'

stages:
- stage: Build
  displayName: 'Build Order Service'
  jobs:
  - job: BuildJob
    displayName: 'Build and Test'
    steps:
    - task: UseDotNet@2
      displayName: 'Use .NET 10 SDK'
      inputs:
        packageType: 'sdk'
        version: '10.x'

    - task: NuGetAuthenticate@1
      displayName: 'Authenticate to Azure Artifacts'

    - task: DotNetCoreCLI@2
      displayName: 'Restore packages (including from Azure Artifacts)'
      inputs:
        command: 'restore'
        projects: '$(projectPath)'
        feedsToUse: 'config'
        nugetConfigPath: 'nuget.config'

    - task: DotNetCoreCLI@2
      displayName: 'Build'
      inputs:
        command: 'build'
        projects: '$(projectPath)'
        arguments: '--configuration $(buildConfiguration) --no-restore'

    - task: DotNetCoreCLI@2
      displayName: 'Publish'
      inputs:
        command: 'publish'
        projects: '$(projectPath)'
        arguments: '--configuration $(buildConfiguration) --output $(Build.ArtifactStagingDirectory)'
        publishWebProjects: false

    - publish: '$(Build.ArtifactStagingDirectory)'
      artifact: 'orderservice'
      displayName: 'Publish artifact'
```

This pipeline demonstrates how the `NuGetAuthenticate` task enables the build agent to restore packages from your private Azure Artifacts feed using the `nuget.config` file you created earlier.

### Create the Pipeline

1. Commit and push all changes:
   ```powershell
   git add .
   git commit -m "Add Order Service pipeline and update nuget.config"
   git push
   ```

1. In Azure DevOps, navigate to **Pipelines**
1. Select **New Pipeline**
1. Select **Azure Repos Git** > **Contoso.Microservices**
1. Select **Existing Azure Pipelines YAML file**
1. Choose:
   - Branch: **Main**
   - Path: **`/azure-pipelines-orderservice.yml`**
1. Select **Continue**
1. Select **Run** to kick off the pipeline
1. From the running pipeline, select the **Build Order Service** Stage to open the **Job Details**.
1. Observe several steps happening in the pipeline:
   - Authenticates to Azure Artifacts using the same Azure Artifacts Credential Provider used locally
   - Restores `Contoso.Shared.Core` from your private feed
   - Builds and publishes the Order Service

> **DevOps Best Practice:** By using Azure Artifacts with CI/CD pipelines, you ensure that all builds use consistent, versioned dependencies. This eliminates "works on my machine" issues and provides full traceability of which package versions are deployed.

## Clean Up Resources

If you created resources specifically for this lab and no longer need them:

1. In Azure DevOps, navigate to your project and select **Project Settings**
1. Under **General**, select **Overview**
1. At the bottom of the page, select **Delete**
1. Type the project name to confirm
1. Select **Delete**

Alternatively, keep the project for future labs or experimentation.

## Summary

In this lab, you simulated a real-world scenario where a DevOps engineer creates and manages internal packages for a microservices architecture using Azure DevOps.
