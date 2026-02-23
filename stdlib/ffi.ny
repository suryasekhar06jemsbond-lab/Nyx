# ===========================================
# Nyx Standard Library - FFI Module
# ===========================================
# Foreign Function Interface for C/C++ interop
# CRITICAL: This enables Nyx to call native code

# Load a shared library (DLL on Windows, .so on Linux)
fn open(lib_path) {
    # This would be implemented as a native call
    # Returns a library handle
    return _ffi_open(lib_path);
}

# Close a loaded library
fn close(lib) {
    return _ffi_close(lib);
}

# Get a function pointer from a library
fn symbol(lib, func_name) {
    return _ffi_symbol(lib, func_name);
}

# Call a C function
fn call(func_ptr, ret_type, ...args) {
    # Types: void, int, float, double, string, pointer
    return _ffi_call(func_ptr, ret_type, args);
}

# Call with argument types specified
fn call_with_types(func_ptr, ret_type, arg_types, args) {
    return _ffi_call_typed(func_ptr, ret_type, arg_types, args);
}

# Allocate memory
fn malloc(size) {
    return _ffi_malloc(size);
}

# Free memory
fn free(ptr) {
    return _ffi_free(ptr);
}

# Allocate string in C memory
fn to_c_string(s) {
    let ptr = _ffi_malloc(len(s) + 1);
    # Copy string to pointer
    # In real implementation, this would copy bytes
    return ptr;
}

# Convert C string to Nyx string
fn from_c_string(ptr) {
    # Would read from C memory
    return "";
}

# Convert Nyx array to C array
fn to_c_array(arr, elem_type) {
    let size = len(arr);
    let elem_size = _ffi_type_size(elem_type);
    let ptr = _ffi_malloc(size * elem_size);
    return ptr;
}

# Get size of C type
fn type_size(type_name) {
    if type_name == "char" {
        return 1;
    }
    if type_name == "short" {
        return 2;
    }
    if type_name == "int" {
        return 4;
    }
    if type_name == "long" {
        return 8;
    }
    if type_name == "float" {
        return 4;
    }
    if type_name == "double" {
        return 8;
    }
    if type_name == "pointer" {
        return 8;
    }
    throw "ffi.type_size: unknown type " + type_name;
}

# Read memory
fn peek(ptr, type_name) {
    return _ffi_peek(ptr, type_name);
}

# Write memory
fn poke(ptr, value, type_name) {
    return _ffi_poke(ptr, value, type_name);
}

# Get pointer address
fn address_of(ptr) {
    return _ffi_address(ptr);
}

# Add offset to pointer
fn ptr_add(ptr, offset) {
    return _ffi_ptr_add(ptr, offset);
}

# Convert to void pointer
fn as_void_ptr(ptr) {
    return _ffi_void_ptr(ptr);
}

# FFI Type constants
let TYPE_VOID = 0;
let TYPE_CHAR = 1;
let TYPE_SHORT = 2;
let TYPE_INT = 3;
let TYPE_LONG = 4;
let TYPE_FLOAT = 5;
let TYPE_DOUBLE = 6;
let TYPE_POINTER = 7;
let TYPE_STRING = 8;

# FFI Library wrapper class
class Library {
    fn init(self, path) {
        self.handle = open(path);
        if self.handle == null {
            throw "ffi.Library: failed to load " + path;
        }
    }
    
    fn func(self, name, ret_type) {
        let ptr = symbol(self.handle, name);
        if ptr == null {
            throw "ffi.Library: function " + name + " not found";
        }
        return CFunction(ptr, ret_type);
    }
    
    fn close(self) {
        close(self.handle);
        self.handle = null;
    }
}

# C Function wrapper
class CFunction {
    fn init(self, ptr, ret_type) {
        self.ptr = ptr;
        self.ret_type = ret_type;
    }
    
    fn call(self, ...args) {
        return call(self.ptr, self.ret_type, ...args);
    }
}

# C Data types for type safety
class CType {
    fn init(self, name, size) {
        self.name = name;
        self.size = size;
    }
}

# Predefined C types
let C_CHAR = CType("char", 1);
let C_SHORT = CType("short", 2);
let C_INT = CType("int", 4);
let C_LONG = CType("long", 8);
let C_FLOAT = CType("float", 4);
let C_DOUBLE = CType("double", 8);
let C_POINTER = CType("pointer", 8);
let C_VOID = CType("void", 0);

# C Struct definition helper
class CStruct {
    fn init(self, name) {
        self.name = name;
        self.fields = [];
    }
    
    fn add_field(self, field_name, field_type) {
        push(self.fields, field_name);
        push(self.fields, field_type);
        return self;
    }
    
    fn size(self) {
        let total = 0;
        for i in range(1, len(self.fields), 2) {
            total = total + self.fields[i].size;
        }
        return total;
    }
}

# Example: Create a C struct for a point
fn Point() {
    return CStruct("Point")
        .add_field("x", C_INT)
        .add_field("y", C_INT);
}

