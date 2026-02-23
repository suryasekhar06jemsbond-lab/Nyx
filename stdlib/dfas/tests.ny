#!/usr/bin/env nyx
# =========================================================================
# DYNAMIC FIELD ARITHMETIC SYSTEM (DFAS) - UNIT TESTS
# =========================================================================
# Comprehensive test suite for all DFAS components
# =========================================================================

import field_core
import arithmetic_engine
import type_system
import safety
import encryption
import compiler

# =========================================================================
# TEST FRAMEWORK
# =========================================================================

class TestSuite {
    name: string,
    tests_passed: int,
    tests_failed: int,
    failures: [string]
    
    fn new(name: string) -> TestSuite = {
        Self {
            name: name,
            tests_passed: 0,
            tests_failed: 0,
            failures: []
        }
    }
    
    fn assert_eq(self, expected: int, actual: int, test_name: string) -> void = {
        if expected == actual {
            self.tests_passed = self.tests_passed + 1
            print("  ✓ " + test_name)
        } else {
            self.tests_failed = self.tests_failed + 1
            let msg = test_name + " FAILED: expected " + expected + ", got " + actual
            self.failures.push(msg)
            print("  ✗ " + msg)
        }
    }
    
    fn assert_true(self, condition: bool, test_name: string) -> void = {
        if condition {
            self.tests_passed = self.tests_passed + 1
            print("  ✓ " + test_name)
        } else {
            self.tests_failed = self.tests_failed + 1
            let msg = test_name + " FAILED: condition was false"
            self.failures.push(msg)
            print("  ✗ " + msg)
        }
    }
    
    fn report(self) -> void = {
        print("\n" + "=" * 70)
        print("Test Suite: " + self.name)
        print("-" * 70)
        print("Passed: " + self.tests_passed)
        print("Failed: " + self.tests_failed)
        print("Total:  " + (self.tests_passed + self.tests_failed))
        
        if self.tests_failed > 0 {
            print("\nFailures:")
            for failure in self.failures {
                print("  - " + failure)
            }
        }
        print("=" * 70)
    }
}

# =========================================================================
# TEST SUITE 1: Core Field Definitions
# =========================================================================

fn test_field_core() -> void = {
    let suite = TestSuite.new("Core Field Definitions")
    print("\n[TEST SUITE] Core Field Definitions")
    print("-" * 70)
    
    # Test 1: Prime field creation
    let field = FieldConfig.prime_field(7)
    suite.assert_eq(7, field.modulus, "Prime field modulus")
    suite.assert_eq(1, field.degree, "Prime field degree")
    suite.assert_true(field.field_type == FieldType.PrimeField, "Prime field type")
    
    # Test 2: Field element creation
    let elem = FieldElement.new(10, field)
    suite.assert_eq(3, elem.value, "Field element reduction (10 mod 7 = 3)")
    suite.assert_true(elem.is_normalized, "Field element is normalized")
    
    # Test 3: Negative value normalization
    let neg_elem = FieldElement.new(-2, field)
    suite.assert_eq(5, neg_elem.value, "Negative value normalization (-2 mod 7 = 5)")
    
    # Test 4: Zero and One elements
    let zero = FieldElement.zero(field)
    let one = FieldElement.one(field)
    suite.assert_eq(0, zero.value, "Zero element")
    suite.assert_eq(1, one.value, "One element")
    suite.assert_true(zero.is_zero(), "Zero check")
    suite.assert_true(one.is_one(), "One check")
    
    # Test 5: Polynomial field creation
    let poly_field = FieldConfig.polynomial_field(2, 3, [1, 1, 0, 1])
    suite.assert_eq(2, poly_field.characteristic, "Polynomial field characteristic")
    suite.assert_eq(3, poly_field.degree, "Polynomial field degree")
    
    # Test 6: Field ID uniqueness
    let field_a = FieldConfig.prime_field(11)
    let field_b = FieldConfig.prime_field(13)
    suite.assert_true(field_a.field_id != field_b.field_id, "Unique field IDs")
    
    suite.report()
}

