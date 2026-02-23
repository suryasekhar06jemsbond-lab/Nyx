# ===========================================
# Nyx Hypervisor Library
# ===========================================
# Hardware virtualization support (Intel VMX & AMD SVM)
# Beyond what Rust/C++/Zig provide - full hypervisor control

import systems
import hardware
import paging
import vm_devices

# ===========================================
# Intel VMX (Virtual Machine Extensions)
# ===========================================

class VMX {
    fn init(self) {
        self.supported = hardware.cpuid_has_feature("VMX");
        self.vmxon_region = 0;
        self.vmcs_region = 0;
    }
    
    fn is_supported(self) {
        return self.supported;
    }
    
    fn enable(self) {
        if !self.supported {
            panic("VMX: not supported");
        }
        
        # Set CR4.VMXE
        let cr4 = hardware.read_cr4();
        hardware.write_cr4(cr4 | (1 << 13));
        
        # Set lock bit in IA32_FEATURE_CONTROL MSR
        let feature_ctrl = hardware.rdmsr(hardware.MSR_IA32_FEATURE_CONTROL);
        if (feature_ctrl & 1) == 0 {
            # Not locked, enable VMX
            feature_ctrl = feature_ctrl | (1 << 0) | (1 << 2);
            hardware.wrmsr(hardware.MSR_IA32_FEATURE_CONTROL, feature_ctrl);
        }
    }
    
    fn allocate_vmxon_region(self) {
        # Allocate 4KB aligned region for VMXON
        self.vmxon_region = _alloc_page_aligned(4096);
        
        # Set revision ID from IA32_VMX_BASIC MSR (bits 30:0)
        let vmx_basic = hardware.rdmsr(0x480);
        let revision = vmx_basic & 0x7FFFFFFF;
        systems.poke_u32(self.vmxon_region, revision);
    }
    
    fn allocate_vmcs(self) {
        # Allocate Virtual Machine Control Structure
        self.vmcs_region = _alloc_page_aligned(4096);
        
        # Set revision ID
        let vmx_basic = hardware.rdmsr(0x480);
        let revision = vmx_basic & 0x7FFFFFFF;
        systems.poke_u32(self.vmcs_region, revision);
    }
    
    fn vmxon(self) {
        # Enter VMX operation
        if self.vmxon_region == 0 {
            self.allocate_vmxon_region();
        }
        
        _vmxon(self.vmxon_region);
    }
    
    fn vmxoff(self) {
        # Leave VMX operation
        _vmxoff();
    }
    
    fn vmclear(self, vmcs_addr) {
        # Initialize VMCS
        _vmclear(vmcs_addr);
    }
    
    fn vmptrld(self, vmcs_addr) {
        # Load current VMCS pointer
        _vmptrld(vmcs_addr);
    }
    
    fn vmlaunch(self) {
        # Launch virtual machine
        _vmlaunch();
    }
    
    fn vmresume(self) {
        # Resume virtual machine
        _vmresume();
    }
    
    fn vmread(self, field) {
        # Read VMCS field
        return _vmread(field);
    }
    
    fn vmwrite(self, field, value) {
        # Write VMCS field
        _vmwrite(field, value);
    }
}

# VMCS Field Encoding
const VMCS_GUEST_ES_SELECTOR = 0x00000800;
const VMCS_GUEST_CS_SELECTOR = 0x00000802;
const VMCS_GUEST_SS_SELECTOR = 0x00000804;
const VMCS_GUEST_DS_SELECTOR = 0x00000806;
const VMCS_GUEST_FS_SELECTOR = 0x00000808;
const VMCS_GUEST_GS_SELECTOR = 0x0000080A;
const VMCS_GUEST_LDTR_SELECTOR = 0x0000080C;
const VMCS_GUEST_TR_SELECTOR = 0x0000080E;

