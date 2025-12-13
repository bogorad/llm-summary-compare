# ADR 001: Use OpenCode for AI Model Orchestration

## Status
Accepted

## Context
We need to compare summarization quality across multiple AI models on the same text fragment. The system must run each model with identical prompts, capture outputs, and compare results objectively.

## Decision
Use OpenCode as the orchestration framework because it:
- Supports multiple AI providers through OpenRouter
- Allows a single agent with runtime model override via `--model` flag
- Provides CLI for non-interactive batch execution
- Enables custom commands for workflow automation

## Consequences
- Requires OpenCode installation and OpenRouter API key
- Single agent definition serves all models
- Easy extension to additional models via `models.json`
