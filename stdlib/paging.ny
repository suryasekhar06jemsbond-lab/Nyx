# ===========================================
# Nyx Advanced Paging Library
# ===========================================
# Direct page table manipulation and memory management
# Beyond what Rust/C++/Zig provide - OS-level memory control

import systems
import hardware

# ===========================================
# Page Table Entry Flags
# ===========================================

const PAGE_PRESENT = 1 << 0;
const PAGE_WRITABLE = 1 << 1;
const PAGE_USER = 1 << 2;
const PAGE_WRITE_THROUGH = 1 << 3;
const PAGE_CACHE_DISABLE = 1 << 4;
const PAGE_ACCESSED = 1 << 5;
const PAGE_DIRTY = 1 << 6;
const PAGE_HUGE = 1 << 7;  # 2MB or 1GB page
const PAGE_GLOBAL = 1 << 8;
const PAGE_NO_EXECUTE = 1 << 63;

# Page sizes
const PAGE_SIZE_4KB = 4096;
const PAGE_SIZE_2MB = 2 * 1024 * 1024;
const PAGE_SIZE_1GB = 1024 * 1024 * 1024;

# ===========================================
# Page Table Entry
# ===========================================

class PageTableEntry {
    fn init(self, value = 0) {
        self.value = value;
    }
    
    fn set_physical_addr(self, addr) {
        # Clear address bits and set new address
        self.value = (self.value & 0xFFF) | (addr & 0xFFFFFFFFFF000);
    }
    
    fn get_physical_addr(self) {
        return self.value & 0xFFFFFFFFFF000;
    }
    
    fn set_flag(self, flag) {
        self.value = self.value | flag;
    }
    
    fn clear_flag(self, flag) {
        self.value = self.value & ~flag;
    }
    
    fn has_flag(self, flag) {
        return (self.value & flag) != 0;
    }
    
    fn is_present(self) {
        return self.has_flag(PAGE_PRESENT);
    }
    
    fn set_present(self, present) {
        if present {
            self.set_flag(PAGE_PRESENT);
        } else {
            self.clear_flag(PAGE_PRESENT);
        }
    }
    
    fn is_writable(self) {
        return self.has_flag(PAGE_WRITABLE);
    }
    
    fn set_writable(self, writable) {
        if writable {
            self.set_flag(PAGE_WRITABLE);
        } else {
            self.clear_flag(PAGE_WRITABLE);
        }
    }
    
    fn is_user_accessible(self) {
        return self.has_flag(PAGE_USER);
    }
    
    fn set_user_accessible(self, accessible) {
        if accessible {
            self.set_flag(PAGE_USER);
        } else {
            self.clear_flag(PAGE_USER);
        }
    }
    
    fn is_executable(self) {
        return !self.has_flag(PAGE_NO_EXECUTE);
    }
    
    fn set_executable(self, executable) {
        if executable {
            self.clear_flag(PAGE_NO_EXECUTE);
        } else {
            self.set_flag(PAGE_NO_EXECUTE);
        }
    }
    
    fn is_huge_page(self) {
        return self.has_flag(PAGE_HUGE);
    }
    
    fn set_huge_page(self, huge) {
        if huge {
            self.set_flag(PAGE_HUGE);
        } else {
            self.clear_flag(PAGE_HUGE);
        }
    }
    
    fn write_to_memory(self, addr) {
        systems.poke_u64(addr, self.value);
    }
    
    fn read_from_memory(self, addr) {
        self.value = systems.peek_u64(addr);
    }
}

# ===========================================
# Page Table (512 entries)
# ===========================================

class PageTable {
    fn init(self, physical_addr = null) {
        if physical_addr == null {
            # Allocate new page-aligned table
            self.physical_addr = _alloc_page_aligned(PAGE_SIZE_4KB);
            systems.memset(self.physical_addr, 0, PAGE_SIZE_4KB);
        } else {
            self.physical_addr = physical_addr;
        }
        
        self.entries = [];
        for i in range(0, 512) {
            let entry = PageTableEntry();
            entry.read_from_memory(self.physical_addr + (i * 8));
            push(self.entries, entry);
        }
    }
    
    fn get_entry(self, index) {
        if index < 0 || index >= 512 {
            panic("PageTable: index out of range");
        }
        return self.entries[index];
    }
    
    fn set_entry(self, index, entry) {
        if index < 0 || index >= 512 {
            panic("PageTable: index out of range");
        }
        self.entries[index] = entry;
        entry.write_to_memory(self.physical_addr + (index * 8));
    }
    
    fn flush(self) {
        # Write all entries back to memory
        for i in range(0, 512) {
            self.entries[i].write_to_memory(self.physical_addr + (i * 8));
        }
    }
    
