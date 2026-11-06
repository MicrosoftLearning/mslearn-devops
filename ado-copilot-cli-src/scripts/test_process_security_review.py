import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from process_security_review import validate_finding


class SecurityReviewTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / "source.cs").write_text("sample source\n", encoding="utf-8")
        self.finding = {
            "rank": 1,
            "severity": "high",
            "confidence": 9,
            "title": "Sample finding",
            "category": "Sample category",
            "cwe": "CWE-22",
            "file": "source.cs",
            "lineStart": 1,
            "lineEnd": 1,
            "evidence": "Sample evidence",
            "impact": "Sample impact",
            "recommendation": "Sample recommendation",
            "validation": "Sample validation",
            "ghasCoverage": "codeql",
        }

    def run_processor(self, mode, findings):
        input_path = self.root / "review.json"
        output_path = self.root / "review.md"
        input_path.write_text(
            json.dumps({
                "schemaVersion": "1.0",
                "executiveSummary": "Sample summary",
                "findings": findings,
                "limitations": [],
            }),
            encoding="utf-8",
        )
        result = subprocess.run(
            [
                sys.executable,
                str(Path(__file__).with_name("process_security_review.py")),
                "--input", str(input_path),
                "--output", str(output_path),
                "--repository-root", str(self.root),
                "--fail-on", "high",
                "--mode", mode,
            ],
            capture_output=True,
            text=True,
            check=False,
        )
        return result, output_path

    def test_integer_confidence_boundaries(self):
        for confidence in (1, 9, 10):
            with self.subTest(confidence=confidence):
                finding = dict(self.finding, confidence=confidence)
                self.assertEqual(
                    validate_finding(finding, 1, self.root)["confidence"],
                    confidence,
                )

    def test_invalid_confidence_is_not_coerced(self):
        for confidence in (0.99, 0.96, 0, 11, 99, 9.0, "9", "9/10", True, False, None):
            with self.subTest(confidence=confidence):
                with self.assertRaisesRegex(ValueError, "JSON integer from 1 through 10"):
                    validate_finding(dict(self.finding, confidence=confidence), 1, self.root)

    def test_high_findings_succeed_in_advisory_mode(self):
        result, output = self.run_processor("advisory", [self.finding])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("copilotGateTriggered]true", result.stdout)
        self.assertIn("security findings do not fail the pipeline", result.stdout)
        self.assertIn("9/10", output.read_text(encoding="utf-8"))
        self.assertIn("Advisory mode", output.read_text(encoding="utf-8"))

    def test_enforce_mode_leaves_failure_to_separate_gate(self):
        result, output = self.run_processor("enforce", [self.finding])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(output.is_file())
        self.assertIn("copilotGateTriggered]true", result.stdout)
        self.assertIn("separate security gate will fail", result.stdout)

    def test_below_threshold_findings_do_not_trigger_gate(self):
        for mode in ("advisory", "enforce"):
            with self.subTest(mode=mode):
                result, _ = self.run_processor(mode, [dict(self.finding, severity="low")])
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("copilotGateTriggered]false", result.stdout)

    def test_no_findings_succeed(self):
        result, output = self.run_processor("advisory", [])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("copilotGateTriggered]false", result.stdout)
        self.assertIn("No evidence-backed findings", output.read_text(encoding="utf-8"))

    def test_probability_output_is_processing_failure_not_gate(self):
        for mode in ("advisory", "enforce"):
            with self.subTest(mode=mode):
                result, output = self.run_processor(
                    mode, [dict(self.finding, confidence=0.99)],
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn("received 0.99", result.stderr)
                self.assertIn("report-processing failure", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertNotIn("copilotGateTriggered]", result.stdout)
                self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
