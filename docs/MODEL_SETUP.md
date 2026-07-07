# Local model setup

The game needs a GGUF model file for live (non-mock) play.

**Default: Qwen3-1.7B, Q4_K_M** (not the brief's original 0.6B suggestion —
see `docs/reports/m3_harness_report.md` for why: 0.6B measured far below the
harness targets, 1.7B measured meaningfully better while staying inside the
~2s latency budget on a mid-range GPU).

1. Download the GGUF file (not vendored in this repo):
   `hf://NobodyWho/Qwen_Qwen3-1.7B-GGUF/Qwen_Qwen3-1.7B-Q4_K_M.gguf`
2. Place it at `user://models/qwen3-1.7b-q4_k_m.gguf`. On Linux this resolves to
   `~/.local/share/godot/app_userdata/The Things They Have Seen/models/qwen3-1.7b-q4_k_m.gguf`.
3. Launch the game without `--mock-nlu`. If the file is missing, a boot screen
   tells you the expected path.

To try the smaller/faster Qwen3-0.6B instead, download
`hf://NobodyWho/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf`, place it at
`user://models/qwen3-0.6b-q4_k_m.gguf`, and launch with the environment
variable `NW_MODEL_FILE=qwen3-0.6b-q4_k_m.gguf` set (see `nlu_service.gd`).

Neither size currently clears the harness targets — see the report above
before relying on the live model for anything but development/demo use.
