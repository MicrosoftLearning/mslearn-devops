# EShopOnWeb Work Items Import Script
# Prerequisites: az extension add --name azure-devops

param(
    [string]$Organization = "",
    [string]$Project = ""
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  EShopOnWeb Work Items Import Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================
# VALIDATE AZURE CLI LOGIN
# ============================================
Write-Host "`nChecking Azure CLI login status..." -ForegroundColor Yellow

try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if ($account) {
        Write-Host "  Logged in as: $($account.user.name)" -ForegroundColor Green
    } else {
        throw "Not logged in"
    }
} catch {
    Write-Host "  ERROR: You are not logged in to Azure CLI." -ForegroundColor Red
    Write-Host "  Please run 'az login' first and try again." -ForegroundColor Yellow
    exit 1
}

# ============================================
# VALIDATE AZURE DEVOPS EXTENSION
# ============================================
Write-Host "`nChecking Azure DevOps extension..." -ForegroundColor Yellow

$extensions = az extension list --output json | ConvertFrom-Json
$devopsExt = $extensions | Where-Object { $_.name -eq "azure-devops" }

if (-not $devopsExt) {
    Write-Host "  Azure DevOps extension not found. Installing..." -ForegroundColor Yellow
    az extension add --name azure-devops
    Write-Host "  Azure DevOps extension installed." -ForegroundColor Green
} else {
    Write-Host "  Azure DevOps extension is installed." -ForegroundColor Green
}

# ============================================
# GET ORGANIZATION
# ============================================
Write-Host "`n----------------------------------------" -ForegroundColor DarkGray

# Helper function to get configured defaults
function Get-AzDevOpsDefault {
    param([string]$ConfigName)
    $configOutput = az devops configure --list 2>$null
    if ($configOutput) {
        foreach ($line in $configOutput) {
            if ($line -match $ConfigName) {
                # For organization, extract just the org name from the URL
                if ($ConfigName -eq "organization" -and $line -match "dev\.azure\.com/([a-zA-Z0-9_-]+)") {
                    return $Matches[1]
                }
                # For project, extract value after = sign
                if ($ConfigName -eq "project" -and $line -match "=\s*(.+)$") {
                    $value = $Matches[1].Trim()
                    if ($value -and $value -ne "None" -and $value -ne "(not set)") {
                        return $value
                    }
                }
            }
        }
    }
    return $null
}

# If command-line parameter provided, use it
if ($Organization) {
    if ($Organization -notlike "https://*") {
        $Organization = "https://dev.azure.com/$Organization"
    }
    Write-Host "  Using provided organization: $Organization" -ForegroundColor Cyan
} else {
    $defaultOrg = Get-AzDevOpsDefault -ConfigName "organization"
    if ($defaultOrg) {
        $inputOrg = Read-Host "Enter Azure DevOps Organization name [$defaultOrg]"
        if (-not $inputOrg) { 
            $Organization = "https://dev.azure.com/$defaultOrg" 
        } else {
            if ($inputOrg -notlike "https://*") {
                $Organization = "https://dev.azure.com/$inputOrg"
            } else {
                $Organization = $inputOrg
            }
        }
    } else {
        $Organization = Read-Host "Enter Azure DevOps Organization (name or full URL)"
        if (-not $Organization) {
            Write-Host "  ERROR: Organization is required." -ForegroundColor Red
            exit 1
        }
        if ($Organization -notlike "https://*") {
            $Organization = "https://dev.azure.com/$Organization"
        }
    }
}

Write-Host "  Organization: $Organization" -ForegroundColor Cyan

# Set organization for project listing
az devops configure --defaults organization=$Organization 2>$null

# ============================================
# GET PROJECTS IN SELECTED ORGANIZATION
# ============================================
Write-Host "`nFetching projects from organization..." -ForegroundColor Yellow

try {
    $projectsJson = az devops project list --output json 2>$null
    if ($projectsJson) {
        $projects = ($projectsJson | ConvertFrom-Json).value
    } else {
        $projects = @()
    }
} catch {
    $projects = @()
}

