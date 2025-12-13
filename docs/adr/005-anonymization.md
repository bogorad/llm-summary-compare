# ADR 005: Blind Anonymization for Evaluation

## Status
Accepted

## Context
The judge model (Gemini 3 Pro) might have inherent biases toward certain providers or model families. To ensure objective evaluation, the judge must not know which summary came from which model.

## Decision
- Shuffle model order randomly using `shuf`
- Assign anonymous IDs (A, B, C) to shuffled models
- Present only anonymous IDs to judge during comparison
- Reveal model mapping only in final results after winner is determined

## Consequences
- Eliminates potential bias in evaluation
- Results XML separates anonymous summaries from model mapping
- Winner extraction uses structured `WINNER: X` format for reliability
