# Nyx Dual Import Syntax — Before & After Examples

## Quick Comparison

### Before (import only, quoted required)
```nyx
import "vm_production";
import "vm_iommu";
import "systems";
import "logging";
import "metrics";

let vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("guest.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .build();
```

### After (unquoted preferred, both keywords work)
```nyx
# Unquoted (preferred)
import vm_production;
import vm_iommu;

# Also available: use keyword
use systems;
use logging;
use metrics;

# Quoted syntax still works
import "optional_module";

let vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("guest.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .build();
```

## Real-World Examples

### Example 1: Single NIC Pass-Through

**Before (quoted required):**
```nyx
import "vm_production";

let vm = ProductionVMBuilder()
    .memory(4 * 1024**3)
    .cpus(2)
    .uefi("OVMF.fd")
    .disk("guest.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .build();

vm.run();
```

**After (unquoted preferred, quoted optional):**
```nyx
import vm_production;  # Unquoted (modern)

# OR use legacy quoted syntax
import "vm_production";

let vm = ProductionVMBuilder()
    .memory(4 * 1024**3)
    .cpus(2)
    .uefi("OVMF.fd")
    .disk("guest.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .build();

vm.run();
```

### Example 2: GPU Workstation

**Before (quoted required):**
```nyx
import "vm_production";
import "vm_iommu";
import "logging";
import "metrics";

let gpu_vm = ProductionVMBuilder()
    .memory(32 * 1024**3)
    .cpus(16)
    .uefi("OVMF_WORKSTATION.fd")
    .disk("gaming_vm.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")
    .passthrough_device(0x0101, "STRICT")
    .passthrough_device(0x0200, "STRICT")
    .with_error_handling()
    .with_metrics()
    .build();

gpu_vm.run();
```

**After (unquoted preferred):**
```nyx
# Modern unquoted syntax
import vm_production;
use vm_iommu;
import logging;
use metrics;

let gpu_vm = ProductionVMBuilder()
    .memory(32 * 1024**3)
    .cpus(16)
    .uefi("OVMF_WORKSTATION.fd")
    .disk("gaming_vm.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")
    .passthrough_device(0x0101, "STRICT")
    .passthrough_device(0x0200, "STRICT")
    .with_error_handling()
    .with_metrics()
    .build();

gpu_vm.run();
```

### Example 3: Enterprise Multi-Device

**Before (quoted required):**
```nyx
import "systems";
import "hardware";
import "memory";
import "vm_core";
import "vm_iommu";
import "vm_production";
import "logging";
import "metrics";

let enterprise_vm = ProductionVMBuilder()
    .memory(64 * 1024**3)
    .cpus(24)
    .uefi("OVMF.fd")
    .disk("enterprise.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")  # GPU
    .passthrough_device(0x0200, "STRICT")  # Storage
    .passthrough_device(0x0300, "STRICT")  # Network
    .with_live_migration()
    .with_error_handling()
    .with_logging()
    .with_metrics()
    .with_snapshot()
    .build();

enterprise_vm.run();
```

**After (unquoted preferred):**
```nyx
# Core system modules
import systems;
import hardware;
import memory;

# Feature modules (use for brevity)
use vm_core;
use vm_iommu;
use vm_production;

# Observability modules
import logging;
use metrics;

let enterprise_vm = ProductionVMBuilder()
    .memory(64 * 1024**3)
    .cpus(24)
    .uefi("OVMF.fd")
    .disk("enterprise.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")  # GPU
    .passthrough_device(0x0200, "STRICT")  # Storage
    .passthrough_device(0x0300, "STRICT")  # Network
    .with_live_migration()
    .with_error_handling()
    .with_logging()
    .with_metrics()
    .with_snapshot()
    .build();

enterprise_vm.run();
```

## Migration Path

### Step 1: Code Still Works
No changes needed. Existing `import` statements continue to work:
```nyx
import "vm_production";  # Works exactly as before
```

