#Requires -Version 7.0
<#
.SYNOPSIS
    Sets up a complete Azure DevOps demo environment for MCP Server training.

.DESCRIPTION
    This script creates:
    - Azure DevOps project with Agile process
    - Team members and iterations/sprints
    - Work items (Epics, Features, User Stories, Tasks, Bugs)
    - Git repository with .NET Core sample application
    - CI/CD pipeline definitions
    - Sample builds and releases

.PARAMETER Organization
    The Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)

.PARAMETER ProjectName
    The name of the project to create (default: "Contoso Web App")

.PARAMETER SkipCodePush
    Skip pushing sample code to the repository

.EXAMPLE
    .\Setup-ADODemoEnvironment.ps1 -Organization "https://dev.azure.com/myorg"

.EXAMPLE
    .\Setup-ADODemoEnvironment.ps1 -Organization "https://dev.azure.com/myorg" -ProjectName "My Demo Project"

.NOTES
    Prerequisites:
    - Azure CLI installed with DevOps extension (az extension add --name azure-devops)
    - Logged in to Azure CLI (az login)
    - Git installed and configured
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Organization,

    [Parameter(Mandatory = $false)]
    [string]$ProjectName = "Contoso Web App",

    [Parameter(Mandatory = $false)]
    [switch]$SkipCodePush
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Colors for output
function Write-Step { param($Message) Write-Host "`n▶ $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "  ✓ $Message" -ForegroundColor Green }
function Write-Info { param($Message) Write-Host "  ℹ $Message" -ForegroundColor Gray }
function Write-Warning { param($Message) Write-Host "  ⚠ $Message" -ForegroundColor Yellow }

# Repository name
$RepoName = "contoso-webapp"

# Sprint dates (adjust based on current date)
$Today = Get-Date
$SprintDuration = 14 # days

$Sprint1Start = $Today.AddDays(-28).ToString("yyyy-MM-dd")
$Sprint1End = $Today.AddDays(-15).ToString("yyyy-MM-dd")
$Sprint2Start = $Today.AddDays(-14).ToString("yyyy-MM-dd")
$Sprint2End = $Today.AddDays(-1).ToString("yyyy-MM-dd")
$Sprint3Start = $Today.ToString("yyyy-MM-dd")
$Sprint3End = $Today.AddDays(13).ToString("yyyy-MM-dd")
$Sprint4Start = $Today.AddDays(14).ToString("yyyy-MM-dd")
$Sprint4End = $Today.AddDays(27).ToString("yyyy-MM-dd")

# ============================================================================
# Helper Functions
# ============================================================================

function Test-AzDevOpsCliReady {
    Write-Step "Checking prerequisites..."
    
    # Check Azure CLI
    $azVersion = az version 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        throw "Azure CLI is not installed. Please install from https://aka.ms/installazurecliwindows"
    }
    Write-Success "Azure CLI version: $($azVersion.'azure-cli')"

    # Check DevOps extension
    $extensions = az extension list 2>$null | ConvertFrom-Json
    $devopsExt = $extensions | Where-Object { $_.name -eq "azure-devops" }
    if (-not $devopsExt) {
        Write-Info "Installing Azure DevOps extension..."
        az extension add --name azure-devops
    }
    Write-Success "Azure DevOps extension installed"

    # Check login status
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }
    Write-Success "Logged in as: $($account.user.name)"

    # Check Git
    $gitVersion = git --version 2>$null
    if (-not $gitVersion) {
        throw "Git is not installed. Please install from https://git-scm.com/"
    }
    Write-Success "Git installed: $gitVersion"
}

function Invoke-AzDevOps {
    param(
        [string]$Command,
        [switch]$ReturnJson,
        [switch]$AllowFailure
    )
    
    $fullCommand = "az devops $Command --org `"$Organization`""
    $result = Invoke-Expression $fullCommand 2>&1
    
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        Write-Warning "Command failed: $fullCommand"
        Write-Warning "Error: $result"
        return $null
    }
    
    if ($ReturnJson -and $result) {
        return $result | ConvertFrom-Json
    }
    return $result
}

function Invoke-AzBoards {
    param(
        [string]$Command,
        [switch]$ReturnJson,
        [switch]$AllowFailure
    )
    
    $fullCommand = "az boards $Command --org `"$Organization`" --project `"$ProjectName`""
    $result = Invoke-Expression $fullCommand 2>&1
    
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        if (-not $AllowFailure) {
            Write-Warning "Command failed: $fullCommand"
            Write-Warning "Error: $result"
        }
        return $null
    }
    
    if ($ReturnJson -and $result) {
        return $result | ConvertFrom-Json
    }
    return $result
}

function Invoke-AzRepos {
    param(
        [string]$Command,
        [switch]$ReturnJson,
        [switch]$AllowFailure
    )
    
    $fullCommand = "az repos $Command --org `"$Organization`" --project `"$ProjectName`""
    $result = Invoke-Expression $fullCommand 2>&1
    
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        Write-Warning "Command failed: $fullCommand"
        return $null
    }
    
    if ($ReturnJson -and $result) {
        return $result | ConvertFrom-Json
    }
    return $result
}

function Invoke-AzPipelines {
    param(
        [string]$Command,
        [switch]$ReturnJson,
        [switch]$AllowFailure
    )
    
    $fullCommand = "az pipelines $Command --org `"$Organization`" --project `"$ProjectName`""
    $result = Invoke-Expression $fullCommand 2>&1
    
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
        Write-Warning "Command failed: $fullCommand"
        return $null
    }
    
    if ($ReturnJson -and $result) {
        return $result | ConvertFrom-Json
    }
    return $result
}

# ============================================================================
# Project Setup
# ============================================================================

function New-ADOProject {
    Write-Step "Creating Azure DevOps project: $ProjectName"
    
    # Check if project already exists
    $existingProject = Invoke-AzDevOps -Command "project show --project `"$ProjectName`"" -ReturnJson -AllowFailure
    
    if ($existingProject) {
        Write-Warning "Project '$ProjectName' already exists. Using existing project."
        return $existingProject
    }
    
    $project = Invoke-AzDevOps -Command "project create --name `"$ProjectName`" --description `"A modern web application for customer engagement - MCP Demo`" --process Agile --source-control git --visibility private" -ReturnJson
    
    if ($project) {
        Write-Success "Project created: $($project.name)"
        # Wait for project to be fully provisioned
        Start-Sleep -Seconds 5
    }
    
    return $project
}