    fn zero(self) {
        # Clear all entries
        for i in range(0, 512) {
            self.entries[i].value = 0;
            self.entries[i].write_to_memory(self.physical_addr + (i * 8));
        }
    }
}

# ===========================================
# Four-Level Paging (x86_64)
# ===========================================

class PageMapper {
    fn init(self, pml4_addr = null) {
        if pml4_addr == null {
            # Create new page tables
            self.pml4 = PageTable();
        } else {
            # Use existing PML4
            self.pml4 = PageTable(pml4_addr);
        }
    }
    
    fn split_virtual_addr(self, virt_addr) {
        # Split virtual address into table indices
        let pml4_index = (virt_addr >> 39) & 0x1FF;
        let pdpt_index = (virt_addr >> 30) & 0x1FF;
        let pd_index = (virt_addr >> 21) & 0x1FF;
        let pt_index = (virt_addr >> 12) & 0x1FF;
        let offset = virt_addr & 0xFFF;
        
        return {
            "pml4": pml4_index,
            "pdpt": pdpt_index,
            "pd": pd_index,
            "pt": pt_index,
            "offset": offset
        };
    }
    
    fn get_or_create_table(self, parent_table, index) {
        let entry = parent_table.get_entry(index);
        
        if !entry.is_present() {
            # Create new table
            let new_table = PageTable();
            entry.set_physical_addr(new_table.physical_addr);
            entry.set_present(true);
            entry.set_writable(true);
            entry.set_user_accessible(true);
            parent_table.set_entry(index, entry);
            
            return new_table;
        } else {
            # Return existing table
            return PageTable(entry.get_physical_addr());
        }
    }
    
    fn map_page(self, virt_addr, phys_addr, flags) {
        let indices = self.split_virtual_addr(virt_addr);
        
        # Walk page tables, creating as needed
        let pdpt = self.get_or_create_table(self.pml4, indices["pml4"]);
        let pd = self.get_or_create_table(pdpt, indices["pdpt"]);
        let pt = self.get_or_create_table(pd, indices["pd"]);
        
        # Set page table entry
        let entry = PageTableEntry();
        entry.set_physical_addr(phys_addr);
        entry.set_flag(flags);
        entry.set_present(true);
        
        pt.set_entry(indices["pt"], entry);
        
        # Invalidate TLB for this page
        hardware.invlpg(virt_addr);
    }
    
    fn map_huge_2mb(self, virt_addr, phys_addr, flags) {
        let indices = self.split_virtual_addr(virt_addr);
        
        # Walk to page directory
        let pdpt = self.get_or_create_table(self.pml4, indices["pml4"]);
        let pd = self.get_or_create_table(pdpt, indices["pdpt"]);
        
        # Set 2MB page
        let entry = PageTableEntry();
        entry.set_physical_addr(phys_addr);
        entry.set_flag(flags);
        entry.set_huge_page(true);
        entry.set_present(true);
        
        pd.set_entry(indices["pd"], entry);
        
        hardware.invlpg(virt_addr);
    }
    
    fn map_huge_1gb(self, virt_addr, phys_addr, flags) {
        let indices = self.split_virtual_addr(virt_addr);
        
        # Walk to PDPT
        let pdpt = self.get_or_create_table(self.pml4, indices["pml4"]);
        
        # Set 1GB page
        let entry = PageTableEntry();
        entry.set_physical_addr(phys_addr);
        entry.set_flag(flags);
        entry.set_huge_page(true);
        entry.set_present(true);
        
        pdpt.set_entry(indices["pdpt"], entry);
        
        hardware.invlpg(virt_addr);
    }
    
    fn unmap_page(self, virt_addr) {
        let indices = self.split_virtual_addr(virt_addr);
        
        # Walk page tables
        let pml4_entry = self.pml4.get_entry(indices["pml4"]);
        if !pml4_entry.is_present() { return; }
        
        let pdpt = PageTable(pml4_entry.get_physical_addr());
        let pdpt_entry = pdpt.get_entry(indices["pdpt"]);
        if !pdpt_entry.is_present() { return; }
        
        let pd = PageTable(pdpt_entry.get_physical_addr());
        let pd_entry = pd.get_entry(indices["pd"]);
        if !pd_entry.is_present() { return; }
        
        let pt = PageTable(pd_entry.get_physical_addr());
        let entry = pt.get_entry(indices["pt"]);
        
        # Clear entry
        entry.value = 0;
        pt.set_entry(indices["pt"], entry);
        
        # Invalidate TLB
        hardware.invlpg(virt_addr);
    }
    
