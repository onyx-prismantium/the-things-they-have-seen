# CLAUDE.md

This project's full design brief and implementation guidance lives in
[`BUILD_BRIEF.md`](BUILD_BRIEF.md) at the repository root — read it before
making non-trivial changes. Key things it establishes:

- **§1 Design pillars are immutable.** Objects never lie; they know sensation,
  not meaning; exactly three answers (Yes/No/Huh?!); questions are scarce;
  the player is never softlocked silently. Don't change these without asking.
- **§3–§9 are implementation guidance** — use judgment on details, keep the
  contracts (data-driven case content, the provider abstraction boundary,
  the pipe-format grammar contract).
- **§9 Data-driven absolutism**: no case string, fact, person, or list may
  appear in a `.gd` file. If a script mentions "Silas", it's a bug.
- **Only `scripts/nlu/nobodywho_provider.gd` touches the NobodyWho plugin**;
  only `scripts/autoload/nlu_service.gd` calls providers.
- Known limitation: live-model classification accuracy does not currently
  meet the §7/§8 targets with either Qwen3-0.6B or Qwen3-1.7B — see
  `docs/reports/m3_harness_report.md` for the full tuning history and
  diagnosis before attempting further prompt/model tuning.

Run `godot --headless --path . -- --check-data` to validate case data, or
`godot --path . -- --mock-nlu` to play against the scripted mock provider
(no model or NobodyWho binary required). See `README.md` for more.