# ============================================================================
# Iterations/Sprints Setup
# ============================================================================

function New-Iterations {
    Write-Step "Creating iterations (sprints)..."
    
    # Create sprints
    $sprints = @(
        @{ Name = "Sprint 1"; Start = $Sprint1Start; End = $Sprint1End },
        @{ Name = "Sprint 2"; Start = $Sprint2Start; End = $Sprint2End },
        @{ Name = "Sprint 3"; Start = $Sprint3Start; End = $Sprint3End },
        @{ Name = "Sprint 4"; Start = $Sprint4Start; End = $Sprint4End }
    )
    
    foreach ($sprint in $sprints) {
        $result = Invoke-AzBoards -Command "iteration project create --name `"$($sprint.Name)`" --start-date $($sprint.Start) --finish-date $($sprint.End)" -AllowFailure
        if ($result) {
            Write-Success "Created: $($sprint.Name) ($($sprint.Start) to $($sprint.End))"
        } else {
            Write-Info "Sprint may already exist: $($sprint.Name)"
        }
    }
}

# ============================================================================
# Work Items Creation
# ============================================================================

function New-WorkItems {
    Write-Step "Creating work items..."
    
    $workItemIds = @{}
    
    # Create Epic
    Write-Info "Creating Epic..."
    $epic = Invoke-AzBoards -Command "work-item create --type `"Epic`" --title `"Customer Authentication Platform`" --description `"Complete authentication solution for the Contoso Web App`"" -ReturnJson
    if ($epic) {
        $workItemIds["Epic1"] = $epic.id
        Write-Success "Epic #$($epic.id): Customer Authentication Platform"
    }
    
    # Create Features
    Write-Info "Creating Features..."
    $features = @(
        @{ Title = "User Login & Registration"; Description = "Core login and registration functionality" },
        @{ Title = "Social Authentication"; Description = "OAuth integration with social providers" },
        @{ Title = "Multi-Factor Authentication"; Description = "MFA for enhanced security" }
    )
    
    $featureIndex = 1
    foreach ($feature in $features) {
        $f = Invoke-AzBoards -Command "work-item create --type `"Feature`" --title `"$($feature.Title)`" --description `"$($feature.Description)`"" -ReturnJson
        if ($f) {
            $workItemIds["Feature$featureIndex"] = $f.id
            Write-Success "Feature #$($f.id): $($feature.Title)"
            
            # Link to Epic
            if ($workItemIds["Epic1"]) {
                $null = az boards work-item relation add --id $f.id --relation-type "Parent" --target-id $workItemIds["Epic1"] --org $Organization 2>&1
            }
        }
        $featureIndex++
    }
    
    # Create User Stories
    Write-Info "Creating User Stories..."
    $stories = @(
        @{ Title = "As a user, I can login with email and password"; Points = 5; Sprint = "Sprint 3"; Feature = "Feature1"; State = "Active"; Assigned = $true },
        @{ Title = "As a user, I can reset my forgotten password"; Points = 3; Sprint = "Sprint 3"; Feature = "Feature1"; State = "Active"; Assigned = $true },
        @{ Title = "As a user, I can register a new account"; Points = 5; Sprint = "Sprint 3"; Feature = "Feature1"; State = "New"; Assigned = $true },
        @{ Title = "As a user, I can login with Google"; Points = 8; Sprint = "Sprint 4"; Feature = "Feature2"; State = "New"; Assigned = $false },
        @{ Title = "As a user, I can login with Microsoft"; Points = 8; Sprint = "Sprint 4"; Feature = "Feature2"; State = "New"; Assigned = $false },
        @{ Title = "As an admin, I can enforce MFA for users"; Points = 13; Sprint = ""; Feature = "Feature3"; State = "New"; Assigned = $false }
    )
    
    $storyIndex = 1
    foreach ($story in $stories) {
        $iterationPath = if ($story.Sprint) { "$ProjectName\$($story.Sprint)" } else { "$ProjectName" }
        
        $cmd = "work-item create --type `"User Story`" --title `"$($story.Title)`" --iteration `"$iterationPath`""
        $s = Invoke-AzBoards -Command $cmd -ReturnJson
        
        if ($s) {
            $workItemIds["Story$storyIndex"] = $s.id
            Write-Success "Story #$($s.id): $($story.Title)"
            
            # Update story points and state
            $null = az boards work-item update --id $s.id --fields "Microsoft.VSTS.Scheduling.StoryPoints=$($story.Points)" "System.State=$($story.State)" --org $Organization --project $ProjectName 2>&1
            
            # Link to Feature
            $featureKey = $story.Feature
            if ($workItemIds[$featureKey]) {
                $null = az boards work-item relation add --id $s.id --relation-type "Parent" --target-id $workItemIds[$featureKey] --org $Organization 2>&1
            }
        }
        $storyIndex++
    }
    
    # Create Tasks
    Write-Info "Creating Tasks..."
    $tasks = @(
        @{ Title = "Implement login API endpoint"; Hours = 4; Story = "Story1"; State = "Active" },
        @{ Title = "Create login UI component"; Hours = 4; Story = "Story1"; State = "Active" },
        @{ Title = "Write unit tests for login"; Hours = 3; Story = "Story1"; State = "New" },
        @{ Title = "Implement password reset API"; Hours = 4; Story = "Story2"; State = "Active" },
        @{ Title = "Create password reset email template"; Hours = 2; Story = "Story2"; State = "Closed" },
        @{ Title = "Design registration form"; Hours = 2; Story = "Story3"; State = "New" }
    )
    
    $taskIndex = 1
    foreach ($task in $tasks) {
        $t = Invoke-AzBoards -Command "work-item create --type `"Task`" --title `"$($task.Title)`"" -ReturnJson
        if ($t) {
            $workItemIds["Task$taskIndex"] = $t.id
            Write-Success "Task #$($t.id): $($task.Title)"
            
            # Update remaining work and state
            $null = az boards work-item update --id $t.id --fields "Microsoft.VSTS.Scheduling.RemainingWork=$($task.Hours)" "System.State=$($task.State)" --org $Organization --project $ProjectName 2>&1
            
            # Link to Story
            $storyKey = $task.Story
            if ($workItemIds[$storyKey]) {
                $null = az boards work-item relation add --id $t.id --relation-type "Parent" --target-id $workItemIds[$storyKey] --org $Organization 2>&1
            }
        }
        $taskIndex++
    }
    
    # Create Bugs
    Write-Info "Creating Bugs..."
    $bugs = @(
        @{ Title = "Login page crashes on mobile Safari"; Severity = "2 - High"; Priority = 2; State = "Active"; Sprint = "Sprint 3"; Story = "Story1"; Tags = "mobile,critical" },
        @{ Title = "Password reset link expires too quickly"; Severity = "3 - Medium"; Priority = 2; State = "New"; Sprint = "Sprint 3"; Story = "Story2"; Tags = "" },
        @{ Title = "Session timeout not working correctly"; Severity = "2 - High"; Priority = 1; State = "Active"; Sprint = "Sprint 3"; Story = "Story1"; Tags = "critical" },
        @{ Title = "Login button unresponsive on slow connections"; Severity = "3 - Medium"; Priority = 3; State = "New"; Sprint = ""; Story = "Story1"; Tags = "mobile" },
        @{ Title = "Email validation accepts invalid formats"; Severity = "3 - Medium"; Priority = 2; State = "Resolved"; Sprint = "Sprint 2"; Story = "Story3"; Tags = "" }
    )
    
    $bugIndex = 1
    foreach ($bug in $bugs) {
        $iterationPath = if ($bug.Sprint) { "$ProjectName\$($bug.Sprint)" } else { "$ProjectName" }
        
        $b = Invoke-AzBoards -Command "work-item create --type `"Bug`" --title `"$($bug.Title)`" --iteration `"$iterationPath`"" -ReturnJson
        if ($b) {
            $workItemIds["Bug$bugIndex"] = $b.id
            Write-Success "Bug #$($b.id): $($bug.Title)"
            
            # Update fields
            $fields = "Microsoft.VSTS.Common.Severity=`"$($bug.Severity)`"", "Microsoft.VSTS.Common.Priority=$($bug.Priority)", "System.State=$($bug.State)"
            if ($bug.Tags) {
                $fields += "System.Tags=`"$($bug.Tags)`""
            }
            $fieldsStr = $fields -join " "
            $null = az boards work-item update --id $b.id --fields $fields --org $Organization --project $ProjectName 2>&1
            
            # Link to Story
            $storyKey = $bug.Story
            if ($workItemIds[$storyKey]) {
                $null = az boards work-item relation add --id $b.id --relation-type "Related" --target-id $workItemIds[$storyKey] --org $Organization 2>&1
            }
        }
        $bugIndex++
    }
    
    Write-Success "Created $(($workItemIds.Keys | Measure-Object).Count) work items"
    return ,$workItemIds
}

