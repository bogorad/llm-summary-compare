# ADR 005: Blind Anonymization for Evaluation

## Status
Accepted

## Context
The judge model might have inherent biases toward certain providers or model families. To ensure objective evaluation, the judge must not know which summary came from which model.

## Decision
- Shuffle model order randomly using `shuf`
- Assign anonymous IDs (A-H) to shuffled models based on count
- Present only anonymous IDs to judge during comparison
- Reveal model mapping only in final results after winner is determined
- Use `Gemini 3 Pro` via Google Vertex with reasoning enabled for thorough evaluation

## Consequences
- Eliminates potential bias in evaluation
- Results XML separates anonymous summaries from model mapping
- Winner extraction uses structured `WINNER: X` format for reliability
- Reasoning tokens provide transparent evaluation rationale
