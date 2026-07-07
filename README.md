# The Things They Have Seen

*"The only innocents in this room are the objects."*

Victorian London, 1887. A murder in a locked study. You are Laura Sinclair, a
spiritualist hired to "cleanse" the room — but you have a real gift: you can
speak with objects. They cannot lie, cannot forget, and want nothing. Ask any
object a natural-language question; it answers **Yes**, **No**, or a
bewildered **Huh?!** — never anything else. Assemble the truth from fragments
before three wrong deductions lose the case.

Full design brief: [`BUILD_BRIEF.md`](BUILD_BRIEF.md).

## Status

All milestones (§7 M0–M6) built. The vertical slice — one case ("The Silent
Study"), 8 interrogable objects, deduction board, win/lose epilogues, voice
blips — is complete and fully playable via `--mock-nlu` (CI-safe, 61/61 golden
questions correct). The live local-model path is wired and functional but its
classification accuracy does not currently meet the harness targets with
either Qwen3-0.6B or Qwen3-1.7B — see `docs/reports/m3_harness_report.md` and
`docs/reports/m6_harness_report.md` for the full tuning history, diagnosis,
and numbers before relying on it for anything beyond development/demo use.

## Requirements

- Godot 4.6.x stable
- [NobodyWho](https://github.com/nobodywho-ooo/nobodywho) GDExtension (pinned v9.4.0) — run `tools/install_nobodywho.sh` to fetch the binary for your platform (gitignored; not vendored)
- A local GGUF model for live play — see `docs/MODEL_SETUP.md`. The game is fully playable without one via `--mock-nlu`.

## Running

```sh
# Validate case data only (no window needed):
godot --headless --path . -- --check-data

# Play against the scripted MockProvider (no model, no NobodyWho binary needed):
godot --path . -- --mock-nlu

# Play against the live local model (after tools/install_nobodywho.sh + model download):
godot --path .
```

## Testing

```sh
# Unit layer (mock, CI-safe, no model needed): normalization, cache keys,
# grammar generation, validator rules, economy math, softlock, CaseLoader.
godot --headless --path . -s res://tests/run_unit_tests.gd -- --mock-nlu

# Paraphrase consistency harness against the live model (needs the model
# file — see docs/MODEL_SETUP.md):
godot --headless --path . -s res://tests/run_harness.gd -- --runs 3
```

## Project layout

See `BUILD_BRIEF.md` §3.1 for the full annotated folder structure.