# ============================================================================
# Repository & Code Setup
# ============================================================================

function New-SampleCode {
    param([string]$TempPath)
    
    Write-Step "Generating .NET Core sample application..."
    
    # Create directory structure
    $srcPath = Join-Path $TempPath "src"
    $apiPath = Join-Path $srcPath "Contoso.WebApp.Api"
    $testPath = Join-Path $TempPath "tests"
    $unitTestPath = Join-Path $testPath "Contoso.WebApp.Api.Tests"
    $pipelinesPath = Join-Path $TempPath ".azure-pipelines"
    
    New-Item -ItemType Directory -Path $apiPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $apiPath "Controllers") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $apiPath "Services") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $apiPath "Models") -Force | Out-Null
    New-Item -ItemType Directory -Path $unitTestPath -Force | Out-Null
    New-Item -ItemType Directory -Path $pipelinesPath -Force | Out-Null
    
    # .gitignore
    @"
## .NET
bin/
obj/
*.user
*.userosscache
*.sln.docstates
*.suo
*.cache
*.dll
*.pdb

## VS Code
.vscode/

## Build results
[Dd]ebug/
[Rr]elease/
x64/
x86/
build/
bld/

## NuGet
*.nupkg
**/packages/*
!**/packages/build/

## Test Results
TestResults/
*.trx

## IDE
.idea/
*.swp
*~

## OS
.DS_Store
Thumbs.db
"@ | Set-Content (Join-Path $TempPath ".gitignore")
    
    # Solution file
    @"
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Contoso.WebApp.Api", "src\Contoso.WebApp.Api\Contoso.WebApp.Api.csproj", "{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Contoso.WebApp.Api.Tests", "tests\Contoso.WebApp.Api.Tests\Contoso.WebApp.Api.Tests.csproj", "{B2C3D4E5-F6A7-8901-BCDE-F12345678901}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}.Release|Any CPU.Build.0 = Release|Any CPU
		{B2C3D4E5-F6A7-8901-BCDE-F12345678901}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
		{B2C3D4E5-F6A7-8901-BCDE-F12345678901}.Debug|Any CPU.Build.0 = Debug|Any CPU
		{B2C3D4E5-F6A7-8901-BCDE-F12345678901}.Release|Any CPU.ActiveCfg = Release|Any CPU
		{B2C3D4E5-F6A7-8901-BCDE-F12345678901}.Release|Any CPU.Build.0 = Release|Any CPU
	EndGlobalSection
EndGlobal
"@ | Set-Content (Join-Path $TempPath "Contoso.WebApp.sln")
    
    # API Project file
    @"
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Authentication.JwtBearer" Version="8.0.0" />
    <PackageReference Include="Swashbuckle.AspNetCore" Version="6.5.0" />
  </ItemGroup>

</Project>
"@ | Set-Content (Join-Path $apiPath "Contoso.WebApp.Api.csproj")
    
    # Program.cs
    @"
using Contoso.WebApp.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();

public partial class Program { }
"@ | Set-Content (Join-Path $apiPath "Program.cs")
    
    # Models
    @"
namespace Contoso.WebApp.Api.Models;

public class LoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class LoginResponse
{
    public bool Success { get; set; }
    public string? Token { get; set; }
    public string? Message { get; set; }
    public UserInfo? User { get; set; }
}

public class UserInfo
{
    public string Id { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
}

public class RegisterRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
}

public class PasswordResetRequest
{
    public string Email { get; set; } = string.Empty;
}

public class PasswordResetConfirmRequest
{
    public string Token { get; set; } = string.Empty;
    public string NewPassword { get; set; } = string.Empty;
}
"@ | Set-Content (Join-Path $apiPath "Models" "AuthModels.cs")
    
    # Auth Service Interface
    @"
using Contoso.WebApp.Api.Models;

namespace Contoso.WebApp.Api.Services;