# =========================================================================
# TEST SUITE 2: Arithmetic Operations
# =========================================================================

fn test_arithmetic() -> void = {
    let suite = TestSuite.new("Arithmetic Operations")
    print("\n[TEST SUITE] Arithmetic Operations")
    print("-" * 70)
    
    let field = FieldConfig.prime_field(13)
    
    # Test 1: Addition
    let a = FieldElement.new(5, field)
    let b = FieldElement.new(10, field)
    let sum_result = a.add(b)
    match sum_result {
        case FieldResult.Ok(sum) => {
            suite.assert_eq(2, sum.value, "Addition: 5 + 10 = 2 (mod 13)")
        }
        case _ => suite.assert_true(false, "Addition failed")
    }
    
    # Test 2: Subtraction
    let diff_result = b.sub(a)
    match diff_result {
        case FieldResult.Ok(diff) => {
            suite.assert_eq(5, diff.value, "Subtraction: 10 - 5 = 5 (mod 13)")
        }
        case _ => suite.assert_true(false, "Subtraction failed")
    }
    
    # Test 3: Multiplication
    let c = FieldElement.new(3, field)
    let d = FieldElement.new(4, field)
    let prod_result = c.mul(d)
    match prod_result {
        case FieldResult.Ok(prod) => {
            suite.assert_eq(12, prod.value, "Multiplication: 3 * 4 = 12 (mod 13)")
        }
        case _ => suite.assert_true(false, "Multiplication failed")
    }
    
    # Test 4: Negation
    let neg = a.neg()
    suite.assert_eq(8, neg.value, "Negation: -5 = 8 (mod 13)")
    
    # Test 5: Exponentiation
    let base = FieldElement.new(2, field)
    let pow_result = base.pow(10)
    match pow_result {
        case FieldResult.Ok(pow_val) => {
            suite.assert_eq(10, pow_val.value, "Exponentiation: 2^10 = 10 (mod 13)")
        }
        case _ => suite.assert_true(false, "Exponentiation failed")
    }
    
    # Test 6: Modular inverse
    let inv_test = FieldElement.new(5, field)
    let inv_result = inv_test.inverse()
    match inv_result {
        case FieldResult.Ok(inv) => {
            # 5 * inv = 1 (mod 13), inv should be 8
            suite.assert_eq(8, inv.value, "Inverse: 5^(-1) = 8 (mod 13)")
        }
        case _ => suite.assert_true(false, "Inverse failed")
    }
    
    # Test 7: Division
    let dividend = FieldElement.new(10, field)
    let divisor = FieldElement.new(2, field)
    let div_result = dividend.div(divisor)
    match div_result {
        case FieldResult.Ok(quot) => {
            suite.assert_eq(5, quot.value, "Division: 10 / 2 = 5 (mod 13)")
        }
        case _ => suite.assert_true(false, "Division failed")
    }
    
    # Test 8: Division by zero
    let zero = FieldElement.zero(field)
    let div_zero = a.div(zero)
    match div_zero {
        case FieldResult.Err(FieldError.DivisionByZero) => {
            suite.assert_true(true, "Division by zero detected")
        }
        case _ => suite.assert_true(false, "Division by zero not detected")
    }
    
    # Test 9: Square operation
    let sq_test = FieldElement.new(5, field)
    let sq_result = sq_test.square()
    match sq_result {
        case FieldResult.Ok(sq) => {
            suite.assert_eq(12, sq.value, "Square: 5^2 = 12 (mod 13)")
        }
        case _ => suite.assert_true(false, "Square failed")
    }
    
    suite.report()
}

# =========================================================================
# TEST SUITE 3: Polynomial Field Arithmetic
# =========================================================================

