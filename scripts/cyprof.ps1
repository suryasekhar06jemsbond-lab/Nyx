#!/usr/bin/env pwsh
# Nyx Profiler - Performance profiling tool

param(
    [Parameter(Position=0)]
    [string]$File,
    
    [Parameter(Position=1)]
    [string]$Output = "profile.json",
    
    [switch]$Cpu,
    [switch]$Memory,
    [switch]$Alloc,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

function Show-Help {
    Write-Host @"
Nyx Profiler - Performance profiling tool

Usage:
    .\scripts\cyprof.ps1 <file> [options]
    .\scripts\cyprof.ps1 program.ny --cpu --output profile.json

Options:
    --cpu         Enable CPU profiling
    --memory      Enable memory profiling
    --alloc       Track allocations
    --output      Output file (default: profile.json)
    --help        Show this help

Examples:
    .\scripts\cyprof.ps1 program.ny
    .\scripts\cyprof.ps1 program.ny --cpu --memory --output profile.json
    .\scripts\cyprof.ps1 program.ny --alloc

Output format:
    {
        "version": "1.0",
        "file": "program.ny",
        "profiler": "nyx-profiler",
        "samples": [...],
        "functions": [...],
        "total_time_ms": 100.5,
        "peak_memory_mb": 10.2
    }
"@
}

if ($Help -or -not $File) {
    Show-Help
    exit 0
}

if (-not (Test-Path $File)) {
    Write-Error "File not found: $File"
    exit 1
}

# Build profiler flags
$profileFlags = @()
if ($Cpu) { $profileFlags += "--profile-cpu" }
if ($Memory) { $profileFlags += "--profile-memory" }
if ($Alloc) { $profileFlags += "--profile-alloc" }

# Default to CPU profiling if nothing specified
if ($profileFlags.Count -eq 0) {
    $profileFlags += "--profile-cpu"
}

Write-Host "Profiling: $File" -ForegroundColor Cyan
Write-Host "Flags: $($profileFlags -join ' ')" -ForegroundColor Gray

# Create temporary output file
$tempOutput = [System.IO.Path]::GetTempFileName()

# Run with profiling enabled
$nyxExe = ".\nyx.bat"
if (-not (Test-Path $nyxExe)) {
    $nyxExe = ".\nyx"
}

$script:profilerError = $null

try {
    & $nyxExe $File $profileFlags --profile-output $tempOutput 2>&1 | Out-Null
    
    if (Test-Path $tempOutput) {
        # Move to desired output
        Move-Item $tempOutput $Output -Force
        Write-Host "Profile saved to: $Output" -ForegroundColor Green
        
        # Display summary
        $content = Get-Content $Output -Raw | ConvertFrom-Json
        Write-Host ""
        Write-Host "=== Profile Summary ===" -ForegroundColor Yellow
        Write-Host "Total time: $($content.total_time_ms)ms"
        Write-Host "Peak memory: $($content.peak_memory_mb)MB"
        
        if ($content.functions) {
            Write-Host ""
            Write-Host "Top functions by time:" -ForegroundColor Yellow
            $content.functions | Sort-Object -Property time_ms -Descending | Select-Object -First 10 | ForEach-Object {
                Write-Host "  $($_.name): $($_.time_ms)ms ($($_.calls) calls)"
            }
        }
    } else {
        Write-Error "Profiling failed - no output generated"
        exit 1
    }
} catch {
    $script:profilerError = $_
    Write-Error "Profiler error: $_"
    exit 1
}
finally {
    if (Test-Path $tempOutput) {
        Remove-Item $tempOutput -ErrorAction SilentlyContinue
    }
}