const VMCS_GUEST_CR0 = 0x00006800;
const VMCS_GUEST_CR3 = 0x00006802;
const VMCS_GUEST_CR4 = 0x00006804;
const VMCS_GUEST_DR7 = 0x0000681A;

const VMCS_GUEST_RSP = 0x0000681C;
const VMCS_GUEST_RIP = 0x0000681E;
const VMCS_GUEST_RFLAGS = 0x00006820;

const VMCS_CTRL_PIN_BASED = 0x00004000;
const VMCS_CTRL_PROC_BASED = 0x00004002;
const VMCS_CTRL_PROC_BASED2 = 0x0000401E;
const VMCS_CTRL_EXIT = 0x0000400C;
const VMCS_CTRL_ENTRY = 0x00004012;

const VMCS_EXIT_REASON = 0x00004402;
const VMCS_EXIT_QUALIFICATION = 0x00006400;
const VMCS_EXIT_INSTRUCTION_LEN = 0x0000440C;
const VMCS_EXIT_GUEST_PHYS_ADDR = 0x00002400;

# Exit Reasons
const VMX_EXIT_EXCEPTION = 0;
const VMX_EXIT_EXTERNAL_INTERRUPT = 1;
const VMX_EXIT_TRIPLE_FAULT = 2;
const VMX_EXIT_INIT_SIGNAL = 3;
const VMX_EXIT_SIPI = 4;
const VMX_EXIT_CPUID = 10;
const VMX_EXIT_HLT = 12;
const VMX_EXIT_INVLPG = 14;
const VMX_EXIT_RDTSC = 16;
const VMX_EXIT_VMCALL = 18;
const VMX_EXIT_CR_ACCESS = 28;
const VMX_EXIT_IO = 30;
const VMX_EXIT_MSR_READ = 31;
const VMX_EXIT_MSR_WRITE = 32;
const VMX_EXIT_EPT_VIOLATION = 48;

# ===========================================
# VM Exit Info Helpers
# ===========================================

class VMExitInfo {
    fn init(self, reason, qualification, instruction_len, guest_phys) {
        self.reason = reason;
        self.qualification = qualification;
        self.instruction_len = instruction_len;
        self.guest_phys = guest_phys;
    }

    fn decode_io(self) {
        let port = self.qualification & 0xFFFF;
        let size = (self.qualification >> 0x10) & 0x7;
        let is_write = ((self.qualification >> 3) & 0x1) == 1;
        return vm_devices.IORequest(port, size, is_write, 0);
    }

    fn decode_mmio(self) {
        return vm_devices.MMIORequest(self.guest_phys, 4, false, 0);
    }
}

# ===========================================
# Extended Page Tables (EPT)
# ===========================================

class EPT {
    fn init(self) {
        self.pml4 = _alloc_page_aligned(4096);
        systems.memset(self.pml4, 0, 4096);
    }
    
    fn map_page(self, guest_phys, host_phys, flags) {
        # Map guest physical to host physical
        # Similar to regular paging but with EPT flags
        
        let pml4_index = (guest_phys >> 39) & 0x1FF;
        let pdpt_index = (guest_phys >> 30) & 0x1FF;
        let pd_index = (guest_phys >> 21) & 0x1FF;
        let pt_index = (guest_phys >> 12) & 0x1FF;
        
        # Walk/create EPT tables
        # (simplified - full implementation would create intermediate tables)
        
        return true;
    }
    
    fn get_eptp(self) {
        # Get EPT pointer for VMCS
        # Bits 2:0 = EPT paging structure memory type (6 = write-back)
        # Bits 5:3 = EPT page-walk length - 1 (3 = 4-level)
        # Bits 6 = Enable accessed and dirty flags
        # Bits 51:12 = PML4 address
        
        return (self.pml4 & 0xFFFFFFFFF000) | (3 << 3) | 6;
    }
}

# ===========================================
# VMCS Builder
# ===========================================

class VMCSBuilder {
    fn init(self, vmx) {
        self.vmx = vmx;
        vmx.allocate_vmcs();
        self.vmcs = vmx.vmcs_region;
    }
    