fn test_polynomial_arithmetic() -> void = {
    let suite = TestSuite.new("Polynomial Field Arithmetic")
    print("\n[TEST SUITE] Polynomial Field Arithmetic")
    print("-" * 70)
    
    let field = FieldConfig.polynomial_field(3, 2, [1, 1, 1])  # x^2 + x + 1 over F_3
    
    # Test 1: Polynomial creation
    let p1 = PolynomialElement.new([1, 2], field)
    suite.assert_eq(2, len(p1.coefficients), "Polynomial coefficient count")
    suite.assert_eq(1, p1.coefficients[0], "Polynomial constant term")
    suite.assert_eq(2, p1.coefficients[1], "Polynomial linear term")
    
    # Test 2: Polynomial addition
    let p2 = PolynomialElement.new([2, 1], field)
    let p_sum = p1.add(p2)
    suite.assert_eq(0, p_sum.coefficients[0], "Poly add: (1+2) mod 3 = 0")
    suite.assert_eq(0, p_sum.coefficients[1], "Poly add: (2+1) mod 3 = 0")
    
    # Test 3: Polynomial multiplication
    let p3 = PolynomialElement.new([1], field)  # Constant 1
    let p4 = PolynomialElement.new([0, 1], field)  # x
    let p_prod = p3.mul(p4)
    suite.assert_eq(0, p_prod.coefficients[0], "Poly mul: constant term")
    
    # Test 4: Zero polynomial
    let p_zero = PolynomialElement.zero(field)
    suite.assert_eq(0, p_zero.coefficients[0], "Zero polynomial")
    
    # Test 5: One polynomial
    let p_one = PolynomialElement.one(field)
    suite.assert_eq(1, p_one.coefficients[0], "One polynomial")
    
    suite.report()
}

# =========================================================================
# TEST SUITE 4: Type System Integration
# =========================================================================

fn test_type_system() -> void = {
    let suite = TestSuite.new("Type System Integration")
    print("\n[TEST SUITE] Type System Integration")
    print("-" * 70)
    
    let field = FieldConfig.prime_field(17)
    
    # Test 1: FieldInt creation
    let x = FieldInt.new(10, field)
    suite.assert_eq(10, x.value(), "FieldInt value")
    
    # Test 2: Operator overloading - addition
    let y = FieldInt.new(15, field)
    let sum = x + y
    suite.assert_eq(8, sum.value(), "FieldInt addition: (10 + 15) mod 17 = 8")
    
    # Test 3: Helper constructor
    let z = field_prime(7, 5)
    suite.assert_eq(5, z.value(), "field_prime constructor")
    
    # Test 4: Field type registry
    suite.assert_true(FIELD_TYPE_REGISTRY.has_type("F7"), "Registry has F7")
    suite.assert_true(FIELD_TYPE_REGISTRY.has_type("Mersenne31"), "Registry has Mersenne31")
    
    # Test 5: Type name generation
    let type_name = generate_type_name(field)
    suite.assert_true(len(type_name) > 0, "Type name generated")
    
    # Test 6: Field compatibility check
    let field_a = FieldConfig.prime_field(5)
    let field_b = FieldConfig.prime_field(5)
    suite.assert_true(!fields_compatible(field_a, field_b), "Different field instances not compatible")
    
    suite.report()
}

# =========================================================================
# TEST SUITE 5: Safety Validation
# =========================================================================