# Callback/Function pointer support
class Callback {
    fn init(self, nyx_func, ret_type, arg_types) {
        self.nyx_func = nyx_func;
        self.ret_type = ret_type;
        self.arg_types = arg_types;
    }
    
    fn to_c(self) {
        # Creates a C function pointer that calls the Nyx function
        return _ffi_callback_create(self.nyx_func, self.ret_type, self.arg_types);
    }
}

# ===========================================
# Advanced FFI Features
# ===========================================

# Variadic function support
class VariadicFunction {
    fn init(self, ptr, ret_type) {
        self.ptr = ptr;
        self.ret_type = ret_type;
    }
    
    fn call(self, ...args) {
        # Convert args to C variadic format
        return _ffi_call_variadic(self.ptr, self.ret_type, args);
    }
}

# Function pointer table (vtable)
class VTable {
    fn init(self) {
        self.functions = {};
    }
    
    fn add(self, name, func_ptr, ret_type) {
        self.functions[name] = CFunction(func_ptr, ret_type);
    }
    
    fn call(self, name, ...args) {
        if name in self.functions {
            return self.functions[name].call(...args);
        }
        throw "VTable: function " + name + " not found";
    }
}

# Union type for C unions
class CUnion {
    fn init(self, size) {
        self.ptr = malloc(size);
        self.size = size;
        
        if self.ptr == null {
            throw "CUnion: allocation failed";
        }
    }
    
    fn read_as(self, type_) {
        return peek(self.ptr, type_);
    }
    
    fn write_as(self, value, type_) {
        poke(self.ptr, value, type_);
    }
    
    fn destroy(self) {
        if self.ptr != null {
            free(self.ptr);
            self.ptr = null;
        }
    }
}

# Bit field support
class BitField {
    fn init(self, value, offset, width) {
        self.value = value;
        self.offset = offset;
        self.width = width;
    }
    
    fn get(self) {
        let mask = (1 << self.width) - 1;
        return (self.value >> self.offset) & mask;
    }
    
    fn set(self, new_value) {
        let mask = (1 << self.width) - 1;
        self.value = (self.value & ~(mask << self.offset)) | ((new_value & mask) << self.offset);
        return self.value;
    }
}

# Packed struct support
class PackedStruct {
    fn init(self, fields) {
        # fields = [(name, type, offset), ...]
        self.fields = fields;
        self.size = self.calculate_size();
        self.ptr = malloc(self.size);
        
        if self.ptr == null {
            throw "PackedStruct: allocation failed";
        }
    }
    
    fn calculate_size(self) {
        let max_end = 0;
        for field in self.fields {
            let offset = field[2];
            let type_ = field[1];
            let end = offset + type_size(type_.name);
            if end > max_end {
                max_end = end;
            }
        }
        return max_end;
    }
    
    fn get(self, field_name) {
        for field in self.fields {
            if field[0] == field_name {
                let offset = field[2];
                let type_ = field[1];
                return peek(ptr_add(self.ptr, offset), type_.name);
            }
        }
        throw "PackedStruct: field " + field_name + " not found";
    }
    
    fn set(self, field_name, value) {
        for field in self.fields {
            if field[0] == field_name {
                let offset = field[2];
                let type_ = field[1];
                poke(ptr_add(self.ptr, offset), value, type_.name);
                return;
            }
        }
        throw "PackedStruct: field " + field_name + " not found";
    }
    
    fn destroy(self) {
        if self.ptr != null {
            free(self.ptr);
            self.ptr = null;
        }
    }
}

# Function trampoline for callbacks
class CallbackTrampoline {
    fn init(self, nyx_func, ret_type, arg_types) {
        self.nyx_func = nyx_func;
        self.ret_type = ret_type;
        self.arg_types = arg_types;
        self.trampoline_ptr = _ffi_create_trampoline(nyx_func, ret_type, arg_types);
    }
    
    fn get_ptr(self) {
        return self.trampoline_ptr;
    }
    
    fn destroy(self) {
        if self.trampoline_ptr != null {
            _ffi_destroy_trampoline(self.trampoline_ptr);
            self.trampoline_ptr = null;
        }
    }
}

# Lazy symbol loading
class LazySymbol {
    fn init(self, lib, symbol_name, ret_type) {
        self.lib = lib;
        self.symbol_name = symbol_name;
        self.ret_type = ret_type;
        self.func_ptr = null;
        self.loaded = false;
    }
    
    fn ensure_loaded(self) {
        if !self.loaded {
            self.func_ptr = symbol(self.lib, self.symbol_name);
            if self.func_ptr == null {
                throw "LazySymbol: failed to load " + self.symbol_name;
            }
            self.loaded = true;
        }
    }
    
    fn call(self, ...args) {
        self.ensure_loaded();
        return call(self.func_ptr, self.ret_type, ...args);
    }
}

# Dynamic library loader with caching
class LibraryCache {
    fn init(self) {
        self.libraries = {};
    }
    
