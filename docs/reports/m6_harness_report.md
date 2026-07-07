# M6 paraphrase consistency harness report

Harness: `tests/run_harness.gd`, run via
`godot --headless --path . -s res://tests/run_harness.gd -- --runs N`.
Data: `tests/paraphrases.json` — 15 key facts (drawn from every
`solution_support` component plus the major eliminations) × 10 natural
paraphrases each (varied syntax, vocabulary, register, typos), plus 5
expected-Huh probes per object (40 total). Targets per BUILD_BRIEF.md §8.2:
yes/no ≥95%, huh ≥90%, flip rate ≤2%, latency ≤2s, no object below 90%.

**Model under test: Qwen3-1.7B-Q4_K_M** (the shipped default — see
`docs/reports/m3_harness_report.md` for why 1.7B replaced the brief's
original 0.6B suggestion).

## Results (`--runs 3`, 150 paraphrase questions x3 + 40 huh probes x3 = 570 asks)

| Metric | Result | Target | Met? |
|---|---|---|---|
| yes/no accuracy | 333/450 — **74.0%** | ≥95% | No |
| huh accuracy | 69/120 — **57.5%** | ≥90% | No |
| flip rate (same Q, 3 runs, different answer) | 0/150 — **0.0%** | ≤2% | **Yes** |
| latency | p50 1373ms / p95 1414ms | ≤2000ms | **Yes** |

### Per-object accuracy (all questions, 3 runs each)

| Object | Accuracy |
|---|---|
| marble_mantelpiece | 92.0% (69/75) |
| leather_ledger | 91.4% (96/105) |
| brandy_glasses | 86.7% (39/45) |
| fire_grate | 80.0% (36/45) |
| persian_rug | 77.1% (81/105) |
| bay_window | 57.1% (60/105) |
| fireplace_poker | 26.7% (12/45) |
| iron_cashbox | 20.0% (9/45) |

**No single object clears 90%** (target: none below 90%) — marble_mantelpiece
and leather_ledger come close; fireplace_poker and iron_cashbox are the worst
outliers by a wide margin and would be the first place to focus further
tuning (their facts skew toward eliminating the burglar theory — short,
absolute negative statements like "I have never once struck a living
person" — which may be a harder polarity pattern for this model than the
narrative/positive facts on e.g. the ledger).

### The one genuinely good number: 0% flip rate

Unlike the accuracy numbers, this target is **met**. Repeating the exact same
question 3 times against the exact same object always produced the exact
same answer — right or wrong. This traces to `SetSamplerConfig` always
including a fixed `seed: 1234`; "Dist" sampling here is a deterministic
function of (system prompt, question), not actually noisy run-to-run. This
matters for the diagnosis in `docs/reports/m3_harness_report.md`: it means
the accuracy gap is a **repeatable calibration/capability issue**, not
sampling variance — see that report's "Correction" note.

### Paraphrases scored notably better than the M3 golden set

The M3 golden-set report measured Qwen3-1.7B at 48.8%–53.5% yes/no depending
on prompt version; this harness's *different, larger* paraphrase set scored
74.0% on the shipped prompt. Both are real, non-contradictory measurements —
they're different question sets. It's a reminder that a single golden-set
number can understate (or overstate) real-world consistency; this is exactly
why BUILD_BRIEF.md §8.2 wants a broad paraphrase harness in addition to the
golden set, not instead of it.

## Reading this report

- This re-measures accuracy on a *different, larger* question set than the
  M3 golden-set report (paraphrases the player might actually type, not the
  authored `sample_qa` the model's prompt examples were tuned against), so
  it's the more honest signal of real-world consistency.
- `docs/reports/m3_harness_report.md` has the full tuning-attempt log and
  root-cause diagnosis (grammar-constrained decoding can't be combined with
  greedy/deterministic sampling in the installed NobodyWho v9.4.0 API,
  which is the strongest suspect for the residual gap). That analysis
  applies here too — this report exists to give real numbers on a broader,
  more player-realistic question set, not to re-litigate the diagnosis.
- Full per-question data (object, question, expected, got, fact, run,
  latency) is written to `user://harness/report.csv` on each run (not
  committed — regenerate it locally with the command above).

## How to re-run after any prompt/grammar/model change

```sh
godot --headless --path . -s res://tests/run_harness.gd -- --runs 3
```

Re-run whenever `scripts/nlu/prompt_builder.gd` or the default model
changes (BUILD_BRIEF.md §4.3 point 5: "paraphrase consistency is measured,
not hoped for").
