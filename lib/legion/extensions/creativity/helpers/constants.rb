# frozen_string_literal: true

module Legion
  module Extensions
    module Creativity
      module Helpers
        module Constants
          # The three modes of creative thinking (Guilford + Boden model)
          CREATIVITY_MODES = %i[divergent convergent combinational].freeze

          # Guilford's four factors of creative thinking
          IDEA_QUALITIES = %i[fluency flexibility originality elaboration].freeze

          # Weighted contribution of each Guilford factor to composite quality (sum to 1.0)
          QUALITY_WEIGHTS = {
            fluency:     0.20,
            flexibility: 0.25,
            originality: 0.35,
            elaboration: 0.20
          }.freeze

          # EMA alpha for tracking creative potential (slow adaptation, stable baseline)
          CREATIVITY_ALPHA = 0.1

          # Ideas below this novelty score are too conventional to register
          NOVELTY_THRESHOLD = 0.5

          # Minimum Jaccard distance between concept sets for an interesting blend
          BLEND_DISTANCE_MIN = 0.3

          # Maximum ideas held in the store at any time
          MAX_IDEAS = 200

          # Maximum active seed concepts in the buffer
          MAX_ACTIVE_SEEDS = 10

          # Minimum ticks an idea must incubate before it can emerge
          INCUBATION_TICKS = 20

          # Idea lifecycle states
          IDEA_STATES = %i[incubating emerged evaluated adopted discarded].freeze
        end
      end
    end
  end
end
