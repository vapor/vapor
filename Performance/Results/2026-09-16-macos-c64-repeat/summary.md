# Local HTTP performance comparison

Median of repeated runs; ranges are min–max throughput. Latencies are medians of each run's percentiles, not pooled percentiles.

| Route | Framework | req/s | req/s range | p50 ms | p99 ms |
| --- | --- | ---: | ---: | ---: | ---: |
| tiny | vapor | 58,853 | 58,281–63,024 | 0.954 | 4.256 |
| tiny | vapor4 | 74,991 | 66,611–75,549 | 0.797 | 2.551 |
| tiny | hummingbird | 84,498 | 84,383–85,834 | 0.721 | 1.105 |
| small | vapor | 61,484 | 55,619–62,930 | 0.962 | 3.933 |
| small | vapor4 | 73,098 | 61,223–75,275 | 0.797 | 2.186 |
| small | hummingbird | 83,304 | 76,463–83,683 | 0.748 | 1.165 |
| large | vapor | 35,986 | 35,740–36,915 | 1.716 | 2.799 |
| large | vapor4 | 45,892 | 45,757–47,858 | 1.347 | 2.312 |
| large | hummingbird | 41,493 | 33,483–45,752 | 1.399 | 9.827 |
| json | vapor | 61,899 | 59,898–61,910 | 0.946 | 2.843 |
| json | vapor4 | 69,193 | 65,854–70,582 | 0.868 | 1.947 |
| json | hummingbird | 84,126 | 83,242–84,426 | 0.732 | 1.559 |
| stream | vapor | 13,717 | 13,601–14,019 | 4.510 | 6.763 |
| stream | vapor4 | 10,215 | 10,207–10,493 | 6.133 | 8.535 |
| stream | hummingbird | 14,042 | 13,998–14,317 | 4.516 | 5.763 |
| file | vapor | 4,243 | 4,140–4,343 | 14.710 | 20.866 |
| file | vapor4 | 2,787 | 2,624–2,793 | 22.713 | 42.321 |
| file | hummingbird | 4,256 | 4,180–4,391 | 14.875 | 25.406 |
