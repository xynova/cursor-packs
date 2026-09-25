---
name: cli-command-surface
description: >-
  Language-agnostic CLI runner contract: explicit start command, version,
  root help, no accidental service start on bare invoke. Use when generating
  or changing command-line binaries, daemons, CLIs, cmd entrypoints, click,
  cobra, clap, argparse, tyro, or when reviewing CLI UX.
---

# CLI command surface

Standing contract for every shipped command-line runner (Go, Python, TypeScript, Rust, and others). Agents MUST apply this when creating or changing a binary entrypoint. Staged Go review applies the same binary checks under **Stage 5** when a CLI entrypoint is in scope (see `review-code-staged`).

**Patterns:** [reference.md](reference.md)

**Related:** `.cursor/skills/setup-goreleaser/SKILL.md` (Go version stamp); `.cursor/skills/setup-go-binary-license/SKILL.md` (Gate skips `version` / `license`); `.cursor/skills/operator-config/SKILL.md` (`init` / config discovery).

---

## When to load

- Creating or changing a CLI binary, daemon, or `cmd/` / `__main__` / `bin/` entrypoint
- Adding subcommands, flags, or release version printing
- Review finds bare invoke starts a server, missing `version`, or missing root help
- User mentions CLI UX, command surface, `serve`, argparse, cobra, clap, click, tyro

---

## Core constraints

**CONSTRAINT 1 — Explicit start.** Long-running serve / daemon / listen MUST be an explicit subcommand (for example `serve`, `run`, `start`). Bare binary invoke (no args) MUST NOT start the service.

- MUST: require a named start command before Listen / server loop / worker loop
- MUST NOT: treat zero args as “start the daemon”
- Enforcement: Trace the entrypoint default path; confirm Listen/Serve is behind a start subcommand
- Violation: STOP, add start command; bare invoke prints the agent operating guide (constraint 7) and exits 0, or prints usage for legacy CLIs until migrated

CORRECT:
```text
$ tool
Usage: tool <command> ...
$ tool serve
# listens
```

PROHIBITED:
```text
$ tool
# immediately loads config and listens
```

**CONSTRAINT 2 — Root command catalog.** The runner MUST expose a root help surface that lists primary commands.

- MUST: support `help` and/or `-h` / `--help` at the root (language-idiomatic is fine)
- MUST: list at least start, `version`, and other operator commands that exist
- MUST: on unknown command, print usage (or point to help) and exit non-zero
- MUST NOT: fail with only a flag-parser error and no command list when the user passed a bare unknown word
- Enforcement: Run `<bin>`, `<bin> help`, `<bin> --help` (or language equivalent); confirm catalog text
- Violation: STOP, add root usage printer and unknown-command path

CORRECT:
```text
Commands:
  serve     Start the daemon
  version   Print version
  init      Create user config
```

PROHIBITED:
```text
flag provided but not defined: -v
# with no command catalog
```

**CONSTRAINT 3 — Version command.** The runner MUST print a build or release identity via an explicit `version` command (or language-standard equivalent that is documented as the operator path).

- MUST: provide `version` as a root command (short `-v` / `--version` MAY alias it; MUST NOT be the only path if `-v` is easy to confuse with verbose)
- MUST: print a stable string operators can compare to a release tag
- MUST NOT: require config, network, license Gate, or service start to answer `version`
- Enforcement: Run `<bin> version` without config; confirm non-empty version line and exit 0
- Violation: STOP, add version command before serve/config/Gate

CORRECT:
```text
$ tool version
tool v1.2.3
```

PROHIBITED:
```text
$ tool -v
# starts verbose server, or "flag not defined" with no version path
```

**CONSTRAINT 4 — Optional flags stay optional.** Flags that have discovery defaults (config path, socket, license file) MUST remain optional overrides. Root help and command help MUST NOT imply they are required when discovery exists.

- MUST: document discovery order in help or operator docs when defaults exist
- MUST NOT: require `--config` / `--license` / equivalent when env and user-dir discovery already resolve
- Enforcement: Read flag definitions and config/license resolvers; confirm empty flag triggers discovery
- Violation: STOP, align help text and parsers with discovery

CORRECT:
```text
serve [--config PATH]   # default: ENV, then ~/.config/<app>/config.yaml
```

PROHIBITED:
```text
Usage: serve --config PATH --socket PATH --license PATH
# when all three have discovery defaults
```

**CONSTRAINT 5 — Docs and runners match.** Makefiles, Docker `CMD`/`ENTRYPOINT`, process-compose, Air/`full_bin`, CI smoke, and README examples MUST invoke the explicit start command.

