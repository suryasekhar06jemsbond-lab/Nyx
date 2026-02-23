# ================================================================
# Nyx Kernel Boot Test Script (PowerShell)
# ================================================================
# Tests that the Nyx OS kernel boots successfully in QEMU
# Exit code 0 = success, 1 = failure

$ErrorActionPreference = "Stop"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$KERNEL_DIR = Join-Path $PROJECT_ROOT "examples\os_kernel"
$BUILD_DIR = Join-Path $KERNEL_DIR "build"
$ISO_DIR = Join-Path $KERNEL_DIR "iso"
$BOOT_LOG = Join-Path $BUILD_DIR "boot_log.txt"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Nyx Kernel Boot Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ================================================================
# Step 1: Check Prerequisites
# ================================================================

Write-Host "[1/6] Checking prerequisites..." -ForegroundColor Yellow

$hasQemu = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
if (-not $hasQemu) {
    Write-Host "❌ QEMU not found. Install from: https://www.qemu.org/download/" -ForegroundColor Red
    exit 1
}

Write-Host "   ✅ QEMU: $($hasQemu.Version)" -ForegroundColor Green

# Check for WSL (can use Linux GRUB)
$hasWSL = Get-Command wsl -ErrorAction SilentlyContinue
if ($hasWSL) {
    Write-Host "   ✅ WSL detected: Will use Linux grub-mkrescue" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  WSL not found. ISO creation may not work on Windows." -ForegroundColor Yellow
    Write-Host "      Recommend installing WSL: wsl --install" -ForegroundColor Yellow
}

Write-Host ""

# ================================================================
# Step 2: Build Kernel (Mock)
# ================================================================

Write-Host "[2/6] Building Nyx kernel..." -ForegroundColor Yellow

New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null
Set-Location $KERNEL_DIR

if (Test-Path "kernel_main.ny") {
    Write-Host "   ✅ Kernel source found: kernel_main.ny" -ForegroundColor Green
    
    # For now, we'll create a marker file
    # TODO: Replace with actual Nyx compilation
    Write-Host "   ⚠️  Mock kernel compilation (actual compilation not yet implemented)" -ForegroundColor Yellow
    
    # Create a placeholder kernel.elf
    Set-Content -Path "$BUILD_DIR\nyx_kernel.elf" -Value "Mock kernel ELF"
    
    Write-Host "   ✅ Kernel placeholder created: build\nyx_kernel.elf" -ForegroundColor Green
} else {
    Write-Host "   ❌ Kernel source not found: kernel_main.ny" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ================================================================
# Step 3: Create Bootable ISO (WSL)
# ================================================================

Write-Host "[3/6] Creating bootable ISO..." -ForegroundColor Yellow

if ($hasWSL) {
    # Use WSL to create ISO with GRUB
    $wslKernelDir = wsl wslpath -a $KERNEL_DIR
    $wslBuildDir = "$wslKernelDir/build"
    $wslIsoDir = "$wslKernelDir/iso"
    
    # Create ISO structure in WSL
    wsl bash -c "mkdir -p $wslIsoDir/boot/grub && cp $wslBuildDir/nyx_kernel.elf $wslIsoDir/boot/ 2>/dev/null || echo 'Mock kernel'"
    
    # Create GRUB config
    $grubCfg = @"
set timeout=0
set default=0

menuentry "Nyx OS Kernel Boot Test" {
    multiboot2 /boot/nyx_kernel.elf
    boot
}
"@
    $grubCfg | Out-File -FilePath "$ISO_DIR\boot\grub\grub.cfg" -Encoding ASCII
    
    # Run grub-mkrescue in WSL
    Write-Host "   ⚠️  Note: ISO creation requires Linux GRUB (using WSL)" -ForegroundColor Yellow
    wsl bash -c "cd $wslKernelDir && grub-mkrescue -o build/nyx_os.iso iso/ 2>&1 | grep -v warning || true"
    
    if (Test-Path "$BUILD_DIR\nyx_os.iso") {
        $isoSize = (Get-Item "$BUILD_DIR\nyx_os.iso").Length / 1MB
        Write-Host "   ✅ ISO created: build\nyx_os.iso ($([math]::Round($isoSize, 2)) MB)" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Failed to create ISO" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "   ⚠️  Skipping ISO creation (WSL not available)" -ForegroundColor Yellow
    Write-Host "      This is a Windows limitation. Install WSL to enable full testing." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# ================================================================
# Step 4: Boot Kernel in QEMU
# ================================================================

Write-Host "[4/6] Booting kernel in QEMU (5 second timeout)..." -ForegroundColor Yellow

$qemuArgs = @(
    "-cdrom", "$BUILD_DIR\nyx_os.iso",
    "-m", "512M",
    "-serial", "stdio",
    "-display", "none",
    "-no-reboot"
)

# Start QEMU and capture output
$qemuJob = Start-Job -ScriptBlock {
    param($qemuPath, $args, $logPath)
    & $qemuPath $args *> $logPath
} -ArgumentList $hasQemu.Source, $qemuArgs, $BOOT_LOG

# Wait 5 seconds then stop
Wait-Job $qemuJob -Timeout 5 | Out-Null
Stop-Job $qemuJob | Out-Null
Remove-Job $qemuJob | Out-Null

if (Test-Path $BOOT_LOG) {
    $logLines = (Get-Content $BOOT_LOG).Count
    Write-Host "   ✅ Boot log captured: $logLines lines" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  No boot log captured" -ForegroundColor Yellow
    New-Item -ItemType File -Path $BOOT_LOG | Out-Null
}

Write-Host ""

# ================================================================
# Step 5: Verify Boot Output
# ================================================================

Write-Host "[5/6] Verifying boot messages..." -ForegroundColor Yellow

$expectedMessages = @(
    "Nyx OS Kernel Booting"
)

$failed = $false
$logContent = Get-Content $BOOT_LOG -ErrorAction SilentlyContinue

foreach ($msg in $expectedMessages) {
    if ($logContent -match [regex]::Escape($msg)) {
        Write-Host "   ✅ Found: '$msg'" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Missing: '$msg'" -ForegroundColor Red
        $failed = $true
    }
}

Write-Host ""

# ================================================================
# Step 6: Final Result
# ================================================================

Write-Host "[6/6] Test Results:" -ForegroundColor Yellow
Write-Host ""

if (-not $failed) {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "  ✅ KERNEL BOOT TEST: PASSED" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "The Nyx OS kernel successfully booted!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Boot log: $BOOT_LOG" -ForegroundColor Cyan
    Write-Host ""
    exit 0
} else {
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host "  ❌ KERNEL BOOT TEST: FAILED" -ForegroundColor Red
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected boot messages not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Boot log contents:" -ForegroundColor Yellow
    Write-Host "-----------------------------------" -ForegroundColor Yellow
    Get-Content $BOOT_LOG
    Write-Host "-----------------------------------" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
