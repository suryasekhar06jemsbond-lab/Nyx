#!/usr/bin/env python3
"""
HTTP Server Benchmark: Nyx Native vs Python
============================================
Compares the native Nyx HTTP server against Python's built-in server
"""

import time
import requests
import subprocess
import threading
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler

class PythonHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<h1>Python HTTP Server</h1>')
        elif self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        pass  # Suppress logging

def run_python_server():
    """Run Python's built-in HTTP server"""
    server = HTTPServer(('localhost', 8081), PythonHandler)
    server.serve_forever()

def benchmark_server(port, name, num_requests=1000):
    """Benchmark HTTP server performance"""
    print(f"\nBenchmarking {name} on port {port}...")
    print(f"Sending {num_requests} requests...")
    
    # Warmup
    try:
        for _ in range(10):
            requests.get(f'http://localhost:{port}/', timeout=2)
    except:
        print(f"❌ Failed to connect to {name}")
        return None
    
    # Benchmark
    start = time.time()
    success = 0
    errors = 0
    
    for i in range(num_requests):
        try:
            resp = requests.get(f'http://localhost:{port}/', timeout=5)
            if resp.status_code == 200:
                success += 1
            else:
                errors += 1
        except Exception as e:
            errors += 1
    
    duration = time.time() - start
    
    print(f"  ✅ Successful: {success}/{num_requests}")
    print(f"  ❌ Errors: {errors}")
    print(f"  ⏱️  Duration: {duration:.3f}s")
    print(f"  🚀 Requests/sec: {success/duration:.2f}")
    print(f"  ⚡ Avg latency: {(duration*1000)/success:.2f}ms")
    
    return success / duration

def main():
    print("""
╔══════════════════════════════════════════════════════════════════════╗
║              HTTP SERVER BENCHMARK: NYX vs PYTHON                    ║
╚══════════════════════════════════════════════════════════════════════╝
    """)
    
    # Start Python server
    print("Starting Python HTTP server on port 8081...")
    python_thread = threading.Thread(target=run_python_server, daemon=True)
    python_thread.start()
    time.sleep(1)
    
    # Start Nyx native server
    print("Starting Nyx native HTTP server on port 8080...")
    nyx_proc = subprocess.Popen(
        ['build/nyx_httpd_test.exe'],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )
    time.sleep(2)
    
    try:
        # Benchmark both
        python_rps = benchmark_server(8081, "Python http.server", 1000)
        nyx_rps = benchmark_server(8080, "Nyx Native HTTPd", 1000)
        
        # Results
        print(f"\n{'='*70}")
        print("📊 FINAL RESULTS")
        print(f"{'='*70}\n")
        
        if python_rps and nyx_rps:
            speedup = nyx_rps / python_rps
            print(f"  Python:  {python_rps:.2f} req/sec")
            print(f"  Nyx:     {nyx_rps:.2f} req/sec")
            print(f"\n  🚀 Nyx is {speedup:.2f}x FASTER!")
            
            if speedup > 10:
                print("\n  ✅ NYX DOMINATES - Over 10x faster!")
            elif speedup > 5:
                print("\n  ✅ NYX WINS - Significantly faster!")
            elif speedup > 1:
                print("\n  ✅ Nyx wins")
            else:
                print("\n  ⚠️ Unexpected results")
        
    finally:
        # Cleanup
        nyx_proc.terminate()

if __name__ == '__main__':
    main()
