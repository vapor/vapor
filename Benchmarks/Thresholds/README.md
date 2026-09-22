# Runner thresholds

Manually dispatch the benchmark workflow with `record_thresholds` enabled to
export the `benchmark-thresholds` artifact from the benchmark runner. Review and
commit its generated files here, retaining the directory layout:

- `instructions/`
- `allocations/`
- `cpu/`
- `wall-clock/`

Normal runs fail until thresholds have been committed. Every measured fixture in
every mode must have matching metrics; partial sets fail the comparison. Recording
is always explicit and reports that no performance comparison was performed.
Never substitute local or smoke measurements.

See [the benchmark README](../README.md#recording-the-first-thresholds) for the
recording and update process.
