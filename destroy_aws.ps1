<#
.SYNOPSIS
    Tears down all AECIP AWS resources to immediately stop billing.
#>

$ErrorActionPreference = "Stop"

Write-Host "============================================================" -ForegroundColor Red
Write-Host "     TEAR DOWN AECIP AWS INFRASTRUCTURE (STOP CHARGES)      " -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red

$confirm = Read-Host "Are you sure you want to destroy all AWS resources? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Tear down aborted." -ForegroundColor Yellow
    exit 0
}

Push-Location terraform
Write-Host "Running terraform destroy..." -ForegroundColor Yellow
terraform destroy -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nAll AWS cloud resources successfully destroyed. Charges stopped." -ForegroundColor Green
} else {
    Write-Host "`nError during terraform destroy. Check AWS Console for remaining resources." -ForegroundColor Red
}

Pop-Location
