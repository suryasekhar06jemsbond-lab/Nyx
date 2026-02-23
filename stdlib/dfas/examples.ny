#!/usr/bin/env nyx
# =========================================================================
# DYNAMIC FIELD ARITHMETIC SYSTEM (DFAS) - USAGE EXAMPLES
# =========================================================================
# Comprehensive examples demonstrating all DFAS features
# =========================================================================

import field_core
import arithmetic_engine
import type_system
import safety
import encryption
import compiler

print("=" * 70)
print("DYNAMIC FIELD ARITHMETIC SYSTEM - COMPREHENSIVE EXAMPLES")
print("=" * 70)

# =========================================================================
# EXAMPLE 1: Basic Prime Field Arithmetic
# =========================================================================

print("\n[EXAMPLE 1] Basic Prime Field Arithmetic (F_104729)")
print("-" * 70)

# Create field configuration for F_104729
let field_f104729 = FieldConfig.prime_field(104729)

# Create field elements
let x = FieldInt.new(5, field_f104729)
let y = FieldInt.new(10, field_f104729)

print("Field: F_104729 (prime modulus: 104729)")
print("x = " + x.value())
print("y = " + y.value())

# Arithmetic operations
let sum = x + y
let diff = x - y
let product = x * y
let quotient = y / x

print("\nArithmetic Results:")
print("x + y = " + sum.value())
print("x - y = " + diff.value())
print("x * y = " + product.value())
print("y / x = " + quotient.value())

# Exponentiation
let power = x ^ 10
print("x^10 = " + power.value())

# Inverse
print("\nInverse: x^(-1) mod 104729")
let inv_result = x.element.inverse()
match inv_result {
    case FieldResult.Ok(inv_elem) => {
        print("x^(-1) = " + inv_elem.value)
    }
    case _ => print("Inverse computation failed")
}

# =========================================================================
# EXAMPLE 2: Polynomial Extension Field
# =========================================================================

print("\n[EXAMPLE 2] Polynomial Extension Field (F_7^2)")
print("-" * 70)

# F(7^2) with irreducible polynomial x^2 + 2x + 1
let poly_coeffs = [1, 2, 1]  # x^2 + 2x + 1
let field_f7_2 = FieldConfig.polynomial_field(7, 2, poly_coeffs)

print("Field: F(7^2) with polynomial x^2 + 2x + 1")

# Create polynomial elements
let p1 = PolynomialElement.new([3, 4], field_f7_2)  # 3 + 4x
let p2 = PolynomialElement.new([2, 5], field_f7_2)  # 2 + 5x

print("p1 = 3 + 4x")
print("p2 = 2 + 5x")

# Polynomial arithmetic
let p_sum = p1.add(p2)
let p_product = p1.mul(p2)

print("\nPolynomial Arithmetic:")
print("p1 + p2 = " + format_polynomial(p_sum.coefficients))
print("p1 * p2 = " + format_polynomial(p_product.coefficients))

# =========================================================================
# EXAMPLE 3: Named Field Types (Type Registry)
# =========================================================================

print("\n[EXAMPLE 3] Named Field Types with Registry")
print("-" * 70)

# Use pre-registered field types
let field_f7 = FIELD_TYPE_REGISTRY.lookup("F7")
match field_f7 {
    case Some(config) => {
        let a = FieldInt.new(3, config)
        let b = FieldInt.new(5, config)
        let result = a + b
        print("Using registered field 'F7':")
        print("3 + 5 = " + result.value() + " (mod 7)")
    }
    case None => print("Field F7 not found in registry")
}

# Use Mersenne prime field
let field_mersenne = FIELD_TYPE_REGISTRY.lookup("Mersenne31")
match field_mersenne {
    case Some(config) => {
        print("\nUsing Mersenne prime field (2^31 - 1):")
        print("Modulus: " + config.modulus)
        
        let m1 = FieldInt.new(1000000, config)
        let m2 = FieldInt.new(2000000, config)
        let m_product = m1 * m2
        print("1000000 * 2000000 = " + m_product.value() + " (mod 2^31-1)")
    }
    case None => print("Mersenne31 field not found")
}

# =========================================================================
# EXAMPLE 4: Type Safety and Cross-Field Protection
# =========================================================================

print("\n[EXAMPLE 4] Type Safety - Cross-Field Arithmetic Prevention")
print("-" * 70)

let field_a = FieldConfig.prime_field(7)
let field_b = FieldConfig.prime_field(11)

let elem_a = FieldInt.new(5, field_a)
let elem_b = FieldInt.new(5, field_b)

print("Field A: F_7, element = 5")
print("Field B: F_11, element = 5")
print("\nAttempting cross-field addition (should be rejected):")

