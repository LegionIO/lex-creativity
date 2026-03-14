# frozen_string_literal: true

module Legion
  module Extensions
    module Creativity
      module Helpers
        class Idea
          attr_reader :id, :mode, :seed_concepts, :description, :novelty_score,
                      :quality_scores, :composite_quality, :state,
                      :created_at, :evaluated_at, :incubation_ticks_remaining

          def initialize(mode:, seed_concepts:, description:, novelty_score: 0.0, quality_scores: {})
            @id                       = generate_id
            @mode                     = mode
            @seed_concepts            = Array(seed_concepts).map(&:to_sym)
            @description              = description
            @novelty_score            = novelty_score.clamp(0.0, 1.0)
            @quality_scores           = build_quality_scores(quality_scores)
            @composite_quality        = compute_composite
            @state                    = :incubating
            @created_at               = Time.now.utc
            @evaluated_at             = nil
            @incubation_ticks_remaining = Constants::INCUBATION_TICKS
          end

          def tick_incubation
            @incubation_ticks_remaining = [@incubation_ticks_remaining - 1, 0].max
          end

          def ready_to_emerge?
            @state == :incubating && @incubation_ticks_remaining.zero?
          end

          def emerge!
            return false unless ready_to_emerge?

            @state = :emerged
            true
          end

          def evaluate!(quality_scores: {})
            return false unless @state == :emerged

            @quality_scores    = build_quality_scores(quality_scores.empty? ? @quality_scores : quality_scores)
            @composite_quality = compute_composite
            @evaluated_at      = Time.now.utc
            @state             = :evaluated
            true
          end

          def adopt!
            return false unless @state == :evaluated

            @state = :adopted
            true
          end

          def discard!
            return false if @state == :adopted

            @state = :discarded
            true
          end

          def to_h
            {
              id:                         @id,
              mode:                       @mode,
              seed_concepts:              @seed_concepts,
              description:                @description,
              novelty_score:              @novelty_score.round(4),
              quality_scores:             @quality_scores,
              composite_quality:          @composite_quality.round(4),
              state:                      @state,
              created_at:                 @created_at,
              evaluated_at:               @evaluated_at,
              incubation_ticks_remaining: @incubation_ticks_remaining
            }
          end

          private

          def generate_id
            "idea_#{Time.now.utc.to_f.to_s.gsub('.', '')}_#{rand(1000)}"
          end

          def build_quality_scores(scores)
            Constants::IDEA_QUALITIES.to_h do |factor|
              [factor, (scores[factor] || 0.0).clamp(0.0, 1.0)]
            end
          end

          def compute_composite
            Constants::QUALITY_WEIGHTS.sum do |factor, weight|
              (@quality_scores[factor] || 0.0) * weight
            end
          end
        end
      end
    end
  end
end
