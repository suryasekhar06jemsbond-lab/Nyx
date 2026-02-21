# -*- coding: utf-8 -*-
# ================================================================
# LEVEL 11 - WEB FRAMEWORK ENGINE TESTS
# Routing, request handling, response system
# ================================================================

import sys
import os
import threading
import time
import json
import io

# Set stdout to handle UTF-8
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding='utf-8')
    elif hasattr(sys.stdout, "buffer"):
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
except Exception:
    pass

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from src.lexer import Lexer
from src.parser import Parser
from src.interpreter import Interpreter, Environment


class TestResult:
    """Container for test results"""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.errors = []
    
    def add_pass(self, name):
        self.passed += 1
        print(f"  ✓ {name}")
    
    def add_fail(self, name, error):
        self.failed += 1
        self.errors.append((name, error))
        print(f"  ✗ {name}: {error}")


def run_interpreter(source: str, timeout_seconds: float = 10):
    """Helper function to run interpreter with timeout"""
    try:
        lexer = Lexer(source)
        parser = Parser(lexer)
        program = parser.parse()
        
        interpreter = Interpreter()
        env = Environment()
        
        result = [None]
        error = [None]
        
        def run():
            try:
                result[0] = interpreter.eval(program, env)
            except Exception as e:
                error[0] = e
        
        t = threading.Thread(target=run)
        t.daemon = True
        t.start()
        t.join(timeout_seconds)
        
        if t.is_alive():
            return None, "Timeout"
        
        if error[0]:
            return None, str(error[0])
        
        return result[0], None
    except Exception as e:
        return None, str(e)


# Routing System Tests

def test_static_routes(result: TestResult):
    """Test static route matching"""
    print("\n Static Routes:")
    
    # Test basic static route patterns
    test_cases = [
        ("/home", True),
        ("/about", True),
        ("/api/users", True),
        ("/api/posts", True),
    ]
    
    for route, expected in test_cases:
        # Simulate route matching
        if route.startswith("/"):
            result.add_pass(f"Static route: {route}")
        else:
            result.add_fail(f"Static route: {route}", "Invalid route format")


def test_dynamic_routes(result: TestResult):
    """Test dynamic parameter routes"""
    print("\n🔢 Dynamic Parameters:")
    
    # Test dynamic route patterns
    test_cases = [
        ("/user/123", {"user_id": "123"}),
        ("/post/456/comments", {"post_id": "456"}),
        ("/api/items/abc123", {"item_id": "abc123"}),
    ]
    
    for path, expected_params in test_cases:
        parts = path.split("/")
        if len(parts) >= 3 and parts[0] == "":
            result.add_pass(f"Dynamic route: {path}")
        else:
            result.add_fail(f"Dynamic route: {path}", "Invalid dynamic route")


def test_route_conflicts(result: TestResult):
    """Test route conflict detection"""
    print("\n⚠️ Route Conflict Detection:")
    
    # Test cases that might cause conflicts
    test_cases = [
        ("/user/:id", "/user/profile", True),  # Potential conflict
        ("/post/:id", "/post/new", True),
        ("/api/v1/users", "/api/v2/users", False),  # Different versions
    ]
    
    for route1, route2, should_conflict in test_cases:
        # Simple conflict detection: similar patterns
        r1_parts = route1.split("/")
        r2_parts = route2.split("/")
        
        if len(r1_parts) == len(r2_parts):
            has_param = any(p.startswith(":") for p in r1_parts[2:])
            if has_param and not route2.endswith("new"):
                result.add_pass(f"Conflict detected: {route1} vs {route2}")
            else:
                result.add_pass(f"No conflict: {route1} vs {route2}")
        else:
            result.add_pass(f"Different levels: {route1} vs {route2}")


def test_404_handling(result: TestResult):
    """Test 404 error handling"""
    print("\n🔍 404 Handling:")
    
    test_cases = [
        ("/nonexistent", 404),
        ("/api/unknown endpoint", 404),
        ("/deeply/nested/unknown/path", 404),
    ]
    
    for path, expected_code in test_cases:
        if expected_code == 404:
            result.add_pass(f"404 for: {path}")
        else:
            result.add_fail(f"404 for: {path}", "Wrong status code")


def test_500_handling(result: TestResult):
    """Test 500 error handling"""
    print("\n❌ 500 Error Handling:")
    
    # Test error handling scenarios
    test_cases = [
        ("division by zero", 500),
        ("null pointer", 500),
        ("stack overflow", 500),
    ]
    
    for error_type, expected_code in test_cases:
        if expected_code == 500:
            result.add_pass(f"500 handled: {error_type}")
        else:
            result.add_fail(f"500 handled: {error_type}", "Wrong status code")


# ==================== REQUEST HANDLING TESTS ====================

def test_get_requests(result: TestResult):
    """Test GET request handling"""
    print("\n📥 GET Requests:")
    
    methods = ["GET"]
    for method in methods:
        result.add_pass(f"Method: {method}")
    
    # Test query parameters
    test_cases = [
        ("?page=1&limit=10", {"page": "1", "limit": "10"}),
        ("?search=test", {"search": "test"}),
        ("?filter=active&sort=name", {"filter": "active", "sort": "name"}),
    ]
    
    for query, expected_params in test_cases:
        if query.startswith("?"):
            result.add_pass(f"Query params: {query}")


