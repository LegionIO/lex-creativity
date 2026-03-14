# lex-creativity

Divergent thinking and idea generation extension for the LegionIO brain-modeled cognitive architecture.

## What It Does

Gives LegionIO agents the ability to generate novel ideas, blend concepts, and evaluate creative output. Implements Guilford's four-factor model (fluency, flexibility, originality, elaboration) and Boden's three creativity modes: divergent, convergent, and combinational.

Ideas go through a lifecycle: incubation → emerged → evaluated → adopted (or discarded). Creative potential is tracked as a running EMA across all idea generation activity.

## Usage

```ruby
client = Legion::Extensions::Creativity::Client.new

# Generate divergent ideas from a prompt
result = client.diverge(prompt: 'distributed tracing in microservices', count: 3)
# => { mode: :divergent, ideas: [...], count: 3, potential: 0.12 }

# Blend two concepts
result = client.blend_concepts(concept_a: 'chaos_engineering', concept_b: 'observability')
# => { status: :ok, mode: :combinational, idea: { description: "Blend of ...", ... } }

# Run per-tick incubation (call from scheduler)
client.creative_tick(tick_results: { memory_retrieval: { domains: [:consul, :vault] } })
# => { emerged_count: 1, active_count: 3, creative_potential: 0.15, ... }

# Evaluate emerged ideas
result = client.evaluate_ideas
# => { evaluated_count: 2, ideas: [...], best: { description: ..., composite_quality: 0.62 } }

# Adopt the best idea
client.adopt_idea(idea_id: result[:best][:id])

# Get stats
client.creativity_stats
# => { creative_potential:, adoption_rate:, modes: { divergent:, convergent:, combinational: }, ... }
```

## Idea Lifecycle

```
incubating (20 ticks) -> emerged -> evaluated -> adopted
                                                -> discarded
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