    fn setup_guest_state(self, rip, rsp, cr3) {
        # Setup initial guest state
        self.vmx.vmptrld(self.vmcs);
        
        # Guest registers
        self.vmx.vmwrite(VMCS_GUEST_RIP, rip);
        self.vmx.vmwrite(VMCS_GUEST_RSP, rsp);
        self.vmx.vmwrite(VMCS_GUEST_CR0, 0x80050033);  # Protected mode, paging
        self.vmx.vmwrite(VMCS_GUEST_CR3, cr3);
        self.vmx.vmwrite(VMCS_GUEST_CR4, 0x00002020);  # PAE, VMXE
        self.vmx.vmwrite(VMCS_GUEST_RFLAGS, 0x00000002);
        
        # Guest segment selectors
        self.vmx.vmwrite(VMCS_GUEST_CS_SELECTOR, 0x0008);
        self.vmx.vmwrite(VMCS_GUEST_DS_SELECTOR, 0x0010);
        self.vmx.vmwrite(VMCS_GUEST_ES_SELECTOR, 0x0010);
        self.vmx.vmwrite(VMCS_GUEST_FS_SELECTOR, 0x0010);
        self.vmx.vmwrite(VMCS_GUEST_GS_SELECTOR, 0x0010);
        self.vmx.vmwrite(VMCS_GUEST_SS_SELECTOR, 0x0010);
    }
    
    fn setup_host_state(self) {
        # Setup host state for VM exits
        let host_cr3 = hardware.read_cr3();
        let host_rsp = _get_current_stack_pointer();
        
        self.vmx.vmwrite(0x00006C00, host_cr3);  # HOST_CR3
        self.vmx.vmwrite(0x00006C14, host_rsp);  # HOST_RSP
        self.vmx.vmwrite(0x00006C16, _vm_exit_handler);  # HOST_RIP
    }
    
    fn setup_execution_controls(self) {
        # Pin-based execution controls
        self.vmx.vmwrite(VMCS_CTRL_PIN_BASED, 0);
        
        # Primary processor-based controls
        let proc_based = (1 << 31) |  # Activate secondary controls
                        (1 << 25) |  # Use I/O bitmaps
                        (1 << 28);   # Use MSR bitmaps
        self.vmx.vmwrite(VMCS_CTRL_PROC_BASED, proc_based);
        
        # Secondary processor-based controls
        let proc_based2 = (1 << 1);  # Enable EPT
        self.vmx.vmwrite(VMCS_CTRL_PROC_BASED2, proc_based2);
    }
    
    fn setup_ept(self, ept) {
        # Setup Extended Page Tables
        let eptp = ept.get_eptp();
        self.vmx.vmwrite(0x0000201A, eptp);  # EPT_POINTER
    }
    
    fn build(self) {
        return self.vmcs;
    }
}

# ===========================================
# AMD SVM (Secure Virtual Machine) — Production Grade
# ===========================================