public interface IAuthService
{
    Task<LoginResponse> LoginAsync(LoginRequest request);
    Task<LoginResponse> RegisterAsync(RegisterRequest request);
    Task<bool> RequestPasswordResetAsync(string email);
    Task<bool> ResetPasswordAsync(string token, string newPassword);
    bool ValidateToken(string token);
}
"@ | Set-Content (Join-Path $apiPath "Services" "IAuthService.cs")
    
    # Auth Service Implementation
    @"
using Contoso.WebApp.Api.Models;
using System.Text.RegularExpressions;

namespace Contoso.WebApp.Api.Services;

public class AuthService : IAuthService
{
    private readonly ILogger<AuthService> _logger;
    private static readonly Dictionary<string, (string Password, string DisplayName)> _users = new()
    {
        ["demo@contoso.com"] = ("Demo123!", "Demo User")
    };
    
    public AuthService(ILogger<AuthService> logger)
    {
        _logger = logger;
    }
    
    public async Task<LoginResponse> LoginAsync(LoginRequest request)
    {
        await Task.Delay(100); // Simulate async operation
        
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Password))
        {
            return new LoginResponse { Success = false, Message = "Email and password are required" };
        }
        
        if (!IsValidEmail(request.Email))
        {
            return new LoginResponse { Success = false, Message = "Invalid email format" };
        }
        
        if (_users.TryGetValue(request.Email.ToLower(), out var userData) && userData.Password == request.Password)
        {
            _logger.LogInformation("User {Email} logged in successfully", request.Email);
            return new LoginResponse
            {
                Success = true,
                Token = GenerateToken(),
                User = new UserInfo
                {
                    Id = Guid.NewGuid().ToString(),
                    Email = request.Email,
                    DisplayName = userData.DisplayName
                }
            };
        }
        
        _logger.LogWarning("Failed login attempt for {Email}", request.Email);
        return new LoginResponse { Success = false, Message = "Invalid credentials" };
    }
    
    public async Task<LoginResponse> RegisterAsync(RegisterRequest request)
    {
        await Task.Delay(100);
        
        if (!IsValidEmail(request.Email))
        {
            return new LoginResponse { Success = false, Message = "Invalid email format" };
        }
        
        if (_users.ContainsKey(request.Email.ToLower()))
        {
            return new LoginResponse { Success = false, Message = "User already exists" };
        }
        
        _users[request.Email.ToLower()] = (request.Password, request.DisplayName);
        _logger.LogInformation("New user registered: {Email}", request.Email);
        
        return new LoginResponse
        {
            Success = true,
            Token = GenerateToken(),
            User = new UserInfo
            {
                Id = Guid.NewGuid().ToString(),
                Email = request.Email,
                DisplayName = request.DisplayName
            }
        };
    }
    
    public async Task<bool> RequestPasswordResetAsync(string email)
    {
        await Task.Delay(100);
        
        if (_users.ContainsKey(email.ToLower()))
        {
            _logger.LogInformation("Password reset requested for {Email}", email);
            // In production, send email with reset link
            return true;
        }
        
        return false;
    }
    
    public async Task<bool> ResetPasswordAsync(string token, string newPassword)
    {
        await Task.Delay(100);
        // In production, validate token and update password
        _logger.LogInformation("Password reset completed");
        return true;
    }
    
    public bool ValidateToken(string token)
    {
        // Simplified validation - in production use JWT validation
        return !string.IsNullOrEmpty(token) && token.Length > 20;
    }
    
    private static bool IsValidEmail(string email)
    {
        if (string.IsNullOrWhiteSpace(email)) return false;
        return Regex.IsMatch(email, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    }
    
    private static string GenerateToken()
    {
        return Convert.ToBase64String(Guid.NewGuid().ToByteArray()) + 
               Convert.ToBase64String(Guid.NewGuid().ToByteArray());
    }
}
"@ | Set-Content (Join-Path $apiPath "Services" "AuthService.cs")
    
    # User Service
    @"
using Contoso.WebApp.Api.Models;

namespace Contoso.WebApp.Api.Services;

public interface IUserService
{
    Task<UserInfo?> GetUserByIdAsync(string id);
    Task<IEnumerable<UserInfo>> GetAllUsersAsync();
}

public class UserService : IUserService
{
    private readonly ILogger<UserService> _logger;
    
    public UserService(ILogger<UserService> logger)
    {
        _logger = logger;
    }
    
    public async Task<UserInfo?> GetUserByIdAsync(string id)
    {
        await Task.Delay(50);
        _logger.LogInformation("Getting user by ID: {Id}", id);
        
        return new UserInfo
        {
            Id = id,
            Email = "demo@contoso.com",
            DisplayName = "Demo User"
        };
    }
    
    public async Task<IEnumerable<UserInfo>> GetAllUsersAsync()
    {
        await Task.Delay(50);
        return new[]
        {
            new UserInfo { Id = "1", Email = "demo@contoso.com", DisplayName = "Demo User" },
            new UserInfo { Id = "2", Email = "admin@contoso.com", DisplayName = "Admin User" }
        };
    }
}
"@ | Set-Content (Join-Path $apiPath "Services" "UserService.cs")
    
    # Auth Controller
    @"
using Microsoft.AspNetCore.Mvc;
using Contoso.WebApp.Api.Models;
using Contoso.WebApp.Api.Services;