- MUST: update every first-party launcher when introducing `serve` (or renaming start)
- MUST NOT: leave `go run ./cmd/x`, `python -m x`, or container entrypoints on the bare binary after the default path becomes help-only
- Enforcement: Grep README, Makefile, compose, Dockerfile, air config for the binary name; confirm start uses the start subcommand
- Violation: STOP, fix launchers before claiming done

CORRECT:
```dockerfile
ENTRYPOINT ["/tool"]
CMD ["serve"]
```

PROHIBITED:
```dockerfile
ENTRYPOINT ["/tool"]
# no CMD; container starts and only prints usage
```

**CONSTRAINT 6 — Language-agnostic, framework-local.** Prefer the ecosystem’s normal CLI framework (Go `flag`/cobra/urfave; Python argparse/click/tyro; Node commander/yargs; Rust clap). The contract is behavioral, not a required library.

- MUST: meet constraints 1–8 regardless of framework
- MUST NOT: rewrite a working CLI stack only to match another language’s framework
- Enforcement: Behavior checklist above; framework choice is out of scope unless the user asks
- Violation: STOP, restore ecosystem-local tooling; keep the behavior contract

**CONSTRAINT 7 — Agent-ready default view.** Bare invoke (no args) MUST print a structured agent operating guide to stdout and exit 0.

- MUST: include tool name, version, one-line purpose, role/boundaries, agent operating guide (paths to `AGENTS.md` and `ai-copilots/`), commands grouped by risk/lifecycle (inspect, plan/dry-run, execute/mutate), and automation rules (`--dry-run`, `--yes`, headless flags)
- MUST: keep human flag syntax under `help` / `-h` / `--help` and per-command `--help`
- MUST NOT: print only a one-line `usage: tool <cmd>` fragment on bare invoke
- MUST NOT: start Listen/Serve on bare invoke
- Enforcement: Run `<bin>` with no args; confirm sections above and exit 0
- Violation: STOP, add `agentGuide()` (or equivalent) before dispatch

**CONSTRAINT 8 — In-module agent harness.** Every shipped CLI module or repository that owns a binary MUST include operator docs for coding agents.

- MUST: ship root `AGENTS.md` pointing into `ai-copilots/README.md` and `ai-copilots/skills/<name>-operator/SKILL.md`
- MUST: ship `ai-copilots/BOOTSTRAP.md` for host IDE symlink discovery when consumers wire skills
- MUST: state-mutating flows SHOULD support `--dry-run` and non-interactive confirmation (`--yes` or equivalent) so subagents do not hang on TTY prompts
- Enforcement: `test -f AGENTS.md && test -f ai-copilots/skills/*/SKILL.md` at module root
- Violation: STOP, add harness before claiming CLI work is done (see `author-ai-copilots`)

---

## Steps

1. **Identify the runner** — binary name, entry file, existing subcommands.
2. **Classify start** — if Listen/Serve/worker loop exists, name the start command (`serve` preferred for daemons).
3. **Wire root dispatch** — bare invoke → usage + non-zero; `version`; `help`; start; other operator commands.
4. **Keep Gate/config out of version** — dispatch `version` / `help` before config load and license Gate.
5. **Update launchers** — Makefile, Docker, Air, compose, README, CI.
6. **Verify** — run the pre-completion checklist below.

---

## Pre-completion checklist

- [ ] **Bare invoke:** No args does not start the service
      Method: Run `<bin>` with no args; confirm no Listen and no socket/port bind
      Pass: Agent operating guide printed (constraint 7); exit 0; or legacy usage + non-zero until migrated
      Fail: Service starts or only a one-line syntax error → STOP, require agent guide + start command
- [ ] **Agent harness:** Module ships `AGENTS.md` and `ai-copilots/` operator skill
      Method: List files at module root
      Pass: Links resolve; operator skill documents safe command order
      Fail: Missing harness → STOP, add before merge
- [ ] **Version:** `<bin> version` works without config
      Method: Run without config file / license
      Pass: Version line, exit 0
      Fail: Missing command, Gate, or config error → STOP, fix dispatch order
- [ ] **Help catalog:** Root help lists start + version + other roots
      Method: `<bin> help` or `--help`
      Pass: Catalog names the real commands
      Fail: Empty or flag-only usage → STOP, add catalog
- [ ] **Unknown command:** Bad root word exits non-zero with usage
      Method: `<bin> not-a-command`
      Pass: Message + usage, exit 2 (or project non-zero)
      Fail: Panic, or silent fall-through to serve → STOP
- [ ] **Launchers:** Docs and automation use start command
      Method: Grep Makefile/Docker/Air/README/compose
      Pass: All start paths include the start subcommand
      Fail: Bare binary still used to run the service → STOP, update