# If command-line parameter provided, use it
if ($Project) {
    Write-Host "  Using provided project: $Project" -ForegroundColor Cyan
} elseif ($projects.Count -gt 0) {
    # Display numbered list of projects
    Write-Host "`nAvailable Projects:" -ForegroundColor Cyan
    Write-Host "-------------------" -ForegroundColor DarkGray
    
    $projList = @()
    $index = 1
    foreach ($proj in $projects) {
        $projList += $proj.name
        $processInfo = ""
        if ($proj.capabilities.processTemplate.templateName) {
            $processInfo = " (Process: $($proj.capabilities.processTemplate.templateName))"
        }
        Write-Host "  [$index] $($proj.name)$processInfo" -ForegroundColor White
        $index++
    }
    
    Write-Host ""
    $selection = Read-Host "Select project (1-$($projList.Count))"
    
    if ($selection -match '^\d+$') {
        $selIndex = [int]$selection - 1
        if ($selIndex -ge 0 -and $selIndex -lt $projList.Count) {
            $Project = $projList[$selIndex]
            Write-Host "  Selected: $Project" -ForegroundColor Green
        } else {
            Write-Host "  ERROR: Invalid selection." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "  ERROR: Please enter a number." -ForegroundColor Red
        exit 1
    }
} else {
    # Fallback to manual entry
    Write-Host "  Could not retrieve projects automatically." -ForegroundColor Yellow
    $Project = Read-Host "Enter Azure DevOps Project name (e.g., EShopOnWeb)"
    if (-not $Project) {
        Write-Host "  ERROR: Project name is required." -ForegroundColor Red
        exit 1
    }
}

Write-Host "  Project: $Project" -ForegroundColor Cyan

# ============================================
# CONFIGURE DEFAULTS
# ============================================
Write-Host "`nConfiguring Azure DevOps defaults..." -ForegroundColor Yellow
az devops configure --defaults organization=$Organization project=$Project

# ============================================
# VALIDATE PROJECT ACCESS
# ============================================
Write-Host "Validating project access..." -ForegroundColor Yellow

try {
    $projectInfo = az devops project show --project $Project --output json 2>$null | ConvertFrom-Json
    if ($projectInfo) {
        Write-Host "  Project '$($projectInfo.name)' found. Process: $($projectInfo.capabilities.processTemplate.templateName)" -ForegroundColor Green
    } else {
        throw "Project not found"
    }
} catch {
    Write-Host "  ERROR: Cannot access project '$Project'." -ForegroundColor Red
    Write-Host "  Please verify the project exists and you have access." -ForegroundColor Yellow
    exit 1
}

# ============================================
# CONFIRM BEFORE PROCEEDING
# ============================================
Write-Host "`n----------------------------------------" -ForegroundColor DarkGray
Write-Host "Ready to import work items:" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor DarkGray

$confirm = Read-Host "Proceed with import? (Y/n)"
if ($confirm -eq "n" -or $confirm -eq "N") {
    Write-Host "Import cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nStarting EShopOnWeb work items import..." -ForegroundColor Cyan

# ============================================
# CREATE ITERATIONS (SPRINTS)
# ============================================
Write-Host "`nCreating Sprints..." -ForegroundColor Yellow

# Get today's date for sprint planning
$sprintStart = Get-Date
$sprintDuration = 14  # 2-week sprints

# Create 4 sprints
for ($i = 1; $i -le 4; $i++) {
    $startDate = $sprintStart.AddDays(($i - 1) * $sprintDuration)
    $endDate = $startDate.AddDays($sprintDuration - 1)
    
    $startDateStr = $startDate.ToString("yyyy-MM-dd")
    $endDateStr = $endDate.ToString("yyyy-MM-dd")
    
    try {
        az boards iteration project create --name "Sprint $i" --path "\$Project\Iteration" --start-date $startDateStr --finish-date $endDateStr --output none 2>$null
        Write-Host "  Created Sprint $i ($startDateStr to $endDateStr)" -ForegroundColor Green
    } catch {
        Write-Host "  Sprint $i already exists or could not be created" -ForegroundColor DarkGray
    }
}

# Create team iterations (add sprints to team backlog)
Write-Host "`nAdding Sprints to Team backlog..." -ForegroundColor Yellow
$team = "$Project Team"
for ($i = 1; $i -le 4; $i++) {
    try {
        az boards iteration team add --id "\$Project\Sprint $i" --team $team --output none 2>$null
        Write-Host "  Added Sprint $i to team backlog" -ForegroundColor Green
    } catch {
        Write-Host "  Sprint $i already in team backlog" -ForegroundColor DarkGray
    }
}

# Helper function to create work item and return ID
function New-WorkItem {
    param(
        [string]$Type,
        [string]$Title,
        [string]$Description,
        [string]$State = "New",
        [int]$Priority = 2,
        [string]$Tags = "",
        [int]$StoryPoints = 0,
        [int]$OriginalEstimate = 0,
        [int]$RemainingWork = 0,
        [int]$CompletedWork = 0,
        [string]$Severity = "",
        [int]$ParentId = 0,
        [string]$IterationPath = ""
    )
    
    # Create work item first (always creates in New state)
    $fields = @(
        "--title", "`"$Title`"",
        "--type", $Type,
        "--description", "`"$Description`"",
        "--fields", "Microsoft.VSTS.Common.Priority=$Priority"
    )
    
    if ($Tags) {
        $fields += "--fields", "System.Tags=`"$Tags`""
    }
    
    if ($StoryPoints -gt 0) {
        $fields += "--fields", "Microsoft.VSTS.Scheduling.StoryPoints=$StoryPoints"
    }
    
    if ($OriginalEstimate -gt 0) {
        $fields += "--fields", "Microsoft.VSTS.Scheduling.OriginalEstimate=$OriginalEstimate"
    }
    
    if ($RemainingWork -gt 0) {
        $fields += "--fields", "Microsoft.VSTS.Scheduling.RemainingWork=$RemainingWork"
    }
    
    if ($CompletedWork -gt 0) {
        $fields += "--fields", "Microsoft.VSTS.Scheduling.CompletedWork=$CompletedWork"
    }
    
    if ($Severity) {
        $fields += "--fields", "Microsoft.VSTS.Common.Severity=`"$Severity`""
    }
    
    if ($IterationPath) {
        $fields += "--iteration", "`"$IterationPath`""
    }
    
    $result = az boards work-item create @fields --output json | ConvertFrom-Json
    $id = $result.id
    
    Write-Host "  Created $Type #$id : $Title" -ForegroundColor Green
    
    # Link to parent if specified
    if ($ParentId -gt 0) {
        az boards work-item relation add --id $id --relation-type Parent --target-id $ParentId --output none
        Write-Host "    Linked to parent #$ParentId" -ForegroundColor DarkGray
    }
    
    # Update state if not "New" (must be done after creation)
    if ($State -ne "New") {
        az boards work-item update --id $id --fields "System.State=$State" --output none 2>$null
        Write-Host "    State: $State" -ForegroundColor DarkYellow
    }
    
    return $id
}

# ============================================
# EPICS (3 epics with varied states)
# ============================================
Write-Host "`nCreating Epics..." -ForegroundColor Yellow

$epicPlatform = New-WorkItem -Type "Epic" -Title "E-Commerce Platform Modernization" `
    -Description "Modernize the EShopOnWeb platform to improve performance and scalability" `
    -State "Active" -Priority 1 -Tags "modernization;platform" -IterationPath "$Project"

$epicMobile = New-WorkItem -Type "Epic" -Title "Mobile Experience Enhancement" `
    -Description "Develop and optimize mobile shopping experience for iOS and Android users" `
    -State "Active" -Priority 2 -Tags "mobile;ux" -IterationPath "$Project"

$epicPayment = New-WorkItem -Type "Epic" -Title "Payment & Checkout Optimization" `
    -Description "Streamline payment processing and checkout flow to reduce cart abandonment" `
    -State "New" -Priority 1 -Tags "payments;checkout" -IterationPath "$Project"

# ============================================
# FEATURES (5 features linked to epics)
# ============================================
Write-Host "`nCreating Features..." -ForegroundColor Yellow

# Platform Epic Features
$featCatalog = New-WorkItem -Type "Feature" -Title "Product Catalog Redesign" `
    -Description "Redesign product catalog with improved filtering and search capabilities" `
    -State "Active" -Priority 1 -Tags "catalog;search" -StoryPoints 13 -ParentId $epicPlatform -IterationPath "$Project\Sprint 1"

$featAuth = New-WorkItem -Type "Feature" -Title "User Authentication & Profile" `
    -Description "Implement modern authentication with social login and enhanced profiles" `
    -State "New" -Priority 1 -Tags "auth;security" -StoryPoints 8 -ParentId $epicPlatform -IterationPath "$Project\Sprint 2"

# Mobile Epic Features
$featMobileUI = New-WorkItem -Type "Feature" -Title "Responsive Mobile UI" `
    -Description "Create fully responsive UI optimized for mobile devices" `
    -State "New" -Priority 1 -Tags "mobile;responsive" -StoryPoints 13 -ParentId $epicMobile -IterationPath "$Project\Sprint 2"

# Payment Epic Features
$featPaymentGateway = New-WorkItem -Type "Feature" -Title "Payment Gateway Integration" `
    -Description "Integrate multiple payment gateways including Stripe and PayPal" `
    -State "New" -Priority 1 -Tags "payments;integration" -StoryPoints 13 -ParentId $epicPayment -IterationPath "$Project\Sprint 3"

$featOneClick = New-WorkItem -Type "Feature" -Title "One-Click Checkout" `
    -Description "Implement streamlined one-click checkout for returning customers" `
    -State "New" -Priority 2 -Tags "checkout;ux" -StoryPoints 8 -ParentId $epicPayment -IterationPath "$Project\Sprint 4"

# ============================================
# USER STORIES (5 stories linked to features)
# ============================================
Write-Host "`nCreating User Stories..." -ForegroundColor Yellow

# Product Catalog Stories
$storySearch = New-WorkItem -Type "User Story" -Title "Implement advanced product search with filters" `
    -Description "As a customer I want to filter products by price brand and size" `
    -State "Active" -Priority 1 -Tags "search;filters" -StoryPoints 5 -ParentId $featCatalog -IterationPath "$Project\Sprint 1"

$storyImages = New-WorkItem -Type "User Story" -Title "Add product image gallery with zoom" `
    -Description "As a customer I want to view multiple product images and zoom in for details" `
    -State "Closed" -Priority 2 -Tags "images;ux" -StoryPoints 3 -ParentId $featCatalog -IterationPath "$Project\Sprint 1"

# Authentication Stories
$storySocialLogin = New-WorkItem -Type "User Story" -Title "Add social login options" `
    -Description "As a customer I want to sign in using Google or Facebook for convenience" `
    -State "Active" -Priority 1 -Tags "auth;social" -StoryPoints 5 -ParentId $featAuth -IterationPath "$Project\Sprint 2"

# Mobile UI Stories
$storyMobileNav = New-WorkItem -Type "User Story" -Title "Implement mobile-optimized navigation" `
    -Description "As a mobile user I want easy thumb-friendly navigation to browse products" `
    -State "New" -Priority 1 -Tags "mobile;navigation" -StoryPoints 5 -ParentId $featMobileUI -IterationPath "$Project\Sprint 2"

# Payment Stories
$storyStripe = New-WorkItem -Type "User Story" -Title "Integrate Stripe payment processing" `
    -Description "As a customer I want to pay securely with my credit card through Stripe" `
    -State "New" -Priority 1 -Tags "payments;stripe" -StoryPoints 8 -ParentId $featPaymentGateway -IterationPath "$Project\Sprint 3"

# ============================================
# TASKS (5 tasks linked to stories)
# ============================================
Write-Host "`nCreating Tasks..." -ForegroundColor Yellow

# Search Tasks - linked to search story
New-WorkItem -Type "Task" -Title "Set up Elasticsearch for product search" `
    -Description "Configure and deploy Elasticsearch cluster for product search" `
    -State "Closed" -Priority 1 -Tags "infrastructure;search" -OriginalEstimate 8 -RemainingWork 0 -CompletedWork 8 `
    -ParentId $storySearch -IterationPath "$Project\Sprint 1"

New-WorkItem -Type "Task" -Title "Create product filter UI components" `
    -Description "Develop reusable filter components for price range and categories" `
    -State "Active" -Priority 1 -Tags "frontend;components" -OriginalEstimate 16 -RemainingWork 10 -CompletedWork 6 `
    -ParentId $storySearch -IterationPath "$Project\Sprint 1"

# Image Gallery Tasks - linked to images story
New-WorkItem -Type "Task" -Title "Implement image zoom component" `
    -Description "Create React component for product image zoom functionality" `
    -State "Closed" -Priority 2 -Tags "frontend;images" -OriginalEstimate 8 -RemainingWork 0 -CompletedWork 8 `
    -ParentId $storyImages -IterationPath "$Project\Sprint 1"

# OAuth Tasks - linked to social login story
New-WorkItem -Type "Task" -Title "Create OAuth integration for Google" `
    -Description "Implement Google OAuth 2.0 authentication flow" `
    -State "Active" -Priority 1 -Tags "auth;google" -OriginalEstimate 8 -RemainingWork 4 -CompletedWork 4 `
    -ParentId $storySocialLogin -IterationPath "$Project\Sprint 2"

New-WorkItem -Type "Task" -Title "Create OAuth integration for Facebook" `
    -Description "Implement Facebook Login authentication flow" `
    -State "New" -Priority 2 -Tags "auth;facebook" -OriginalEstimate 8 -RemainingWork 8 `
    -ParentId $storySocialLogin -IterationPath "$Project\Sprint 2"

# ============================================
# BUGS (5 bugs with varied states)
# ============================================
Write-Host "`nCreating Bugs..." -ForegroundColor Yellow

New-WorkItem -Type "Bug" -Title "Product images not loading on slow connections" `
    -Description "Product images fail to load or timeout on 3G connections" `
    -State "Resolved" -Priority 1 -Tags "images;performance" -Severity "3 - Medium" -IterationPath "$Project\Sprint 1"

New-WorkItem -Type "Bug" -Title "Search results showing out-of-stock items" `
    -Description "Search results include products that are out of stock without indication" `
    -State "Active" -Priority 2 -Tags "search;inventory" -Severity "2 - High" -IterationPath "$Project\Sprint 1"

New-WorkItem -Type "Bug" -Title "Cart total not updating after quantity change" `
    -Description "When changing item quantity in cart the total does not update" `
    -State "Closed" -Priority 1 -Tags "cart;calculation" -Severity "2 - High" -IterationPath "$Project\Sprint 1"

New-WorkItem -Type "Bug" -Title "Mobile menu overlapping content on iOS Safari" `
    -Description "Navigation menu overlaps page content on iOS Safari orientation change" `
    -State "New" -Priority 2 -Tags "mobile;ios" -Severity "3 - Medium" -IterationPath "$Project\Sprint 2"

New-WorkItem -Type "Bug" -Title "Social login failing with popup blocker" `
    -Description "Social login popup is blocked by default browser settings" `
    -State "Active" -Priority 2 -Tags "auth;popup" -Severity "2 - High" -IterationPath "$Project\Sprint 2"

# ============================================
# ISSUES (5 issues with varied states)
# ============================================
Write-Host "`nCreating Issues..." -ForegroundColor Yellow

New-WorkItem -Type "Issue" -Title "Third-party shipping API downtime" `
    -Description "FedEx API experiencing intermittent outages affecting order tracking" `
    -State "Active" -Priority 1 -Tags "integration;shipping" -IterationPath "$Project\Sprint 4"

New-WorkItem -Type "Issue" -Title "Payment gateway rate limits reached" `
    -Description "Stripe rate limits being hit during peak hours causing failures" `
    -State "Active" -Priority 1 -Tags "payments;performance" -IterationPath "$Project\Sprint 3"

New-WorkItem -Type "Issue" -Title "CDN cache invalidation delays" `
    -Description "Product updates taking up to 2 hours to reflect due to CDN cache" `
    -State "Closed" -Priority 2 -Tags "infrastructure;cdn" -IterationPath "$Project\Sprint 2"

New-WorkItem -Type "Issue" -Title "Database connection pool exhaustion" `
    -Description "Database connections being exhausted during traffic spikes" `
    -State "Closed" -Priority 1 -Tags "database;performance" -IterationPath "$Project\Sprint 1"

New-WorkItem -Type "Issue" -Title "SSL certificate expiring next month" `
    -Description "Production SSL certificate expires in 30 days and needs renewal" `
    -State "Active" -Priority 1 -Tags "security;infrastructure" -IterationPath "$Project\Sprint 2"

# ============================================
# SUMMARY
# ============================================
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Import Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Created a total of 28 work items with full hierarchy and varied states"