namespace Contoso.WebApp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ILogger<AuthController> _logger;
    
    public AuthController(IAuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
        _logger = logger;
    }
    
    /// <summary>
    /// Authenticate user with email and password
    /// </summary>
    [HttpPost("login")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }
        
        var result = await _authService.LoginAsync(request);
        
        if (!result.Success)
        {
            return BadRequest(result);
        }
        
        return Ok(result);
    }
    
    /// <summary>
    /// Register a new user account
    /// </summary>
    [HttpPost("register")]
    [ProducesResponseType(typeof(LoginResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<LoginResponse>> Register([FromBody] RegisterRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }
        
        var result = await _authService.RegisterAsync(request);
        
        if (!result.Success)
        {
            return BadRequest(result);
        }
        
        return CreatedAtAction(nameof(Login), result);
    }
    
    /// <summary>
    /// Request a password reset email
    /// </summary>
    [HttpPost("password-reset")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RequestPasswordReset([FromBody] PasswordResetRequest request)
    {
        var result = await _authService.RequestPasswordResetAsync(request.Email);
        
        if (!result)
        {
            return NotFound(new { message = "Email not found" });
        }
        
        return Ok(new { message = "Password reset email sent" });
    }
    
    /// <summary>
    /// Reset password with token
    /// </summary>
    [HttpPost("password-reset/confirm")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> ConfirmPasswordReset([FromBody] PasswordResetConfirmRequest request)
    {
        var result = await _authService.ResetPasswordAsync(request.Token, request.NewPassword);
        
        if (!result)
        {
            return BadRequest(new { message = "Invalid or expired token" });
        }
        
        return Ok(new { message = "Password reset successful" });
    }
}
"@ | Set-Content (Join-Path $apiPath "Controllers" "AuthController.cs")
    
    # Users Controller
    @"
using Microsoft.AspNetCore.Mvc;
using Contoso.WebApp.Api.Models;
using Contoso.WebApp.Api.Services;

namespace Contoso.WebApp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController : ControllerBase
{
    private readonly IUserService _userService;
    private readonly ILogger<UsersController> _logger;
    
    public UsersController(IUserService userService, ILogger<UsersController> logger)
    {
        _userService = userService;
        _logger = logger;
    }
    
    /// <summary>
    /// Get all users
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<UserInfo>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<UserInfo>>> GetUsers()
    {
        var users = await _userService.GetAllUsersAsync();
        return Ok(users);
    }
    
    /// <summary>
    /// Get user by ID
    /// </summary>
    [HttpGet("{id}")]
    [ProducesResponseType(typeof(UserInfo), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<UserInfo>> GetUser(string id)
    {
        var user = await _userService.GetUserByIdAsync(id);
        
        if (user == null)
        {
            return NotFound();
        }
        
        return Ok(user);
    }
}
"@ | Set-Content (Join-Path $apiPath "Controllers" "UsersController.cs")
    
    # Health Controller
    @"
using Microsoft.AspNetCore.Mvc;

namespace Contoso.WebApp.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HealthController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new 
        { 
            status = "healthy",
            timestamp = DateTime.UtcNow,
            version = "1.0.0"
        });
    }
}
"@ | Set-Content (Join-Path $apiPath "Controllers" "HealthController.cs")
    
    # appsettings.json
    @"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
"@ | Set-Content (Join-Path $apiPath "appsettings.json")
    
    # Test Project
    @"
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <IsPackable>false</IsPackable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.AspNetCore.Mvc.Testing" Version="8.0.0" />
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.8.0" />
    <PackageReference Include="Moq" Version="4.20.70" />
    <PackageReference Include="xunit" Version="2.6.2" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.5.4" />
    <PackageReference Include="coverlet.collector" Version="6.0.0" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\..\src\Contoso.WebApp.Api\Contoso.WebApp.Api.csproj" />
  </ItemGroup>

</Project>
"@ | Set-Content (Join-Path $unitTestPath "Contoso.WebApp.Api.Tests.csproj")
    
    # Unit Tests
    @"
using Xunit;
using Moq;
using Microsoft.Extensions.Logging;
using Contoso.WebApp.Api.Services;
using Contoso.WebApp.Api.Models;

namespace Contoso.WebApp.Api.Tests;

public class AuthServiceTests
{
    private readonly AuthService _authService;
    private readonly Mock<ILogger<AuthService>> _loggerMock;
    
    public AuthServiceTests()
    {
        _loggerMock = new Mock<ILogger<AuthService>>();
        _authService = new AuthService(_loggerMock.Object);
    }
    
    [Fact]
    public async Task Login_WithValidCredentials_ReturnsSuccess()
    {
        // Arrange
        var request = new LoginRequest
        {
            Email = "demo@contoso.com",
            Password = "Demo123!"
        };
        
        // Act
        var result = await _authService.LoginAsync(request);
        
        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.Token);
        Assert.NotNull(result.User);
        Assert.Equal("demo@contoso.com", result.User.Email);
    }
    
    [Fact]
    public async Task Login_WithInvalidCredentials_ReturnsFailure()
    {
        // Arrange
        var request = new LoginRequest
        {
            Email = "demo@contoso.com",
            Password = "wrongpassword"
        };
        
        // Act
        var result = await _authService.LoginAsync(request);
        
        // Assert
        Assert.False(result.Success);
        Assert.Null(result.Token);
        Assert.Equal("Invalid credentials", result.Message);
    }
    
    [Theory]
    [InlineData("", "password")]
    [InlineData("email@test.com", "")]
    [InlineData("", "")]
    public async Task Login_WithMissingFields_ReturnsFailure(string email, string password)
    {
        // Arrange
        var request = new LoginRequest { Email = email, Password = password };
        
        // Act
        var result = await _authService.LoginAsync(request);
        
        // Assert
        Assert.False(result.Success);
    }
    
    [Theory]
    [InlineData("invalid-email")]
    [InlineData("@nodomain.com")]
    [InlineData("missing@domain")]
    public async Task Login_WithInvalidEmailFormat_ReturnsFailure(string email)
    {
        // Arrange
        var request = new LoginRequest { Email = email, Password = "password123" };
        
        // Act
        var result = await _authService.LoginAsync(request);
        
        // Assert
        Assert.False(result.Success);
        Assert.Equal("Invalid email format", result.Message);
    }
    
    [Fact]
    public async Task Register_WithNewUser_ReturnsSuccess()
    {
        // Arrange
        var request = new RegisterRequest
        {
            Email = $"newuser{Guid.NewGuid():N}@contoso.com",
            Password = "NewUser123!",
            DisplayName = "New User"
        };
        
        // Act
        var result = await _authService.RegisterAsync(request);
        
        // Assert
        Assert.True(result.Success);
        Assert.NotNull(result.Token);
    }
    
    [Fact]
    public void ValidateToken_WithValidToken_ReturnsTrue()
    {
        // Arrange
        var token = "this_is_a_valid_token_with_more_than_20_characters";
        
        // Act
        var result = _authService.ValidateToken(token);
        
        // Assert
        Assert.True(result);
    }
    
    [Theory]
    [InlineData("")]
    [InlineData("short")]
    [InlineData(null)]
    public void ValidateToken_WithInvalidToken_ReturnsFalse(string? token)
    {
        // Act
        var result = _authService.ValidateToken(token!);
        
        // Assert
        Assert.False(result);
    }
}
"@ | Set-Content (Join-Path $unitTestPath "AuthServiceTests.cs")
    
    # CI Pipeline
    @"
# Contoso WebApp - CI Pipeline
# Triggers on PR and feature branches

trigger:
  branches:
    include:
      - main
      - develop
      - feature/*
      - bugfix/*

pr:
  branches:
    include:
      - main
      - develop

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  dotnetVersion: '8.0.x'

stages:
- stage: Build
  displayName: 'Build Stage'
  jobs:
  - job: Build
    displayName: 'Build Job'
    steps:
    - task: UseDotNet@2
      displayName: 'Install .NET SDK'
      inputs:
        packageType: 'sdk'
        version: `$(dotnetVersion)

    - task: DotNetCoreCLI@2
      displayName: 'Restore NuGet packages'
      inputs:
        command: 'restore'
        projects: '**/*.csproj'

    - task: DotNetCoreCLI@2
      displayName: 'Build solution'
      inputs:
        command: 'build'
        projects: '**/*.sln'
        arguments: '--configuration `$(buildConfiguration) --no-restore'

    - task: DotNetCoreCLI@2
      displayName: 'Publish application'
      inputs:
        command: 'publish'
        publishWebProjects: true
        arguments: '--configuration `$(buildConfiguration) --output `$(Build.ArtifactStagingDirectory)'

    - task: PublishBuildArtifacts@1
      displayName: 'Publish artifacts'
      inputs:
        PathtoPublish: '`$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'drop'

- stage: Test
  displayName: 'Test Stage'
  dependsOn: Build
  jobs:
  - job: UnitTests
    displayName: 'Run Unit Tests'
    steps:
    - task: UseDotNet@2
      displayName: 'Install .NET SDK'
      inputs:
        packageType: 'sdk'
        version: `$(dotnetVersion)

    - task: DotNetCoreCLI@2
      displayName: 'Run tests'
      inputs:
        command: 'test'
        projects: '**/tests/**/*.csproj'
        arguments: '--configuration `$(buildConfiguration) --collect:"XPlat Code Coverage" --logger trx --results-directory "`$(Agent.TempDirectory)"'

    - task: PublishTestResults@2
      displayName: 'Publish test results'
      inputs:
        testResultsFormat: 'VSTest'
        testResultsFiles: '**/*.trx'
        searchFolder: '`$(Agent.TempDirectory)'

    - task: PublishCodeCoverageResults@1
      displayName: 'Publish code coverage'
      inputs:
        codeCoverageTool: 'Cobertura'
        summaryFileLocation: '`$(Agent.TempDirectory)/**/coverage.cobertura.xml'

- stage: SecurityScan
  displayName: 'Security Scan Stage'
  dependsOn: Build
  jobs:
  - job: SecurityScan
    displayName: 'Security Analysis'
    steps:
    - task: UseDotNet@2
      displayName: 'Install .NET SDK'
      inputs:
        packageType: 'sdk'
        version: `$(dotnetVersion)

    - script: |
        dotnet tool install --global dotnet-outdated-tool
        dotnet outdated || true
      displayName: 'Check for outdated packages'
"@ | Set-Content (Join-Path $pipelinesPath "ci-pipeline.yml")
    
    # CD Pipeline
    @"
# Contoso WebApp - CD Pipeline
# Deploys to Azure environments

trigger:
  branches:
    include:
      - main

pool:
  vmImage: 'ubuntu-latest'

variables:
  buildConfiguration: 'Release'
  azureSubscription: 'Azure-ServiceConnection'

stages:
- stage: Build
  displayName: 'Build for Deployment'
  jobs:
  - job: Build
    steps:
    - task: UseDotNet@2
      inputs:
        packageType: 'sdk'
        version: '8.0.x'

    - task: DotNetCoreCLI@2
      displayName: 'Build and Publish'
      inputs:
        command: 'publish'
        publishWebProjects: true
        arguments: '--configuration `$(buildConfiguration) --output `$(Build.ArtifactStagingDirectory)'

    - task: PublishBuildArtifacts@1
      inputs:
        PathtoPublish: '`$(Build.ArtifactStagingDirectory)'
        ArtifactName: 'webapp'

- stage: DeployDev
  displayName: 'Deploy to Development'
  dependsOn: Build
  variables:
    environmentName: 'Development'
    appServiceName: 'contoso-webapp-dev'
  jobs:
  - deployment: DeployDev
    displayName: 'Deploy to Dev'
    environment: 'Development'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureWebApp@1
            displayName: 'Deploy to Azure Web App'
            inputs:
              azureSubscription: `$(azureSubscription)
              appType: 'webApp'
              appName: `$(appServiceName)
              package: '`$(Pipeline.Workspace)/webapp/**/*.zip'

- stage: DeployStaging
  displayName: 'Deploy to Staging'
  dependsOn: DeployDev
  variables:
    environmentName: 'Staging'
    appServiceName: 'contoso-webapp-staging'
  jobs:
  - deployment: DeployStaging
    displayName: 'Deploy to Staging'
    environment: 'Staging'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureWebApp@1
            displayName: 'Deploy to Azure Web App'
            inputs:
              azureSubscription: `$(azureSubscription)
              appType: 'webApp'
              appName: `$(appServiceName)
              package: '`$(Pipeline.Workspace)/webapp/**/*.zip'

- stage: DeployProduction
  displayName: 'Deploy to Production'
  dependsOn: DeployStaging
  variables:
    environmentName: 'Production'
    appServiceName: 'contoso-webapp-prod'
  jobs:
  - deployment: DeployProduction
    displayName: 'Deploy to Production'
    environment: 'Production'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureWebApp@1
            displayName: 'Deploy to Azure Web App'
            inputs:
              azureSubscription: `$(azureSubscription)
              appType: 'webApp'
              appName: `$(appServiceName)
              package: '`$(Pipeline.Workspace)/webapp/**/*.zip'
"@ | Set-Content (Join-Path $pipelinesPath "cd-pipeline.yml")
    
    # README
    @"
# Contoso WebApp

A modern .NET 8 web application demonstrating authentication patterns.

## Features

- User registration and login
- Password reset functionality
- JWT-based authentication
- RESTful API design
- Swagger/OpenAPI documentation

## Getting Started

### Prerequisites

- .NET 8.0 SDK
- Visual Studio 2022 or VS Code

### Running Locally

```bash
cd src/Contoso.WebApp.Api
dotnet run
```

Navigate to `https://localhost:5001/swagger` to view the API documentation.

### Running Tests

```bash
dotnet test
```

## Project Structure

```
├── src/
│   └── Contoso.WebApp.Api/     # Main API project
│       ├── Controllers/         # API controllers
│       ├── Models/             # Data models
│       └── Services/           # Business logic
├── tests/
│   └── Contoso.WebApp.Api.Tests/  # Unit tests
└── .azure-pipelines/           # CI/CD pipelines
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/auth/login | User login |
| POST | /api/auth/register | User registration |
| POST | /api/auth/password-reset | Request password reset |
| GET | /api/users | List all users |
| GET | /api/users/{id} | Get user by ID |
| GET | /api/health | Health check |

## Contributing

1. Create a feature branch from `develop`
2. Make your changes
3. Submit a pull request

## License

Copyright © Contoso Ltd. All rights reserved.
"@ | Set-Content (Join-Path $TempPath "README.md")
    
    Write-Success "Sample .NET Core application generated"
}

function Push-SampleCode {
    param([string]$TempPath)
    
    Write-Step "Setting up Azure DevOps repository..."
    
    # First, check if the repo exists. When a project is created with Git, 
    # a default repo with the project name is created automatically.
    # We need to either use that or create our own.
    
    $repo = $null
    
    # Try to get the repo by name
    Write-Info "Checking for existing repository: $RepoName"
    $repoList = az repos list --org $Organization --project "$ProjectName" 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    
    if ($repoList) {
        $repo = $repoList | Where-Object { $_.name -eq $RepoName } | Select-Object -First 1
    }
    
    if (-not $repo) {
        # Check if there's a default repo with the project name we can use
        $defaultRepo = $repoList | Where-Object { $_.name -eq $ProjectName } | Select-Object -First 1
        
        if ($defaultRepo -and -not ($repoList | Where-Object { $_.name -eq $RepoName })) {
            Write-Info "Creating repository: $RepoName"
            $createResult = az repos create --name "$RepoName" --org $Organization --project "$ProjectName" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $repo = $createResult | ConvertFrom-Json -ErrorAction SilentlyContinue
                Write-Success "Repository created: $RepoName"
                # Wait for repo to be fully provisioned
                Start-Sleep -Seconds 3
            } else {
                Write-Warning "Failed to create repo, trying to use default project repo"
                $repo = $defaultRepo
            }
        } else {
            $repo = $defaultRepo
        }
    }
    
    if (-not $repo) {
        # Last resort: create the repo
        Write-Info "Creating repository: $RepoName"
        $createResult = az repos create --name "$RepoName" --org $Organization --project "$ProjectName" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $repo = $createResult | ConvertFrom-Json -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3
        }
    }
    
    if (-not $repo -or -not $repo.remoteUrl) {
        Write-Warning "Could not get or create repository. Skipping code push."
        return $false
    }
    
    $repoUrl = $repo.remoteUrl
    $script:ActualRepoName = $repo.name  # Store for pipeline creation
    Write-Success "Using repository: $($repo.name)"
    Write-Info "Repository URL: $repoUrl"
    
    # Initialize git and push
    Push-Location $TempPath
    try {
        # Configure git for this operation
        git config --local user.email "demo@contoso.com" 2>$null
        git config --local user.name "Demo Setup Script" 2>$null
        
        git init 2>$null
        git checkout -b main 2>$null
        git add -A
        git commit -m "Initial commit: .NET 8 Web API with authentication" 2>$null
        
        # Add remote and push
        git remote remove origin 2>$null
        git remote add origin $repoUrl 2>$null
        
        Write-Info "Pushing to main branch..."
        $pushResult = git push -u origin main --force 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Push to main failed: $pushResult"
            Write-Info "You may need to configure Git credential manager or use a PAT"
            return $false
        }
        Write-Success "Pushed to main branch"
        
        # Create develop branch
        git checkout -b develop 2>$null
        $pushResult = git push -u origin develop --force 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Pushed develop branch"
        }
        
        # Create feature branch
        git checkout -b feature/auth 2>$null
        
        # Make a small change for the feature branch
        $readmePath = Join-Path $TempPath "README.md"
        Add-Content -Path $readmePath -Value "`n## Feature: Authentication Improvements`nThis branch contains enhanced authentication features."
        git add README.md
        git commit -m "Add authentication feature documentation" 2>$null
        $pushResult = git push -u origin feature/auth --force 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Pushed feature/auth branch"
        }
        
        # Create bugfix branch
        git checkout develop 2>$null
        git checkout -b bugfix/safari-crash 2>$null
        
        # Make a fix in the bugfix branch
        $authServicePath = Join-Path $TempPath "src" "Contoso.WebApp.Api" "Services" "AuthService.cs"
        if (Test-Path $authServicePath) {
            $content = Get-Content $authServicePath -Raw
            $content = $content -replace "// Simplified validation", "// Safari compatibility fix - Simplified validation"
            Set-Content -Path $authServicePath -Value $content
        }
        git add -A
        git commit -m "Fix: Safari crash on login page - iOS 17 compatibility" 2>$null
        $pushResult = git push -u origin bugfix/safari-crash --force 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Pushed bugfix/safari-crash branch"
        }
        
        Write-Success "Code pushed to all branches"
        return $true
    }
    catch {
        Write-Warning "Git operation failed: $_"
        return $false
    }
    finally {
        Pop-Location
    }
}