fn test_safety() -> void = {
    let suite = TestSuite.new("Safety Validation")
    print("\n[TEST SUITE] Safety Validation")
    print("-" * 70)
    
    let field = FieldConfig.prime_field(11)
    
    # Test 1: Safe arithmetic
    let safe_a = SafeFieldInt.new(FieldInt.new(7, field), SafetyLevel.Standard)
    let safe_b = SafeFieldInt.new(FieldInt.new(4, field), SafetyLevel.Standard)
    
    let safe_result = safe_a.safe_add(safe_b)
    match safe_result {
        case Ok(result) => {
            suite.assert_eq(0, result.value.value(), "Safe addition: (7 + 4) mod 11 = 0")
        }
        case Err(_) => suite.assert_true(false, "Safe addition should succeed")
    }
    
    # Test 2: Division by zero detection
    let zero_val = SafeFieldInt.new(FieldInt.new(0, field), SafetyLevel.Standard)
    let div_zero_result = safe_a.safe_div(zero_val)
    match div_zero_result {
        case Err(_) => {
            suite.assert_true(true, "Division by zero detected")
        }
        case Ok(_) => suite.assert_true(false, "Division by zero should fail")
    }
    
    # Test 3: Field validation
    let valid_field = FieldConfig.prime_field(13)
    let validation = validate_field_config(valid_field)
    match validation {
        case SafetyResult.Safe => {
            suite.assert_true(true, "Valid field configuration")
        }
        case _ => suite.assert_true(false, "Valid field should pass validation")
    }
    
    # Test 4: Access control
    let acl = FieldAccessControl.new(field.field_id)
    suite.assert_true(acl.has_permission(FieldPermission.Read), "Default read permission")
    suite.assert_true(acl.has_permission(FieldPermission.Compute), "Default compute permission")
    
    acl.grant(FieldPermission.Write)
    suite.assert_true(acl.has_permission(FieldPermission.Write), "Granted write permission")
    
    acl.revoke(FieldPermission.Write)
    suite.assert_true(!acl.has_permission(FieldPermission.Write), "Revoked write permission")
    
    # Test 5: Overflow detection
    suite.assert_true(!will_overflow(100, 200, 1000000), "No overflow for small values")
    
    suite.report()
}

# =========================================================================
# TEST SUITE 6: Encryption Mode
# =========================================================================

fn test_encryption() -> void = {
    let suite = TestSuite.new("Encryption Mode")
    print("\n[TEST SUITE] Encryption Mode")
    print("-" * 70)
    
    # Test 1: Secure field creation
    let secure_config = SecureFieldConfig.new(12345, 64, SecureLevel.High)
    suite.assert_true(secure_config.base_config.is_secure, "Secure field flag set")
    suite.assert_true(secure_config.constant_time_ops, "Constant-time operations enabled")
    
    # Test 2: Encrypted element creation
    let enc_elem = EncryptedFieldElement.new(42, secure_config)
    suite.assert_true(enc_elem.encrypted_value != 42, "Value is encrypted")
    
    # Test 3: Encrypted arithmetic
    let enc_a = EncryptedFieldElement.new(10, secure_config)
    let enc_b = EncryptedFieldElement.new(20, secure_config)
    let enc_sum = enc_a.encrypted_add(enc_b)
    suite.assert_true(true, "Encrypted addition completed")
    
    # Test 4: Blinding factor generation
    let blind1 = generate_blinding_factor()
    let blind2 = generate_blinding_factor()
    suite.assert_true(blind1 != blind2, "Unique blinding factors")
    
    # Test 5: Key derivation
    let key1 = derive_obfuscation_key(111)
    let key2 = derive_obfuscation_key(222)
    suite.assert_true(key1 != key2, "Different seeds produce different keys")
    
    # Test 6: Reconstruction token
    let token = generate_reconstruction_token(999, 128)
    suite.assert_true(len(token) > 0, "Reconstruction token generated")
    
    suite.report()
}

# =========================================================================
# TEST SUITE 7: Compiler Simulation
# =========================================================================

