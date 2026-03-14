# frozen_string_literal: true

module Legion
  module Extensions
    module Creativity
      module Runners
        module Creativity
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def creative_tick(tick_results: {}, **)
            seeds = harvest_seeds(tick_results)
            creative_engine.idea_store.ingest_seeds(seeds) if seeds.any?

            emerged = creative_engine.incubate
            store   = creative_engine.idea_store

            Legion::Logging.debug "[creativity] tick: seeds=#{seeds.size} emerged=#{emerged.size} " \
                                  "active=#{store.active_count} potential=#{creative_engine.creative_potential.round(3)}"

            {
              emerged_count:      emerged.size,
              active_count:       store.active_count,
              seeds_ingested:     seeds.size,
              creative_potential: creative_engine.creative_potential.round(4),
              emerged_ideas:      emerged.map(&:to_h)
            }
          end

          def diverge(prompt:, count: 5, **)
            ideas = creative_engine.diverge(prompt: prompt, count: count)

            Legion::Logging.debug "[creativity] diverge: prompt=#{prompt.inspect} count=#{ideas.size} " \
                                  "potential=#{creative_engine.creative_potential.round(3)}"

            {
              mode:      :divergent,
              prompt:    prompt,
              ideas:     ideas.map(&:to_h),
              count:     ideas.size,
              potential: creative_engine.creative_potential.round(4)
            }
          end

          def blend_concepts(concept_a:, concept_b:, **)
            result = creative_engine.blend(concept_a: concept_a, concept_b: concept_b)

            if result[:status] == :ok
              Legion::Logging.debug "[creativity] blend: #{concept_a} + #{concept_b} -> " \
                                    "novelty=#{result[:idea].novelty_score.round(3)}"
              {
                status:    :ok,
                mode:      :combinational,
                idea:      result[:idea].to_h,
                potential: creative_engine.creative_potential.round(4)
              }
            else
              Legion::Logging.debug "[creativity] blend rejected: #{result[:message]}"
              result
            end
          end

          def evaluate_ideas(**)
            emerged = creative_engine.idea_store.by_state(:emerged)
            ranked  = creative_engine.converge(ideas: emerged)

            Legion::Logging.debug "[creativity] evaluate: #{ranked.size} ideas ranked"

            {
              evaluated_count: ranked.size,
              ideas:           ranked.map(&:to_h),
              best:            ranked.first&.to_h
            }
          end

          def adopt_idea(idea_id:, **)
            idea = creative_engine.idea_store.ideas.find { |i| i.id == idea_id }

            unless idea
              Legion::Logging.debug "[creativity] adopt: idea_id=#{idea_id} not found"
              return { status: :not_found, idea_id: idea_id }
            end

            if idea.adopt!
              Legion::Logging.debug "[creativity] adopt: idea_id=#{idea_id} adopted"
              { status: :adopted, idea: idea.to_h }
            else
              Legion::Logging.debug "[creativity] adopt: idea_id=#{idea_id} state=#{idea.state} not adoptable"
              { status: :not_adoptable, idea_id: idea_id, current_state: idea.state }
            end
          end

          def creative_status(**)
            store  = creative_engine.idea_store
            best   = store.best_ideas(limit: 3)

            Legion::Logging.debug "[creativity] status: potential=#{creative_engine.creative_potential.round(3)} " \
                                  "active=#{store.active_count}"

            {
              creative_potential: creative_engine.creative_potential.round(4),
              active_count:       store.active_count,
              seed_buffer:        store.seed_buffer,
              best_ideas:         best.map(&:to_h),
              stats:              store.stats
            }
          end

          def creativity_stats(**)
            store = creative_engine.idea_store
            Legion::Logging.debug '[creativity] stats'

            adopted   = store.by_state(:adopted)
            discarded = store.by_state(:discarded)

            {
              creative_potential: creative_engine.creative_potential.round(4),
              total_ideas:        store.ideas.size,
              active_count:       store.active_count,
              adopted_count:      adopted.size,
              discarded_count:    discarded.size,
              adoption_rate:      adoption_rate(adopted, discarded),
              modes:              mode_breakdown(store),
              average_quality:    average_quality(store),
              tick_count:         store.tick_count,
              seed_buffer_size:   store.seed_buffer.size
            }
          end

          private

          def creative_engine
            @creative_engine ||= Helpers::CreativeEngine.new
          end

          def harvest_seeds(tick_results)
            seeds = []
            seeds += extract_key_concepts(tick_results.dig(:memory_retrieval, :domains) || [])
            seeds += extract_key_concepts(tick_results.dig(:attention, :focus_domain) ? [tick_results.dig(:attention, :focus_domain)] : [])
            seeds += extract_key_concepts(tick_results.dig(:prediction_engine, :active_domains) || [])
            seeds += extract_key_concepts(tick_results.dig(:volition, :current_domain) ? [tick_results.dig(:volition, :current_domain)] : [])
            seeds.uniq
          end

          def extract_key_concepts(domains)
            Array(domains).map { |d| d.to_s.split(/\W+/) }.flatten.map(&:to_sym).reject { |s| s.to_s.empty? }
          end

          def adoption_rate(adopted, discarded)
            total = adopted.size + discarded.size
            return 0.0 if total.zero?

            (adopted.size.to_f / total).round(4)
          end

          def mode_breakdown(store)
            Helpers::Constants::CREATIVITY_MODES.to_h do |mode|
              [mode, store.ideas.count { |i| i.mode == mode }]
            end
          end

          def average_quality(store)
            scored = store.ideas.select { |i| %i[evaluated adopted discarded].include?(i.state) }
            return 0.0 if scored.empty?

            (scored.sum(&:composite_quality) / scored.size.to_f).round(4)
          end
        end
      end
    end
  end
end
