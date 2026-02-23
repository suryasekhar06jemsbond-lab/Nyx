# ============================================================================
# Nyx Engine Test Suite - PowerShell Runner
# Run all engine tests on Windows
# ============================================================================

param(
    [string]$Suite = "all",
    [switch]$Verbose = $false,
    [switch]$Report = $true,
    [int]$Timeout = 300
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning-Custom { Write-Host $args -ForegroundColor Yellow }

# Banner
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║         NyX ENGINE TEST SUITE - PowerShell Runner              ║" -ForegroundColor Cyan
Write-Host "║         Testing All 117 Engines                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Test suites
$testSuites = @{
    "ai_ml" = @{
        name = "AI/ML Engines"
        file = "tests\engines\test_ai_ml_engines.ny"
        engines = 21
    }
    "data" = @{
        name = "Data Processing Engines"
        file = "tests\engines\test_data_engines.ny"
        engines = 18
    }
    "security" = @{
        name = "Security Engines"
        file = "tests\engines\test_security_engines.ny"
        engines = 17
    }
    "web" = @{
        name = "Web & Network Engines"
        file = "tests\engines\test_web_engines.ny"
        engines = 15
    }
    "graphics" = @{
        name = "Graphics & Media Engines"
        file = "tests\engines\test_graphics_engines.ny"
        engines = 10
    }
    "devops" = @{
        name = "DevOps & System Engines"
        file = "tests\engines\test_devops_engines.ny"
        engines = 12
    }
    "scientific" = @{
        name = "Scientific Computing Engines"
        file = "tests\engines\test_scientific_engines.ny"
        engines = 8
    }
    "utility" = @{
        name = "Utility Engines"
        file = "tests\engines\test_utility_engines.ny"
        engines = 8
    }
}

# Check if Nyx is available
try {
    $nyxVersion = & nyx --version 2>&1
    Write-Success "✓ Nyx runtime found: $nyxVersion"
} catch {
    Write-Error-Custom "✗ Nyx runtime not found in PATH"
    Write-Info "  Please install Nyx or add it to your PATH"
    exit 1
}

Write-Host ""

# Function to run a test suite
function Run-TestSuite {
    param(
        [string]$Name,
        [string]$File,
        [int]$Engines
    )
    
    Write-Info "Running: $Name ($Engines engines)"
    $startTime = Get-Date
    
    try {
        if ($Verbose) {
            & nyx run $File
        } else {
            $output = & nyx run $File 2>&1
        }
        
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "  ✓ PASSED - ${duration}ms"
            return @{
                name = $Name
                passed = $true
                duration = $duration
                engines = $Engines
            }
        } else {
            Write-Error-Custom "  ✗ FAILED - Exit code: $LASTEXITCODE"
            return @{
                name = $Name
                passed = $false
                duration = $duration
                engines = $Engines
                error = "Exit code: $LASTEXITCODE"
            }
        }
    } catch {
        $duration = ((Get-Date) - $startTime).TotalMilliseconds
        Write-Error-Custom "  ✗ CRASHED - $($_.Exception.Message)"
        return @{
            name = $Name
            passed = $false
            duration = $duration
            engines = $Engines
            error = $_.Exception.Message
        }
    }
}

# Run tests
$results = @()
$totalStart = Get-Date

if ($Suite -eq "all") {
    # Run all test suites
    foreach ($key in $testSuites.Keys | Sort-Object) {
        $suite = $testSuites[$key]
        $result = Run-TestSuite -Name $suite.name -File $suite.file -Engines $suite.engines
        $results += $result
        Write-Host ""
    }
} else {
    # Run specific suite
    if ($testSuites.ContainsKey($Suite)) {
        $suite = $testSuites[$Suite]
        $result = Run-TestSuite -Name $suite.name -File $suite.file -Engines $suite.engines
        $results += $result
    } else {
        Write-Error-Custom "Unknown test suite: $Suite"
        Write-Info "Available suites: $($testSuites.Keys -join ', ')"
        exit 1
    }
}

$totalDuration = ((Get-Date) - $totalStart).TotalMilliseconds

# Summary
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              TEST SUITE SUMMARY                                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$passed = ($results | Where-Object { $_.passed }).Count
$failed = ($results | Where-Object { -not $_.passed }).Count
$totalEngines = ($results | Measure-Object -Property engines -Sum).Sum

Write-Info "📊 Statistics:"
Write-Host "  • Total Test Suites:    $($results.Count)"
Write-Host "  • Total Engines Tested: $totalEngines"
Write-Success "  • Suites Passed:        $passed ✓"
if ($failed -gt 0) {
    Write-Error-Custom "  • Suites Failed:        $failed ✗"
} else {
    Write-Host "  • Suites Failed:        $failed"
}
Write-Host "  • Total Duration:       ${totalDuration}ms"
Write-Host "  • Success Rate:         $([math]::Round($passed * 100 / $results.Count, 1))%"
Write-Host ""

Write-Info "📋 Detailed Results:"
foreach ($result in $results) {
    if ($result.passed) {
        Write-Success "  ✓ PASSED: $($result.name) ($($result.engines) engines) - $($result.duration)ms"
    } else {
        Write-Error-Custom "  ✗ FAILED: $($result.name) ($($result.engines) engines) - $($result.duration)ms"
        if ($result.error) {
            Write-Warning-Custom "    Error: $($result.error)"
        }
    }
}
Write-Host ""

# Generate report
if ($Report) {
    $reportData = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        total_suites = $results.Count
        total_engines = $totalEngines
        passed_suites = $passed
        failed_suites = $failed
        total_duration_ms = $totalDuration
        success_rate = [math]::Round($passed * 100 / $results.Count, 2)
        results = $results
    }
    
    # Save JSON report
    $jsonReport = $reportData | ConvertTo-Json -Depth 10
    $jsonReport | Out-File -FilePath "test_results.json" -Encoding UTF8
    Write-Info "📄 JSON report saved: test_results.json"
    
    # Save Markdown report
    $mdReport = @"
# Nyx Engine Test Report

**Generated:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Summary

| Metric | Value |
|--------|-------|
| Total Suites | $($results.Count) |
| Total Engines | $totalEngines |
| Passed | $passed |
| Failed | $failed |
| Duration | ${totalDuration}ms |
| Success Rate | $([math]::Round($passed * 100 / $results.Count, 1))% |

## Detailed Results

"@
    
    foreach ($result in $results) {
        $status = if ($result.passed) { "✓ PASS" } else { "✗ FAIL" }
        $mdReport += "- **$status**: $($result.name) ($($result.engines) engines, $($result.duration)ms)`n"
    }
    
    $mdReport | Out-File -FilePath "test_results.md" -Encoding UTF8
    Write-Info "📄 Markdown report saved: test_results.md"
}

Write-Host ""

# Final verdict
if ($failed -eq 0) {
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  ✓✓✓ ALL TESTS PASSED - $totalEngines ENGINES VERIFIED ✓✓✓       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    exit 0
} else {
    Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  ⚠️  SOME TESTS FAILED - REVIEW ERRORS ABOVE  ⚠️               ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    exit 1
}