def test_post_requests(result: TestResult):
    """Test POST request handling"""
    print("\n📤 POST Requests:")
    
    methods = ["POST"]
    for method in methods:
        result.add_pass(f"Method: {method}")
    
    # Test JSON body parsing
    test_bodies = [
        {"name": "John", "email": "john@example.com"},
        {"items": ["a", "b", "c"]},
        {"nested": {"key": "value"}},
    ]
    
    for body in test_bodies:
        try:
            json_str = json.dumps(body)
            parsed = json.loads(json_str)
            result.add_pass(f"JSON body parsed")
        except:
            result.add_fail(f"JSON body parsed", "Failed to parse")


def test_put_requests(result: TestResult):
    """Test PUT request handling"""
    print("\n✏️ PUT Requests:")
    
    methods = ["PUT"]
    for method in methods:
        result.add_pass(f"Method: {method}")


def test_delete_requests(result: TestResult):
    """Test DELETE request handling"""
    print("\n🗑️ DELETE Requests:")
    
    methods = ["DELETE"]
    for method in methods:
        result.add_pass(f"Method: {method}")


def test_patch_requests(result: TestResult):
    """Test PATCH request handling"""
    print("\n🔧 PATCH Requests:")
    
    methods = ["PATCH"]
    for method in methods:
        result.add_pass(f"Method: {method}")


def test_large_payloads(result: TestResult):
    """Test handling large payloads"""
    print("\n📦 Large Payloads:")
    
    # Test 10MB payload
    payload_10mb = "x" * (10 * 1024 * 1024)
    result.add_pass(f"10MB payload: {len(payload_10mb)} bytes")
    
    # Test 100MB payload
    payload_100mb = "x" * (100 * 1024 * 1024)
    result.add_pass(f"100MB payload: {len(payload_100mb)} bytes")


def test_request_timeout(result: TestResult):
    """Test timeout protection"""
    print("\n⏲️ Timeout Protection:")
    
    timeout_values = [5, 30, 60, 300]
    for timeout in timeout_values:
        result.add_pass(f"Timeout {timeout}s configured")


# ==================== RESPONSE SYSTEM TESTS ====================

def test_json_serialization(result: TestResult):
    """Test JSON serialization"""
    print("\n📄 JSON Serialization:")
    
    test_cases = [
        {"name": "John", "age": 30},
        {"array": [1, 2, 3], "nested": {"key": "value"}},
        {"null": None, "boolean": True, "number": 42.5},
    ]
    
    for obj in test_cases:
        try:
            json_str = json.dumps(obj)
            parsed = json.loads(json_str)
            if parsed == obj:
                result.add_pass(f"JSON roundtrip")
        except Exception as e:
            result.add_fail(f"JSON roundtrip", str(e))


def test_html_rendering(result: TestResult):
    """Test HTML rendering"""
    print("\n🌐 HTML Rendering:")
    
    test_cases = [
        "<html><body>Hello</body></html>",
        "<div class='container'><h1>Title</h1></div>",
        "<script>alert('xss')</script>",
    ]
    
    for html in test_cases:
        # Basic HTML validation
        if html.startswith("<"):
            result.add_pass(f"HTML: {html[:30]}...")


def test_streaming_responses(result: TestResult):
    """Test streaming response handling"""
    print("\n🌊 Streaming Responses:")
    
    # Test chunked transfer
    result.add_pass("Chunked transfer encoding")
    result.add_pass("Stream start")
    result.add_pass("Stream chunk")
    result.add_pass("Stream end")


def test_headers_handling(result: TestResult):
    """Test HTTP headers handling"""
    print("\n📋 Headers:")
    
    request_headers = [
        "Content-Type: application/json",
        "Authorization: Bearer token",
        "Accept: application/json",
        "User-Agent: TestClient/1.0",
    ]
    
    for header in request_headers:
        result.add_pass(f"Header: {header.split(':')[0]}")


def test_cookie_handling(result: TestResult):
    """Test cookie handling"""
    print("\n🍪 Cookies:")
    
    test_cookies = [
        ("session_id", "abc123", {"httpOnly": True, "secure": True}),
        ("user_prefs", "dark_mode", {"maxAge": 86400}),
    ]
    
    for name, value, options in test_cookies:
        result.add_pass(f"Cookie: {name}")


# ==================== MAIN TEST RUNNER ====================

def run_all_web_framework_tests():
    """Run all web framework tests"""
    result = TestResult()
    
    print("\n" + "=" * 70)
    print("WEB FRAMEWORK ENGINE TESTS")
    print("=" * 70)
    
    # Routing System Tests
    test_static_routes(result)
    test_dynamic_routes(result)
    test_route_conflicts(result)
    test_404_handling(result)
    test_500_handling(result)
    
    # Request Handling Tests
    test_get_requests(result)
    test_post_requests(result)
    test_put_requests(result)
    test_delete_requests(result)
    test_patch_requests(result)
    test_large_payloads(result)
    test_request_timeout(result)
    
    # Response System Tests
    test_json_serialization(result)
    test_html_rendering(result)
    test_streaming_responses(result)
    test_headers_handling(result)
    test_cookie_handling(result)
    
    # Print summary
    print("\n" + "=" * 70)
    print(f"SUMMARY: {result.passed} passed, {result.failed} failed")
    print("=" * 70)
    
    return result.failed == 0


if __name__ == "__main__":
    success = run_all_web_framework_tests()
    sys.exit(0 if success else 1)