# ============================================================================
# Pipeline Setup
# ============================================================================

function New-Pipelines {
    Write-Step "Creating pipeline definitions..."
    
    # Use the actual repo name if set by Push-SampleCode
    $targetRepo = if ($script:ActualRepoName) { $script:ActualRepoName } else { $RepoName }
    
    Write-Info "Target repository: $targetRepo"
    
    # Wait for repo to be ready
    Start-Sleep -Seconds 3
    
    # Create CI Pipeline
    Write-Info "Creating CI Pipeline..."
    $ciPipeline = Invoke-AzPipelines -Command "create --name `"Contoso WebApp - CI`" --repository `"$targetRepo`" --repository-type tfsgit --branch main --yml-path .azure-pipelines/ci-pipeline.yml --skip-first-run true" -ReturnJson -AllowFailure
    
    if ($ciPipeline) {
        Write-Success "CI Pipeline created: $($ciPipeline.name)"
    } else {
        Write-Warning "CI Pipeline may already exist or YAML file not found"
    }
    
    # Create CD Pipeline
    Write-Info "Creating CD Pipeline..."
    $cdPipeline = Invoke-AzPipelines -Command "create --name `"Contoso WebApp - CD`" --repository `"$targetRepo`" --repository-type tfsgit --branch main --yml-path .azure-pipelines/cd-pipeline.yml --skip-first-run true" -ReturnJson -AllowFailure
    
    if ($cdPipeline) {
        Write-Success "CD Pipeline created: $($cdPipeline.name)"
    } else {
        Write-Warning "CD Pipeline may already exist or YAML file not found"
    }
}

