import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location("compare", Path(__file__).resolve().parents[1] / "compare.py")
compare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(compare)


class HarnessTests(unittest.TestCase):
    def test_balanced_interleaved_schedule(self):
        frameworks = ["vapor", "vapor4", "hummingbird"]
        rows = list(compare.schedule(frameworks, ["tiny", "json"], 3, True))
        for route in ["tiny", "json"]:
            orders = [[name for number, name, routes in rows if number == repeat and routes == [route]] for repeat in range(3)]
            for position in range(3):
                self.assertEqual({order[position] for order in orders}, set(frameworks))

    def test_cpu_time_formats(self):
        for text, seconds in [("00:01.25", 1.25), ("02:03:04", 7384), ("1-02:03:04.50", 93784.5)]:
            with self.subTest(text=text):
                self.assertEqual(compare.cpu_seconds(text), seconds)

    def test_validate_complete_body_and_status(self):
        response = MagicMock()
        response.status = 204
        response.read.return_value = b""
        response.__enter__.return_value = response
        with patch.object(compare.HTTP, "open", return_value=response):
            self.assertEqual(compare.check_response("http://localhost/bench/status", "status")["body_bytes"], 0)
            response.read.return_value = b"unexpected"
            with self.assertRaises(RuntimeError):
                compare.check_response("http://localhost/bench/status", "status")
            response.read.return_value = b""
            response.status = 200
            with self.assertRaises(RuntimeError):
                compare.check_response("http://localhost/bench/status", "status")

    def test_json_order_is_not_significant(self):
        response = MagicMock()
        response.status = 200
        response.read.return_value = b'{"tags":["a","b","c"],"name":"benchmark","id":1}'
        response.headers.get_content_type.return_value = "application/json"
        response.__enter__.return_value = response
        with patch.object(compare.HTTP, "open", return_value=response):
            compare.check_response("http://localhost/bench/json", "json")
            response.headers.get_content_type.return_value = "text/plain"
            with self.assertRaises(RuntimeError):
                compare.check_response("http://localhost/bench/json", "json")

    def test_upload_validation_posts_and_checks_all_bytes(self):
        response = MagicMock()
        response.status = 200
        response.read.return_value = compare.EXPECTED["upload-stream"]
        response.__enter__.return_value = response
        with patch.object(compare.HTTP, "open", return_value=response) as request:
            compare.check_response("http://localhost/bench/upload-stream", "upload-stream")
            sent = request.call_args.args[0]
            self.assertEqual(sent.get_method(), "POST")
            self.assertEqual(sent.data, b"x" * 65536)
            response.read.return_value = b"y" * 65536
            with self.assertRaises(RuntimeError):
                compare.check_response("http://localhost/bench/upload-stream", "upload-stream")

    def test_direct_mode_rejects_streaming_before_build(self):
        for route in ["stream-chunked", "stream-fine", "upload", "upload-stream"]:
            with self.subTest(route=route):
                result = subprocess.run([sys.executable, str(Path(compare.__file__)), route, "--frameworks", "vapor-direct"],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn("vapor-direct supports", result.stderr)

    def test_invalid_measurements_are_rejected(self):
        metrics = dict(requests=1, duration_us=1, bytes=1, p50_us=1, p99_us=1,
                       connect_errors=0, read_errors=0, write_errors=0, status_errors=0, timeouts=0)
        self.assertEqual(compare.parse_metrics("METRICS " + json.dumps(metrics)), metrics)
        for key in ["connect_errors", "read_errors", "write_errors", "status_errors", "timeouts"]:
            with self.subTest(error=key), self.assertRaises(RuntimeError):
                compare.parse_metrics("METRICS " + json.dumps(dict(metrics, **{key: 1})))
        for key in ["requests", "duration_us"]:
            with self.subTest(empty=key), self.assertRaises(RuntimeError):
                compare.parse_metrics("METRICS " + json.dumps(dict(metrics, **{key: 0})))
        with self.assertRaises(RuntimeError):
            compare.parse_metrics("No metrics produced")

    def test_unsupported_routing_comparison_fails_before_build(self):
        result = subprocess.run([sys.executable, str(Path(compare.__file__)), "routing-parameter/42", "--frameworks", "hummingbird"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("routing diagnostics require", result.stderr)


if __name__ == "__main__":
    unittest.main()