    fn translate_addr(self, virt_addr) {
        let indices = self.split_virtual_addr(virt_addr);
        
        # Walk page tables
        let pml4_entry = self.pml4.get_entry(indices["pml4"]);
        if !pml4_entry.is_present() { return null; }
        
        let pdpt = PageTable(pml4_entry.get_physical_addr());
        let pdpt_entry = pdpt.get_entry(indices["pdpt"]);
        if !pdpt_entry.is_present() { return null; }
        
        # Check for 1GB page
        if pdpt_entry.is_huge_page() {
            let base = pdpt_entry.get_physical_addr();
            return base + (virt_addr & 0x3FFFFFFF);
        }
        
        let pd = PageTable(pdpt_entry.get_physical_addr());
        let pd_entry = pd.get_entry(indices["pd"]);
        if !pd_entry.is_present() { return null; }
        
        # Check for 2MB page
        if pd_entry.is_huge_page() {
            let base = pd_entry.get_physical_addr();
            return base + (virt_addr & 0x1FFFFF);
        }
        
        let pt = PageTable(pd_entry.get_physical_addr());
        let pt_entry = pt.get_entry(indices["pt"]);
        if !pt_entry.is_present() { return null; }
        
        # 4KB page
        let base = pt_entry.get_physical_addr();
        return base + indices["offset"];
    }
    
    fn identity_map(self, start_addr, size, flags) {
        # Identity map a region (virtual == physical)
        let pages = (size + PAGE_SIZE_4KB - 1) / PAGE_SIZE_4KB;
        
        for i in range(0, pages) {
            let addr = start_addr + (i * PAGE_SIZE_4KB);
            self.map_page(addr, addr, flags);
        }
    }
    
    fn activate(self) {
        # Set CR3 to PML4 address
        hardware.write_cr3(self.pml4.physical_addr);
    }
}

# ===========================================
# Memory Protection Keys (Intel PKU)
# ===========================================

class MemoryProtectionKeys {
    fn init(self) {
        # Check if PKU is supported
        self.supported = hardware.cpuid_has_feature("PKU");
    }
    
    fn write_pkru(self, key, disable_access, disable_write) {
        if !self.supported {
            panic("PKU not supported");
        }
        
        let pkru = _rdpkru();
        
        # Set bits for this key
        let bit_offset = key * 2;
        if disable_access {
            pkru = pkru | (1 << bit_offset);
        } else {
            pkru = pkru & ~(1 << bit_offset);
        }
        
        if disable_write {
            pkru = pkru | (1 << (bit_offset + 1));
        } else {
            pkru = pkru & ~(1 << (bit_offset + 1));
        }
        
        _wrpkru(pkru);
    }
    
    fn protect_key(self, key) {
        # Disable access to pages with this key
        self.write_pkru(key, true, true);
    }
    
    fn unprotect_key(self, key) {
        # Enable access to pages with this key
        self.write_pkru(key, false, false);
    }
    
    fn set_page_key(self, pte, key) {
        # Set protection key for page (bits 59-62)
        pte.value = (pte.value & ~(0xF << 59)) | ((key & 0xF) << 59);
    }
}

# ===========================================
# Physical Memory Allocator
# ===========================================

class PhysicalMemoryAllocator {
    fn init(self, memory_map) {
        self.free_frames = [];
        self.used_frames = {};
        
        # Parse memory map and build free frame list
        for region in memory_map {
            if region["type"] == "available" {
                let start = region["start"] / PAGE_SIZE_4KB;
                let end = (region["start"] + region["length"]) / PAGE_SIZE_4KB;
                
                for frame in range(start, end) {
                    push(self.free_frames, frame);
                }
            }
        }
    }
    
    fn alloc_frame(self) {
        if len(self.free_frames) == 0 {
            panic("PhysicalMemoryAllocator: out of memory");
        }
        
        let frame = pop(self.free_frames);
        self.used_frames[frame] = true;
        return frame * PAGE_SIZE_4KB;
    }
    
    fn alloc_contiguous(self, num_frames) {
        # Allocate contiguous physical frames
        let frames = [];
        
        for i in range(0, num_frames) {
            push(frames, self.alloc_frame());
        }
        
        return frames;
    }
    
    fn free_frame(self, phys_addr) {
        let frame = phys_addr / PAGE_SIZE_4KB;
        
        if !self.used_frames.get(frame, false) {
            panic("PhysicalMemoryAllocator: double free");
        }
        
        delete self.used_frames[frame];
        push(self.free_frames, frame);
    }
    
    fn get_free_memory(self) {
        return len(self.free_frames) * PAGE_SIZE_4KB;
    }
    
    fn get_used_memory(self) {
        return len(self.used_frames) * PAGE_SIZE_4KB;
    }
}

# ===========================================
# Virtual Memory Manager
# ===========================================

class VirtualMemoryManager {
    fn init(self, phys_allocator) {
        self.phys_allocator = phys_allocator;
        self.mapper = PageMapper();
        self.next_virt_addr = 0x10000000;  # Start at 256MB
    }
    
