# Nyx Package Signing Tool

param(
    [string]$Package,
    [string]$Output,
    [switch]$Verify,
    [switch]$Gpg,
    [string]$KeyId,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help -or -not $Package) {
    Write-Host "Nyx Package Signing Tool"
    Write-Host "Usage: .\scripts\nysign.ps1 <package> [--output <file>]"
    Write-Host "       .\scripts\nysign.ps1 <package> --verify <signature>"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --verify    Verify signature"
    Write-Host "  --gpg       Use GPG signing"
    Write-Host "  --key-id    GPG key ID"
    Write-Host "  --output    Output file"
    exit 0
}

if (-not (Test-Path $Package)) {
    Write-Error "Package not found: $Package"
    exit 1
}

$pkgName = Split-Path $Package -Leaf
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($pkgName)

if ($Verify) {
    Write-Host "Verifying: $Package"
    
    if (-not (Test-Path $Verify)) {
        Write-Error "Signature not found: $Verify"
        exit 1
    }
    
    $sigContent = Get-Content $Verify -Raw
    $currentHash = (Get-FileHash -Path $Package -Algorithm SHA256).Hash.ToLower()
    
    Write-Host "Current:  $currentHash"
    Write-Host "Expected: $($sigContent.Trim().ToLower())"
    
    if ($currentHash -eq $sigContent.Trim().ToLower()) {
        Write-Host "VERIFIED" -ForegroundColor Green
        exit 0
    } else {
        Write-Error "FAILED"
        exit 1
    }
}

# Sign
Write-Host "Signing: $Package"

if (-not $Output) {
    $Output = "$baseName.sha256"
}

$hash = (Get-FileHash -Path $Package -Algorithm SHA256).Hash.ToLower()
"$hash  $pkgName" | Out-File -FilePath $Output -Encoding ASCII

Write-Host "Saved to: $Output" -ForegroundColor Green
exit 0
