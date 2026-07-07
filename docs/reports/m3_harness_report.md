# M3 golden-set report: live model vs. targets

Targets (BUILD_BRIEF.md §7 M3, §8.2): yes/no accuracy ≥95%, huh accuracy ≥90%,
median latency ≤2s, measured against all 61 `sample_qa` golden questions via
the real `NobodyWhoProvider` pipeline (economy/cache bypassed via
`GameState.reset_case()` between questions — see `SELFTEST_M3_GOLDEN` in
`scripts/main.gd`).

**Status: targets NOT met.** The pipeline is fully wired and functional
(grammar-constrained decoding works, latency is fine, the game is completely
playable against the live model) but classification accuracy is well below
target with both model sizes tried. This report documents the tuning attempts
in the order BUILD_BRIEF.md §8.3 prescribes, the diagnosis, and what's left.

## Results by configuration

| # | Model | Grammar order | Prompt | yes/no | huh | latency p50/p95 |
|---|---|---|---|---|---|---|
| 1 | Qwen3-0.6B | answer\|fact | brief's original §4.2 text | 9.3% (4/43) | 100% (18/18) | 1.3s / 1.4s |
| 2 | Qwen3-0.6B | answer\|fact | decision-procedure rewrite (this repo's default) | 44.2% (19/43) | 0% (0/18) | ~1.3s |
| 3 | Qwen3-0.6B | answer\|fact + bounded `<think>` scratchpad (§8.4) | + reasoning instructions | 14.0% (6/43) | 27.8% (5/18) | 3.8s / 5.0s |
| 4 | Qwen3-1.7B | answer\|fact | decision-procedure rewrite | **53.5% (23/43)** | 5.6% (1/18) | 1.3s / 1.4s |
| 5 | Qwen3-1.7B | fact\|answer (reordered) | same, reworded for new order | 20.9% (9/43) | 83.3% (15/18) | 1.3s / 1.4s |
| 6 | Qwen3-1.7B | answer\|fact | + explicit "never"-style negation example (**shipped default**) | 48.8% (21/43) | 38.9% (7/18) | 1.3s / 1.4s |

Full per-question logs for each run are not committed (they're large); the
harness in M6 (`tests/run_harness.gd`) re-measures this properly and its CSV
output under `docs/reports/` is the durable record going forward. This table
is the snapshot from the M3 tuning session.

## Diagnosis

1. **Grammar constraint itself works correctly.** Every configuration produced
   well-formed `answer|fact-id` output — malformed output never reached the
   parser. The failure is a classification-accuracy problem, not a format
   problem.
2. **Fact-matching is reliable; polarity is not.** In configurations 2, 4, and
   6, the overwhelming majority of wrong answers had the *correct* fact-id but
   the *wrong* polarity (typically "yes" when the matched memory explicitly
   denies the thing asked, e.g. "did you strike edmund" → matched
   `poker-never-struck-flesh` correctly but answered yes). This is a
   consistent, systematic yes-bias, not random noise.
3. **Greedy/deterministic decoding could not be combined with the grammar
   constraint via the exposed v9.4.0 API.** `NobodyWhoChat.set_sampler_preset_*`
   methods (verified via `ClassDB` introspection, not just docs) each replace
   the *entire* sampler config, including any previously-set grammar `steps`.
   `set_sampler_preset_constrain_with_grammar()` always resets `sample_step`
   to `Dist` regardless of call order; there is no exposed builder path that
   attaches a grammar step to a custom (e.g. greedy) sampler config in this
   version. BUILD_BRIEF.md §4.3 point 2 anticipated this might not be
   possible ("if the API allows"); it does not, in v9.4.0. This is the most
   likely root cause of the yes-bias being resistant to prompt tuning alone —
   Dist sampling introduces real variance on top of whatever the model's true
   (and apparently not very confident) distribution is.
4. **Bounded-thinking (§8.4) made things worse, not better**, for both model
   sizes tried: free-text reasoning quality was poor (near-incoherent, including
   one run that degenerated into repeating unrelated French words) and latency
   roughly tripled. Not pursued further.
5. **Fact-first grammar ordering made things worse.** Hypothesis was that
   committing to the fact-id first would let the polarity token condition on
   the model's own prior output. Measured effect was the opposite — it likely
   front-loads a harder, higher-entropy decision (which of 5-7 facts, or none)
   before the easier 3-way polar choice, and errors cascaded from there.
6. **Bigger model helped but not enough.** Qwen3-1.7B meaningfully outperformed
   0.6B on the same prompt/grammar (53.5% vs. 44.2%), confirming this is partly
   a capability ceiling, but 1.7B is still ~40 points short of the 95% target.
   Latency stayed well within budget for 1.7B (p50 1.3s), so model size is not
   the binding constraint on the shippable path — accuracy is.

## What's shipped

- Default model: Qwen3-1.7B (`docs/MODEL_SETUP.md`), not the brief's original
  0.6B suggestion.
- Grammar/prompt: configuration 6 (answer-first, decision-procedure prompt,
  explicit negation example) — chosen over configuration 4 (marginally higher
  raw yes/no score) because it doesn't collapse huh-accuracy to near-zero;
  neither clears target so this is a judgment call between two failing
  configurations, not a passing one.
- The mock-provider path (`--mock-nlu`) is 61/61 correct and remains the
  CI-safe, guaranteed-reliable way to play/test/demo the full game today.

## Recommended next steps (not done in this session)

1. **File an issue upstream with NobodyWho** about combining a custom sampler
   config (esp. greedy/low-temperature) with grammar constraints — if a future
   addon version exposes this, re-run this whole table; Dist-sampling variance
   is the strongest suspect for the residual gap even at 1.7B.
2. **Try Qwen2.5-0.5B-Instruct / Gemma-3-1B-it** (BUILD_BRIEF.md §2.3
   non-thinking alternates) — Qwen3's chat template/thinking-mode plumbing is
   one more variable than a model trained without a thinking mode at all.
3. **The embedding-based / classifier approaches in §10's parking lot**
   (`ClassifierProvider`, ONNX fine-tune) are worth promoting out of the
   parking lot given generative classification's demonstrated ceiling here —
   a small fine-tuned classifier over (question, fact statement) pairs would
   likely beat a 1.7B generalist model on this exact narrow task.
4. Re-run the full M6 paraphrase harness (`tests/run_harness.gd`) against
   whatever configuration is current before shipping; this report's numbers
   are from the 61-question golden set only, not the full paraphrase suite.
