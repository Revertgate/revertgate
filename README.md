# Revertgate

**Merge AI pull requests with proof, not hope.**

Agents like Claude Fable 5.2 write far more code, far faster, than anyone can review.
Revertgate proves their tests actually test the change. It is a GitHub check that reverts the
PR's code and reruns your tests: if they still pass, the tests don't exercise the change, and
the PR is blocked. It also blocks the shortcuts an agent takes to get a green tick: skipped,
deleted and weakened tests, and a switched-off gate.

**Works with any agent or model:** Claude Fable, Claude Opus, Claude Code, GitHub Copilot
agent, Cursor, Devin, Jules, Codex and other GPT-based agents, local models, and humans. The
check is deterministic and looks only at the diff and what your tests do, so it doesn't matter who
or what wrote the PR.

No LLM is involved. The same PR always gets the same verdict, and your code never leaves your
CI runner.

## Quick start

```yaml
# .github/workflows/revertgate.yml
name: revertgate
on:
  pull_request:
    types: [opened, synchronize, reopened, labeled, unlabeled]
permissions:
  contents: read
  pull-requests: write
jobs:
  revertgate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
        with:
          fetch-depth: 0
      - run: npm ci            # whatever your tests need
      - uses: revertgate/revertgate@v0
        with:
          license-key: ${{ secrets.REVERTGATE_LICENSE_KEY }}  # private repos only
```

Add `.revertgate.toml` with your test command (`test = "npm test"`), commit both in their own PR,
then make the `revertgate` check **required** in branch protection.

Free for public repositories. Private repositories need a subscription:
https://revertgate.github.io/#pricing

## Inputs

| Input | Default | |
|---|---|---|
| `license-key` | | Private repositories only |
| `test` | from `.revertgate.toml` | The test command |
| `comment` | `true` | Post the report as a PR comment, updated on every push |
| `override-label` | `revertgate-override` | A maintainer adds it to merge past blocking findings |

## What it checks

| Rule | Default | Meaning |
|---|---|---|
| `unproven-change` | block | With the code change reverted, the tests still pass |
| `tests-failing` | block | The tests fail on the PR, so nothing can be proven |
| `skip-added` / `focus-added` | block | A new skip, `xit`, `#[ignore]`, `.only`, `fit` … |
| `skip-conditional` | warn | A skip guarded by a condition (`skipif`, `#[ignore = "needs postgres"]`, a skip inside an `if`): usually about the environment, so check the condition |
| `tests-removed` | block | Net loss of tests across the PR, or a deleted test file |
| `assertions-removed` | block | Net loss of assertions across the PR's test files |
| `gate-tampered` | block | `continue-on-error`, `--passWithNoTests`, `\|\| true`, removed test steps … |
| `revertgate-config-changed` | block | The PR edits Revertgate's own config or workflow |
| `untested-file` | warn | Reverting this one file alone doesn't fail any test |
| `no-tests` | warn | Code changed and no test did |
| `matcher-loosened` | warn | An exact assertion swapped for a truthiness check |
| `suppression-added` | warn | `eslint-disable`, `@ts-ignore`, `# noqa`, `#[allow]` … |
| `error-swallowed` | warn | Empty `catch`, `except: pass`, discarded errors |
| `test-command-changed` | warn | The `test` script in package.json changed |
| `sorry-added` | block | Lean: a new `sorry` or `admit`, so the goal is assumed, not proved |
| `axiom-added` | block | Lean: a new `axiom`, `@[implemented_by]`, `@[extern]` or `debug.skipKernelTC` |
| `required-theorem-changed` | block | Lean: a required theorem's statement changed or it disappeared, or a definition it talks about changed |
| `native-decide-added` | warn | Lean: `native_decide` trusts compiled code instead of the kernel |
| `theorem-changed` | warn | Lean: a theorem's statement changed |
| `theorem-removed` | warn | Lean: a theorem disappeared from the PR's changed `.lean` files |
| `definition-changed` | warn | Lean: a definition, or the `variable` binders, changed |

Override any severity in `.revertgate.toml` under `[rules]` (`block`, `warn`, `off`). Revertgate reads
that file **from the base commit**, so a PR can't relax its own check. A maintainer can add
the `revertgate-override` label to merge past blocking findings; they are still reported.

### Lean 4 proofs

Proof files get the same treatment as tests: `.lean` files are compared at base and head as
text, with no Lean toolchain needed. To protect your key guarantees, list them; Revertgate
reads the list from the base commit:

```toml
[lean]
required = ["Shop.total_nonneg"]          # namespace-qualified, or just the name
required_file = "proofs/REQUIRED_THEOREMS" # one name per line; text after it is ignored
```

These are text checks, not a proof checker: against a hostile author, also rebuild the proofs
with lean4checker.

## Limits

- A flaky suite can fake either answer.
- A build error with the change reverted counts as "caught".
- Tests inside a source file (Rust `#[cfg(test)]`) are reverted with it; put the tests that
  prove a change in a test file.
- The static detectors are text heuristics; the report says which check found what.
- A PR can edit the workflow file itself. Revertgate flags it, and branch protection with a
  required check plus CODEOWNERS on `.github/` is what stops it merging.