fn test_compiler() -> void = {
    let suite = TestSuite.new("Compiler Simulation")
    print("\n[TEST SUITE] Compiler Simulation")
    print("-" * 70)
    
    # Test 1: Tokenization
    let tokens = tokenize("field<prime=7> int x")
    suite.assert_true(len(tokens) > 0, "Tokenization produces tokens")
    suite.assert_true(tokens[len(tokens)-1].token_type == TokenType.EOF, "EOF token added")
    
    # Test 2: Field annotation parsing
    let location = SourceLocation { file: "test", line: 1, column: 0 }
    let annotation = parse_field_annotation("field<prime=13>", location)
    suite.assert_eq("prime", annotation.annotation_type, "Annotation type parsed")
    
    # Test 3: Type compatibility check
    let anno1 = parse_field_annotation("field<prime=7>", location)
    let anno2 = parse_field_annotation("field<prime=7>", location)
    suite.assert_true(annotations_compatible(anno1, anno2), "Same annotations compatible")
    
    # Test 4: Type checking
    let type_checker = TypeChecker.new()
    suite.assert_eq(0, len(type_checker.errors), "Type checker initialized with no errors")
    
    # Test 5: IR generation
    let ir_gen = IRGenerator.new()
    suite.assert_eq(0, ir_gen.next_register, "IR generator initialized")
    
    let reg = ir_gen.allocate_register()
    suite.assert_eq(0, reg, "First register is 0")
    
    let reg2 = ir_gen.allocate_register()
    suite.assert_eq(1, reg2, "Second register is 1")
    
    suite.report()
}

# =========================================================================
# TEST SUITE 8: Cryptographic Primitives
# =========================================================================

fn test_cryptographic_primitives() -> void = {
    let suite = TestSuite.new("Cryptographic Primitives")
    print("\n[TEST SUITE] Cryptographic Primitives")
    print("-" * 70)
    
    # Test 1: Primality testing
    suite.assert_true(is_prime(7), "7 is prime")
    suite.assert_true(is_prime(13), "13 is prime")
    suite.assert_true(is_prime(104729), "104729 is prime")
    suite.assert_true(!is_prime(4), "4 is not prime")
    suite.assert_true(!is_prime(100), "100 is not prime")
    
    # Test 2: Modular exponentiation
    let powmod_result = power_mod(2, 10, 13)
    suite.assert_eq(10, powmod_result, "2^10 mod 13 = 10")
    
    # Test 3: Extended GCD (modular inverse)
    let inv = extended_gcd(3, 7)
    suite.assert_eq(5, inv, "3^(-1) mod 7 = 5")
    
    # Verify: (3 * 5) mod 7 = 1
    suite.assert_eq(1, (3 * inv) % 7, "Inverse verification")
    
    # Test 4: Constant-time comparison
    suite.assert_true(constant_time_compare(5, 5, 100), "Equal values compare equal")
    suite.assert_true(!constant_time_compare(5, 7, 100), "Different values compare unequal")
    
    # Test 5: Bit length
    suite.assert_eq(3, bit_length(7), "Bit length of 7 is 3")
    suite.assert_eq(8, bit_length(255), "Bit length of 255 is 8")
    
    # Test 6: Hash function consistency
    let hash1 = hash_seed(12345)
    let hash2 = hash_seed(12345)
    suite.assert_eq(hash1, hash2, "Hash function is deterministic")
    
    suite.report()
}

# =========================================================================
# MAIN TEST RUNNER
# =========================================================================

fn run_all_tests() -> void = {
    print("\n")
    print("╔" + "═" * 68 + "╗")
    print("║" + center_text("DFAS COMPREHENSIVE TEST SUITE", 68) + "║")
    print("╚" + "═" * 68 + "╝")
    
    test_field_core()
    test_arithmetic()
    test_polynomial_arithmetic()
    test_type_system()
    test_safety()
    test_encryption()
    test_compiler()
    test_cryptographic_primitives()
    
    print("\n" + "=" * 70)
    print("ALL TEST SUITES COMPLETED")
    print("=" * 70)
}

# =========================================================================
# UTILITIES
# =========================================================================

fn center_text(text: string, width: int) -> string = {
    let padding = (width - len(text)) / 2
    let left_pad = " " * padding
    let right_pad = " " * (width - len(text) - padding)
    left_pad + text + right_pad
}

# Run all tests
run_all_tests()
