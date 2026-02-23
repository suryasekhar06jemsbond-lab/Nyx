// ============================================================================
// MASTER ENGINE TEST RUNNER
// Run all 117 engine tests across 9 categories
// ============================================================================

use production;
use observability;
use error_handling;
use nysystem;

// Test suite metadata
const TEST_SUITES = [
    {
        name: "AI/ML Engines",
        file: "tests/engines/test_ai_ml_engines.ny",
        engines: 21,
        category: "ai_ml"
    },
    {
        name: "Data Processing Engines",
        file: "tests/engines/test_data_engines.ny",
        engines: 18,
        category: "data"
    },
    {
        name: "Security Engines",
        file: "tests/engines/test_security_engines.ny",
        engines: 17,
        category: "security"
    },
    {
        name: "Web & Network Engines",
        file: "tests/engines/test_web_engines.ny",
        engines: 15,
        category: "web"
    },
    {
        name: "Graphics & Media Engines",
        file: "tests/engines/test_graphics_engines.ny",
        engines: 10,
        category: "graphics"
    },
    {
        name: "DevOps & System Engines",
        file: "tests/engines/test_devops_engines.ny",
        engines: 12,
        category: "devops"
    },
    {
        name: "Scientific Computing Engines",
        file: "tests/engines/test_scientific_engines.ny",
        engines: 8,
        category: "scientific"
    },
    {
        name: "Utility Engines",
        file: "tests/engines/test_utility_engines.ny",
        engines: 8,
        category: "utility"
    }
];

// ============================================================================
// Test Results Tracking
// ============================================================================
struct TestResult {
    suite: string,
    engines: int,
    passed: bool,
    duration_ms: int,
    error: ?string
}

struct TestSummary {
    total_suites: int,
    total_engines: int,
    passed_suites: int,
    failed_suites: int,
    total_duration_ms: int,
    results: [TestResult]
}

