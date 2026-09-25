# CLI command surface patterns

LOAD-WHEN: implementing or reviewing a language-agnostic CLI runner under `.cursor/skills/cli-command-surface/SKILL.md`.

---

## Behavioral matrix

| Invoke | Required behavior |
|--------|-------------------|
| `<bin>` (no args) | Print agent operating guide (constraint 7); do **not** Listen/Serve; exit `0` |
| `<bin> help` / `-h` / `--help` | Print root catalog; exit 0 |
| `<bin> version` | Print identity; no config/Gate/network; exit 0 |
| `<bin> serve` (or `run` / `start`) | Load config, optional Gate, then Listen |
| `<bin> unknown` | Usage + non-zero; never fall through to serve |

MUST: Prefer `serve` for daemons that expose a socket or HTTP listener.
MUST NOT: Use `version` as the only way to learn commands exist.

---

## Go (flag switch)

```go
func run(args []string) int {
	if len(args) < 2 {
		printUsage(os.Stderr)
		return 2
	}
	switch args[1] {
	case "version":
		fmt.Printf("%s %s\n", appName, reportVersion())
		return 0
	case "help", "-h", "--help":
		printUsage(os.Stdout)
		return 0
	case "serve":
		return runServe(args[2:])
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n\n", args[1])
		printUsage(os.Stderr)
		return 2
	}
}
```

MUST: Call license Gate only inside `runServe` after flags, never for `version`.
MUST: Stamp release version via ldflags / BuildInfo (see `setup-goreleaser`).

---

## Python (argparse subparsers)

```python
def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="tool")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("version")
    serve = sub.add_parser("serve")
    serve.add_argument("--config", default="")
    args = parser.parse_args(argv)
    if args.command == "version":
        print(f"tool {VERSION}")
        return 0
    if args.command == "serve":
        return run_serve(args)
    return 2
```

MUST: `required=True` on subparsers (or manual check) so bare invoke cannot start serve.
NEVER: Default `command="serve"` on the root parser.

---

## TypeScript (commander / yargs)

```ts
program
  .name("tool")
  .command("version", "print version", () => {
    console.log(`tool ${version}`);
  })
  .command("serve", "start the daemon", serveAction)
  .showHelpAfterError(true);

if (!process.argv.slice(2).length) {
  program.outputHelp();
  process.exitCode = 2;
} else {
  program.parse();
}
```

MUST: Empty argv shows help and exits non-zero when start is not implied.
NEVER: `.action(serveAction)` on the root program for a daemon.

---

## Rust (clap)

```rust
#[derive(Parser)]
#[command(name = "tool")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Serve { #[arg(long)] config: Option<PathBuf> },
    Version,
}
```

MUST: Use an enum subcommand so the binary has no implicit serve.
NEVER: Make `Serve` the default variant applied when argv is empty without printing help.

---

## Launcher updates checklist

When introducing `serve` (or renaming start):

- [ ] README run examples
- [ ] `make run` / `make air` / process-compose command
- [ ] `.air.toml` `full_bin` (or equivalent) includes `serve`
- [ ] Dockerfile `CMD` or compose `command`
- [ ] CI smoke that executes the binary as a service

---

## Go (agent guide on bare invoke)

```go
func run(args []string) int {
	if len(args) == 0 {
		fmt.Fprint(os.Stdout, agentOperatingGuide())
		return 0
	}
	switch args[0] {
	case "help", "-h", "--help":
		printUsage(os.Stdout)
		return 0
	case "version":
		fmt.Printf("%s %s\n", appName, reportVersion())
		return 0
	default:
		// dispatch subcommands
	}
}
```

MUST: `agentOperatingGuide()` includes ROLE, AGENT OPERATING GUIDE, COMMANDS BY RISK, AUTOMATION RULES.
MUST: Unknown command prints stderr error + `printUsage` and returns non-zero.

---

## Review mapping

| Check | Mechanical (Stage 5 when CLI in scope) | Consultant (Stage A) |
|-------|------------------------------------------|----------------------|
| Bare invoke starts service | Detect fail | Ask why start is implicit |
| Missing `version` | Detect fail | — |
| Missing root catalog | Detect fail | — |
| Launchers still bare | Detect fail | — |
| Subcommand taxonomy / naming | — | Ask if `serve` vs `run` matches operator vocabulary |
