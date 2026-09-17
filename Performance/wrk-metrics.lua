-- Only aggregate after the run: no per-response Lua overhead.
done = function(summary, latency, requests)
    io.write(string.format(
        '\nMETRICS {"requests":%d,"duration_us":%d,"bytes":%d,"p50_us":%d,"p99_us":%d,"connect_errors":%d,"read_errors":%d,"write_errors":%d,"status_errors":%d,"timeouts":%d}\n',
        summary.requests, summary.duration, summary.bytes,
        latency:percentile(50), latency:percentile(99),
        summary.errors.connect, summary.errors.read, summary.errors.write,
        summary.errors.status, summary.errors.timeout
    ))
end
