# CLI command surface patterns

LOAD-WHEN: implementing or reviewing a language-agnostic CLI runner under `.cursor/skills/cli-command-surface/SKILL.md`.

---

## Behavioral matrix

| Invoke | Required behavior |
|--------|-------------------|
| `<bin>` (no args) | Print agent operating guide (constraints 7–9); do **not** Listen/Serve; exit `0` |
| `<bin> help` / `-h` / `--help` | Print root catalog (one command per line); exit 0 |
| `<bin> version` | Print identity; no config/Gate/network; exit 0 |
| `<bin> status` / `doctor` / inspect | Dual-audience text (constraint 10); `--json` when a report object exists |
| `<bin> serve` (or `run` / `start`) | Load config, optional Gate, then Listen |
| `<bin> unknown` | Usage + non-zero; never fall through to serve |

MUST: Prefer `serve` for daemons that expose a socket or HTTP listener.
MUST NOT: Use `version` as the only way to learn commands exist.

---

## Go (Cobra)

MUST: Use `github.com/spf13/cobra` for all first-party Go operator binaries (golang-quality **C27**). MUST NOT ship or extend hand-rolled `switch args` / manual subcommand routers.
MUST: `SetArgs(args)` before `Execute()` when wrapping Cobra in a `Run(args []string)` helper so tests do not inherit `os.Args`.

```go
func newRoot() *cobra.Command {
	root := &cobra.Command{
		Use:          "tool",
		SilenceUsage: true,
		SilenceErrors: true,
		Version:      version,
		RunE: func(cmd *cobra.Command, args []string) error {
			if len(args) > 0 {
				return fmt.Errorf("unknown command: %s", args[0])
			}
			_, err := fmt.Fprint(cmd.OutOrStdout(), agentOperatingGuide(cmd))
			return err
		},
	}
	root.AddCommand(newServeCmd(), newVersionCmd())
	return root
}

func main() {
	if err := newRoot().Execute(); err != nil {
		os.Exit(exitCode(err))
	}
}
```

MUST: Bare root invoke (no subcommand) prints the agent operating guide and exits 0.
MUST: `serve` (or `run` / `start`) is a subcommand; MUST NOT Listen on bare `Execute()`.
MUST: Call license Gate only inside the serve subcommand, never for `version`.
MUST: Stamp release version via ldflags / `cobra.Command.Version` or explicit `version` subcommand (see `setup-goreleaser`).
MUST: Map `RunE` errors to process exit codes via a small `exitError` type or `SilenceErrors` + `main` wrapper.
NEVER: Add new subcommands by extending a `switch` on `os.Args` or `args[0]`.

### Go (legacy flag switch — do not extend)

Hand-rolled dispatch is legacy only. MUST NOT add cases or new subcommands to this pattern; migrate the binary to Cobra instead.

```go
// PROHIBITED for new code — migrate to cobra
switch args[0] {
case "serve":
	return runServe(args[1:])
}
```

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

Wire the guide on the **root** `cobra.Command` `RunE` when no subcommand is given (see [Go (Cobra)](#go-cobra) above). `agentOperatingGuide(cmd *cobra.Command)` SHOULD use `cmd.OutOrStdout()` for testability.

MUST: `agentOperatingGuide` includes ROLE, AGENT OPERATING GUIDE, COMMANDS BY RISK, AUTOMATION RULES.
MUST: Unknown subcommand is handled by Cobra (non-zero exit); MUST NOT fall through to `serve`.

---

## Go (stdout newline helper)

Guide and usage printers often share one helper. Each logical line MUST end with `\n` in the terminal.

```go
func writeln(w io.Writer, format string, args ...any) {
	if format == "" {
		fmt.Fprintln(w)
		return
	}
	out := fmt.Sprintf(format, args...)
	if !strings.HasSuffix(out, "\n") {
		out += "\n"
	}
	fmt.Fprint(w, out)
}
```

MUST: Route `agentOperatingGuide()`, `printUsage`, root help, and inspect/status text renderers through `writeln` or explicit `fmt.Println` per line.
MUST NOT: chain `fmt.Fprintf` calls without newlines between sections (constraint 9).

Example guide shape (stdout):

```text
tool v1.2.3
One-line purpose.

Short boundary sentence (bare invoke does not start serve).

Documentation for agents
  AGENTS.md
  ai-copilots/README.md

Read-only
  doctor, version, help

Changes host or remote
  init, setup

Automation example
  tool setup --non-interactive --yes ...

Full command list: tool help
```

---

## Inspect / status text (dual audience)

Default inspect stdout is for a person at a terminal **and** an agent grepping headings. JSON is a separate document.

```go
func renderStatus(w io.Writer, rep *Report) {
	writeln(w, "Host")
	writeln(w, "  OS:             %s/%s", rep.GOOS, rep.GOARCH)
	writeln(w, "  gitlab-runner:  %s", compactVersion(rep.RunnerVer))
	writeln(w, "")
	writeln(w, "Services")
	writeln(w, "  How the process is kept alive (launchd, Homebrew, or Windows).")
	// one service block per unit; gloss kind once
}
```

MUST: Stable section titles; one labeled field per line; compact vendor `--version` banners (constraint 10).
MUST: Keep `--json` field names stable when pretty-printing text.
MUST NOT: `fmt.Fprintf(w, "os=%s arch=%s runner=%s\n", ..., fullVersionBanner)`.

---

## Review mapping

| Check | Mechanical (Stage 5 when CLI in scope) | Consultant (Stage A) |
|-------|------------------------------------------|----------------------|
| Bare invoke starts service | Detect fail | Ask why start is implicit |
| Missing `version` | Detect fail | — |
| Missing root catalog | Detect fail | — |
| Launchers still bare | Detect fail | — |
| Guide/help wall of text (missing newlines) | Detect fail | — |
| Inspect/status packed `key=value` or raw `--version` banner | Detect fail | — |
| Subcommand taxonomy / naming | — | Ask if `serve` vs `run` matches operator vocabulary |