function Start-SampleBuilds {
    Write-Step "Triggering sample pipeline runs..."
    
    # Get CI pipeline
    $pipelines = Invoke-AzPipelines -Command "list" -ReturnJson
    $ciPipeline = $pipelines | Where-Object { $_.name -like "*CI*" } | Select-Object -First 1
    
    if ($ciPipeline) {
        Write-Info "Queueing builds on different branches..."
        
        # Queue on main
        $build1 = Invoke-AzPipelines -Command "run --id $($ciPipeline.id) --branch main" -ReturnJson -AllowFailure
        if ($build1) { Write-Success "Build queued on main: #$($build1.id)" }
        
        Start-Sleep -Seconds 2
        
        # Queue on feature branch
        $build2 = Invoke-AzPipelines -Command "run --id $($ciPipeline.id) --branch feature/auth" -ReturnJson -AllowFailure
        if ($build2) { Write-Success "Build queued on feature/auth: #$($build2.id)" }
        
        Start-Sleep -Seconds 2
        
        # Queue on bugfix branch
        $build3 = Invoke-AzPipelines -Command "run --id $($ciPipeline.id) --branch bugfix/safari-crash" -ReturnJson -AllowFailure
        if ($build3) { Write-Success "Build queued on bugfix/safari-crash: #$($build3.id)" }
    } else {
        Write-Warning "CI Pipeline not found. Skipping build triggers."
    }
}

