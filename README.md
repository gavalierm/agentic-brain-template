# agentic-brain-template

This is a template for the `agentic-brain/` folder of a project repo. The agent finds rules, skills, artifacts, an error register, decisions and memory in one visible place. It needs only git, bash and node. No server, task manager or other tool is required.

## What the repo is

The repo has two uses with the same structure.

- The `agentic-brain/` folder in a project repo is the local layer. It holds the rules and knowledge of one project.
- The repo `~/agentic-brain` on the agent's machine is the global layer. It holds the rules and skills for all projects on that machine.

In a project, `CLAUDE.md` and `AGENTS.md` in the root each hold a single line, `@agentic-brain/RULES.md`. The global layer is not copied into the project. The user's `~/.claude/CLAUDE.md` loads it.

Claude Code reads skills only from `.claude/skills/<name>`. For that reason each skill has a symlink there that points to `agentic-brain/skills/<name>`. The `.claude/` folder holds only symlinks and `settings.json`. It holds no data. Symlinks in git need a setting on Windows and are not verified there. On Windows, run bash through Git Bash or WSL.

## New repo

1. On GitHub, use "Use this template", or clone the repo and delete its history.
2. Run `agentic-brain/bin/install.sh`. It adds the skill symlinks and installs the pre-commit hook.
3. Run `agentic-brain/bin/check.sh`.

## Existing repo

From a clone of the template, run `agentic-brain/bin/adopt.sh <path-to-repo>`. The script copies `agentic-brain/` without overwriting existing files and prints what it skipped. It creates the skill symlinks and `.claude/settings.json` (if missing, otherwise it prints what to add). It adds the line `@agentic-brain/RULES.md` to `CLAUDE.md` and `AGENTS.md`, and the `scratch/` lines to `.gitignore`. It commits nothing.

Then, in the target repo, run `agentic-brain/bin/check.sh --install-hook` and `agentic-brain/bin/check.sh`. If `CLAUDE.md` and `AGENTS.md` differ, `check.sh` reports an error. Make them identical.

## Global layer

The global repo is the content of the `agentic-brain/` folder in the root, without the project wrapper. Create it from this folder. A clone of the whole template also works. The import then points to `~/agentic-brain/agentic-brain/RULES.md`.

1. Clone the repo to `~/agentic-brain`.
2. Run `bin/install.sh --global` from the clone (for a clone of the whole template, `agentic-brain/bin/install.sh --global`).

The script adds a line to `~/.claude/CLAUDE.md` that imports `RULES.md`, and creates the symlinks `~/.claude/skills/<name>` into the clone. It leaves any existing foreign symlink or folder alone and prints it. A second run changes nothing.

Cloud and Cowork sessions do not read the `~/.claude/` of the machine. For those, put a copy of the global layer directly into the project repo.

## What check.sh does

`agentic-brain/bin/check.sh` runs from the repo root and from any subfolder. On error it exits with code 1 and prints one line with a path for each error. It checks these things.

- `CLAUDE.md` and `AGENTS.md` exist, are identical and contain the import line.
- Each skill has a `SKILL.md` with a `description` and a non-empty `scripts/`.
- Each skill has a symlink in `.claude/skills`. A missing one is created, a dangling one is deleted, a foreign entry is reported.
- A skill with the same name in the local and the global layer is an error.
- Each artifact has a `PLAYBOOK.md` and a non-empty `reference/`.
- Two or more rows of the error register with the same class and no fix are an error. One such row is a warning.
- `scratch/` is empty.
- `MEMORY.md` and the memory files match.
- Relative links in md files point to existing files.
- A skill or artifact with `scope: shared` that is not in the global layer is a warning.

The optional pre-commit hook runs `check.sh` before each commit and rejects the commit on error. Install it with `agentic-brain/bin/check.sh --install-hook`. The hook is copied to `.git/hooks/pre-commit`. The script does not change `core.hooksPath`.

## Hook against manual repetition

`.claude/settings.json` turns on the hook `agentic-brain/bin/repeat_guard.mjs` for the Bash tool in Claude Code. The hook rejects the third different manual run of the same program in a session and asks for a script. Programs the hook does not count are listed in `agentic-brain/bin/repeat_guard.allow`. The hook is optional. The rule and `check.sh` apply without it.

## Tests

Run `agentic-brain/test/run.sh`. The tests run in temporary folders and do not touch your HOME or your repo.
