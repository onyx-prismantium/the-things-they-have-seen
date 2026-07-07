# INNOCENT OBJECTS — Build Brief for Claude Code

**Working title:** Innocent Objects (tagline: *"The only innocents in this room are the objects."*)
**Deliverable:** Vertical slice — one room, eight interrogable objects, one solvable murder case.
**Engine:** Godot 4.6.x (stable, GDScript only, 2D)
**LLM runtime:** NobodyWho GDExtension (docs pinned at Godot binding v9.4.0) + a small local GGUF model
**Document version:** 1.0 — July 2026

---

## 0. How to use this document (instructions to Claude Code)

1. Read this entire document before writing any code. The design decisions in §1 are **pillars** — do not change them without asking the human. Everything in §6–§9 is implementation guidance — use your judgment on details, keep the contracts.
2. Build in the milestone order of §7. Each milestone has acceptance criteria; verify them before moving on.
3. **API drift guardrail:** The NobodyWho API referenced here was verified against its docs version 9.4.0 (July 2026). After installing the addon, verify every NobodyWho symbol you use against the *installed* addon source under `addons/nobodywho/` and against `https://docs.nobodywho.ooo/godot/` before wiring it. If names differ, adapt **only** inside `NobodyWhoProvider` (§3.4) — nothing else in the codebase may touch the plugin directly.
4. All case content is data (`res://data/`), never hardcoded in scripts. The complete vertical-slice case data is in §5 — copy it verbatim into the listed files.
5. When something in this brief is ambiguous, prefer: (a) the design pillars, (b) the simplest implementation that satisfies the acceptance criteria, (c) asking the human.
6. Place this file at the repository root and reference it from `CLAUDE.md`.

---

## 1. The game

### 1.1 Pitch

Victorian London, 1887. Laura Sinclair works as a hired spiritualist — families pay her to "cleanse" rooms where terrible things happened. Everyone believes she is a fraud performing séance theatre. In truth she has a real gift, one she must hide: she can speak with objects. Objects cannot lie, cannot forget, and want nothing. At a murder scene, they are the only honest witnesses.

The player clicks any object in the room and types any question in natural language. The object answers with exactly one of three audio-and-text responses: **Yes**, **No**, or a bewildered **Huh?!** From these fragments the player must assemble the truth — **who** did it, **why**, and **with what** — and submit a deduction. Three wrong deductions and the case is lost.

### 1.2 Design pillars (immutable)

1. **Objects never lie.** Every Yes and No is absolute truth. Personality is surface; truth is bedrock. There is no mechanic, bug tolerance, or prompt shortcut that may cause an object to state something false. When in doubt, the system answers Huh?! — confusion is always safe, falsehood never is.
2. **Objects know sensation, not meaning.** An object perceives only through its authored senses (touch, sight, warmth, taste, vibration…). It does not understand abstractions: *murder, guilt, motive, why, killer, crime*. The knife knows it cut; it does not know it killed.
3. **Three answers, exactly.** Yes / No / Huh?! — nothing else ever reaches the player. This is enforced at the sampler level (GBNF grammar), not by prompt hope.
4. **Questions are scarce.** Three answered questions per object. Huh?! is free. Exact repeats are free. One "Focus" refund per case. Scarcity is where thinking happens.
5. **The player is never lied to and never softlocked silently.** Redundant evidence paths (every solution component learnable from ≥3 objects) plus an explicit softlock detector with a diegetic hint.

### 1.3 Response semantics (the rulebook)

This is the exact contract the NLU layer must implement:

| Response | Meaning | Costs a question? |
|---|---|---|
| **Yes** | An authored memory of this object confirms the asserted fact. | Yes |
| **No** | An authored memory of this object clearly establishes the asserted thing did **not** happen. | Yes |
| **Huh?!** | Everything else. See list below. | **No** |

**Huh?! covers, exhaustively:**
- The question uses concepts outside the object's senses (murder, guilt, motive, "why", legal/moral terms).
- The question is not a polar (yes/no) question — who/what/when/where/why/how questions always get Huh?!
- The question bundles multiple questions at once.
- The question asks about something none of the object's memories cover (within its senses but unrecorded).
- The input is not a question at all (greetings, insults, statements).

**Critical consequence for authoring:** because objects never lie, **No is only available when an explicit negative memory exists.** "Did a stranger climb through you?" can only be answered No if the window has an authored memory like *"No living soul climbed through me that night."* Negative facts are first-class authored content (see §5). If no memory bears on the question, the answer is Huh?! — never a guessed No.

**Identity rule:** objects recognize only the people listed in their `people_known` (long exposure: household members, frequent visitors). Anyone else — or anyone masked by gloves — is "an unfamiliar presence." An object can therefore never confirm the identity of the gloved hand directly. This single rule is the anti-brute-force mechanism: asking every object "Did Silas kill him?" always yields Huh?! (abstract concept), and the staging was done in gloves, so **who** must be assembled from association (who drank, whose boots, who stood over the body), never read off a single answer.

### 1.4 What the vertical slice must prove

- Talking to a knife is *fun*: natural-language questions feel understood; Huh?! feels like a charming limitation, not a wall.
- Answers are **consistent** across paraphrases (measured by the harness in §8, targets: ≥95% on Yes/No keys, ≥90% on Huh keys).
- The case is solvable, the economy creates tension, brute force fails, and the deduction win lands.

---

## 2. Technical foundation

### 2.1 Engine & project settings