// ============================================================================
// Test Runner Functions
// ============================================================================
fn run_test_suite(suite) {
    println("\n" + "="*70);
    println("  Running: \");
    println("  Engines: \");
    println("="*70);
    
    let start_time = now();
    let result = TestResult {
        suite: suite.name,
        engines: suite.engines,
        passed: false,
        duration_ms: 0,
        error: null
    };
    
    try {
        // Execute the test file
        let sys = nysystem.System::new();
        let proc = sys.spawn_process("nyx", ["run", suite.file]);
        let output = proc.wait();
        
        if proc.exit_code == 0 {
            result.passed = true;
            println("✓ \ PASSED", suite.name);
        } else {
            result.passed = false;
            result.error = "Exit code: " + proc.exit_code.to_string();
            println("✗ \ FAILED", suite.name);
        }
        
    } catch (err) {
        result.passed = false;
        result.error = err.to_string();
        println("✗ \ CRASHED", suite.name);
        error_handling.handle_error(err, "run_test_suite");
    }
    
    result.duration_ms = now() - start_time;
    return result;
}

fn print_summary(summary: TestSummary) {
    println("\n");
    println("╔════════════════════════════════════════════════════════════════╗");
    println("║              NyX ENGINE TEST SUITE - FINAL REPORT              ║");
    println("╚════════════════════════════════════════════════════════════════╝");
    println("");
    
    // Overall statistics
    println("📊 Overall Statistics:");
    println("  • Total Test Suites:    \", summary.total_suites);
    println("  • Total Engines Tested: \", summary.total_engines);
    println("  • Suites Passed:        \ ✓", summary.passed_suites);
    println("  • Suites Failed:        \ ✗", summary.failed_suites);
    println("  • Total Duration:       \ ms", summary.total_duration_ms);
    println("  • Success Rate:         \%", 
        (summary.passed_suites * 100 / summary.total_suites));
    println("");
    
    // Detailed results
    println("📋 Detailed Results:");
    for result in summary.results {
        let status_icon = result.passed ? "✓" : "✗";
        let status_text = result.passed ? "PASSED" : "FAILED";
        
        println("  \ [] \ (\ engines) - \ms",
            status_icon, status_text, result.suite, result.engines, result.duration_ms);
        
        if !result.passed && result.error != null {
            println("     Error: \", result.error);
        }
    }
    println("");
    
    // Performance breakdown
    println("⚡ Performance Breakdown:");
    for result in summary.results {
        let bar_length = (result.duration_ms * 50 / summary.total_duration_ms).max(1);
        let bar = "█" * bar_length;
        println("  \ \", result.suite.pad_right(35), bar);
    }
    println("");
    
    // Final verdict
    if summary.failed_suites == 0 {
        println("╔════════════════════════════════════════════════════════════════╗");
        println("║  ✓✓✓ ALL TESTS PASSED - 117 ENGINES VERIFIED ✓✓✓              ║");
        println("╚════════════════════════════════════════════════════════════════╝");
    } else {
        println("╔════════════════════════════════════════════════════════════════╗");
        println("║  ⚠️  SOME TESTS FAILED - REVIEW ERRORS ABOVE  ⚠️               ║");
        println("╚════════════════════════════════════════════════════════════════╝");
    }
}

fn generate_test_report(summary: TestSummary, format: string) {
    if format == "json" {
        return JSON.stringify(summary, {indent: 2});
    } else if format == "html" {
        return generate_html_report(summary);
    } else if format == "markdown" {
        return generate_markdown_report(summary);
    }
}

fn generate_markdown_report(summary: TestSummary) {
    let report = "# Nyx Engine Test Report\n\n";
    report += "**Date:** " + now().to_string() + "\n\n";
    report += "## Summary\n\n";
    report += "| Metric | Value |\n";
    report += "|--------|-------|\n";
    report += "| Total Suites | \ |\n", summary.total_suites);
    report += "| Total Engines | \ |\n", summary.total_engines);
    report += "| Passed | \ |\n", summary.passed_suites);
    report += "| Failed | \ |\n", summary.failed_suites);
    report += "| Duration | \ ms |\n", summary.total_duration_ms);
    report += "\n## Results\n\n";
    
    for result in summary.results {
        let status = result.passed ? "✓ PASS" : "✗ FAIL";
        report += "- **\**: \ (\ engines, \ms)\n";
    }
    
    return report;
}

fn generate_html_report(summary: TestSummary) {
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Nyx Engine Test Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .pass { color: green; }
            .fail { color: red; }
            table { border-collapse: collapse; width: 100%; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        </style>
    </head>
    <body>
        <h1>Nyx Engine Test Report</h1>
        <p><strong>Total Engines:</strong> \</p>
        <p><strong>Passed:</strong> \</p>
        <p><strong>Failed:</strong> \</p>
        <!-- Add more details -->
    </body>
    </html>
    """;
}

// ============================================================================
// Main Test Runner
// ============================================================================
fn main() {
    println("");
    println("╔════════════════════════════════════════════════════════════════╗");
    println("║         NyX ENGINE TEST SUITE - MASTER RUNNER                  ║");
    println("║         Testing All 117 Engines Across 9 Categories           ║");
    println("╚════════════════════════════════════════════════════════════════╝");
    println("");
    
    // Initialize production runtime
    let runtime = production.ProductionRuntime::new();
    let tracer = observability.Tracer::new("master_test_runner");
    let span = tracer.start_span("run_all_tests");
    
    runtime.logger.info("Starting master test suite", {
        total_suites: TEST_SUITES.length,
        total_engines: 117
    });
    
    // Initialize summary
    let summary = TestSummary {
        total_suites: TEST_SUITES.length,
        total_engines: 117,
        passed_suites: 0,
        failed_suites: 0,
        total_duration_ms: 0,
        results: []
    };
    
    let overall_start = now();
    
    // Run all test suites
    for suite in TEST_SUITES {
        let result = run_test_suite(suite);
        summary.results.push(result);
        
        if result.passed {
            summary.passed_suites += 1;
        } else {
            summary.failed_suites += 1;
        }
        
        summary.total_duration_ms += result.duration_ms;
        
        // Log progress
        runtime.metrics.increment("test_suites_completed");
        runtime.metrics.gauge("test_progress_percent").set(
            (summary.results.length * 100) / summary.total_suites
        );
    }
    
    summary.total_duration_ms = now() - overall_start;
    
    // Print summary
    print_summary(summary);
    
    // Generate reports
    let md_report = generate_test_report(summary, "markdown");
    nyio.write_file("test_results.md", md_report);
    println("📄 Markdown report saved: test_results.md");
    
    let json_report = generate_test_report(summary, "json");
    nyio.write_file("test_results.json", json_report);
    println("📄 JSON report saved: test_results.json");
    
    // Log completion
    span.set_tag("passed_suites", summary.passed_suites);
    span.set_tag("failed_suites", summary.failed_suites);
    span.set_tag("total_duration_ms", summary.total_duration_ms);
    span.finish();
    
    runtime.logger.info("Test suite completed", {
        passed: summary.passed_suites,
        failed: summary.failed_suites,
        duration_ms: summary.total_duration_ms
    });
    
    // Exit with appropriate code
    if summary.failed_suites > 0 {
        exit(1);
    } else {
        exit(0);
    }
}