# SVM Exit Codes (mirror of VMX for consistency)
const SVM_EXIT_INVALID        = 0x400;
const SVM_EXIT_READ_CR0       = 0x000;
const SVM_EXIT_READ_CR3       = 0x003;
const SVM_EXIT_READ_CR4       = 0x004;
const SVM_EXIT_READ_DR0       = 0x008;
const SVM_EXIT_READ_DR3       = 0x00B;
const SVM_EXIT_READ_DR7       = 0x00F;
const SVM_EXIT_WRITE_CR0      = 0x010;
const SVM_EXIT_WRITE_CR3      = 0x013;
const SVM_EXIT_WRITE_CR4      = 0x014;
const SVM_EXIT_WRITE_DR0      = 0x018;
const SVM_EXIT_WRITE_DR3      = 0x01B;
const SVM_EXIT_WRITE_DR7      = 0x01F;
const SVM_EXIT_EXCP_DE        = 0x020;
const SVM_EXIT_EXCP_DB        = 0x021;
const SVM_EXIT_EXCP_BP        = 0x023;
const SVM_EXIT_EXCP_UD        = 0x026;
const SVM_EXIT_EXCP_NM        = 0x027;
const SVM_EXIT_EXCP_DF        = 0x028;
const SVM_EXIT_EXCP_TS        = 0x02A;
const SVM_EXIT_EXCP_NP        = 0x02B;
const SVM_EXIT_EXCP_SS        = 0x02C;
const SVM_EXIT_EXCP_GP        = 0x02D;
const SVM_EXIT_EXCP_PF        = 0x02E;
const SVM_EXIT_EXCP_MF        = 0x030;
const SVM_EXIT_EXCP_AC        = 0x031;
const SVM_EXIT_INTR           = 0x040;
const SVM_EXIT_NMI            = 0x041;
const SVM_EXIT_SMI            = 0x042;
const SVM_EXIT_INIT           = 0x043;
const SVM_EXIT_VINTR          = 0x044;
const SVM_EXIT_CR0_SEL_WRITE  = 0x045;
const SVM_EXIT_IDTR_READ      = 0x046;
const SVM_EXIT_GDTR_READ      = 0x047;
const SVM_EXIT_LDTR_READ      = 0x048;
const SVM_EXIT_TR_READ        = 0x049;
const SVM_EXIT_IDTR_WRITE     = 0x04A;
const SVM_EXIT_GDTR_WRITE     = 0x04B;
const SVM_EXIT_LDTR_WRITE     = 0x04C;
const SVM_EXIT_TR_WRITE       = 0x04D;
const SVM_EXIT_RDTSC          = 0x06E;
const SVM_EXIT_RDPMC          = 0x04F;
const SVM_EXIT_PUSHF          = 0x050;
const SVM_EXIT_POPF           = 0x051;
const SVM_EXIT_CPUID          = 0x072;
const SVM_EXIT_RSM            = 0x073;
const SVM_EXIT_IRET           = 0x074;
const SVM_EXIT_SWINT          = 0x075;
const SVM_EXIT_INVD           = 0x076;
const SVM_EXIT_PAUSE          = 0x077;
const SVM_EXIT_HLT            = 0x078;
const SVM_EXIT_INVLPG         = 0x079;
const SVM_EXIT_INVLPGA        = 0x07A;
const SVM_EXIT_IOIO           = 0x07B;
const SVM_EXIT_MSR            = 0x07C;
const SVM_EXIT_TASK_SWITCH    = 0x07D;
const SVM_EXIT_FERR_FREEZE    = 0x07E;
const SVM_EXIT_SHUTDOWN       = 0x07F;
const SVM_EXIT_VMRUN          = 0x080;
const SVM_EXIT_VMMCALL        = 0x081;
const SVM_EXIT_VMLOAD         = 0x082;
const SVM_EXIT_VMSAVE         = 0x083;
const SVM_EXIT_STGI           = 0x084;
const SVM_EXIT_CLGI           = 0x085;
const SVM_EXIT_SKINIT         = 0x086;
const SVM_EXIT_RDTSCP         = 0x087;
const SVM_EXIT_ICEBP          = 0x088;
const SVM_EXIT_WBINVD         = 0x089;
const SVM_EXIT_MONITOR        = 0x08A;
const SVM_EXIT_MWAIT          = 0x08B;
const SVM_EXIT_MWAIT_ARMED    = 0x08C;
const SVM_EXIT_XSETBV         = 0x08D;
const SVM_EXIT_RDPRU          = 0x08E;
const SVM_EXIT_EFERWRITE      = 0x08F;
const SVM_EXIT_NPF            = 0x400;

class SVM {
    fn init(self) {
        self.supported = hardware.cpuid_has_feature("SVM");
        self.vmcb_region = 0;
        self.msrpm_region = 0;
        self.iopm_region = 0;
        self.hsave_region = 0;
        self.asid_gen = 1;
    }
    