    fn alloc_virtual_page(self, flags = PAGE_PRESENT | PAGE_WRITABLE) {
        # Allocate physical frame
        let phys_addr = self.phys_allocator.alloc_frame();
        
        # Map to virtual address
        let virt_addr = self.next_virt_addr;
        self.mapper.map_page(virt_addr, phys_addr, flags);
        
        self.next_virt_addr = self.next_virt_addr + PAGE_SIZE_4KB;
        
        return virt_addr;
    }
    
    fn alloc_virtual_pages(self, num_pages, flags = PAGE_PRESENT | PAGE_WRITABLE) {
        let pages = [];
        
        for i in range(0, num_pages) {
            push(pages, self.alloc_virtual_page(flags));
        }
        
        return pages;
    }
    
    fn free_virtual_page(self, virt_addr) {
        # Get physical address
        let phys_addr = self.mapper.translate_addr(virt_addr);
        
        if phys_addr != null {
            # Unmap page
            self.mapper.unmap_page(virt_addr);
            
            # Free physical frame
            self.phys_allocator.free_frame(phys_addr);
        }
    }
    
    fn change_permissions(self, virt_addr, flags) {
        let indices = self.mapper.split_virtual_addr(virt_addr);
        
        # Walk to page table entry
        let pml4_entry = self.mapper.pml4.get_entry(indices["pml4"]);
        if !pml4_entry.is_present() { return false; }
        
        let pdpt = PageTable(pml4_entry.get_physical_addr());
        let pdpt_entry = pdpt.get_entry(indices["pdpt"]);
        if !pdpt_entry.is_present() { return false; }
        
        let pd = PageTable(pdpt_entry.get_physical_addr());
        let pd_entry = pd.get_entry(indices["pd"]);
        if !pd_entry.is_present() { return false; }
        
        let pt = PageTable(pd_entry.get_physical_addr());
        let entry = pt.get_entry(indices["pt"]);
        
        # Update flags
        let phys_addr = entry.get_physical_addr();
        entry.set_physical_addr(phys_addr);
        entry.set_flag(flags);
        pt.set_entry(indices["pt"], entry);
        
        # Invalidate TLB
        hardware.invlpg(virt_addr);
        
        return true;
    }
}

# ===========================================
# Copy-on-Write (CoW) Support
# ===========================================

class CopyOnWrite {
    fn init(self, vmm) {
        self.vmm = vmm;
        self.ref_counts = {};
    }
    
    fn share_page(self, virt_addr) {
        # Make page read-only and track reference count
        let phys_addr = self.vmm.mapper.translate_addr(virt_addr);
        
        if phys_addr == null {
            return false;
        }
        
        # Make read-only
        self.vmm.change_permissions(virt_addr, PAGE_PRESENT);
        
        # Increment reference count
        let count = self.ref_counts.get(phys_addr, 0);
        self.ref_counts[phys_addr] = count + 1;
        
        return true;
    }
    
    fn handle_write_fault(self, virt_addr) {
        # Handle write to CoW page
        let phys_addr = self.vmm.mapper.translate_addr(virt_addr);
        
        if phys_addr == null {
            return false;
        }
        
        let ref_count = self.ref_counts.get(phys_addr, 0);
        
        if ref_count <= 1 {
            # Only reference, just make writable
            self.vmm.change_permissions(virt_addr, PAGE_PRESENT | PAGE_WRITABLE);
            delete self.ref_counts[phys_addr];
        } else {
            # Multiple references, need to copy
            let new_phys = self.vmm.phys_allocator.alloc_frame();
            
            # Copy page contents
            systems.memcpy(new_phys, phys_addr, PAGE_SIZE_4KB);
            
            # Unmap old page
            self.vmm.mapper.unmap_page(virt_addr);
            
            # Map new page
            self.vmm.mapper.map_page(virt_addr, new_phys, PAGE_PRESENT | PAGE_WRITABLE);
            
            # Decrement reference count
            self.ref_counts[phys_addr] = ref_count - 1;
        }
        
        return true;
    }
}

# ===========================================
# Native Implementation Stubs
# ===========================================

fn _alloc_page_aligned(size) {
    return systems.alloc(size);
}

fn _rdpkru() {
    return 0;
}

fn _wrpkru(value) {
}

# ===========================================
# Global Instances
# ===========================================

let PAGE_MAPPER_GLOBAL = null;
let VMM_GLOBAL = null;

# Convenience functions
fn current_page_mapper() {
    if PAGE_MAPPER_GLOBAL == null {
        let cr3 = hardware.read_cr3();
        PAGE_MAPPER_GLOBAL = PageMapper(cr3);
    }
    return PAGE_MAPPER_GLOBAL;
}
