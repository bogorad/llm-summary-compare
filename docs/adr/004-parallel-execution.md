# ADR 004: Parallel Model Execution

## Status
Accepted

## Context
Running three AI models sequentially would take 3x the time of a single model. Since models are independent and API calls are I/O bound, concurrent execution improves performance.

## Decision
Execute summarization requests in parallel using bash job control (`&` and `wait`). Track PIDs to detect failures in any parallel job.

## Consequences
- Total execution time reduced to ~1x the slowest model
- Requires bash with job control support
- Error handling captures failures from any parallel process
