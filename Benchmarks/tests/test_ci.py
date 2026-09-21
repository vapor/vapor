import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("benchmark_ci", Path(__file__).parents[1] / "ci.py")
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class BenchmarkCITests(unittest.TestCase):
    def test_builds_are_isolated_and_only_allocations_enable_trait(self):
        for mode in ci.METRICS:
            command = ci.command(mode, "baseline", "update", "test")
            scratch = command[command.index("--scratch-path") + 1]
            if mode == "allocations":
                self.assertTrue(scratch.endswith("/allocations"))
                self.assertEqual(command[command.index("--traits") + 1], "AllocationCounting")
            else:
                self.assertTrue(scratch.endswith("/uninstrumented"))
                self.assertNotIn("--traits", command)

    def test_baseline_titles_cannot_create_paths_or_collide_after_sanitizing(self):
        one = ci.baseline_name("../feature/stream", "cpu")
        two = ci.baseline_name("../feature stream", "cpu")
        self.assertNotIn("/", one)
        self.assertNotEqual(one, two)
        self.assertNotEqual(one, ci.baseline_name("../feature/stream", "instructions"))

    def test_filter_only_selects_what_is_recorded(self):
        for category, operation in [("baseline", "update"), ("baseline", "read"),
                                    ("thresholds", "update"), ("thresholds", "check")]:
            command = ci.command("instructions", category, operation, "test", benchmark_filter="^trie/static$")
            self.assertEqual("--filter" in command, (category, operation) == ("baseline", "update"))

    def test_measurement_environment_is_explicit(self):
        with patch.object(ci.subprocess, "run") as run:
            ci.run("cpu", "baseline", "update", "example")
        environment = run.call_args.kwargs["env"]
        self.assertEqual(environment["BENCHMARK_MODE"], "cpu")
        self.assertEqual(environment["NIO_SINGLETON_GROUP_LOOP_COUNT"], "2")
        self.assertEqual(environment["NIO_SINGLETON_BLOCKING_POOL_THREAD_COUNT"], "2")

    def test_comparison_exit_codes_preserve_mixed_deviations_and_errors(self):
        for codes, expected in [([0, 0], 0), ([0, 2], 2), ([4, 0], 4),
                                ([2, 4], 1), ([1, 0], 1), ([2, 30, 4], 30)]:
            with self.subTest(codes=codes):
                self.assertEqual(ci.comparison_status(codes), expected)

    def test_threshold_export_round_trips_spaces_and_slashes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            package = root / "Benchmarks"
            baseline = package / ".benchmarkBaselines" / "VaporBenchmarks" / "example"
            baseline.mkdir(parents=True)
            (baseline / "results.json").write_text(json.dumps({"results": [
                {"target": "VaporBenchmarks", "name": "middleware/sessions update (measurement: instructions)"}, []
            ]}))
            destination = root / "Thresholds"

            def run(mode, category, operation, name, *arguments, **kwargs):
                path = Path(arguments[arguments.index("--path") + 1])
                if operation == "update":
                    (path / "VaporBenchmarks.middleware_sessions_update_(measurement:_instructions).p90.json").write_text(
                        '{"instructions": 1000}')
                    return 0
                self.assertTrue((path / "VaporBenchmarks.middleware/sessions update (measurement: instructions).p90.json").is_file())
                return 4

            with patch.object(ci, "PACKAGE", package), patch.object(ci, "run", side_effect=run):
                self.assertEqual(ci.thresholds("instructions", "update", "example", destination, None), 0)
                self.assertEqual(ci.thresholds("instructions", "check", "example", destination, None), 4)
                path = destination / "instructions/VaporBenchmarks.middleware_sessions_update_(measurement__instructions).p90.json"
                self.assertTrue(path.is_file())
                path.unlink()
                with self.assertRaises(FileNotFoundError):
                    ci.thresholds("instructions", "check", "example", destination, None)

    def test_missing_or_wrong_metrics_and_zero_instructions_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "threshold.json"
            for value in [{}, {"instructions": 0}, {"instructions": -1},
                          {"instructions": True}, {"mallocCountTotal": 10},
                          {"instructions": 100, "wallClock": 200}]:
                with self.subTest(value=value):
                    path.write_text(json.dumps(value))
                    with self.assertRaises(ValueError):
                        ci.validate_threshold(path, "instructions")
            path.write_text('{"mallocCountTotal": 0}')
            ci.validate_threshold(path, "allocations")

    def test_threshold_filenames_can_be_uploaded_as_github_artifacts(self):
        name = ci.threshold_filename('VaporBenchmarks.request/?key="value" (measurement: instructions).p90.json')
        self.assertTrue(name.endswith(".p90.json"))
        self.assertFalse(set(name) & set('/\\:*?"<>|\r\n '))

    def test_threshold_filename_collisions_are_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            package = Path(temporary)
            baseline = package / ".benchmarkBaselines" / "VaporBenchmarks" / "example"
            baseline.mkdir(parents=True)
            (baseline / "results.json").write_text(json.dumps({"results": [
                {"target": "VaporBenchmarks", "name": "one/two"}, [],
                {"target": "VaporBenchmarks", "name": "one two"}, [],
            ]}))
            with patch.object(ci, "PACKAGE", package), self.assertRaises(ValueError):
                ci.threshold_names("example")

    def test_growth_from_zero_is_a_regression_even_if_plugin_accepts_it(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary)
            name = "VaporBenchmarks.trie/static (measurement: allocations).p90.json"
            exported = name.replace("/", "_").replace(" ", "_")
            reference = destination / "allocations" / ci.threshold_filename(name)
            reference.parent.mkdir()
            reference.write_text('{"mallocCountTotal": 0}')

            def run(mode, category, operation, baseline, *arguments, **kwargs):
                if operation == "update":
                    path = Path(arguments[arguments.index("--path") + 1])
                    (path / exported).write_text('{"mallocCountTotal": 1000}')
                return 0

            with patch.object(ci, "threshold_names", return_value={name: exported}), \
                    patch.object(ci, "run", side_effect=run), patch("sys.stdout"):
                status = ci.thresholds("allocations", "check", "example", destination, None)
            self.assertEqual(status, 2)

    def test_smoke_results_cannot_be_recorded(self):
        with patch.dict(ci.os.environ, {"BENCHMARK_SMOKE": "1"}), \
                patch.object(ci.sys, "argv", ["ci.py", "baseline", "update", "test"]), \
                patch("sys.stderr"), self.assertRaises(SystemExit) as result:
            ci.main()
        self.assertEqual(result.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
