#!/usr/bin/env pwsh
# Build script for Nyx Native HTTP Server

param(
    [string]$Output = 'nyx_httpd_test.exe',
    [switch]$Release
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Building Nyx Native HTTP Server" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host ""

# Find C compiler
$clangCmd = Get-Command clang -ErrorAction SilentlyContinue
$gccCmd = Get-Command gcc -ErrorAction SilentlyContinue
$clCmd = Get-Command cl -ErrorAction SilentlyContinue

$compiler = $null
$compilerName = ""

if ($clangCmd) {
    $compiler = $clangCmd.Source
    $compilerName = "clang"
} elseif ($gccCmd) {
    $compiler = $gccCmd.Source
    $compilerName = "gcc"
} elseif ($clCmd) {
    $compiler = $clCmd.Source
    $compilerName = "cl"
} else {
    throw "No C compiler found. Install LLVM (clang), MinGW (gcc), or MSVC (cl)"
}

Write-Host "Compiler: $compilerName ($compiler)" -ForegroundColor Green

# Build command
$sourceFiles = @(
    "native\nyx_httpd.c",
    "native\test_httpd.c"
)

$outputPath = "build\$Output"

# Create build directory
New-Item -ItemType Directory -Force -Path "build" | Out-Null

Write-Host "Building HTTP server test..." -ForegroundColor Yellow

if ($compilerName -eq "clang" -or $compilerName -eq "gcc") {
    $flags = @(
        "-std=c99",
        "-Wall",
        "-Wextra",
        "-I.",
        "-o", $outputPath
    )
    
    if ($Release) {
        $flags += @("-O3", "-DNDEBUG")
    } else {
        $flags += @("-g", "-O0")
    }
    
    $cmdArgs = $flags + $sourceFiles
    
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        $cmdArgs += "-lws2_32"
    } else {
        $cmdArgs += "-lpthread"
    }
    
    & $compiler @cmdArgs
    
} elseif ($compilerName -eq "cl") {
    $flags = @(
        "/std:c11",
        "/W4",
        "/I.",
        "/Fe:$outputPath"
    )
    
    if ($Release) {
        $flags += @("/O2", "/DNDEBUG")
    } else {
        $flags += @("/Zi", "/Od")
    }
    
    $flags += "ws2_32.lib"
    
    & $compiler @flags @sourceFiles
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed" -ForegroundColor Red
    exit 1
}

if (Test-Path $outputPath) {
    Write-Host "✅ Build successful: $outputPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Run the server:" -ForegroundColor Yellow
    Write-Host "  .\$outputPath" -ForegroundColor White
} else {
    Write-Host "❌ Build failed: output file not created" -ForegroundColor Red
    exit 1
}
