# Local HTTP performance comparison

Median of repeated runs; ranges are min–max throughput. Latencies are medians of each run's percentiles, not pooled percentiles.

| Route | Framework | req/s | req/s range | p50 ms | p99 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| stream | vapor | 14,744 | 14,728–14,759 | 4.300 | 5.319 |
| stream | vapor-batched | 14,620 | 14,537–14,713 | 4.339 | 5.348 |
| file | vapor | 4,375 | 4,368–4,413 | 14.439 | 23.029 |
| file | vapor-batched | 4,356 | 4,343–4,371 | 14.500 | 20.485 |
