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

Building in the milestone order set out in the brief (§7). See that document
for the full architecture, data model, and acceptance criteria per milestone.

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

## Project layout

See `BUILD_BRIEF.md` §3.1 for the full annotated folder structure.