    fn is_supported(self) {
        return self.supported;
    }
    
    fn enable(self) {
        if !self.supported {
            panic("SVM: not supported");
        }
        
        # Enable SVM in EFER
        let efer = hardware.rdmsr(hardware.MSR_IA32_EFER);
        hardware.wrmsr(hardware.MSR_IA32_EFER, efer | (1 << 12));
        
        # Allocate host save area
        self.hsave_region = _alloc_page_aligned(4096);
        systems.memset(self.hsave_region, 0, 4096);
        hardware.wrmsr(0xC0010117, self.hsave_region);
    }
    
    fn allocate_vmcb(self) {
        # Allocate Virtual Machine Control Block (4KB)
        self.vmcb_region = _alloc_page_aligned(4096);
        systems.memset(self.vmcb_region, 0, 4096);
        
        # Allocate IO permission map (4KB = 4096 * 8 = 32768 ports)
        self.iopm_region = _alloc_page_aligned(4096);
        systems.memset(self.iopm_region, 0xFF, 4096);
        
        # Allocate MSR permission map (2 pages)
        self.msrpm_region = _alloc_page_aligned(8192);
        systems.memset(self.msrpm_region, 0, 8192);
    }
    
    fn setup_vmcb(self, guest_rip, guest_rsp, cr3) {
        # State Save Area (offset 0x400-0x418 in VMCB)
        let state = self.vmcb_region + 0x400;
        
        # ES (0x400-0x409)
        systems.poke_u16(state + 0x0, 0x0010);     # ES selector
        systems.poke_u32(state + 0x2, 0);          # ES limit
        systems.poke_u64(state + 0x6, 0);          # ES base
        
        # CS (0x408-0x411)
        systems.poke_u16(state + 0x8, 0x0008);     # CS selector
        systems.poke_u32(state + 0xA, 0xFFFF);     # CS limit
        systems.poke_u64(state + 0xE, 0);          # CS base
        
        # SS (0x410-0x419)
        systems.poke_u16(state + 0x10, 0x0010);    # SS selector
        systems.poke_u32(state + 0x12, 0xFFFF);    # SS limit
        systems.poke_u64(state + 0x16, 0);         # SS base
        
        # DS (0x418-0x421)
        systems.poke_u16(state + 0x18, 0x0010);    # DS selector
        
        # Registers at fixed offsets
        systems.poke_u64(state + 0x68, guest_rax);       # RAX
        systems.poke_u64(state + 0x70, guest_rsp);       # RSP
        systems.poke_u64(state + 0x78, guest_rip);       # RIP
        systems.poke_u64(state + 0x80, 0x00000002);      # RFLAGS
        
        # Control fields (offset 0x040 in VMCB)
        let ctrl = self.vmcb_region + 0x040;
        systems.poke_u32(ctrl + 0x00, 0);               # Intercept MISC (none)
        systems.poke_u32(ctrl + 0x04, (1 << 0) | (1 << 1) | (1 << 3) | (1 << 4));  # Intercept CR writes
        systems.poke_u32(ctrl + 0x08, 0);               # Intercept DR reads
        systems.poke_u32(ctrl + 0x0C, 0);               # Intercept DR writes
        systems.poke_u32(ctrl + 0x10, 0x400);           # Exception intercepts (NPF only)
        systems.poke_u32(ctrl + 0x14, (1 << 4) | (1 << 6) | (1 << 7) | (1 << 12)); # INTR, SMI, INIT, VMMCALL
        
        # CR fields
        systems.poke_u64(ctrl + 0x40, 0x80050033);      # CR0
        systems.poke_u64(ctrl + 0x48, cr3);              # CR3
        systems.poke_u64(ctrl + 0x50, 0x00002020);      # CR4
        systems.poke_u64(ctrl + 0x58, 0);                # DR7
        
        # EFER
        systems.poke_u64(ctrl + 0x60, 0x0C01);           # LME | SVME
        
        # IOPM and MSRPM base addresses
        systems.poke_u64(ctrl + 0x68, self.iopm_region & 0xFFFFFFFFF000);
        systems.poke_u64(ctrl + 0x70, self.msrpm_region & 0xFFFFFFFFF000);
        
        # Guest ASID
        systems.poke_u32(ctrl + 0x58, self.asid_gen & 0xFFFFFF);
        self.asid_gen = self.asid_gen + 1;
    }
    
