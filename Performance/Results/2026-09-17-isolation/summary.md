# Local HTTP performance comparison

Median of repeated runs; ranges are min–max throughput. Latencies are medians of each run's percentiles, not pooled percentiles.

| Route | Framework | req/s | req/s range | p50 ms | p99 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| tiny | vapor | 59,478 | 58,807–65,954 | 0.993 | 2.318 |
| tiny | vapor4 | 73,254 | 71,170–76,237 | 0.805 | 1.908 |
| tiny | hummingbird | 77,161 | 76,946–77,719 | 0.789 | 1.484 |
| tiny | http-server | 60,112 | 59,603–60,679 | 1.027 | 1.930 |
| tiny | vapor-direct | 61,437 | 56,708–64,643 | 0.990 | 2.095 |
| tiny | vapor-no-middleware | 60,108 | 57,214–60,753 | 0.981 | 2.541 |
| large | vapor | 35,531 | 34,204–37,539 | 1.728 | 2.656 |
| large | vapor4 | 44,115 | 43,500–44,769 | 1.397 | 2.301 |
| large | hummingbird | 42,250 | 41,316–42,257 | 1.467 | 2.085 |
| large | http-server | 34,803 | 34,130–34,930 | 1.794 | 2.582 |
| large | vapor-direct | 34,553 | 32,588–37,249 | 1.732 | 2.661 |
| large | vapor-no-middleware | 34,027 | 33,363–34,739 | 1.808 | 2.842 |
