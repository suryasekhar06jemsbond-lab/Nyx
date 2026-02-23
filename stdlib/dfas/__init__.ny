#!/usr/bin/env nyx
# =========================================================================
# DYNAMIC FIELD ARITHMETIC SYSTEM (DFAS) - MAIN INITIALIZATION
# =========================================================================
# Production-Grade Finite Field Arithmetic for Nyx Systems Language
# 
# This is the master initialization file that loads all DFAS components
# and provides a unified interface for field arithmetic operations.
#
# USAGE:
#   import dfas
#   let field = dfas.create_prime_field(104729)
#   let x = dfas.field_element(5, field)
#   let y = dfas.field_element(10, field)
#   let sum = x + y
# =========================================================================

print("╔" + "═" * 68 + "╗")
print("║" + center_text("DYNAMIC FIELD ARITHMETIC SYSTEM (DFAS)", 68) + "║")
print("║" + center_text("v1.0.0 - Production Release", 68) + "║")
print("╚" + "═" * 68 + "╝")

# =========================================================================
# MODULE IMPORTS
# =========================================================================

print("\n[LOADING] Core modules...")

import field_core
import arithmetic_engine
import type_system
import safety
import encryption
import compiler

print("[✓] All DFAS modules loaded successfully")

# =========================================================================
# UNIFIED API
# =========================================================================

# Easy field creation functions
fn create_prime_field(modulus: int) -> FieldConfig = {
    FieldConfig.prime_field(modulus)
}

fn create_polynomial_field(prime: int, degree: int, poly_coeffs: [int]) -> FieldConfig = {
    FieldConfig.polynomial_field(prime, degree, poly_coeffs)
}

fn create_secure_field(seed: int, bit_length: int, security_level: SecureLevel) -> SecureFieldConfig = {
    SecureFieldConfig.new(seed, bit_length, security_level)
}

# Element creation
fn field_element(value: int, field: FieldConfig) -> FieldInt = {
    FieldInt.new(value, field)
}

fn safe_field_element(value: int, field: FieldConfig, level: SafetyLevel) -> SafeFieldInt = {
    SafeFieldInt.new(FieldInt.new(value, field), level)
}

fn encrypted_element(value: int, secure_config: SecureFieldConfig) -> EncryptedFieldElement = {
    EncryptedFieldElement.new(value, secure_config)
}

# Polynomial elements
fn polynomial_element(coeffs: [int], field: FieldConfig) -> PolynomialElement = {
    PolynomialElement.new(coeffs, field)
}

# Field lookup from registry
fn get_field(name: string) -> Option<FieldConfig> = {
    FIELD_TYPE_REGISTRY.lookup(name)
}

fn register_field(name: string, config: FieldConfig) -> void = {
    FIELD_TYPE_REGISTRY.register(name, config)
}

# =========================================================================
# SYSTEM INFORMATION
# =========================================================================

struct DFASInfo {
    version: string,
    modules_loaded: [string],
    registered_fields: [string],
    features: [string]
}

fn get_system_info() -> DFASInfo = {
    DFASInfo {
        version: "1.0.0",
        modules_loaded: [
            "field_core",
            "arithmetic_engine",
            "type_system",
            "safety",
            "encryption",
            "compiler"
        ],
        registered_fields: [
            "F7", "F11", "F13",
            "F104729", "F1000003",
            "Mersenne31", "F_2_8"
        ],
        features: [
            "Prime field arithmetic",
            "Polynomial extension fields",
            "Montgomery optimization",
            "Barrett reduction",
            "Secure/encrypted fields",
            "Type-safe operations",
            "Runtime safety validation",
            "Cross-field protection",
            "Access control",
            "Audit logging",
            "Compiler integration",
            "SIMD-ready layout"
        ]
    }
}

fn print_system_info() -> void = {
    let info = get_system_info()
    
    print("\n" + "─" * 70)
    print("DFAS System Information")
    print("─" * 70)
    print("Version: " + info.version)
    
    print("\nModules Loaded:")
    for module in info.modules_loaded {
        print("  • " + module)
    }
    
    print("\nRegistered Fields:")
    for field in info.registered_fields {
        print("  • " + field)
    }
    
    print("\nAvailable Features:")
    for feature in info.features {
        print("  • " + feature)
    }
    
    print("─" * 70)
}

# =========================================================================
# QUICK START EXAMPLES
# =========================================================================

fn quick_start_demo() -> void = {
    print("\n╔" + "═" * 68 + "╗")
    print("║" + center_text("QUICK START DEMONSTRATION", 68) + "║")
    print("╚" + "═" * 68 + "╝")
    
    # Example 1: Basic usage
    print("\n[Example 1] Basic Prime Field Arithmetic")
    print("-" * 70)
    
    let field = create_prime_field(17)
    let a = field_element(10, field)
    let b = field_element(15, field)
    let sum = a + b
    
    print("Field: F_17")
    print("a = 10, b = 15")
    print("a + b = " + sum.value() + " (mod 17)")
    
    # Example 2: Using registered field
    print("\n[Example 2] Using Registered Field")
    print("-" * 70)
    
    let f7_maybe = get_field("F7")
    match f7_maybe {
        case Some(f7) => {
            let x = field_element(5, f7)
            let y = field_element(6, f7)
            let product = x * y
            print("Field: F7 (from registry)")
            print("5 * 6 = " + product.value() + " (mod 7)")
        }
        case None => print("Field F7 not found")
    }
    
    # Example 3: Safe arithmetic
    print("\n[Example 3] Safe Arithmetic")
    print("-" * 70)
    
    let safe_field = create_prime_field(13)
    let safe_a = safe_field_element(8, safe_field, SafetyLevel.Standard)
    let safe_b = safe_field_element(7, safe_field, SafetyLevel.Standard)
    
    let safe_result = safe_a.safe_mul(safe_b)
    match safe_result {
        case Ok(result) => {
            print("Safe multiplication: 8 * 7 = " + result.value.value() + " (mod 13)")
        }
        case Err(msg) => {
            print("Safe operation failed: " + msg)
        }
    }
    
    print("\n" + "═" * 70)
}

# =========================================================================
# UTILITY FUNCTIONS
# =========================================================================

fn center_text(text: string, width: int) -> string = {
    let padding = (width - len(text)) / 2
    let left_pad = " " * padding
    let right_pad = " " * (width - len(text) - padding)
    left_pad + text + right_pad
}

# =========================================================================
# INITIALIZATION
# =========================================================================

print_system_info()
quick_start_demo()

print("\n╔" + "═" * 68 + "╗")
print("║" + center_text("DFAS READY", 68) + "║")
print("╚" + "═" * 68 + "╝")

print("\nTo run examples: nyx stdlib/dfas/examples.ny")
print("To run tests:    nyx stdlib/dfas/tests.ny")
print("To benchmark:    nyx stdlib/dfas/benchmarks.ny")
print("Documentation:   docs/DFAS_DOCUMENTATION.md")
print("")
