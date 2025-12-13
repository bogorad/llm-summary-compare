# ADR 006: XML Output Format

## Status
Accepted

## Context
Results need a structured format for storage and potential future analysis. The format should preserve text content including special characters and be both machine-readable and human-readable.

## Decision
Use XML format for `results.xml` with:
- CDATA sections to preserve text content verbatim
- Structure: `<results>` containing `<input>`, `<summaries>`, `<winner>`, `<model_mapping>`
- Model mapping separated from summaries to maintain anonymization integrity

## Consequences
- Easy to parse programmatically
- Preserves formatting in summaries
- Self-documenting hierarchical structure
- Can be transformed to other formats (JSON, HTML) if needed
