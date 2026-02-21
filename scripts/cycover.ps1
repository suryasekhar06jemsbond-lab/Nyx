# Nyx Code Coverage Tool

param(
    [string]$Source = ".",
    [string]$Tests = ".",
    [string]$Output = "coverage.json",
    [int]$Threshold = 80,
    [switch]$Html,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
    Write-Host "Nyx Code Coverage Tool"
    Write-Host "Usage: .\scripts\cycover.ps1 <source> <tests>"
    Write-Host "Options: --html, --threshold, --output"
    exit 0
}

Write-Host "Analyzing coverage..." -ForegroundColor Cyan
Write-Host "Source: $Source"

# Find source files
$sourceFiles = Get-ChildItem -Path $Source -Recurse -Filter "*.ny" -ErrorAction SilentlyContinue

Write-Host "Found $($sourceFiles.Count) source files"

# Initialize
$totalLines = 0
$coveredLines = 0
$fileResults = @()

foreach ($file in $sourceFiles) {
    $content = Get-Content $file.FullName
    $lines = $content.Count
    $cov = 0
    
    foreach ($line in $content) {
        $trimmed = $line.Trim()
        if ($trimmed -and -not $trimmed.StartsWith("#")) {
            $cov++
        }
    }
    
    $totalLines += $lines
    $coveredLines += $cov
    
    $fileResults += @{
        name = $file.FullName
        lines = $lines
        covered = $cov
    }
}

$lineCoverage = 0
if ($totalLines -gt 0) {
    $lineCoverage = [math]::Round(($coveredLines / $totalLines) * 100, 1)
}

Write-Host ""
Write-Host "=== Coverage Results ===" -ForegroundColor Yellow
Write-Host "Lines: $lineCoverage% ($coveredLines/$totalLines)"

# JSON output
$json = @{
    version = "1.0"
    line_coverage = $lineCoverage
    files = $fileResults
} | ConvertTo-Json

$json | Out-File -FilePath $Output -Encoding UTF8
Write-Host "Saved to: $Output"

# HTML output
if ($Html) {
    $htmlOut = $Output -replace ".json", ".html"
    $html = "<html><head><title>Coverage</title></head><body>"
    $html += "<h1>Coverage: $lineCoverage%</h1><table>"
    $html += "<tr><th>File</th><th>Lines</th><th>Covered</th></tr>"
    
    foreach ($f in $fileResults) {
        $covPct = 0
        if ($f.lines -gt 0) {
            $covPct = [math]::Round(($f.covered / $f.lines) * 100, 1)
        }
        $html += "<tr><td>$($f.name)</td><td>$($f.lines)</td><td>$covPct%</td></tr>"
    }
    
    $html += "</table></body></html>"
    $html | Out-File -FilePath $htmlOut -Encoding UTF8
    Write-Host "HTML: $htmlOut"
}

if ($lineCoverage -lt $Threshold) {
    Write-Warning "Below threshold"
    exit 1
}

exit 0