    fn load(self, path) {
        if path in self.libraries {
            return self.libraries[path];
        }
        
        let lib = Library(path);
        self.libraries[path] = lib;
        return lib;
    }
    
    fn unload(self, path) {
        if path in self.libraries {
            let lib = self.libraries[path];
            lib.close();
            delete(self.libraries, path);
        }
    }
    
    fn unload_all(self) {
        for path in keys(self.libraries) {
            self.libraries[path].close();
        }
        self.libraries = {};
    }
}

# Opaque pointers (for C void*)
class OpaquePtr {
    fn init(self, ptr) {
        self.ptr = ptr;
    }
    
    fn as_int(self) {
        return address_of(self.ptr);
    }
    
    fn cast(self, type_) {
        return self.ptr;
    }
    
    fn is_null(self) {
        return self.ptr == null;
    }
}

# Array marshalling helpers
class ArrayMarshaller {
    fn to_c_array_i32(self, arr) {
        let size = len(arr);
        let ptr = malloc(size * 4);
        
        for i in range(0, size) {
            poke(ptr_add(ptr, i * 4), arr[i], "int");
        }
        
        return ptr;
    }
    
    fn from_c_array_i32(self, ptr, size) {
        let arr = [];
        
        for i in range(0, size) {
            let val = peek(ptr_add(ptr, i * 4), "int");
            push(arr, val);
        }
        
        return arr;
    }
    
    fn to_c_array_f64(self, arr) {
        let size = len(arr);
        let ptr = malloc(size * 8);
        
        for i in range(0, size) {
            poke(ptr_add(ptr, i * 8), arr[i], "double");
        }
        
        return ptr;
    }
    
    fn from_c_array_f64(self, ptr, size) {
        let arr = [];
        
        for i in range(0, size) {
            let val = peek(ptr_add(ptr, i * 8), "double");
            push(arr, val);
        }
        
        return arr;
    }
}

# String encoding conversions
class StringEncoding {
    fn utf8_to_utf16(self, utf8_str) {
        return _encoding_convert(utf8_str, "utf8", "utf16");
    }
    
    fn utf16_to_utf8(self, utf16_str) {
        return _encoding_convert(utf16_str, "utf16", "utf8");
    }
    
    fn to_wide_string(self, str) {
        # Windows WCHAR* (UTF-16)
        return self.utf8_to_utf16(str);
    }
}

# Error code handling
class FFIError {
    fn init(self) {
        self.last_error = 0;
    }
    
    fn set_last_error(self, code) {
        self.last_error = code;
    }
    
    fn get_last_error(self) {
        return self.last_error;
    }
    
    fn clear_error(self) {
        self.last_error = 0;
    }
    
    fn check_error(self, message = "FFI call failed") {
        if self.last_error != 0 {
            throw message + " (error code: " + str(self.last_error) + ")";
        }
    }
}

# Global instances
let GLOBAL_LIBRARY_CACHE = LibraryCache();
let GLOBAL_ARRAY_MARSHALLER = ArrayMarshaller();
let GLOBAL_STRING_ENCODING = StringEncoding();
let GLOBAL_FFI_ERROR = FFIError();

# Convenience functions
fn load_library_cached(path) {
    return GLOBAL_LIBRARY_CACHE.load(path);
}

fn to_c_array_i32(arr) {
    return GLOBAL_ARRAY_MARSHALLER.to_c_array_i32(arr);
}

fn from_c_array_i32(ptr, size) {
    return GLOBAL_ARRAY_MARSHALLER.from_c_array_i32(ptr, size);
}

fn utf8_to_utf16(str) {
    return GLOBAL_STRING_ENCODING.utf8_to_utf16(str);
}

fn get_ffi_last_error() {
    return GLOBAL_FFI_ERROR.get_last_error();
}

# Native stubs for advanced features
fn _ffi_call_variadic(ptr, ret_type, args) {
    # Native variadic call implementation
    return null;
}

fn _ffi_create_trampoline(func, ret_type, arg_types) {
    # Create executable trampoline for callback
    return null;
}

fn _ffi_destroy_trampoline(ptr) {
    # Free trampoline memory
}

fn _encoding_convert(str, from_enc, to_enc) {
    # Native encoding conversion
    return str;
}

# Example usage:
# let lib = Library("libc.so.6");
# let printf = lib.func("printf", C_INT);
# printf.call("Hello %s\n", "World");
#
# # Advanced usage:
# let lib_cache = LibraryCache();
# let libc = lib_cache.load("libc.so.6");
#
# # Callbacks:
# let callback = CallbackTrampoline(fn(x, y) { return x + y; }, C_INT, [C_INT, C_INT]);
# some_c_function(callback.get_ptr());
#
# # Packed structs:
# let my_struct = PackedStruct([
#     ("x", C_INT, 0),
#     ("y", C_INT, 4),
#     ("z", C_FLOAT, 8)
# ]);
# my_struct.set("x", 42);
# print(my_struct.get("x"));
