# frozen_string_literal: true

module Legion
  module Extensions
    module Creativity
      module Helpers
        class IdeaStore
          attr_reader :ideas, :seed_buffer, :tick_count

          def initialize
            @ideas       = []
            @seed_buffer = []
            @tick_count  = 0
          end

          def add(idea)
            @ideas << idea
            @ideas.shift while @ideas.size > Constants::MAX_IDEAS
            idea
          end

          def tick
            @tick_count += 1
            @ideas.select { |i| i.state == :incubating }.each(&:tick_incubation)
          end

          def ingest_seeds(seeds)
            Array(seeds).each do |seed|
              sym = seed.to_sym
              @seed_buffer << sym unless @seed_buffer.include?(sym)
            end
            @seed_buffer.shift while @seed_buffer.size > Constants::MAX_ACTIVE_SEEDS
          end

          def emerge_ready
            emerged = []
            @ideas.select(&:ready_to_emerge?).each do |idea|
              idea.emerge!
              emerged << idea
            end
            emerged
          end

          def by_state(state)
            @ideas.select { |i| i.state == state }
          end

          def best_ideas(limit: 5)
            @ideas
              .select { |i| %i[emerged evaluated adopted].include?(i.state) }
              .sort_by { |i| -i.composite_quality }
              .first(limit)
          end

          def compute_novelty(idea)
            existing = @ideas.reject { |i| i.id == idea.id }
            return 1.0 if existing.empty?

            set_a = idea.seed_concepts.to_set
            distances = existing.map do |other|
              set_b = other.seed_concepts.to_set
              jaccard_distance(set_a, set_b)
            end
            distances.sum / distances.size.to_f
          end

          def active_count
            @ideas.count { |i| %i[incubating emerged evaluated].include?(i.state) }
          end

          def stats
            {
              total:      @ideas.size,
              incubating: by_state(:incubating).size,
              emerged:    by_state(:emerged).size,
              evaluated:  by_state(:evaluated).size,
              adopted:    by_state(:adopted).size,
              discarded:  by_state(:discarded).size,
              seeds:      @seed_buffer.size,
              tick_count: @tick_count
            }
          end

          private

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
