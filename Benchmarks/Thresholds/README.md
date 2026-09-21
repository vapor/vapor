# Runner thresholds

The first shared-workflow run exports the `benchmark-thresholds` artifact for
review. Commit its generated files here, retaining the directory layout:

- `instructions/`
- `allocations/`
- `cpu/`
- `wall-clock/`

Until values have been committed, runs record thresholds and explicitly report
that no performance comparison was performed. Never substitute local or smoke
measurements. Once any thresholds exist, every measured fixture in every mode
must have a matching metric; partial sets fail the comparison.

See [the benchmark README](../README.md#recording-the-first-thresholds) for the
recording and update process.
