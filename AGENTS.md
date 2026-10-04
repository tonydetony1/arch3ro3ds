# AI Agent & Contribution Guidelines — Arch3ro 3DS

## 1. Language & Git Conventions (Mandatory)

- **All Git Commit Messages MUST be in English**:
  - Use the **Conventional Commits** standard format:
    - `feat(scope): description`
    - `fix(scope): description`
    - `docs(scope): description`
    - `perf(scope): description`
    - `refactor(scope): description`
    - `chore(scope): description`
    - `test(scope): description`
  - Examples:
    - `fix(inventory): fix pet and gear equip/unequip`
    - `feat(audio): add sound effect on hero level up`
    - `docs: update setup instructions in README`
- **All PRs & GitHub communication**:
  - Pull request titles, descriptions, and comments sent to GitHub must be in English.
  - Git branch names must be in English (e.g., `fix/inventory-scroll`, `feat/new-hero`).

## 2. Codebase Language Conventions

- **Code & Comments**:
  - All new code, variable names, functions, docstrings, and inline comments must be written in **English**.
  - Maintain the existing English naming style for all game data (`src/data/`), UI strings, and entities.
  - When editing existing files with French comments, translate surrounding comments to English as you touch them.

## 3. Nintendo 3DS Constraints

- **Zero GC Allocations** in gameplay loops (`update`/`draw`).
- **PICA200 vertex budget**: Do not exceed 24,576 vertices per frame.
- **Batching & Draw Calls**: Always prioritize sprite batching and cached canvas rendering.