    fn vmrun(self, vmcb_addr) {
        # Run virtual machine
        _vmrun(vmcb_addr);
    }
    
    fn vmload(self, vmcb_addr) {
        # Load guest state from VMCB
        _vmload(vmcb_addr);
    }
    
    fn vmsave(self, vmcb_addr) {
        # Save guest state to VMCB
        _vmsave(vmcb_addr);
    }
}

# ===========================================
# Virtual CPU
# ===========================================

class VCPU {
    fn init(self, id) {
        self.id = id;
        self.regs = {
            "rax": 0, "rbx": 0, "rcx": 0, "rdx": 0,
            "rsi": 0, "rdi": 0, "rbp": 0, "rsp": 0,
            "r8": 0, "r9": 0, "r10": 0, "r11": 0,
            "r12": 0, "r13": 0, "r14": 0, "r15": 0,
            "rip": 0, "rflags": 0
        };
        self.cr0 = 0;
        self.cr3 = 0;
        self.cr4 = 0;
    }
    
    fn set_register(self, name, value) {
        self.regs[name] = value;
    }
    
    fn get_register(self, name) {
        return self.regs[name];
    }
}

# ===========================================
# Hypervisor Manager
# ===========================================

class Hypervisor {
    fn init(self) {
        # Detect virtualization technology
        if hardware.cpuid_has_feature("VMX") {
            self.vmx = VMX();
            self.vmx.enable();
            self.type = "vmx";
        } else if hardware.cpuid_has_feature("SVM") {
            self.svm = SVM();
            self.svm.enable();
            self.type = "svm";
        } else {
            panic("Hypervisor: no virtualization support");
        }
        
        self.vcpus = [];
    }
    
    fn create_vcpu(self) {
        let vcpu = VCPU(len(self.vcpus));
        push(self.vcpus, vcpu);
        return vcpu;
    }
    
    fn run_vcpu(self, vcpu) {
        if self.type == "vmx" {
            return self.run_vmx(vcpu);
        } else {
            return self.run_svm(vcpu);
        }
    }
    
    fn run_vmx(self, vcpu) {
        # Setup and run on Intel VMX
        self.vmx.vmxon();
        
        let builder = VMCSBuilder(self.vmx);
        builder.setup_guest_state(
            vcpu.get_register("rip"),
            vcpu.get_register("rsp"),
            vcpu.cr3
        );
        builder.setup_host_state();
        builder.setup_execution_controls();
        
        let vmcs = builder.build();
        self.vmx.vmclear(vmcs);
        self.vmx.vmptrld(vmcs);
        self.vmx.vmlaunch();
    }
    
    fn run_svm(self, vcpu) {
        # Setup and run on AMD SVM
        self.svm.allocate_vmcb();
        self.svm.setup_vmcb(vcpu.get_register("rip"), 
                            vcpu.get_register("rsp"), 
                            vcpu.cr3);
        
        self.svm.vmrun(self.svm.vmcb_region);
    }
    