# This would cause a safety error
# Wrapped in try to handle gracefully
try {
    let invalid_sum = elem_a + elem_b
    print("ERROR: Cross-field operation allowed (should not happen)")
} catch {
    print("✓ Cross-field operation correctly rejected by type system")
}

# =========================================================================
# EXAMPLE 5: Safe Arithmetic with Runtime Checks
# =========================================================================

print("\n[EXAMPLE 5] Safe Arithmetic with Runtime Validation")
print("-" * 70)

let field_safe = FieldConfig.prime_field(13)
let safe_a = SafeFieldInt.new(
    FieldInt.new(10, field_safe), 
    SafetyLevel.Strict
)
let safe_b = SafeFieldInt.new(
    FieldInt.new(8, field_safe),
    SafetyLevel.Strict
)

print("Safety Level: Strict")
print("Field: F_13")

# Safe multiplication
let safe_mul_result = safe_a.safe_mul(safe_b)
match safe_mul_result {
    case Ok(result) => {
        print("Safe multiplication: 10 * 8 = " + result.value.value() + " (mod 13)")
    }
    case Err(msg) => {
        print("Safe multiplication failed: " + msg)
    }
}

# Safe division
let safe_div_result = safe_a.safe_div(safe_b)
match safe_div_result {
    case Ok(result) => {
        print("Safe division: 10 / 8 = " + result.value.value() + " (mod 13)")
    }
    case Err(msg) => {
        print("Safe division failed: " + msg)
    }
}

# =========================================================================
# EXAMPLE 6: Secure Field with Encryption
# =========================================================================

print("\n[EXAMPLE 6] Secure Field with Encryption Mode")
print("-" * 70)

# Create secure field from seed
let secure_config = SecureFieldConfig.new(123456789, 256, SecureLevel.High)
print("Secure Field: seed=123456789, bit_length=256")
print("Security Level: High (constant-time operations)")
print("Modulus (generated): " + secure_config.base_config.modulus)

# Create encrypted field elements
let enc_x = EncryptedFieldElement.new(42, secure_config)
let enc_y = EncryptedFieldElement.new(17, secure_config)

print("\nEncrypted Elements: x=42, y=17 (values are encrypted in memory)")

# Encrypted arithmetic
let enc_sum = enc_x.encrypted_add(enc_y)
let enc_product = enc_x.encrypted_mul(enc_y)

print("✓ Encrypted addition performed")
print("✓ Encrypted multiplication performed")
print("(Results remain encrypted for security)")

# Decrypt with authorization
let auth_token = secure_config.reconstruction_token
let decrypted_sum = enc_sum.decrypt(auth_token)
match decrypted_sum {
    case Ok(plain_sum) => {
        print("\nDecrypted sum: " + plain_sum.value())
    }
    case Err(msg) => {
        print("Decryption failed: " + msg)
    }
}

# =========================================================================
# EXAMPLE 7: Montgomery Optimization
# =========================================================================

print("\n[EXAMPLE 7] Montgomery Multiplication Optimization")
print("-" * 70)

let field_mont = FieldConfig.prime_field(104729).with_montgomery()
print("Field: F_104729 with Montgomery optimization")
print("Reduction method: Montgomery")

let m_elem1 = FieldElement.new(50000, field_mont)
let m_elem2 = FieldElement.new(60000, field_mont)

print("\nElements: 50000, 60000")

# Compute Montgomery parameters
let mont_params = compute_montgomery_params(field_mont.modulus)
print("Montgomery R: 2^" + mont_params.k_bits)

# Convert to Montgomery form
let m_form1 = to_montgomery_form(m_elem1, mont_params)
let m_form2 = to_montgomery_form(m_elem2, mont_params)

print("✓ Converted to Montgomery form")

# Montgomery multiplication
let mont_product = montgomery_mul(m_form1, m_form2)
print("✓ Montgomery multiplication performed")

# Convert back
let plain_product = from_montgomery_form(mont_product, mont_params)
print("Result: " + plain_product.value)

# =========================================================================
# EXAMPLE 8: Compiler Simulation
# =========================================================================

print("\n[EXAMPLE 8] Compiler Simulation - Source to IR")
print("-" * 70)

let source_code = "field<prime=13> int x = 5"
print("Source code: " + source_code)

let compile_result = compile_field_program(source_code)
match compile_result {
    case Ok(ir_instructions) => {
        print("\n✓ Compilation successful!")
        print("IR Instructions generated: " + len(ir_instructions))
        
        for i in 0..min(len(ir_instructions)-1, 4) {
            let instr = ir_instructions[i]
            print("  [" + i + "] Opcode: " + format_opcode(instr.opcode))
        }
    }
    case Err(msg) => {
        print("Compilation failed: " + msg)
    }
}

