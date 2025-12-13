# ADR 006: Dual Output Format (XML + Markdown)

## Status
Accepted

## Context
Results need structured format for programmatic access and human-readable format for review. Work files should be separated from final results.

## Decision
Generate two output formats:

**XML** (`work/results.xml`):
- CDATA sections to preserve text content verbatim (with `]]>` escaping)
- Structure: `<results>` containing `<input>`, `<summaries>`, `<winner>`, `<model_mapping>`
- Model mapping separated from summaries to maintain anonymization integrity

**Markdown** (`RESULT.md` in project root):
- Human-readable report with winner, all summaries, judge evaluation, and timing table
- Easy to view in any markdown renderer

All intermediate files (`*_summary.md`, `results.xml`) stored in `work/` directory.

## Consequences
- XML for programmatic parsing
- Markdown for human review
- Work directory keeps project root clean
- `work/` is gitignored
