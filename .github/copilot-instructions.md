# GitHub Copilot Instructions

## Git Workflow

- Always work on a branch — never commit directly to `main` or `dev`.
- The `dev` branch is the integration branch. All feature branches are based on the latest commit of `dev`.
- Branch naming: `feature/<short-description>` or `fix/<short-description>`.
- All pull requests target `dev`, not `main`.
- After making code changes, show `git diff` for review. Do NOT commit automatically — wait for explicit user confirmation.
- When creating git commits, always include the Co-authored-by trailer:
  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`

## Project

- Erlang OTP application. Build with `make compile`, lint with `make lint`, type-check with `make dialyzer`, test with `make test`.
- Uses `erlc` directly (not mix or rebar3 — mix/rebar3 builds are broken on this setup).