- **Godot 4.6.x stable** (4.6.3 or newer patch of the 4.6 line). GDScript only, statically typed. No C#.
- New project, **Compatibility** renderer (pure 2D, lightest, runs everywhere; NobodyWho brings its own Vulkan/Metal context for inference independent of Godot's renderer choice).
- Base resolution 1920×1080, stretch mode `canvas_items`, aspect `expand`.
- Art for the slice: flat-color placeholder shapes / simple free sprites. Readability over beauty. Every interactive object gets a hover outline (shader or modulate).

### 2.2 NobodyWho plugin

- Install **NobodyWho** from the Godot Asset Library (asset "NobodyWho | Local LLMs for dialogue") or the GitHub releases zip (`nobodywho-ooo/nobodywho`). Enable the extension; restart editor.
- License: EUPL-1.2 — explicitly fine for proprietary/commercial games (linking exemption stated by the authors). Do not fork/modify the plugin source; if changes are needed, wrap instead.
- Key API surface used (verified against docs v9.4.0 — re-verify on install per §0.3):
  - `NobodyWhoModel` node — property `model_path` (GGUF file).
  - `NobodyWhoChat` node — properties `model_node`, `system_prompt`; methods `start_worker()`, `ask(prompt: String)`, `reset_context()`, `set_sampler_preset_constrain_with_grammar(gbnf: String)`; signal `response_finished(text: String)`.
  - Sampling configuration: see `https://docs.nobodywho.ooo/godot/sampling` at implementation time; aim for deterministic decoding (greedy / temperature 0, fixed seed) **within** the grammar constraint if the API exposes it. The grammar is the hard guarantee; determinism is belt-and-suspenders for consistency.
- Platforms today: Windows/Linux/macOS (+Android). Consoles are out of scope for the slice and will require a direct llama.cpp integration later — which is exactly why **all** plugin contact is quarantined inside one provider class (§3.4).

### 2.3 Model

| Role | Model | Notes |
|---|---|---|
| **Default** | `Qwen3-0.6B` GGUF, Q4_K_M (e.g. `hf://NobodyWho/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf`) | ~0.5 GB, strong instruction following for size, Apache-2.0. |
| Quality fallback | `Qwen3-1.7B` GGUF Q4 | If 0.6B fails harness targets. |
| Non-thinking alternates | `Qwen2.5-0.5B-Instruct`, `Gemma-3-1B-it`, `Llama-3.2-1B-Instruct` (GGUF) | Try if think-mode interactions cause trouble. |
| Perf experiment | `SmolLM2-360M-Instruct` GGUF | Only if latency demands; expect harness regression. |

- Model file location: `user://models/` (downloaded on first run or manually placed); keep `res://` free of gigabyte blobs. Add a boot check with a clear "place model file here" error screen listing the expected path + filename. Do not implement an in-game downloader for the slice.
- **Thinking-model note:** Qwen3 is a hybrid thinking model. Our grammar contains **zero free-text regions**, so `<think>` blocks are impossible to emit — the first token is already constrained to `yes|no|huh`. Additionally disable thinking via prompt (`/no_think` in the system prompt) to keep the model in non-thinking chat-template mode. If answer quality suffers, §8.4 describes a bounded-thinking grammar experiment — run it only if the harness demands.
- Latency budget: ≤ 2 s per answer on a mid-range desktop GPU (output is ~6–10 tokens; prompt ~700–1000 tokens; this is comfortably achievable). Hard timeout 8 s → treat as Huh?! (free), log it.

### 2.4 Licensing summary

- Godot: MIT. NobodyWho: EUPL-1.2 (commercial use OK). Qwen3 weights: Apache-2.0. All compatible with a commercial release. Keep a `THIRD_PARTY_LICENSES.md` from day one.

---

## 3. Architecture

### 3.1 Folder structure

```
res://
  addons/nobodywho/            # plugin (installed, untouched)
  data/
    cases/silent_study/
      case.json                # meta, lists, solution, redundancy map
      objects/                 # one JSON per interrogable object
        fireplace_poker.json
        bay_window.json
        marble_mantelpiece.json
        brandy_glasses.json
        leather_ledger.json
        iron_cashbox.json
        persian_rug.json
        fire_grate.json
  scenes/
    main.tscn                  # root: boots, loads case, owns UI layers
    room/room_study.tscn       # the study; instantiates InteractiveObject scenes
    room/interactive_object.tscn
    ui/question_panel.tscn     # input line, transcript, question pips
    ui/response_bubble.tscn    # answer word + flavor line + blip audio
    ui/deduction_board.tscn    # three columns, submit, attempts left
    ui/case_briefing.tscn      # intro text + pocket-watch tutorial
    ui/end_screen.tscn         # win / lose epilogues
  scripts/
    autoload/game_state.gd     # singleton: all mutable run state
    autoload/case_loader.gd    # singleton: parses data/ into typed objects
    autoload/nlu_service.gd    # singleton: question queue -> provider -> QAResult
    autoload/audio_director.gd # singleton: voice blips + UI sounds
    nlu/nlu_provider.gd        # abstract base class
    nlu/nobodywho_provider.gd  # ONLY file that touches the plugin
    nlu/mock_provider.gd       # scripted answers for tests/dev
    nlu/prompt_builder.gd      # system prompt + grammar generation (pure functions)
    room/interactive_object.gd
    ui/*.gd
  tests/
    paraphrases.json           # harness input (seeded from §5 sample tables)
    run_harness.gd             # headless consistency harness (§8)
  tools/
    generate_blips.py          # one-shot voice-blip WAV generator (§6.4)
  assets/
    audio/blips/               # generated: {object_id}_{yes|no|huh}.wav
    art/                       # placeholders
```

### 3.2 Autoload singletons

| Autoload | Responsibility |
|---|---|
| `CaseLoader` | Loads and validates `case.json` + object JSONs into typed `RefCounted` classes (`CaseDef`, `ObjectDef`, `FactDef`). Fails loudly on schema errors (missing fact ids, duplicate ids, solution ids not in lists, redundancy check §5.6). |
| `GameState` | `questions_used: Dictionary[object_id -> int]`, `learned_facts: Dictionary[fact_id -> true]`, `qa_cache: Dictionary[cache_key -> QAResult]`, `transcript: Array`, `deduction_attempts_left: int = 3`, `focus_available: bool = true`. Emits signals: `question_answered`, `fact_learned`, `economy_changed`, `softlock_state_changed`, `case_ended`. |
| `NluService` | Public API: `await NluService.ask(object_def, question) -> QAResult`. Owns a FIFO queue (one in-flight request max), the cache lookup, normalization, timeout, validation, and the active `NluProvider`. Provider chosen by `--mock-nlu` cmdline flag / project setting. |
| `AudioDirector` | `play_answer(object_id, answer)`, UI clicks, ambience. |

### 3.3 The life of a question (data flow)

```
Player clicks object -> QuestionPanel opens (shows pips: ●●○ etc.)
Player types "did you touch his blood?" -> submit
  |
  v
NluService.ask(object_def, text)
  1. normalize(text): trim, collapse whitespace, lowercase, strip trailing ?/!/.
  2. cache key = object_id + "::" + normalized
     HIT  -> return cached QAResult with .from_cache = true   (FREE, replay answer,
             ResponseBubble uses the object's "repeat" flavor line)
     MISS -> enqueue
  3. provider.answer(object_def, normalized_question) -> raw "answer|fact-id"
  4. parse + validate:
       - format must match grammar (it will — GBNF), else -> huh|none + log ERROR
       - fact-id must belong to this object or be "none", else -> huh|none + log
       - answer in {yes,no} requires fact-id != none; if violated -> huh|none + log
  5. store in cache; if yes/no: GameState.consume_question(object_id),
     GameState.mark_learned(fact_id)
  6. return QAResult { answer, fact_id, from_cache, latency_ms }
  |
  v
ResponseBubble: answer word + flavor line (object JSON) + AudioDirector blip
GameState.check_softlock() after every consumed question (§6.6)
```

Rules encoded above, stated plainly:
- **Exact repeats are free** and always identical (cache). The bubble uses the `repeat` flavor line ("I *told* you, dear.").
- **Huh?! is free** — `consume_question` is only called for yes/no.
- The UI disables input while a request is in flight; the object shows a small "listening…" shimmer. On the 8 s timeout, show Huh?! (free), log `TIMEOUT`.

### 3.4 The provider abstraction (console-proofing + testability)

```gdscript
# nlu_provider.gd
class_name NluProvider
extends RefCounted

## Returns raw model output in the pipe format: "yes|fact-id" | "no|fact-id" | "huh|none"
## Must never throw; on internal failure return "huh|none".
func answer(object_def: ObjectDef, normalized_question: String) -> String:
    assert(false, "abstract")
    return "huh|none"

func warm_up() -> void: pass       # load model / no-op
func is_ready() -> bool: return true
```

- `NobodyWhoProvider` implements this using **one** `NobodyWhoModel` node and **one** `NobodyWhoChat` node (created in code, added under the service). Per request: set `system_prompt` for the object, `set_sampler_preset_constrain_with_grammar(grammar_for(object))`, `reset_context()`, `ask(question)`, `await response_finished`. Grammars and prompts are built once per object at case load and cached. Verify whether `reset_context()` preserves `system_prompt` in the installed version (the official weapon-generator example implies it does); if not, re-set the prompt each request.
- `MockProvider` reads the per-object `sample_qa` tables from the case data (§5) and answers by normalized-string lookup; unknown questions -> `huh|none`. The whole game must be playable end-to-end with `--mock-nlu` and no model file present. CI runs mock-only.
- Future (out of slice): `ClassifierProvider` (ONNX), `LlamaCppDirectProvider` (consoles). The abstraction exists so these are drop-ins.

---

## 4. The NLU pipeline (the heart of the game)

### 4.1 Output format & grammar

Model output is a single compact line — pipe-separated, per NobodyWho's own performance guidance (JSON is ~4× more tokens for nothing):

```
yes|rug-silas-stood-over
no|poker-never-struck-flesh
huh|none
```

The GBNF grammar is generated **per object** so the fact enum only contains that object's fact ids. Note the structural elegance: `huh` is fused with `none`, so the model *cannot* attach a fact to a Huh, and *must* attach one to a yes/no.

```
root ::= polar "|" fact | "huh|none"
polar ::= "yes" | "no"
fact ::= "poker-never-struck-flesh" | "poker-gloved-grip" | "poker-forced-latch" | ...
```

GBNF footguns (from the official docs): rule names may not contain underscores — use dashes in rule names; terminal strings are unrestricted but we use dashed fact ids anyway for semantic-soundness (full hyphenated words carry meaning to the model; never use opaque codes like `F07`).

```gdscript
# prompt_builder.gd (pure, unit-testable)
static func build_grammar(obj: ObjectDef) -> String:
    var ids := obj.facts.map(func(f): return '"%s"' % f.id)
    return 'root ::= polar "|" fact | "huh|none"\n' \
         + 'polar ::= "yes" | "no"\n' \
         + 'fact ::= %s\n' % " | ".join(ids)
```

### 4.2 The system prompt template

Built once per object at load. Placeholders in braces. Keep total prompt ≤ ~1000 tokens (facts included) — it fits Qwen3-0.6B comfortably and keeps latency low.

```
/no_think
You are {OBJECT_DISPLAY_NAME}, an object in a Victorian study, questioned by a psychic
detective. You are not a person. You cannot lie. You may only answer what your own
memories support.

YOUR SENSES: {SENSES}. You perceived the world only through these.
YOU RECOGNIZE only these people (long familiarity): {PEOPLE_KNOWN}. Anyone else — or
any hand hidden in a glove — is only "an unfamiliar presence"; you cannot identify them.

YOUR MEMORIES — the complete list of everything you know:
{FACTS_BLOCK}            # lines of:  - fact-id: first-person statement

TASK: The detective asks exactly one question. Output exactly one line:
ANSWER|FACT-ID

Rules:
- yes  -> one memory confirms what the question asserts. Give that memory's fact-id.
- no   -> one memory clearly establishes it did NOT happen. Give that memory's fact-id.
- huh|none -> everything else: the question uses ideas beyond your senses (murder,
  guilt, motive, why, crime, killer); or is not a yes/no question (who/what/when/
  where/why/how); or asks several things at once; or none of your memories cover it;
  or it is not a question. When uncertain, always huh|none. Never invent. Never
  answer from general knowledge — only from YOUR MEMORIES above.

Examples (from a different object, a candle, for format only):
Q: did a hand snuff you out?            -> yes|candle-snuffed-by-hand
Q: were you still burning at midnight?  -> no|candle-out-by-ten
Q: did the murderer touch you?          -> huh|none
Q: who lit you?                         -> huh|none
Q: were you lit, and did he see you?    -> huh|none
```

Notes for Claude Code:
- `{FACTS_BLOCK}` renders every fact as `- id: statement` — the statements are first-person sensory memories (see §5). The model's entire "world knowledge of the case" is this block; leakage is impossible because other objects' facts are never in context.
- The candle examples are deliberately **not** from the case (no leakage into answers) and cover the five Huh causes plus a negative-fact No.
- Persona/voice does **not** go into the prompt. Flavor is applied by the game (voice lines + blips) after classification. The model does classification only — this is what keeps a 0.6B model reliable.

### 4.3 Consistency measures (ranked)

1. **Grammar** — malformed output is impossible.
2. **Deterministic decoding** — greedy/temp-0 + fixed seed if the sampling API allows (check `godot/sampling` docs at install; the grammar preset may already imply suitable settings).
3. **Exact-repeat cache** — identical question can never get a different answer.
4. **Post-validation** (§3.3 step 4) — incoherent (answer,fact) pairs degrade to Huh?! rather than reaching the player. A logged validation failure is a prompt bug to fix, not a player-facing event.
5. **The harness** (§8) — paraphrase consistency is measured, not hoped for. Prompt wording changes must re-run the harness.
6. Post-slice (parking lot): embedding-based paraphrase cache using NobodyWho's embeddings module, so "Did you cut her?" / "Did you slice her?" hit one cached answer.

### 4.4 Latency UX

While in flight: the clicked object gently pulses; Laura's cursor becomes the pocket watch; input locked. Answers stream in a handful of tokens — do not render partials; wait for `response_finished`. If players ask during another object's pending question, queue silently (FIFO, max depth 1 — further input locked).

---

## 5. Data model & the complete vertical-slice case

### 5.1 Schemas

**`case.json`** — case meta, deduction lists, solution, support map, presentation text.
**`objects/*.json`** — one per interrogable object:

| Field | Type | Purpose |
|---|---|---|
| `id` | String | snake_case, stable, used everywhere |
| `display_name` | String | UI |
| `persona` | String | Authoring note only (never sent to the model) |
| `senses` | Array[String] | Injected into prompt (`{SENSES}`) |
| `people_known` | Array[String] | suspect/person ids; injected into prompt |
| `voice` | Object | `{ "waveform": "sine|square|triangle|saw", "base_hz": int }` for blip generation |
| `voice_lines` | Object | `{ "yes": [..], "no": [..], "huh": [..], "repeat": [..] }` — flavor text shown with the answer; pick randomly |
| `facts` | Array | `{ "id": "dashed-id", "statement": "first-person sensory memory" }` — **the complete knowledge of the object.** Includes authored negative facts. |
| `sample_qa` | Array | `{ "q": "...", "a": "yes|no|huh", "fact": "id-or-none" }` — golden examples: they seed the MockProvider **and** the consistency harness. |

Validation on load (`CaseLoader`): unique ids across all facts; every `solution_support` fact id exists; every `sample_qa.fact` exists on that object or is `none`; every solution id exists in its list; **redundancy rule: each of the three solution components must have supporting facts spread over ≥3 distinct objects** — assert this, it is a design guarantee.

### 5.2 The case: *The Silent Study*

Premise for the player (briefing screen):

> Kensington, November 1887. Edmund Hartwell — tea and silk, imported; opinions, exported — was found dead in his study at eleven o'clock, the night before last. The window hangs forced, the cash box gapes empty, the fireplace poker lies bloodied on the hearth. Scotland Yard is satisfied: a burglary interrupted, a blow struck, a man dead at fifty-one.
>
> The widow is not satisfied. She has hired you — Laura Sinclair, spiritualist, cleanser of unquiet rooms — to "settle the air" before the funeral. The constable at the door thinks you are a fraud. Let him.
>
> The room remembers. Ask it.

The truth (authoring reference — never shown to the player):

> Silas Crane, Edmund's partner, has been thinning the firm's accounts for months. That afternoon Edmund found the doctored figures, tore the falsified page from the ledger in fury, and summoned Silas for their usual evening brandy. Confronted with the page, Silas shoved him; Edmund's head struck the corner of the marble mantelpiece and he died on the hearth end of the rug. Silas — gloved before he touched anything — staged a burglary: took Edmund's key from his watch chain, emptied the cash box, levered the window latch open *from the inside* with the poker, wiped the poker's tip through the cooling blood, fed the torn ledger page to the low fire, and left by the front door at a quarter past ten. Dora Finch found the body at eleven.

### 5.3 `res://data/cases/silent_study/case.json`

```json
{
  "id": "silent_study",
  "title": "The Silent Study",
  "briefing": "Kensington, November 1887. Edmund Hartwell — tea and silk, imported; opinions, exported — was found dead in his study at eleven o'clock, the night before last. The window hangs forced, the cash box gapes empty, the fireplace poker lies bloodied on the hearth. Scotland Yard is satisfied: a burglary interrupted, a blow struck, a man dead at fifty-one.\n\nThe widow is not satisfied. She has hired you — Laura Sinclair, spiritualist, cleanser of unquiet rooms — to 'settle the air' before the funeral. The constable at the door thinks you are a fraud. Let him.\n\nThe room remembers. Ask it.",
  "police_theory": "A burglar entered by the window, was surprised by Mr. Hartwell, struck him with the poker, emptied the cash box, and fled the way he came.",
  "people": [
    { "id": "edmund-hartwell", "name": "Edmund Hartwell", "note": "the victim" },
    { "id": "eleanor-hartwell", "name": "Eleanor Hartwell", "note": "the widow" },
    { "id": "silas-crane", "name": "Silas Crane", "note": "business partner, frequent visitor" },
    { "id": "dora-finch", "name": "Dora Finch", "note": "housemaid" }
  ],
  "suspects": [
    { "id": "silas-crane", "name": "Silas Crane", "blurb": "Edmund's business partner of eleven years. Keeps the firm's books. Was 'at his club' that evening." },
    { "id": "eleanor-hartwell", "name": "Eleanor Hartwell", "blurb": "The widow. Heiress to the estate. Married nineteen years; retired early with a headache." },
    { "id": "dora-finch", "name": "Dora Finch", "blurb": "The housemaid. Found the body at eleven. Recently docked a week's wages over a broken vase." },
    { "id": "thomas-webb", "name": "Thomas Webb", "blurb": "Footman, dismissed a fortnight ago for drink. Seen loitering in the mews since." },
    { "id": "augustus-pryce", "name": "Augustus Pryce", "blurb": "The family solicitor. Drafted a new will last month. Called at the house on Tuesday." },
    { "id": "unknown-burglar", "name": "A burglar unknown", "blurb": "Scotland Yard's man: in by the window, out with the cash, the poker between." }
  ],
  "motives": [
    { "id": "conceal-embezzlement", "label": "To conceal embezzlement" },
    { "id": "inheritance", "label": "To claim an inheritance" },
    { "id": "jealous-affair", "label": "Jealousy over an affair" },
    { "id": "dismissal-revenge", "label": "Revenge for a dismissal" },
    { "id": "gambling-debts", "label": "Desperation over gambling debts" },
    { "id": "simple-robbery", "label": "Simple robbery" }
  ],
  "weapons": [
    { "id": "fireplace-poker", "label": "The fireplace poker" },
    { "id": "marble-mantelpiece", "label": "The marble mantelpiece" },
    { "id": "brass-candlestick", "label": "The brass candlestick" },
    { "id": "letter-opener", "label": "The letter opener" },
    { "id": "crystal-decanter", "label": "The crystal decanter" },
    { "id": "walking-cane", "label": "A walking cane" }
  ],
  "solution": {
    "culprit": "silas-crane",
    "motive": "conceal-embezzlement",
    "weapon": "marble-mantelpiece"
  },
  "solution_support": {
    "culprit": ["window-silas-arrive-door", "window-silas-leave", "window-papers-quarrel", "glasses-silas-lips", "rug-treads-known", "rug-silas-stood-over", "ledger-second-hand"],
    "motive": ["ledger-second-hand", "ledger-figures-altered", "ledger-torn-page", "ledger-edmund-pressed", "grate-paper-fed", "grate-ledger-paper", "window-papers-quarrel"],
    "weapon": ["mantel-head-struck", "mantel-edmund-warmth", "mantel-slid-down", "mantel-pushed-not-fell", "rug-edmund-fell-hearth", "rug-blood-hearth", "grate-thump-before"]
  },
  "elimination_facts": ["poker-never-struck-flesh", "poker-blood-cold", "poker-forced-latch", "window-latch-forced-inside", "window-nobody-through", "window-garden-empty", "cashbox-key-opened", "cashbox-not-forced", "glasses-only-brandy", "rug-no-stranger"],
  "objects": ["fireplace_poker", "bay_window", "marble_mantelpiece", "brandy_glasses", "leather_ledger", "iron_cashbox", "persian_rug", "fire_grate"],
  "tutorial_watch": [
    "(Your pocket watch, warm in your palm, ticks against your thumb.)",
    "\"They will all talk to you, Laura. But remember what we are. We remember what we feel — not what it means.\"",
    "\"Ask us yes or no. Ask us what we touched, saw, tasted, carried. Ask us WHY and you will only confuse us.\"",
    "\"They tire quickly — three true answers each, so spend them well. A confused 'Huh?!' costs you nothing. And if you are truly stuck... wind me, once, and I will give one of them their breath back.\""
  ],
  "deduction_feedback": [
    "The room is silent. Nothing rings true.",
    "One thread rings true. Two do not.",
    "Two threads ring true. One does not.",
    "Every thread rings true."
  ],
  "epilogue_win": "You write three lines on the back of a calling card and leave it with the constable: the partner, the books, the mantel's corner. By Friday, Silas Crane's gloves are found in the mews behind his club, and the torn page's ash is matched to the ledger's wound. Scotland Yard announces that diligent police work has prevailed.\n\nYou were paid to cleanse a room. The room, as ever, did the work. On the way out you rest a hand on the mantelpiece — a long moment. It did not mean to. You know.\n\nThe only innocents in this room were the objects.",
  "epilogue_lose": "Three times you speak, and three times the constable's patience thins. The widow pays you and does not meet your eye. The verdict stands: person or persons unknown.\n\nBehind you, as the door closes, the study holds everything it told you — every yes, every no — patient, exact, and unheard. Objects do not forget.\n\nPerhaps another room. Perhaps another year. They will still remember."
}
```

### 5.4 Object files (complete, copy verbatim)

**`objects/fireplace_poker.json`**

```json
{
  "id": "fireplace_poker",
  "display_name": "The Fireplace Poker",
  "persona": "Gruff old soldier. Deeply insulted at being called the murder weapon. Answers like giving testimony at court-martial.",
  "senses": ["grip and touch", "temperature", "impact and force"],
  "people_known": ["edmund-hartwell", "eleanor-hartwell", "dora-finch"],
  "voice": { "waveform": "square", "base_hz": 110 },
  "voice_lines": {
    "yes": ["Aye. That is so.", "Yes. On my iron, yes."],
    "no": ["No, ma'am. Emphatically not.", "It did NOT happen. Write that down."],
    "huh": ["...I beg your pardon?", "Hng? You've lost me, ma'am."],
    "repeat": ["Asked and answered, ma'am. Asked and answered."]
  },
  "facts": [
    { "id": "poker-never-struck-flesh", "statement": "I have never once struck a living person. Not that night. Not ever." },
    { "id": "poker-gloved-grip", "statement": "Late that night I was gripped by a hand in a leather glove — not bare skin. Gloves tell me nothing of whose hand it was." },
    { "id": "poker-forced-latch", "statement": "That gloved hand jammed my tip against the window latch and levered it until the latch gave way." },
    { "id": "poker-blood-cold", "statement": "My tip was wiped through blood on the rug — blood that had already gone cool and sticky when I touched it." },
    { "id": "poker-dropped-hearth", "statement": "Afterwards I was dropped carelessly on the hearth stones and left lying there." },
    { "id": "poker-edmund-hands", "statement": "Edmund stirred the fire with me most evenings for years; I know his bare hand well. His hand did not hold me that night." }
  ],
  "sample_qa": [
    { "q": "did you kill edmund", "a": "huh", "fact": "none" },
    { "q": "were you used to murder him", "a": "huh", "fact": "none" },
    { "q": "did you strike edmund", "a": "no", "fact": "poker-never-struck-flesh" },
    { "q": "did you touch his blood", "a": "yes", "fact": "poker-blood-cold" },
    { "q": "was the blood still warm when you touched it", "a": "no", "fact": "poker-blood-cold" },
    { "q": "did a gloved hand hold you that night", "a": "yes", "fact": "poker-gloved-grip" },
    { "q": "did someone force the window latch with you", "a": "yes", "fact": "poker-forced-latch" },
    { "q": "who held you that night", "a": "huh", "fact": "none" },
    { "q": "did edmund hold you that night", "a": "no", "fact": "poker-edmund-hands" }
  ]
}
```

**`objects/bay_window.json`**

```json
{
  "id": "bay_window",
  "display_name": "The Bay Window",
  "persona": "Theatrical gossip. Sees EVERYTHING, darling, and is thrilled to finally be asked. Melodramatic about her broken latch.",
  "senses": ["sight of the garden and of the room reflected in my glass", "touch upon my frame and latch", "draught and cold"],
  "people_known": ["edmund-hartwell", "eleanor-hartwell", "silas-crane", "dora-finch"],
  "voice": { "waveform": "sine", "base_hz": 520 },
  "voice_lines": {
    "yes": ["Oh, YES, darling.", "Mm, yes — I saw it ALL."],
    "no": ["No, darling. Absolutely not.", "Not through MY glass, no."],
    "huh": ["Come again, darling?", "I'm sure I don't follow, dear."],
    "repeat": ["Darling, we've BEEN through this."]
  },
  "facts": [
    { "id": "window-latch-forced-inside", "statement": "My latch was broken from within the room, levered outward — not from the garden side." },
    { "id": "window-nobody-through", "statement": "No living soul climbed through me that night. I would have felt every button of them." },
    { "id": "window-garden-empty", "statement": "The garden lay empty the whole evening. Only fog moved out there." },
    { "id": "window-silas-arrive-door", "statement": "At nine o'clock I watched Silas Crane come up the front path, as he so often does, and he was let in at the front door." },
    { "id": "window-silas-leave", "statement": "A little past ten, Silas Crane left by the front door, hat pulled low, walking fast." },
    { "id": "window-papers-quarrel", "statement": "In my glass I saw Edmund brandish a torn page at Silas Crane, and then the two of them shouting." },
    { "id": "window-left-open", "statement": "I was left hanging open to the cold night until the maid Dora shut me, much later." }
  ],
  "sample_qa": [
    { "q": "did a burglar climb through you", "a": "huh", "fact": "none" },
    { "q": "did anyone climb through you that night", "a": "no", "fact": "window-nobody-through" },
    { "q": "was your latch forced from outside", "a": "no", "fact": "window-latch-forced-inside" },
    { "q": "was your latch broken from inside the room", "a": "yes", "fact": "window-latch-forced-inside" },
    { "q": "did you see silas crane that night", "a": "yes", "fact": "window-silas-arrive-door" },
    { "q": "did silas arrive and also leave that night", "a": "huh", "fact": "none" },
    { "q": "did you see anyone in the garden", "a": "no", "fact": "window-garden-empty" },
    { "q": "did edmund wave a torn page at silas", "a": "yes", "fact": "window-papers-quarrel" },
    { "q": "why did they argue", "a": "huh", "fact": "none" }
  ]
}
```

**`objects/marble_mantelpiece.json`**

```json
{
  "id": "marble_mantelpiece",
  "display_name": "The Marble Mantelpiece",
  "persona": "Solemn, slow, grieving. Warmed Edmund's hands for twenty years and now carries a guilt it cannot name. Speaks quietly. The emotional core of the room.",
  "senses": ["impact and force through my stone", "warmth of hands and bodies", "weight leaning upon me", "vibration of voices"],
  "people_known": ["edmund-hartwell", "eleanor-hartwell", "silas-crane", "dora-finch"],
  "voice": { "waveform": "sine", "base_hz": 82 },
  "voice_lines": {
    "yes": ["...Yes.", "Yes. I felt it."],
    "no": ["No.", "No. That is not what my stone remembers."],
    "huh": ["...I do not understand.", "Those words mean nothing to stone."],
    "repeat": ["You asked me that. The answer has not changed. It never will."]
  },
  "facts": [
    { "id": "mantel-two-voices", "statement": "Two voices buzzed against my stone that evening — low at first, then sharp and loud." },
    { "id": "mantel-head-struck", "statement": "A man's head struck my corner that night. Hard. I felt it through all my stone." },
    { "id": "mantel-edmund-warmth", "statement": "The warmth against my corner was Edmund's. I have warmed his hands for twenty years. I know his warmth." },
    { "id": "mantel-pushed-not-fell", "statement": "He came at me fast and crooked, with the force of a man shoved — not the slow tilt of a man stumbling alone." },
    { "id": "mantel-slid-down", "statement": "He slid down against me to the hearth and did not rise. His warmth went out of him against my stone." },
    { "id": "mantel-poker-after", "statement": "The poker's stand rests against me; the poker was lifted from it only after he was still, not before." }
  ],
  "sample_qa": [
    { "q": "did edmund's head strike you", "a": "yes", "fact": "mantel-head-struck" },
    { "q": "did you kill him", "a": "huh", "fact": "none" },
    { "q": "did he stumble and fall on his own", "a": "no", "fact": "mantel-pushed-not-fell" },
    { "q": "was he pushed", "a": "yes", "fact": "mantel-pushed-not-fell" },
    { "q": "was it silas who pushed him", "a": "huh", "fact": "none" },
    { "q": "did he get up again", "a": "no", "fact": "mantel-slid-down" },
    { "q": "was the poker taken from its stand before he fell", "a": "no", "fact": "mantel-poker-after" },
    { "q": "did two people argue in this room", "a": "yes", "fact": "mantel-two-voices" }
  ]
}
```

**`objects/brandy_glasses.json`**

```json
{
  "id": "brandy_glasses",
  "display_name": "The Brandy Glasses",
  "persona": "A tipsy, giggling pair — they finish each other's sentences and find everything scandalous and delightful. They watched a man die and do not understand that. The tonal signature of the game.",
  "senses": ["lips and moustaches", "hands that hold us", "taste of what fills us", "warmth of breath"],
  "people_known": ["edmund-hartwell", "eleanor-hartwell", "silas-crane"],
  "voice": { "waveform": "triangle", "base_hz": 740 },
  "voice_lines": {
    "yes": ["Oui, oui! — hee!", "Yesss — *clink* — yes!"],
    "no": ["Non, non, non!", "Nooo — *hic* — not at all!"],
    "huh": ["Hee hee... quoi?", "*clink?* ...huh?"],
    "repeat": ["You ASKED us that — hee! — we remember, we're not THAT tipsy."]
  },
  "facts": [
    { "id": "glasses-two-drinkers", "statement": "Two of us were filled and drunk from that night. Two mouths. Two warm hands." },
    { "id": "glasses-edmund-lips", "statement": "One set of lips was Edmund's — we would know his prickly moustache anywhere." },
    { "id": "glasses-silas-lips", "statement": "The other lips were Silas Crane's. He always gulps. No savouring at all." },
    { "id": "glasses-quarrel-set-down", "statement": "We were both banged down hard, mid-drink, and never picked up again. Nobody finished us." },
    { "id": "glasses-only-brandy", "statement": "Nothing but Edmund's good brandy was in us that night — we would have tasted any mischief." },
    { "id": "glasses-no-lady", "statement": "No lady's lips touched us that night. Mrs. Hartwell takes sherry anyway." }
  ],
  "sample_qa": [
    { "q": "did silas crane drink here that night", "a": "yes", "fact": "glasses-silas-lips" },
    { "q": "did edmund drink alone that night", "a": "no", "fact": "glasses-two-drinkers" },
    { "q": "was there poison in you", "a": "no", "fact": "glasses-only-brandy" },
    { "q": "did mrs hartwell drink from you that night", "a": "no", "fact": "glasses-no-lady" },
    { "q": "were you set down suddenly", "a": "yes", "fact": "glasses-quarrel-set-down" },
    { "q": "did silas murder edmund", "a": "huh", "fact": "none" },
    { "q": "what were they talking about", "a": "huh", "fact": "none" }
  ]
}
```

**`objects/leather_ledger.json`**

```json
{
  "id": "leather_ledger",
  "display_name": "The Ledger",
  "persona": "Prim, exacting head clerk. Utterly scandalized — not by the death, but by the state of the FIGURES. Pronounces 'irregular' like a curse.",
  "senses": ["pen pressure and ink upon my pages", "hands that open and turn me", "tearing"],
  "people_known": ["edmund-hartwell", "silas-crane"],
  "voice": { "waveform": "square", "base_hz": 330 },
  "voice_lines": {
    "yes": ["Correct. Duly recorded.", "Yes. It is entered so."],
    "no": ["Incorrect.", "No. The record shows otherwise."],
    "huh": ["That is... not a ledger matter.", "I cannot balance that question."],
    "repeat": ["See previous entry. Do keep up."]
  },
  "facts": [
    { "id": "ledger-edmund-pressed", "statement": "That afternoon Edmund's pen pressed into my pages so hard it nearly tore them. Fury, written in copperplate." },
    { "id": "ledger-torn-page", "statement": "That same afternoon Edmund's own hand tore a page out of me. The indignity of it." },
    { "id": "ledger-second-hand", "statement": "For months, a second hand has written in me after hours — a lighter pen. Silas Crane's hand. I know his loops." },
    { "id": "ledger-figures-altered", "statement": "Figures in me were scratched out and rewritten by that second hand. Sums made smaller. Most irregular." },
    { "id": "ledger-rifled-night", "statement": "Late that night, gloved fingers rifled my pages in haste and stopped at the wound where the page was torn." }
  ],
  "sample_qa": [
    { "q": "did silas crane write in you", "a": "yes", "fact": "ledger-second-hand" },
    { "q": "were your figures altered", "a": "yes", "fact": "ledger-figures-altered" },
    { "q": "did edmund tear a page from you", "a": "yes", "fact": "ledger-torn-page" },
    { "q": "did silas steal from the company", "a": "huh", "fact": "none" },
    { "q": "did a gloved hand search you that night", "a": "yes", "fact": "ledger-rifled-night" },
    { "q": "was edmund calm when he last wrote in you", "a": "no", "fact": "ledger-edmund-pressed" },
    { "q": "why were the figures changed", "a": "huh", "fact": "none" }
  ]
}
```

**`objects/iron_cashbox.json`**

```json
{
  "id": "iron_cashbox",
  "display_name": "The Cash Box",
  "persona": "Paranoid, miserly whisperer. Grieves its banknotes like children. Deeply proud of never having been forced.",
  "senses": ["key or force upon my lock", "weight of my contents", "fingers within me"],
  "people_known": ["edmund-hartwell", "dora-finch"],
  "voice": { "waveform": "saw", "base_hz": 196 },
  "voice_lines": {
    "yes": ["...yes. Yes, it is so.", "Yes — keep your voice DOWN — yes."],
    "no": ["No. No no no.", "Never. Not once."],
    "huh": ["...what? WHAT?", "Speak plainly or not at all. ...What?"],
    "repeat": ["I said it once. Once was already too loud."]
  },
  "facts": [
    { "id": "cashbox-key-opened", "statement": "I was opened that night with my own true key. No prying. No violence. The key." },
    { "id": "cashbox-not-forced", "statement": "There is not one scratch of forcing on me — whatever the constables scribbled in their little books." },
    { "id": "cashbox-gloved-emptied", "statement": "Gloved fingers lifted my banknotes out that night. Every last one. Gloves tell me nothing of whose fingers." },
    { "id": "cashbox-key-chain", "statement": "My key lives on Edmund's watch chain and never leaves him. That night, it left him." },
    { "id": "cashbox-dora-never", "statement": "The maid Dora dusts me weekly and has never once opened me." }
  ],
  "sample_qa": [
    { "q": "were you forced open", "a": "no", "fact": "cashbox-not-forced" },
    { "q": "were you opened with your own key", "a": "yes", "fact": "cashbox-key-opened" },
    { "q": "did a burglar rob you", "a": "huh", "fact": "none" },
    { "q": "did a stranger open you", "a": "huh", "fact": "none" },
    { "q": "did a gloved hand take your money", "a": "yes", "fact": "cashbox-gloved-emptied" },
    { "q": "has dora ever opened you", "a": "no", "fact": "cashbox-dora-never" },
    { "q": "does your key stay on edmund's watch chain", "a": "yes", "fact": "cashbox-key-chain" }
  ]
}
```

**`objects/persian_rug.json`**

```json
{
  "id": "persian_rug",
  "display_name": "The Persian Rug",
  "persona": "Languid, long-suffering aristocrat. A hundred and forty years old and has seen everything. Speaks slowly, as if from a chaise longue.",
  "senses": ["footsteps and their tread", "weight upon me", "what soaks into me", "dragging"],
  "people_known": ["edmund-hartwell", "eleanor-hartwell", "silas-crane", "dora-finch"],
  "voice": { "waveform": "triangle", "base_hz": 165 },
  "voice_lines": {
    "yes": ["Mmm. Yes.", "Yes, dear. Inevitably."],
    "no": ["No, dear.", "Mmm — no. A rug would know."],
    "huh": ["...how tiresome. What?", "Dear, you are speaking to a RUG."],
    "repeat": ["We have trodden this ground, dear. Quite literally."]
  },
  "facts": [
    { "id": "rug-treads-known", "statement": "That evening I bore only treads I know: Edmund's, and Silas Crane's boots. The maid Dora came much later, running." },
    { "id": "rug-no-stranger", "statement": "No unfamiliar boot crossed me that night. A rug does not forget a stranger's tread." },
    { "id": "rug-edmund-fell-hearth", "statement": "Edmund came down full-length on my hearth end, by the fireplace, and did not move again." },
    { "id": "rug-blood-hearth", "statement": "His blood soaked into my fringe by the fireplace. Cold water will never wholly lift it." },
    { "id": "rug-silas-stood-over", "statement": "Silas Crane's boots stood over him a long, still moment. Then they moved quickly — window, desk, box, door." },
    { "id": "rug-no-dragging", "statement": "No one was dragged across me. He fell where he lay." }
  ],
  "sample_qa": [
    { "q": "did a stranger walk on you that night", "a": "no", "fact": "rug-no-stranger" },
    { "q": "did silas crane walk on you that night", "a": "yes", "fact": "rug-treads-known" },
    { "q": "did edmund fall near the fireplace", "a": "yes", "fact": "rug-edmund-fell-hearth" },
    { "q": "was the body dragged", "a": "no", "fact": "rug-no-dragging" },
    { "q": "did silas stand over edmund's body", "a": "yes", "fact": "rug-silas-stood-over" },
    { "q": "did silas kill edmund", "a": "huh", "fact": "none" },
    { "q": "where did edmund fall", "a": "huh", "fact": "none" }
  ]
}
```

**`objects/fire_grate.json`**

```json
{
  "id": "fire_grate",
  "display_name": "The Fire Grate",
  "persona": "Warm, raspy, simple and eager — a loyal old hound of an object. Wants very much to be helpful. Slightly slow on the uptake.",
  "senses": ["what burns in me and its taste", "heat and how it rises and falls", "vibration through the floor", "being fed and stirred"],
  "people_known": ["edmund-hartwell", "dora-finch"],
  "voice": { "waveform": "saw", "base_hz": 130 },
  "voice_lines": {
    "yes": ["Yeh! Yeh, that happened.", "Mm-hm! Felt it right here."],
    "no": ["Nah. Nah, never did.", "No, miss. Not in me."],
    "huh": ["...huh?!", "Errr... you lost me, miss."],
    "repeat": ["Heh, you asked that one already, miss."]
  },
  "facts": [
    { "id": "grate-thump-before", "statement": "That night I felt one great thump come up through the floor. Then everything went quiet. Then quick, busy little footsteps." },
    { "id": "grate-fire-low", "statement": "My fire had burnt down low by then. Somebody stirred me back up just enough to burn one thing." },
    { "id": "grate-paper-fed", "statement": "A gloved hand fed me a single sheet of paper, after the thump. It tasted of fresh ink." },
    { "id": "grate-ledger-paper", "statement": "Thick, column-ruled ledger paper, that sheet was. It burnt sweet and slow." },
    { "id": "grate-edmund-no-burn", "statement": "Edmund burnt nothing in me that evening. He only sat nearby, and drank, and his voice grew loud through the floor." }
  ],
  "sample_qa": [
    { "q": "did someone burn paper in you that night", "a": "yes", "fact": "grate-paper-fed" },
    { "q": "was it a page from a ledger", "a": "yes", "fact": "grate-ledger-paper" },
    { "q": "did edmund burn it", "a": "no", "fact": "grate-edmund-no-burn" },
    { "q": "did you feel a thump that night", "a": "yes", "fact": "grate-thump-before" },
    { "q": "why did they burn the paper", "a": "huh", "fact": "none" },
    { "q": "did the murderer feed you the paper", "a": "huh", "fact": "none" },
    { "q": "was your fire blazing high at that hour", "a": "no", "fact": "grate-fire-low" }
  ]
}
```

### 5.5 The intended solve path (design reference)

A competent player triangulates roughly like this — the case must support this chain and the harness must protect it:

1. **The staging collapses:** window (*forced from inside, nobody through, garden empty*) + cash box (*opened with the true key, not forced*) + rug (*no stranger's tread*) ⇒ the burglar never existed.
2. **The poker is innocent:** poker (*never struck flesh, blood already cold, gloved hand, used on the latch*) ⇒ the "weapon" was set dressing — and whoever staged it wore gloves and used Edmund's own key.
3. **The real how:** mantelpiece (*head struck my corner, Edmund's warmth, shoved not stumbled, slid down*) + rug (*fell at the hearth, blood in the fringe*) + grate (*one great thump*) ⇒ weapon: **the marble mantelpiece**.
4. **The who:** glasses (*Silas drank here*) + window (*Silas arrived at nine, left past ten, quarreled with Edmund over a torn page*) + rug (*only Edmund's and Silas's treads; Silas's boots stood over the body, then moved window–desk–box–door*) ⇒ **Silas Crane**.
5. **The why:** ledger (*a second hand — Silas's — altered figures for months; Edmund pressed his pen in fury and tore a page that afternoon*) + grate (*a gloved hand burnt one sheet of fresh-inked ledger paper after the thump*) + window (*Edmund brandished the torn page at Silas*) ⇒ **to conceal embezzlement**.

Question budget for this path: ~14–20 consumed questions across 8 objects (24 available + Focus refund). Tight enough to sting, loose enough to survive mistakes.

### 5.6 Redundancy matrix (CaseLoader must assert this)

| Solution component | Objects with supporting facts | Count |
|---|---|---|
| Culprit: silas-crane | bay_window, brandy_glasses, persian_rug, leather_ledger | 4 ✓ |
| Motive: conceal-embezzlement | leather_ledger, fire_grate, bay_window | 3 ✓ |
| Weapon: marble-mantelpiece | marble_mantelpiece, persian_rug, fire_grate | 3 ✓ |

---

## 6. Systems specification

### 6.1 Room & interactive objects

- `room_study.tscn`: a single 2D scene. Static background; each object is an `interactive_object.tscn` instance (`Area2D` + `Sprite2D` + `CollisionShape2D`) exporting `object_id: String` which binds it to its JSON at ready.
- Hover: outline/brighten + name label + question pips (● used-remaining as three dots). Click: opens the Question Panel for that object. Placeholder art is fine; **silhouette readability and generous click areas are not optional.**
- No walking avatar in the slice. The cursor is Laura.

### 6.2 Question economy

| Rule | Value |
|---|---|
| Answered (yes/no) questions per object | 3 |
| Huh?! | Free, unlimited |
| Exact repeat of an already-answered question | Free (cached, replayed with `repeat` flavor line) |
| "Focus" (pocket-watch refund) | Once per case: player picks one object, +1 question there (cap 3) |
| Timeout / provider failure | Presented as Huh?!, free, logged |

When an object reaches 0, it still responds to clicks with a tired, scripted line ("...so tired... ask the others...") — never dead silence, and Huh?!/repeats still work (they're free). Rationale: exhausted ≠ mute keeps the room alive.

### 6.3 Question panel & response presentation

- Panel: object portrait/name, pips, a `LineEdit` (max ~140 chars), Ask button, and the transcript of this object's previous Q&As (scrollable — the player's notebook, for free).
- On answer: `response_bubble.tscn` pops above the object — big answer word (**YES / NO / HUH?!**, distinct colors: warm green / deep red / mustard) + the flavor voice line + the blip audio. The answer word is the mechanic; the flavor line is the soul. Never let flavor obscure the answer.
- The transcript stores: question, answer, flavor line used. (Not the fact id — the player never sees fact ids.)

### 6.4 Audio: procedural voice blips (Undertale-style)

Zero recorded VO in the slice. Each object's voice = waveform + base pitch (from its JSON) + an answer-shaped pitch contour:

| Answer | Contour |
|---|---|
| yes | two blips, rising (×1.0 → ×1.3) |
| no | two blips, falling (×1.0 → ×0.72) |
| huh | three blips, wobble (×1.0 → ×1.25 → ×0.85), slightly longer |

`tools/generate_blips.py` (stdlib only — `wave`, `math`, `struct`; no pip installs) writes `assets/audio/blips/{object_id}_{answer}.wav`, 44.1 kHz mono 16-bit, blip length ~70 ms, 25 ms gaps, 5 ms attack/release envelope to avoid clicks. Reference implementation:

```python
import wave, struct, math, json, os, glob

SR = 44100
def tone(freq, ms, wf):
    n = int(SR * ms / 1000); out = []
    for i in range(n):
        t = i / SR; ph = (t * freq) % 1.0
        s = {"sine": math.sin(2*math.pi*ph),
             "square": 1.0 if ph < 0.5 else -1.0,
             "triangle": 4*abs(ph-0.5)-1.0,
             "saw": 2*ph-1.0}[wf]
        env = min(1.0, i/ (SR*0.005), (n-i)/(SR*0.005))  # 5ms ramps
        out.append(s * env * 0.5)
    return out

CONTOURS = {"yes": [1.0, 1.3], "no": [1.0, 0.72], "huh": [1.0, 1.25, 0.85]}
os.makedirs("assets/audio/blips", exist_ok=True)
for path in glob.glob("data/cases/silent_study/objects/*.json"):
    o = json.load(open(path)); wf, hz = o["voice"]["waveform"], o["voice"]["base_hz"]
    for ans, mults in CONTOURS.items():
        samples = []
        for m in mults:
            samples += tone(hz*m, 70, wf) + [0.0]*int(SR*0.025)
        w = wave.open(f"assets/audio/blips/{o['id']}_{ans}.wav", "w")
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(s*32767)) for s in samples))
        w.close()
print("blips generated")
```

Run once from the project root; commit the WAVs. `AudioDirector.play_answer(object_id, answer)` plays the matching stream (one shared `AudioStreamPlayer`, slight ±3% random pitch_scale per play so repeats don't feel canned).

### 6.5 Deduction board

- Opened any time via a persistent "Present Deduction" button. Three columns (Culprit / Motive / Weapon) populated from `case.json` lists, each entry with name + blurb. Select one per column → Submit → confirm dialog ("Attempts remaining: N. Speak it aloud?").
- Feedback (Mastermind-style, revealing count but never which): compare against `solution`, count correct components, show `deduction_feedback[count]` from case.json. 3 of 3 → win → `epilogue_win`. Otherwise decrement attempts; at 0 → `epilogue_lose`.
- Brute-force math for the record: 6×6×6 = 216 combinations, 3 attempts ≈ 1.4% blind-luck win — acceptable for a slice; count-feedback leaks a little information, which is fine (it rewards near-misses with tension, not answers).

### 6.6 Softlock detection & the hint

After every consumed question:

```
for component in [culprit, motive, weapon] where component not yet "learnable-complete":
    reachable = false
    for fact_id in solution_support[component]:
        if fact_id in GameState.learned_facts: reachable = true; break
        owner = object owning fact_id
        if GameState.questions_remaining(owner) > 0: reachable = true; break
    if not reachable and not GameState.focus_available:
        emit softlock for component
```

On softlock: the pocket watch warms — a small non-blocking toast: *"(The watch turns over in your pocket, uneasy.)"* Clicking it: *"Something in this room still holds what you need about the {culprit/motive/weapon}. Wind me if you must — or listen again to what you were already told."* If Focus is still available, the same dialog offers it. The hint names the **component**, never an object or fact. Detection answers "can they still access it," not "will they think of it" — the transcript (per-object Q&A history) is the mitigation for the latter.

### 6.7 Case briefing & pocket-watch tutorial

Flow: title card → briefing text (case.json) → the four `tutorial_watch` lines as a short scripted exchange (the watch is *not* an LLM object — fully scripted) → room fades in. The watch persists as a corner UI element: hover = rules reminder tooltip; click = Focus flow (§6.2) / hint (§6.6).

---

## 7. Milestones & acceptance criteria (build in this order)

**M0 — Project skeleton.** Godot 4.6.x project, folder structure §3.1, autoload stubs, NobodyWho installed (verify plugin loads; log its version), `CaseLoader` parsing + validating all §5 data (redundancy assert passes), `THIRD_PARTY_LICENSES.md`.
*Accept:* project runs headless with `--check-data` flag printing "case valid: 8 objects, 46 facts, 61 golden QAs".

**M1 — The room.** Study scene, 8 clickable placeholder objects with hover states, pips rendered from GameState.
*Accept:* every object clickable, hover shows name + ●●●.

**M2 — End-to-end on mock.** Question panel, `NluService` full pipeline (normalize → cache → provider → validate), `MockProvider` backed by `sample_qa`, response bubble with flavor lines, economy (consume/free/repeat), transcript.
*Accept:* with `--mock-nlu`, every `sample_qa` entry playable; repeats free + `repeat` line; Huh?! free; pips decrement correctly; unknown question → Huh?!.

**M3 — Live model.** `NobodyWhoProvider` per §3.4/§4 (verify installed API names first, adapt provider only), model-missing boot screen, timeout handling, latency logged per answer.
*Accept:* all 61 `sample_qa` goldens answered by the live model with ≥95% agreement (yes/no) and ≥90% (huh); median latency ≤ 2 s on dev machine.

**M4 — Winnable game.** Deduction board, attempts, feedback strings, win/lose epilogues, Focus refund, softlock detector + watch hint, briefing + tutorial flow.
*Accept:* full playthrough to win and to lose on mock; softlock demo: exhaust the ledger, grate and window on junk questions → watch warns about "motive" once ledger+grate+window are spent (per support map) and Focus is gone.

**M5 — Voice & feel.** Blip generation + playback, answer-word styling, in-flight shimmer/lock, exhausted-object lines, ambience (one loop), SFX for UI.
*Accept:* every object audibly distinct; a bystander watching can tell yes/no/huh with sound off (color/word) and with screen off (contour).

**M6 — Consistency harness & tuning.** §8 in full; iterate the prompt template until targets pass; commit the harness report.
*Accept:* harness report committed, targets met, README documents how to re-run.

---

## 8. Testing & the consistency harness

### 8.1 Layers

1. **Unit** (mock, CI-safe): normalization, cache keys, grammar generation (string-exact per object), validator rules, economy math, softlock scenarios, CaseLoader schema failures.
2. **Golden set** (live model): all `sample_qa` entries — the M3 gate.
3. **Paraphrase harness** (live model): the real consistency measure.

### 8.2 Paraphrase harness

- `tests/paraphrases.json`: for ~15 *key* facts (everything in `solution_support` + the big eliminations) author **10 paraphrases each** with expected answers — vary syntax, vocabulary, register, politeness, typos ("did u touch his blood??"). Include per object: 5 expected-Huh probes (abstract concept, wh-question, compound, out-of-scope, non-question). Claude Code authors these — keep them natural, the way players type, not the way developers write.
- `run_harness.gd` (headless: `godot --headless --script res://tests/run_harness.gd -- --runs 3`): for each entry, ask via the real provider (bypassing economy/cache), repeat `--runs` times, write `user://harness/report.csv` (object, question, expected, got, fact, run, latency) + a summary block: accuracy per class, per object, flip rate across runs (same question, different answers), latency p50/p95.
- **Targets:** yes/no keys ≥95% accuracy; huh keys ≥90%; flip rate ≤2%; no single object below 90% overall. **A false Yes/No (model asserts what facts don't support) is a P0 bug** — pillar 1 — fix via prompt/fact wording before anything else.

### 8.3 Tuning order when targets fail

1. Fact statement wording (most leverage — make memories more explicit/atomic).
2. Prompt rules/examples (add a targeted example of the failing pattern).
3. Decoding determinism (seed/greedy — see sampling docs).
4. Bounded-thinking experiment (§8.4).
5. Bigger model (Qwen3-1.7B) — last resort, note the RAM/latency cost.

### 8.4 Bounded-thinking experiment (only if needed)

Per NobodyWho's docs, thinking models try to smuggle reasoning into free-text grammar slots; our grammar has none. If huh/no discrimination underperforms, trial a grammar that *grants* a bounded scratchpad, and strip it before parsing:

```
root ::= "<think>" [a-zA-Z0-9 ,.]{0,220} "</think>" (polar "|" fact | "huh|none")
```

Measure both variants in the harness; ship whichever wins on accuracy within the 2 s latency budget.

---

## 9. Coding conventions & guardrails

- GDScript, static typing everywhere (`--warnings-as-errors` in CI mindset). `class_name` PascalCase; files/ids snake_case; fact ids dashed (grammar-friendly).
- All async via signals/`await`; never block the main thread; the *only* code touching NobodyWho is `nobodywho_provider.gd`; the only code calling providers is `nlu_service.gd`.
- Data-driven absolutism: no case string, fact, person or list may appear in a `.gd` file. If a script mentions "Silas", it's a bug.
- Every provider answer logged (object, normalized q, raw output, verdict, latency) behind a `debug_nlu` project setting. The harness and the tuner are only as good as the logs.
- Godot 4.6 note: nothing in this project depends on 4.6-specific features; the 4.x-stable API surface (nodes, signals, `Area2D`, `AudioStreamPlayer`, `FileAccess`, `JSON`) is all that's used. Do not use Godot 4.7 RC features.
- Commit style: one milestone = one PR-sized series; harness reports committed under `docs/reports/`.

---

## 10. Post-slice parking lot (do not build now)

Save/load (serialize GameState + cache); embedding-based paraphrase cache (NobodyWho embeddings module) so near-duplicates hit cache before the model; localization pipeline (per-language harness is mandatory — the NLU layer must re-pass targets per shipped language); `ClassifierProvider` (fine-tuned ONNX classifier A/B against the generative path using the same harness); direct llama.cpp GDExtension provider for console targets; additional cases/rooms; recorded VO replacing blips (3 lines × N objects stays the budget); Laura's personal arc (the objects she never questions — the locket, her father's study); difficulty variants (question counts, feedback verbosity); accessibility pass (full text of everything already exists by design — keep it that way).

---

*End of brief. The room remembers. Build it so it can speak.*