### Step 2: Gradual Adoption
Add `use` keyword where it improves readability:
```nyx
import "vm_production";
use "vm_iommu";         # New syntax, same functionality
```

### Step 3: Optional Standardization
If team agrees on style, update to preferred syntax:
```nyx
// Standardized on 'use' for all modules
use "vm_production";
use "vm_iommu";
use "logging";
use "metrics";
```

## Performance Comparison

| Aspect | import | use |
|--------|--------|-----|
| **Parsing** | 100% | 100% (identical) |
| **Loading** | 100% | 100% (identical) |
| **Runtime** | 100% | 100% (identical) |
| **Speed** | Same | Same |

**Result:** No performance difference, choose for readability.

## Style Guide Recommendations

### Option A: Import Only (Traditional)
```nyx
# Consistent with Python, Rust, Go
import "vm_production";
import "vm_iommu";
import "logging";
```

### Option B: Use Only (Concise)
```nyx
# Consistent with Perl, Raku, Zig
use "vm_production";
use "vm_iommu";
use "logging";
```

### Option C: Mixed by Category
```nyx
# System modules
import "systems";
import "hardware";

# Feature modules
use "vm_production";
use "vm_iommu";

# Utilities
import "logging";
import "metrics";
```

### Option D: Mixed by Preference
```nyx
# No rules, choose what reads best per case
import "vm_production";  // Feels like "load module"
use "vm_iommu";         // Feels like "make available"
import "logging";        // Explicit about loading
use "metrics";          // Concise, modern feel
```

## Backward Compatibility Matrix

| Code | Before | After | Status |
|------|--------|-------|--------|
| `import "mod"` | ✅ Works | ✅ Works | ✓ |
| `use "mod"` | ❌ Error | ✅ Works | ✓ New |
| Mixed | ❌ Not possible | ✅ Works | ✓ New |

## FAQ

**Q: Do I need to change my code?**  
A: No, existing `import` statements work unchanged.

**Q: Which should I use?**  
A: Both work identically. Choose based on readability.

**Q: Can I mix them?**  
A: Yes, both work together in the same file.

**Q: Is one faster?**  
A: No, zero performance difference.

**Q: Will this break anything?**  
A: No, fully backward compatible.

**Q: Should I update all my code?**  
A: Not necessary. Both styles work fine indefinitely.

## Syntax Validation

Both forms are **syntactically valid:**

```nyx
import "module_name";   ✅ Valid
use "module_name";      ✅ Valid
import "path/module";   ✅ Valid
use "path/module";      ✅ Valid
IMPORT "module";        ❌ Invalid (case-sensitive)
USE "module";           ❌ Invalid (case-sensitive)
```

## Complete Feature Example

```nyx
#!/usr/bin/nyx
# Dual import syntax example

# Load core modules (demonstrating both keywords)
import "systems";
use "hardware";
import "memory";
use "vm_core";

# Load feature modules
import "vm_production";
use "vm_iommu";

# Load observability
import "logging";
use "metrics";

// Both keywords work identically - use what reads best
fn main() {
    # Create a production VM with direct hardware access
    let vm = ProductionVMBuilder()
        .memory(8 * 1024**3)
        .cpus(4)
        .uefi("OVMF.fd")
        .disk("guest.qcow2")
        .with_iommu()
        .passthrough_device(0x0300, "STRICT")
        .with_logging()
        .with_metrics()
        .build();

    # Run the VM
    let exit_code = vm.run();
    
    # Check exit code
    if (exit_code == 0) {
        printf("VM ran successfully\n");
    } else {
        printf("VM exited with code: %d\n", exit_code);
    }
    
    return exit_code;
}

main();
```

## Summary

✅ **Both `import` and `use` now fully supported**
✅ **100% backward compatible**
✅ **No performance difference**
✅ **Choose based on preference**
✅ **Mix freely in same file**

---

**Nyx now supports flexible module loading with both syntaxes**