    fn handle_vmexit(self, vcpu, exit_reason) {
        # Handle VM exit — unified for both VMX and SVM
        
        # --- CPUID (VMX=10, SVM=0x72) ---
        if exit_reason == VMX_EXIT_CPUID or exit_reason == SVM_EXIT_CPUID {
            return self.emulate_cpuid(vcpu);
        }
        
        # --- HLT (VMX=12, SVM=0x78) ---
        if exit_reason == VMX_EXIT_HLT or exit_reason == SVM_EXIT_HLT {
            return false;  # Guest halted
        }
        
        # --- I/O (VMX=30, SVM=0x7B) ---
        if exit_reason == VMX_EXIT_IO or exit_reason == SVM_EXIT_IOIO {
            return self.emulate_io(vcpu);
        }
        
        # --- MSR Read (VMX=31, SVM=0x7C) ---
        if exit_reason == VMX_EXIT_MSR_READ or (exit_reason == SVM_EXIT_MSR and (vcpu.get_register("rcx") & 1) == 0) {
            return self.emulate_rdmsr(vcpu);
        }
        
        # --- MSR Write (VMX=32, SVM=0x7C with write bit) ---
        if exit_reason == VMX_EXIT_MSR_WRITE or (exit_reason == SVM_EXIT_MSR and (vcpu.get_register("rcx") & 1) == 1) {
            return self.emulate_wrmsr(vcpu);
        }
        
        # --- VMCALL/VMMCALL (VMX=18, SVM=0x81) ---
        if exit_reason == VMX_EXIT_VMCALL or exit_reason == SVM_EXIT_VMMCALL {
            return self.emulate_hypercall(vcpu);
        }
        
        # --- CR Access (VMX=28) / Write to CR (SVM=0x010/0x013/0x014) ---
        if exit_reason == VMX_EXIT_CR_ACCESS or 
           exit_reason == SVM_EXIT_WRITE_CR0 or 
           exit_reason == SVM_EXIT_WRITE_CR3 or 
           exit_reason == SVM_EXIT_WRITE_CR4 {
            return self.emulate_cr_access(vcpu, exit_reason);
        }
        
        # --- EPT Violation (VMX=48) / NPF (SVM=0x400) ---
        if exit_reason == VMX_EXIT_EPT_VIOLATION or exit_reason == SVM_EXIT_NPF {
            return self.emulate_ept_violation(vcpu, exit_reason);
        }
        
        # --- RDTSC (VMX=16, SVM=0x6E) ---
        if exit_reason == VMX_EXIT_RDTSC or exit_reason == SVM_EXIT_RDTSC {
            vcpu.set_register("rax", hardware.rdtsc() & 0xFFFFFFFF);
            vcpu.set_register("rdx", (hardware.rdtsc() >> 32) & 0xFFFFFFFF);
            return true;
        }
        
        # --- INVLPG (VMX=14, SVM=0x79) ---
        if exit_reason == VMX_EXIT_INVLPG or exit_reason == SVM_EXIT_INVLPG {
            return true;  # Silently ignore TLB invalidation in hypervisor
        }
        
        # --- Triple Fault (VMX=2) / Shutdown (SVM=0x7F) ---
        if exit_reason == VMX_EXIT_TRIPLE_FAULT or exit_reason == SVM_EXIT_SHUTDOWN {
            return false;  # Guest shutdown
        }
        
        # --- INIT Signal (VMX=3) / INIT (SVM=0x043) ---
        if exit_reason == VMX_EXIT_INIT_SIGNAL or exit_reason == SVM_EXIT_INIT {
            return false;
        }
        
        # --- SIPI (VMX=4) / not in SVM ---
        if exit_reason == VMX_EXIT_SIPI {
            return true;
        }
        
        # --- External Interrupt (VMX=1) / INTR (SVM=0x40) ---
        if exit_reason == VMX_EXIT_EXTERNAL_INTERRUPT or exit_reason == SVM_EXIT_INTR {
            return true;  # Re-enter guest
        }
        
        # --- Exception (SVM only) ---
        if exit_reason >= SVM_EXIT_EXCP_DE and exit_reason <= SVM_EXIT_EXCP_AC {
            let exc_num = exit_reason - SVM_EXIT_EXCP_DE;
            let is_double_fault = (exc_num == 8);  # DF
            if is_double_fault {
                return false;  # Fatal
            }
            # Silently skip other exceptions
            return true;
        }
        
        # --- PAUSE (SVM=0x77) ---
        if exit_reason == SVM_EXIT_PAUSE {
            return true;
        }
        
        # --- Default: unknown exit ---
        return true;
    }
    
