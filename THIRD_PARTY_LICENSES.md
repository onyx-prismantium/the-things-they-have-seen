# Third-party licenses

| Component | License | Notes |
|---|---|---|
| Godot Engine 4.6.x | MIT | Engine itself. |
| NobodyWho (GDExtension) | EUPL-1.2 | Local LLM inference for dialogue. Commercial/proprietary use explicitly permitted by the authors' linking exemption. Plugin source is not modified — see `scripts/nlu/nobodywho_provider.gd` for the sole point of contact. |
| Qwen3-0.6B (and other Qwen3 sizes) weights | Apache-2.0 | Default local model, GGUF quantized. Not vendored in this repo — downloaded to `user://models/` per `docs/MODEL_SETUP.md`. |

All licenses listed above are compatible with a commercial release of this game.
This file is kept up to date from the first commit (BUILD_BRIEF.md §2.4).