# ============================================================================
# Pull Request Creation
# ============================================================================

function New-PullRequests {
    param([hashtable]$WorkItemIds)
    
    Write-Step "Creating sample pull requests..."
    
    # Use the actual repo name if set by Push-SampleCode
    $targetRepo = if ($script:ActualRepoName) { $script:ActualRepoName } else { $RepoName }
    
    # PR from bugfix to develop
    Write-Info "Creating PR: Safari crash fix..."
    $pr1 = Invoke-AzRepos -Command "pr create --repository `"$targetRepo`" --source-branch bugfix/safari-crash --target-branch develop --title `"Fix Safari crash on login page`" --description `"Fixes the login page crash on mobile Safari (iOS 17+) by addressing a JavaScript compatibility issue.`n`nFixes #$($WorkItemIds['Bug1'])`" --draft false" -ReturnJson -AllowFailure
    
    if ($pr1) {
        Write-Success "PR #$($pr1.pullRequestId): Fix Safari crash on login page"
        
        # Link work item if we have the bug ID
        if ($WorkItemIds['Bug1']) {
            $null = az repos pr work-item add --id $pr1.pullRequestId --work-items $WorkItemIds['Bug1'] --org $Organization --project $ProjectName 2>&1
        }
    }
    
    # PR from feature to develop
    Write-Info "Creating PR: Authentication feature..."
    $pr2 = Invoke-AzRepos -Command "pr create --repository `"$targetRepo`" --source-branch feature/auth --target-branch develop --title `"Add authentication feature documentation`" --description `"Adds documentation for the authentication feature enhancements.`n`nRelated to Story #$($WorkItemIds['Story1'])`" --draft true" -ReturnJson -AllowFailure
    
    if ($pr2) {
        Write-Success "PR #$($pr2.pullRequestId): Add authentication feature documentation (Draft)"
        
        if ($WorkItemIds['Story1']) {
            $null = az repos pr work-item add --id $pr2.pullRequestId --work-items $WorkItemIds['Story1'] --org $Organization --project $ProjectName 2>&1
        }
    }
}

# ============================================================================
# Main Execution
# ============================================================================

function Main {
    Write-Host "`n" -NoNewline
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║     Azure DevOps MCP Demo Environment Setup                  ║" -ForegroundColor Magenta
    Write-Host "║     Setting up: $($ProjectName.PadRight(40))║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    
    $startTime = Get-Date
    
    try {
        # Prerequisites check
        Test-AzDevOpsCliReady
        
        # Configure defaults
        Write-Step "Configuring Azure DevOps defaults..."
        az devops configure --defaults organization=$Organization project="$ProjectName" 2>$null
        Write-Success "Defaults configured"
        
        # Create project
        $project = New-ADOProject
        
        # Create iterations
        New-Iterations
        
        # Create work items
        $workItemIds = New-WorkItems
        
        # Create and push sample code
        if (-not $SkipCodePush) {
            $tempPath = Join-Path $env:TEMP "contoso-webapp-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            
            try {
                New-SampleCode -TempPath $tempPath
                $codePushSuccess = Push-SampleCode -TempPath $tempPath
                
                if ($codePushSuccess) {
                    New-Pipelines
                    Start-SampleBuilds
                    New-PullRequests -WorkItemIds $workItemIds
                } else {
                    Write-Warning "Code push failed. Skipping pipeline and PR creation."
                    Write-Info "You can manually push the code and run the script again with -SkipCodePush"
                }
            }
            finally {
                # Cleanup temp directory
                if (Test-Path $tempPath) {
                    Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Warning "Skipping code push (--SkipCodePush specified)"
        }
        
        $elapsed = (Get-Date) - $startTime
        
        Write-Host "`n" -NoNewline
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║     ✓ Setup Complete!                                        ║" -ForegroundColor Green
        Write-Host "╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Green
        Write-Host "║  Project URL:                                                ║" -ForegroundColor Green
        Write-Host "║  $($Organization.Replace('https://',''))/$([uri]::EscapeDataString($ProjectName))".PadRight(61) + "║" -ForegroundColor Cyan
        Write-Host "║                                                              ║" -ForegroundColor Green
        Write-Host "║  Time elapsed: $($elapsed.ToString('mm\:ss'))                                        ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
        
        Write-Host "`nNext steps:" -ForegroundColor Yellow
        Write-Host "  1. Open the project in Azure DevOps" -ForegroundColor White
        Write-Host "  2. Configure the MCP Server connection" -ForegroundColor White
        Write-Host "  3. Start exploring with the sample prompts!" -ForegroundColor White
    }
    catch {
        Write-Host "`n❌ Setup failed: $_" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor DarkRed
        exit 1
    }
}

# Run main
Main
