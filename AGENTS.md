# AI & Automated Agent Policy

This document outlines our policy on AI-assisted contributions and automated agents interacting with this project.

## Issues

### Good First Issues

Issues tagged with `good-first-issue` are there to allow new contributors to learn the processs of contributing to open source and Vapor with relatively easy tasks, to help grow open source. These issues are written by human maintainers and are intended to be solved by humans learning the codebase. **Do not use automated agents to claim, triage, or submit solutions to `good-first-issue` tickets.**

### Security Issues

Security vulnerabilities must be reported by humans through our responsible disclosure process. Automated scanning tools may identify potential issues, but all security reports must be reviewed, verified, and submitted by a human. Automated or AI-generated security reports will be closed without action. See our [organisation security policy](https://github.com/vapor/.github/blob/main/SECURITY.md) for disclosure instructions.

### General Issues

Issues must reflect genuine, human-identified bugs or feature requests. We will close issues that appear to be generated entirely by an automated agent without meaningful human review. Low-effort, bot-generated issues waste maintainer time and will not be tolerated.

## Pull Requests

We welcome AI-assisted contributions under the following conditions:

- **A human must author and submit the PR.** Using AI tools (Copilot, Claude, Cursor, etc.) to help write or refine code is fine, but a human must understand, review, and take responsibility for every change in the PR.
- **Fully automated PRs will be closed.** If a PR appears to have been generated and submitted by an agent with no meaningful human involvement, we will close it.
- **Contributors must be able to discuss their changes.** Maintainers may ask questions about implementation choices during review. You should be able to explain and defend your approach.
- **AI-generated code must meet the same standards as any other contribution.** It must pass CI, follow project conventions, include tests where appropriate, and be consistent with the existing codebase.

## How We Identify Automated Contributions

We look for patterns such as:

- Generic or templated issue descriptions with no project-specific context
- PRs submitted moments after an issue is opened
- Inability to respond to review feedback in a meaningful way
- Bulk submissions across multiple issues in a short timeframe
- Commit messages or PR descriptions that read like raw LLM output

Maintainers reserve the right to close any issue or PR that we believe violates this policy. These decisions are made at our discretion and are final.

## Why This Policy Exists

Open source thrives on human collaboration. Automated noise—whether from bots filing low-quality issues or agents submitting unreviewed code—drains maintainer energy and undermines the community we are building. This policy exists to protect contributor experience, maintain code quality, and keep Vapor a welcoming place for people who want to learn and contribute.