# =========================================================================
# EXAMPLE 9: Field Reconstruction from Token
# =========================================================================

print("\n[EXAMPLE 9] Secure Field Reconstruction")
print("-" * 70)

let original_seed = 987654321
let original_config = SecureFieldConfig.new(original_seed, 128, SecureLevel.Medium)
let reconstruction_token = original_config.reconstruction_token

print("Original seed: " + original_seed)
print("Reconstruction token: " + reconstruction_token)

# Reconstruct field from token
let reconstructed = SecureFieldConfig.reconstruct(reconstruction_token, original_seed)
match reconstructed {
    case Some(config) => {
        print("\n✓ Field successfully reconstructed!")
        print("Reconstructed modulus: " + config.base_config.modulus)
        print("Moduli match: " + (config.base_config.modulus == original_config.base_config.modulus))
    }
    case None => {
        print("Reconstruction failed - invalid token or seed")
    }
}

# =========================================================================
# EXAMPLE 10: Access Control for Secure Fields
# =========================================================================

print("\n[EXAMPLE 10] Access Control System")
print("-" * 70)

let field_acl = FieldConfig.prime_field(17)
let acl = FieldAccessControl.new(field_acl.field_id)

print("Field ID: " + field_acl.field_id)
print("Initial permissions: Read, Compute")

# Grant additional permissions
acl.grant(FieldPermission.Write)
acl.grant(FieldPermission.Cast)

print("\nPermissions granted: Write, Cast")
print("Has Write permission: " + acl.has_permission(FieldPermission.Write))
print("Has Admin permission: " + acl.has_permission(FieldPermission.Admin))

# Lock access control
acl.lock()
print("\nAccess control locked (immutable)")

# Attempt to grant after lock (should fail silently)
acl.grant(FieldPermission.Admin)
print("Admin permission after lock: " + acl.has_permission(FieldPermission.Admin))

# =========================================================================
# EXAMPLE 11: Audit Logging
# =========================================================================

print("\n[EXAMPLE 11] Audit Logging for Critical Operations")
print("-" * 70)

AUDIT_LOGGER.enable()
print("Audit logging enabled")

let audit_field = FieldConfig.prime_field(23)
let audit_a = FieldInt.new(15, audit_field)
let audit_b = FieldInt.new(20, audit_field)

# Perform logged operation
AUDIT_LOGGER.log("FIELD_ADD", audit_field.field_id, [15, 20], 12, SafetyLevel.Standard)
AUDIT_LOGGER.log("FIELD_MUL", audit_field.field_id, [15, 20], 14, SafetyLevel.Standard)

print("\nOperations logged:")
let recent = AUDIT_LOGGER.recent(2)
for entry in recent {
    print("  - " + entry.operation + " on field " + entry.field_id)
}

# =========================================================================
# SUMMARY
# =========================================================================

print("\n" + "=" * 70)
print("EXAMPLES COMPLETE")
print("=" * 70)
print("\nKey Features Demonstrated:")
print("✓ Prime field arithmetic")
print("✓ Polynomial extension fields")
print("✓ Type system integration")
print("✓ Cross-field safety checks")
print("✓ Runtime validation")
print("✓ Secure/encrypted fields")
print("✓ Montgomery optimization")
print("✓ Compiler simulation")
print("✓ Field reconstruction")
print("✓ Access control")
print("✓ Audit logging")

# =========================================================================
# UTILITY FUNCTIONS
# =========================================================================

fn format_polynomial(coeffs: [int]) -> string = {
    let mut result = ""
    for i in 0..len(coeffs)-1 {
        if coeffs[i] != 0 {
            if i == 0 {
                result = result + coeffs[i]
            } else if i == 1 {
                result = result + " + " + coeffs[i] + "x"
            } else {
                result = result + " + " + coeffs[i] + "x^" + i
            }
        }
    }
    if result == "" { "0" } else { result }
}

fn format_opcode(opcode: IROpcode) -> string = {
    match opcode {
        case IROpcode.FIELD_LOAD => "FIELD_LOAD"
        case IROpcode.FIELD_STORE => "FIELD_STORE"
        case IROpcode.FIELD_ADD => "FIELD_ADD"
        case IROpcode.FIELD_MUL => "FIELD_MUL"
        case IROpcode.FIELD_DIV => "FIELD_DIV"
        case IROpcode.FIELD_POW => "FIELD_POW"
        case _ => "FIELD_OP"
    }
}

fn min(a: int, b: int) -> int = {
    if a < b { a } else { b }
}
