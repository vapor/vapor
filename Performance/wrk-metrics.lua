-- Only aggregate after the run: no per-response Lua overhead.
-- Prepare POST bodies once per wrk thread, retaining wrk's static request fast path.
init = function(args)
    if args[1] then
        local file = assert(io.open(args[1], "rb"))
        wrk.method = "POST"
        wrk.body = file:read("*all")
        file:close()
        wrk.headers["Content-Type"] = "application/octet-stream"
    end
end

done = function(summary, latency, requests)
    io.write(string.format(
        '\nMETRICS {"requests":%d,"duration_us":%d,"bytes":%d,"p50_us":%d,"p99_us":%d,"connect_errors":%d,"read_errors":%d,"write_errors":%d,"status_errors":%d,"timeouts":%d}\n',
        summary.requests, summary.duration, summary.bytes,
        latency:percentile(50), latency:percentile(99),
        summary.errors.connect, summary.errors.read, summary.errors.write,
        summary.errors.status, summary.errors.timeout
    ))
end
