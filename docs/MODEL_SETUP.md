# Local model setup

The game needs a GGUF model file for live (non-mock) play. Per `BUILD_BRIEF.md`
§2.3, the default is Qwen3-0.6B, quantized Q4_K_M.

1. Download the GGUF file (not vendored in this repo):
   `hf://NobodyWho/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf`
2. Place it at `user://models/qwen3-0.6b-q4_k_m.gguf`. On Linux this resolves to
   `~/.local/share/godot/app_userdata/The Things They Have Seen/models/qwen3-0.6b-q4_k_m.gguf`.
3. Launch the game without `--mock-nlu`. If the file is missing, a boot screen
   tells you the expected path.

Quality fallback / alternates are listed in `BUILD_BRIEF.md` §2.3 if the
default underperforms the consistency harness (§8).
