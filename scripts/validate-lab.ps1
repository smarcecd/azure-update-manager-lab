param(
    [string]$ResourceGroup = "rg-aumlab",
    [string]$SubscriptionId
)

# ============================================================
# Azure Update Manager Compliance Validation
# ============================================================

Write-Host ""
Write-Host "=== Azure Update Manager Compliance Validation ===" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Validate Azure CLI
# ------------------------------------------------------------

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Azure CLI (az) is not installed or not in PATH." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# Login / Subscription
# ------------------------------------------------------------

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Unable to select subscription: $SubscriptionId" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "No SubscriptionId supplied. Using current Azure CLI subscription." -ForegroundColor Yellow
}

$account = az account show --output json 2>$null | ConvertFrom-Json

if (-not $account) {
    Write-Host "[INFO] Azure CLI is not logged in. Starting login..." -ForegroundColor Yellow

    az login

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Azure CLI login failed." -ForegroundColor Red
        exit 1
    }

    if ($SubscriptionId) {
        az account set --subscription $SubscriptionId
    }
}

$account = az account show --output json | ConvertFrom-Json

Write-Host "Subscription: $($account.name)" -ForegroundColor Green
Write-Host "Tenant:       $($account.tenantId)" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# VMs to validate
# ------------------------------------------------------------

$vms = @(
    "DC01",
    "WS01",
    "WS02"
)

$results = @()
$allPass = $true

# ------------------------------------------------------------
# Validate each VM
# ------------------------------------------------------------

foreach ($vm in $vms) {

    Write-Host "--------------------------------------------------"
    Write-Host "Validating $vm..." -ForegroundColor Cyan

    # --------------------------------------------------------
    # Get VM configuration
    # --------------------------------------------------------

    $vmJson = az vm show `
        --resource-group $ResourceGroup `
        --name $vm `
        --output json 2>$null

    if ($LASTEXITCODE -ne 0 -or -not $vmJson) {

        Write-Host "[FAIL] $vm -- VM not found" -ForegroundColor Red

        $allPass = $false

        $results += [PSCustomObject]@{
            VMName                   = $vm
            AssessmentStatus         = "VM_NOT_FOUND"
            CriticalAndSecurityCount = $null
            OtherPatchCount          = $null
            LastAssessmentTime       = $null
            PatchMode                = $null
            BypassSafetyChecks       = $null
            RebootSetting            = $null
            Compliant                = $false
            Result                   = "FAIL"
        }

        continue
    }

    $vmData = $vmJson | ConvertFrom-Json

    # --------------------------------------------------------
    # Patch configuration
    # --------------------------------------------------------

    $patchMode = $vmData.patchMode
    $bypassSafety = $vmData.bypassPlatformSafetyChecksOnUserSchedule
    $rebootSetting = $vmData.rebootSetting

    Write-Host "Patch Mode:       $patchMode"
    Write-Host "Bypass Safety:    $bypassSafety"
    Write-Host "Reboot Setting:   $rebootSetting"

    # --------------------------------------------------------
    # Trigger patch assessment
    # --------------------------------------------------------

    Write-Host "Starting patch assessment..." -ForegroundColor Yellow

    $assessmentJson = az vm assess-patches `
        --resource-group $ResourceGroup `
        --name $vm `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {

        Write-Host "[FAIL] $vm -- Patch assessment could not be started" -ForegroundColor Red
        Write-Host $assessmentJson -ForegroundColor DarkRed

        $allPass = $false

        $results += [PSCustomObject]@{
            VMName                   = $vm
            AssessmentStatus         = "AssessmentFailed"
            CriticalAndSecurityCount = $null
            OtherPatchCount          = $null
            LastAssessmentTime       = $null
            PatchMode                = $patchMode
            BypassSafetyChecks       = $bypassSafety
            RebootSetting            = $rebootSetting
            Compliant                = $false
            Result                   = "FAIL"
        }

        continue
    }

    $assessment = $assessmentJson | ConvertFrom-Json

    # --------------------------------------------------------
    # Extract assessment results
    # --------------------------------------------------------

    $status = $assessment.status

    $criticalSecurity = $assessment.availablePatchSummary.criticalAndSecurityPatchCount

    $otherPatches = $assessment.availablePatchSummary.otherPatchCount

    $assessmentTime = $assessment.availablePatchSummary.lastModifiedDateTime

    # --------------------------------------------------------
    # Compliance logic
    # --------------------------------------------------------

    #
    # For this lab:
    #
    # 1. Assessment must succeed
    # 2. VM must use AutomaticByPlatform
    # 3. Bypass safety checks must be enabled
    #
    # Patch counts are informational because a newly deployed
    # VM can legitimately have outstanding patches.
    #

    $configurationCompliant =
        ($patchMode -eq "AutomaticByPlatform") -and
        ($bypassSafety -eq $true)

    $assessmentSucceeded =
        ($status -eq "Succeeded")

    $compliant =
        $configurationCompliant -and
        $assessmentSucceeded

    if ($compliant) {
        $result = "PASS"
        $color = "Green"
    }
    else {
        $result = "FAIL"
        $color = "Red"
        $allPass = $false
    }

    # --------------------------------------------------------
    # Display result
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[$result] $vm" -ForegroundColor $color
    Write-Host "  Assessment Status:       $status"
    Write-Host "  Critical/Security:       $criticalSecurity"
    Write-Host "  Other Patches:           $otherPatches"
    Write-Host "  Patch Mode:              $patchMode"
    Write-Host "  Bypass Safety Checks:    $bypassSafety"
    Write-Host "  Reboot Setting:          $rebootSetting"
    Write-Host "  Assessment Time:         $assessmentTime"

    # --------------------------------------------------------
    # Save result
    # --------------------------------------------------------

    $results += [PSCustomObject]@{
        VMName                   = $vm
        AssessmentStatus         = $status
        CriticalAndSecurityCount = $criticalSecurity
        OtherPatchCount          = $otherPatches
        LastAssessmentTime       = $assessmentTime
        PatchMode                = $patchMode
        BypassSafetyChecks       = $bypassSafety
        RebootSetting            = $rebootSetting
        Compliant                = $compliant
        Result                   = $result
    }
}

# ------------------------------------------------------------
# Overall result
# ------------------------------------------------------------

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan

if ($allPass) {
    Write-Host "Overall: ALL PASS" -ForegroundColor Green
}
else {
    Write-Host "Overall: FAILURES DETECTED" -ForegroundColor Red
}

Write-Host "==================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# Export JSON report
# ------------------------------------------------------------

$report = @{
    GeneratedAt   = (Get-Date -Format "o")
    ResourceGroup = $ResourceGroup
    Subscription  = $account.name
    SubscriptionId = $account.id
    VMs           = $results
}

$report |
    ConvertTo-Json -Depth 10 |
    Out-File "./aum-compliance-report.json" -Encoding UTF8

Write-Host ""
Write-Host "Report exported: aum-compliance-report.json" -ForegroundColor Cyan
Write-Host ""