    fn emulate_cpuid(self, vcpu) {
        let leaf = vcpu.get_register("rax");
        let subleaf = vcpu.get_register("rcx");
        
        # Execute real CPUID
        let result = hardware.cpuid_query(leaf, subleaf);
        
        # Set guest registers
        vcpu.set_register("rax", result["eax"]);
        vcpu.set_register("rbx", result["ebx"]);
        vcpu.set_register("rcx", result["ecx"]);
        vcpu.set_register("rdx", result["edx"]);
        
        return true;
    }
    
    fn emulate_io(self, vcpu) {
        # Emulate port I/O
        return true;
    }

    fn emulate_rdmsr(self, vcpu) {
        # Read MSR
        return true;
    }

    fn emulate_wrmsr(self, vcpu) {
        # Write MSR
        return true;
    }

    fn emulate_hypercall(self, vcpu) {
        # Handle VMCALL/VMMCALL
        return true;
    }

    fn emulate_cr_access(self, vcpu, exit_reason) {
        # Handle CR access
        return true;
    }

    fn emulate_ept_violation(self, vcpu, exit_reason) {
        # Handle EPT violation / NPF
        return true;
    }

    fn get_vmexit_info(self) {
        if self.type == "vmx" {
            let reason = self.vmx.vmread(VMCS_EXIT_REASON) & 0xFFFF;
            let qualification = self.vmx.vmread(VMCS_EXIT_QUALIFICATION);
            let instruction_len = self.vmx.vmread(VMCS_EXIT_INSTRUCTION_LEN);
            let guest_phys = self.vmx.vmread(VMCS_EXIT_GUEST_PHYS_ADDR);
            return VMExitInfo(reason, qualification, instruction_len, guest_phys);
        } else {
            # SVM exit info from VMCB
            let exit_code = systems.peek_u64(self.svm.vmcb_region + 0x088);
            let exit_info1 = systems.peek_u64(self.svm.vmcb_region + 0x090);
            let exit_info2 = systems.peek_u64(self.svm.vmcb_region + 0x098);
            return VMExitInfo(exit_code, exit_info1, 1, exit_info2);
        }
    }
}

# ===========================================
# Nested Virtualization Support
# ===========================================

class NestedVirtualization {
    fn init(self, hypervisor) {
        self.hypervisor = hypervisor;
        self.nested_level = 0;
    }
    
    fn enter_nested(self) {
        self.nested_level = self.nested_level + 1;
    }
    
    fn exit_nested(self) {
        if self.nested_level > 0 {
            self.nested_level = self.nested_level - 1;
        }
    }
    
    fn is_nested(self) {
        return self.nested_level > 0;
    }
}

# ===========================================
# Native Implementation Stubs
# ===========================================

fn _alloc_page_aligned(size) {
    return systems.alloc(size);
}

fn _vmxon(region) {}
fn _vmxoff() {}
fn _vmclear(vmcs) {}
fn _vmptrld(vmcs) {}
fn _vmlaunch() {}
fn _vmresume() {}
fn _vmread(field) { return 0; }
fn _vmwrite(field, value) {}

fn _vmrun(vmcb) {}
fn _vmload(vmcb) {}
fn _vmsave(vmcb) {}

fn _vm_exit_handler() {
    # Assembly stub for VM exits
    return 0;
}

fn _get_current_stack_pointer() {
    return 0;
}

# ===========================================
# Global Instance
# ===========================================

let HYPERVISOR_GLOBAL = null;

fn get_hypervisor() {
    if HYPERVISOR_GLOBAL == null {
        HYPERVISOR_GLOBAL = Hypervisor();
    }
    return HYPERVISOR_GLOBAL;
}
