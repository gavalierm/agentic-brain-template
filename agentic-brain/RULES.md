# Project rules

The agent loads this file in every session. It applies to everything you do in this repo.
All agent data is in one visible folder, `agentic-brain/`.

## Where things are

- `agentic-brain/skills/<name>/`: a skill, with `SKILL.md` and `scripts/`. Claude Code reads it through the symlink `.claude/skills/<name>`, which `agentic-brain/bin/check.sh` creates.
- `agentic-brain/artifacts/<name>/`: an approved pattern of work, with `PLAYBOOK.md` and `reference/`.
- `agentic-brain/errors/REGISTER.md`: the error register. The script `skills/error/scripts/error.sh` adds a row.
- `agentic-brain/decisions/`: decisions, one file `D0001-<slug>.md` per decision. `bin/decide.sh` creates new ones.
- `agentic-brain/memory/MEMORY.md`: the memory index. The content is in `memory/<file>.md`.
- `agentic-brain/scratch/`: working files of a task. Git ignores them, and the folder is empty at the end of a task.
- `agentic-brain/bin/`: the check `check.sh`, the installer `install.sh`, the rollout `adopt.sh`, `decide.sh` and the hook `repeat_guard.mjs`.

The `.claude/` folder holds only symlinks to skills and `settings.json`. It holds no data.

## Mandatory automation

You decide the goal and check the result. A script does the mechanical step.

A mechanical step is an upload, a download, a search, a comparison, a move or a conversion. Do not run such a step by hand with terminal commands. Write a script in `agentic-brain/skills/<name>/scripts/` and run it.

- A manual run of a mechanical step is an error. Record it in the register with the skill `error`.
- Each skill has `scripts/`. `SKILL.md` says what the agent decides and what the script does.
- A script you can reuse belongs in a skill, not in `scratch/`.
- The hook `bin/repeat_guard.mjs` (optional, Claude Code only) rejects the third manual run of the same program with different arguments in one session. The rule applies without the hook too.

## End of task

Before you report the end of a task, run the skill `task-end`. It verifies these points.

- `agentic-brain/bin/check.sh` passed without errors.
- `agentic-brain/scratch/` is empty.
- A repeated procedure is a skill with a script.
- An error from the run is in the error register.
- New knowledge is in `memory/` or in `decisions/`.
- A skill or artifact that reaches beyond the project has `scope: shared` in its frontmatter and appears in the report to the operator.

## Central and local

This folder is the local layer of the project. The optional second layer is a central repo with the same structure. On the agent's machine it is cloned as `~/agentic-brain` and installed with `agentic-brain/bin/install.sh --global`.

An optional line `upstream: <url>` in the header of this file points to the central repo.

The operator promotes an item with `scope: shared` to the center. The agent only marks it in the end-of-task report. A skill with the same name in the local and the central layer is an error, and `check.sh` reports it.

## Artifact

An artifact is an approved pattern for repeated work. Before you design or implement something an artifact may cover, look at the list in `agentic-brain/artifacts/`.

1. If one fits, read the whole `PLAYBOOK.md` and open the files in `reference/`.
2. Take values (colors, sizes, fonts, structure) from the reference. Do not write them from memory. If text and reference disagree, the reference wins.
3. Deviate from an artifact only with a reason. Tell the operator the deviation in one sentence and do not rewrite the rule.
4. Do the verification steps from the playbook before you hand over, and report the result.
5. The agent that did the work creates a new artifact, and the operator approves it. Without approval, nothing is created.
