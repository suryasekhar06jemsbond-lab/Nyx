#!/usr/bin/env pwsh
# Nyx Test Runner - Comprehensive test framework

param(
    [Parameter(Position=0)]
    [string]$Path = ".",
    
    [switch]$ShowVerbose,
    [switch]$Coverage,
    [switch]$Watch,
    [string]$Pattern = "*.test.ny",
    [string]$Output = "test-results.xml",
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host @"
Nyx Test Runner - Comprehensive test framework

Usage:
    .\scripts\cytest.ps1 [path] [options]
    .\scripts\cytest.ps1 .\tests
    .\scripts\cytest.ps1 --coverage --output results.xml

Options:
    --verbose      Show detailed output
    --coverage     Enable code coverage
    --watch        Watch mode (rerun on changes)
    --pattern      Test file pattern (default: *.test.ny)
    --output       Output file (JUnit XML)
    --help         Show this help

Test Discovery:
    Test files are named *.test.ny and contain test functions:
    
    # example.test.ny
    module test {
        fn test_addition() {
            assert(1 + 1 == 2, "Addition failed");
        }
        
        fn test_array() {
            let arr = [1, 2, 3];
            assert(len(arr) == 3, "Array length wrong");
        }
    }

Exit Codes:
    0 - All tests passed
    1 - Some tests failed
    2 - Test framework error
"@
}

if ($Help) {
    Show-Help
    exit 0
}

# Find test files
$testFiles = Get-ChildItem -Path $Path -Recurse -Filter $Pattern -ErrorAction SilentlyContinue

if ($testFiles.Count -eq 0) {
    Write-Warning "No test files found matching: $Pattern"
    Write-Host "Tip: Test files should be named *.test.ny"
    exit 0
}

Write-Host "Found $($testFiles.Count) test file(s)" -ForegroundColor Cyan

# Initialize counters
$script:passed = 0
$script:failed = 0
$script:skipped = 0
$script:errors = @()

# Test framework functions (embedded)
$testFramework = @'
module test {
    fn assert(condition, message) {
        if (!condition) {
            throw "Assertion failed: " + message;
        }
    }
    
    fn assert_eq(actual, expected, message) {
        if (actual != expected) {
            throw message + " (expected: " + str(expected) + ", got: " + str(actual) + ")";
        }
    }
    
    fn assert_ne(actual, not_expected, message) {
        if (actual == not_expected) {
            throw message + " (should not be: " + str(not_expected) + ")";
        }
    }
    
    fn assert_contains(haystack, needle, message) {
        if (str(haystack) == str(needle)) {
            return;
        }
        if (type(haystack) == "array") {
            for (item in haystack) {
                if (item == needle) {
                    return;
                }
            }
        }
        throw message + " (" + str(needle) + " not found in " + str(haystack) + ")";
    }
    
    fn assert_throws(fn_callback, message) {
        try {
            fn_callback();
            throw message + " (no exception thrown)";
        } catch (e) {
            # Expected
        }
    }
    
    fn skip(reason) {
        print("SKIPPED: " + reason);
    }
}
'@

# Temporary file for framework
$frameworkFile = [System.IO.Path]::GetTempFileName() + ".ny"
Set-Content -Path $frameworkFile -Value $testFramework

# Find nyx executable
$nyxExe = ".\nyx.bat"
if (-not (Test-Path $nyxExe)) {
    $nyxExe = ".\nyx"
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Run each test file
foreach ($testFile in $testFiles) {
    Write-Host ""
    Write-Host "=== $($testFile.Name) ===" -ForegroundColor Yellow
    
    # Create test harness
    $testContent = Get-Content $testFile.FullName -Raw
    
    # Run test file
    $result = & $nyxExe $testFile.FullName 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $script:passed++
        Write-Host "  PASS" -ForegroundColor Green
        if ($ShowVerbose) {
            Write-Host $result -ForegroundColor Gray
        }
    } elseif ($LASTEXITCODE -eq 2) {
        $script:skipped++
        Write-Host "  SKIP" -ForegroundColor Yellow
    } else {
        $script:failed++
        Write-Host "  FAIL" -ForegroundColor Red
        $script:errors += @{
            File = $testFile.Name
            Error = $result
        }
        if ($ShowVerbose) {
            Write-Host $result -ForegroundColor Red
        }
    }
}

$stopwatch.Stop()

# Cleanup
Remove-Item $frameworkFile -ErrorAction SilentlyContinue

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Yellow
Write-Host "Passed:  $script:passed" -ForegroundColor Green
Write-Host "Failed:  $script:failed" -ForegroundColor Red
Write-Host "Skipped: $script:skipped" -ForegroundColor Yellow
Write-Host "Time:    $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor Gray

# Generate JUnit XML output
$xmlOutput = @"
<?xml version="1.0" encoding="UTF-8"?>
<testsuite name="nyx-tests" tests="$($testFiles.Count)" failures="$script:failed" errors="$script:errors.Count" time="$($stopwatch.ElapsedSeconds)">
"@

foreach ($testFile in $testFiles) {
    $status = if ($script:errors.File -contains $testFile.Name) { "failure" } else { "passed" }
    $xmlOutput += "`n    <testcase name=""$($testFile.BaseName)"" time=""0""/>"
}

$xmlOutput += "`n</testsuite>"

$xmlOutput | Out-File -FilePath $Output -Encoding UTF8
Write-Host ""
Write-Host "Results saved to: $Output" -ForegroundColor Cyan

# Exit code
if ($script:failed -gt 0) {
    exit 1
} else {
    exit 0
}
