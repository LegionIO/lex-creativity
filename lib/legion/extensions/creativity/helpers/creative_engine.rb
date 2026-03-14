# frozen_string_literal: true

module Legion
  module Extensions
    module Creativity
      module Helpers
        class CreativeEngine
          attr_reader :creative_potential, :idea_store

          def initialize(idea_store: nil)
            @idea_store         = idea_store || IdeaStore.new
            @creative_potential = 0.0
          end

          def diverge(prompt:, count: 5)
            count = [count.to_i, 1].max
            seeds = extract_seeds(prompt)
            ideas = []

            count.times do |i|
              quality = diverge_quality_scores(i, count)
              idea    = Idea.new(
                mode:           :divergent,
                seed_concepts:  seeds + [@idea_store.seed_buffer.sample].compact,
                description:    "#{prompt} — variant #{i + 1}",
                quality_scores: quality
              )
              novelty        = @idea_store.compute_novelty(idea)
              idea_with_nov  = Idea.new(
                mode:           :divergent,
                seed_concepts:  idea.seed_concepts,
                description:    idea.description,
                quality_scores: quality.merge(originality: novelty)
              )
              @idea_store.add(idea_with_nov)
              ideas << idea_with_nov
            end

            update_potential(ideas)
            ideas
          end

          def converge(ideas:)
            return [] if ideas.nil? || ideas.empty?

            ranked = ideas
                     .select { |i| %i[emerged evaluated].include?(i.state) }
                     .sort_by { |i| -i.composite_quality }
            ranked.each { |i| i.evaluate!(quality_scores: i.quality_scores) if i.state == :emerged }
            ranked
          end

          def blend(concept_a:, concept_b:)
            set_a    = Set.new(Array(concept_a).map(&:to_sym))
            set_b    = Set.new(Array(concept_b).map(&:to_sym))
            distance = jaccard_distance(set_a, set_b)

            return too_similar_result(distance) if distance < Constants::BLEND_DISTANCE_MIN

            idea = build_blended_idea(set_a, set_b, distance, concept_a, concept_b)
            @idea_store.add(idea)
            update_potential([idea])
            { status: :ok, idea: idea }
          end

          def incubate
            @idea_store.tick
            @idea_store.emerge_ready
          end

          def compute_novelty(idea, existing = nil)
            if existing
              set_a = idea.seed_concepts.to_set
              return 1.0 if existing.empty?

              distances = existing.map { |e| jaccard_distance(set_a, e.seed_concepts.to_set) }
              distances.sum / distances.size.to_f
            else
              @idea_store.compute_novelty(idea)
            end
          end

          private

          def too_similar_result(distance)
            {
              status:  :too_similar,
              message: "Concepts are too similar (distance=#{distance.round(3)}, min=#{Constants::BLEND_DISTANCE_MIN})"
            }
          end

          def build_blended_idea(set_a, set_b, distance, concept_a, concept_b)
            blended_seeds = (set_a | set_b).to_a
            quality = {
              fluency:     0.5,
              flexibility: distance.clamp(0.0, 1.0),
              originality: distance.clamp(0.0, 1.0),
              elaboration: 0.4
            }
            draft   = Idea.new(mode: :combinational, seed_concepts: blended_seeds,
                               description: "Blend of [#{concept_a}] and [#{concept_b}]",
                               quality_scores: quality)
            novelty = @idea_store.compute_novelty(draft)
            Idea.new(mode: :combinational, seed_concepts: blended_seeds,
                     description: draft.description,
                     quality_scores: quality.merge(originality: novelty))
          end

          def extract_seeds(prompt)
            prompt.to_s.downcase.split(/\W+/).reject(&:empty?).map(&:to_sym).uniq.first(5)
          end

          def diverge_quality_scores(index, total)
            spread = total > 1 ? index.to_f / (total - 1) : 0.5
            {
              fluency:     (0.4 + (spread * 0.4)).clamp(0.0, 1.0),
              flexibility: (0.3 + (rand * 0.5)).clamp(0.0, 1.0),
              originality: 0.5,
              elaboration: (0.3 + (spread * 0.3)).clamp(0.0, 1.0)
            }
          end

          def update_potential(ideas)
            return if ideas.empty?

            avg_quality = ideas.sum(&:composite_quality) / ideas.size.to_f
            @creative_potential = ema(@creative_potential, avg_quality, Constants::CREATIVITY_ALPHA)
          end

          def ema(current, observed, alpha)
            (current * (1.0 - alpha)) + (observed * alpha)
          end

          def jaccard_distance(set_a, set_b)
            return 1.0 if set_a.empty? && set_b.empty?

            intersection = (set_a & set_b).size.to_f
            union        = (set_a | set_b).size.to_f
            return 1.0 if union.zero?

            1.0 - (intersection / union)
          end
        end
      end
    end
  end
end
