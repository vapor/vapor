# Incomplete attempt

This attempt stopped during the first pass, after the `tiny` and `small` measurements.
`wrk` reported **one timeout** during the `large` route's three-second warm-up against
current Vapor. The driver stopped the server and aborted rather than include the failed
warm-up in a complete comparison. The warm-up completed 99,540 requests; its other error
counters were zero. See `1-vapor-large-warmup.txt` for the complete output.

These two measured samples are **not** a complete three-framework baseline and are excluded
from the reported comparison. The subsequent attempt is in `../2026-09-16-macos-c64-repeat/`.

Background activity was present on this laptop, including Time Machine. The timeout's
cause was not established.
