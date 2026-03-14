# lex-creativity

**Level 3 Documentation** — Parent: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`

## Purpose

Divergent thinking and idea generation engine for the LegionIO cognitive architecture. Implements Guilford's four-factor creativity model (fluency, flexibility, originality, elaboration) plus Boden's three creativity modes (divergent, convergent, combinational). Tracks creative potential via EMA and manages an idea lifecycle from incubation through adoption.

## Gem Info

- **Gem name**: `legion-extensions-creativity` (gemspec) / `lex-creativity` (directory)
- **Version**: `0.1.0`
- **Namespace**: `Legion::Extensions::Creativity`
- **Location**: `extensions-agentic/lex-creativity/`

## File Structure

```
lib/legion/extensions/creativity/
  creativity.rb                 # Top-level requires
  version.rb                    # VERSION = '0.1.0'
  client.rb                     # Client class: includes Runners::Creativity, exposes @creative_engine
  helpers/
    constants.rb                # CREATIVITY_MODES, IDEA_QUALITIES, QUALITY_WEIGHTS, thresholds
    idea.rb                     # Idea value object with lifecycle state machine
    idea_store.rb               # In-memory idea collection with seed buffer and tick mechanism
    creative_engine.rb          # Engine: diverge, converge, blend, incubate
  runners/
    creativity.rb               # Runner module: all public methods
```

## Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `CREATIVITY_MODES` | `[:divergent, :convergent, :combinational]` | Boden creativity modes |
| `IDEA_QUALITIES` | `[:fluency, :flexibility, :originality, :elaboration]` | Guilford factors |
| `QUALITY_WEIGHTS` | `{fluency: 0.20, flexibility: 0.25, originality: 0.35, elaboration: 0.20}` | Composite quality weights |
| `CREATIVITY_ALPHA` | 0.1 | EMA alpha for `creative_potential` tracking |
| `NOVELTY_THRESHOLD` | 0.5 | Minimum novelty to count an idea |
| `BLEND_DISTANCE_MIN` | 0.3 | Minimum Jaccard distance for a valid conceptual blend |
| `MAX_IDEAS` | 200 | In-memory cap |
| `INCUBATION_TICKS` | 20 | Ticks before an incubating idea can emerge |
| `IDEA_STATES` | `[:incubating, :emerged, :evaluated, :adopted, :discarded]` | Lifecycle states |

## Runners

All methods in `Legion::Extensions::Creativity::Runners::Creativity`.

| Method | Key Args | Returns |
|---|---|---|
| `creative_tick` | `tick_results: {}` | `{ emerged_count:, active_count:, seeds_ingested:, creative_potential:, emerged_ideas: }` |
| `diverge` | `prompt:, count: 5` | `{ mode: :divergent, ideas:, count:, potential: }` |
| `blend_concepts` | `concept_a:, concept_b:` | `{ status:, idea:, potential: }` or `{ status: :too_similar, message: }` |
| `evaluate_ideas` | — | `{ evaluated_count:, ideas:, best: }` |
| `adopt_idea` | `idea_id:` | `{ status: :adopted/:not_found/:not_adoptable, idea: }` |
| `creative_status` | — | `{ creative_potential:, active_count:, seed_buffer:, best_ideas:, stats: }` |
| `creativity_stats` | — | Full stats hash with mode breakdown, adoption rate, average quality |

## Helpers

### `Idea`
Value object with state machine. States transition: `incubating → emerged → evaluated → adopted` (or `discarded`). Key methods: `tick_incubation`, `ready_to_emerge?`, `emerge!`, `evaluate!(quality_scores:)`, `adopt!`, `discard!`. `composite_quality` is a weighted sum of Guilford factor scores.

### `IdeaStore`
Manages the collection plus a `seed_buffer` (capped at `MAX_ACTIVE_SEEDS = 10`). Methods: `add(idea)`, `tick` (decrements incubation), `emerge_ready` (transitions ready ideas), `compute_novelty(idea)` (Jaccard distance from existing ideas), `best_ideas(limit:)`, `stats`.

### `CreativeEngine`
Key methods: `diverge(prompt:, count:)` (generates N divergent ideas from prompt seeds), `converge(ideas:)` (ranks emerged ideas), `blend(concept_a:, concept_b:)` (Jaccard distance check then combinational idea), `incubate` (ticks store + emerges ready), `compute_novelty(idea, existing)`.

## Integration Points

- `creative_tick` is called from lex-tick/lex-cortex with `tick_results:` containing memory/attention/prediction data
- Seed harvest extracts concepts from: `tick_results[:memory_retrieval][:domains]`, `tick_results[:attention][:focus_domain]`, `tick_results[:prediction_engine][:active_domains]`, `tick_results[:volition][:current_domain]`
- `creative_potential` EMA provides a signal to lex-emotion
- Adopted ideas can feed lex-memory as semantic traces

## Development Notes

- `CreativeEngine` uses Jaccard distance for novelty: `1 - (intersection / union)`
- Seeds extracted from prompts: `downcase.split(/\W+/).first(5).map(&:to_sym)`
- Novelty assigned to divergent ideas by querying the store after creation
- `blend` returns `{ status: :too_similar }` when distance < `BLEND_DISTANCE_MIN`
- `creative_potential` is updated via EMA only after each diverge/blend call
