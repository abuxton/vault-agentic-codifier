# Waza review of the codifier skills (TASK-033)

Review of the 23 skills under `skills/` with [microsoft/waza](https://github.com/microsoft/waza).

## Environment and commands

| Item | Value |
|---|---|
| Waza version (final run) | 0.42.0 (`~/bin/waza`) |
| Waza version (baseline) | 0.38.7 |
| Environment | `WAZA_NO_UPDATE_CHECK=1 WAZA_TELEMETRY_OPTOUT=1` |
| Config | [`.waza.yaml`](../.waza.yaml) |

```sh
waza check --format json                       # all skills; filter to this project's 23
waza check --format json | jq '.skills[] | select(.name | test("^(discovery|codification|validation|vault)"))'
python3 scripts/waza-restructure.py            # restructure tool, see below
```

`waza check` also scans the unrelated `openspec-*` skills under `.claude/skills`. They are out of scope and are filtered out.

## Result

| Measure | Before | After |
|---|---|---|
| Skills | 23 | 23 |
| `ready: true` | 0 | **23** |
| Total `SKILL.md` tokens | 53,723 | 27,407 |
| Largest `SKILL.md` | 3,391 (baseline of 17) | 1,496 |
| `spec-allowed-fields` | 23 | **0** |
| Broken links | not measured | **0** |
| `procedural-content` | 11 | **0** |
| `over-specificity` | 20 | 18 |
| `negative-delta-risk` | 9 | 7 |
| `body-structure` | 23 | 23 |
| `complexity` | 23 | 23 |
| `module-count` | not reported | 15 |
| `cross-model-density` | 0 | 9 (description word count over 60) |
| Eval suite | none | none |

## What changed

1. **Config.** `.waza.yaml` sets `skills/*/SKILL.md` to 1,500 tokens. Measured sizes after restructuring run from 587 to 1,496. Process, governance and stop conditions fit within the limit. Examples, schemas, API tables and reference implementations live in `references/`. The limit was not raised to hide the problem; the content moved.
2. **Frontmatter.** `triggers`, `capability`, `task`, `depends_on` and `role` moved under `metadata:`. Trigger phrases are folded into the description as `USE FOR` and `DO NOT USE FOR`. Descriptions start "Use when you need to ..." and name the next step.
3. **Token reduction.** 101 reference files were created. Content was moved verbatim. `scripts/waza-restructure.py` counts the non-blank lines of the original body and compares them with the new body plus its references, ignoring heading level. Every skill reported 0 lines lost and 0 gained, so no acceptance criterion was dropped.
4. **Over-specificity.** `/opt/homebrew/bin/` prefixes were removed. Sibling-skill links became plain names, because waza treats `../x/SKILL.md` as a scope escape.
5. **Generators.** No `generate.sh` or discovery script was edited by this task.

## Deviations and retained advisories

| Finding | Decision | Reason | Owner |
|---|---|---|---|
| `body-structure` (no examples, no troubleshooting) | Kept | Waza looks for headings named "Examples" and "Troubleshooting". The skills carry a `Stop conditions` section and a validated reference implementation under `references/`. Renaming headings to satisfy the heuristic adds no information. | skill author |
| `complexity` ("comprehensive") | Kept | Each skill describes a read-only Vault API surface or a generator. The size is inherent. Progressive disclosure is already used. | skill author |
| `module-count` (15 skills have 4+ references) | Kept | Each reference is a distinct section such as the output schema, the example or the acceptance criteria. Merging them would put the tokens back into `SKILL.md`. | skill author |
| `over-specificity` (18 skills) | Kept | Remaining hits are `127.0.0.1` and port numbers, which the project security rules require for the harness, and Vault API paths such as `sys/audit`, which are the subject of the skills. | skill author |
| `negative-delta-risk` (7 skills, 6 to 12 constraint keywords) | Kept | The "MUST" and "NEVER" statements are the read-only and no-secrets guarantees (CAC3 and CAC4). They are verified by `make verify`. Removing them would weaken the guarantee. | skill author |
| `cross-model-density` (9 descriptions, 62 to 88 words) | Kept | Advisory only. The `USE FOR` and `DO NOT USE FOR` text is needed for routing. | skill author |
| Eval suite (`waza new eval`) | **Not done** | The project's behavioural evidence is `make codify-test` (CAC1 to CAC7). A `executor: mock` eval would only exercise the harness and would not show agent quality. Real executor runs may incur provider cost and need explicit approval. | project owner |
| Token limit | 1,500 instead of waza's default 500 | See "What changed", item 1. | skill author |

## Regression checks after the restructure

| Check | Result |
|---|---|
| `make assemble` | Output tree byte-identical (`git diff --stat discovered_terraform/terraform` empty) |
| `make static-gate` | PASS |
| `VAULT_TOKEN=root make zero-diff` | PASS (`0 to add, 0 to change, 0 to destroy` in every layer) |
| `make verify` | PASS, verdict PASS |
| `make codify-test` | PASS, 11 stages, harness unchanged |
| `waza check` links | 0 broken |

## Restructure tool

`scripts/waza-restructure.py` reads each `SKILL.md` from `git HEAD`. It was run once against the pre-TASK-033 commit. Running it again on the restructured files will not reproduce the same result, because it treats HEAD as the original. Keep it as the record of how the references were derived. Recover the originals from the parent of the TASK-033 commit.
