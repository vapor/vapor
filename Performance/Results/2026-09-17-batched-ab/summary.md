# Local HTTP performance comparison

Median of repeated runs; ranges are min–max throughput. Latencies are medians of each run's percentiles, not pooled percentiles.

| Route | Framework | req/s | req/s range | p50 ms | p99 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| tiny | vapor | 66,247 | 63,994–68,997 | 0.912 | 1.979 |
| tiny | vapor4 | 73,505 | 69,255–76,779 | 0.782 | 1.885 |
| tiny | hummingbird | 85,764 | 84,664–88,915 | 0.716 | 1.181 |
| tiny | http-server | 63,172 | 60,574–64,006 | 0.999 | 1.528 |
| tiny | http-server-batched | 83,122 | 82,865–86,823 | 0.729 | 1.342 |
| tiny | vapor-batched | 83,914 | 82,711–83,919 | 0.658 | 2.122 |
| large | vapor | 36,232 | 35,402–38,883 | 1.718 | 2.316 |
| large | vapor4 | 47,157 | 46,387–48,431 | 1.308 | 1.788 |
| large | hummingbird | 44,568 | 43,978–46,022 | 1.378 | 1.877 |
| large | http-server | 37,177 | 35,955–37,436 | 1.658 | 2.308 |
| large | http-server-batched | 44,376 | 43,683–45,794 | 1.391 | 2.006 |
| large | vapor-batched | 45,152 | 45,145–45,274 | 1.370 | 2.025 |
| json | vapor | 60,761 | 58,050–65,148 | 0.887 | 2.767 |
| json | vapor4 | 71,121 | 69,586–72,467 | 0.868 | 1.891 |
| json | hummingbird | 82,802 | 74,972–85,493 | 0.712 | 1.403 |
| json | http-server | 65,511 | 63,165–67,297 | 0.935 | 1.538 |
| json | http-server-batched | 86,316 | 86,031–87,260 | 0.697 | 1.349 |
| json | vapor-batched | 78,417 | 77,038–79,397 | 0.691 | 2.732 |
