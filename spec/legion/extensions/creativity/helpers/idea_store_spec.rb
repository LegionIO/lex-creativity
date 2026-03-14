# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Creativity::Helpers::IdeaStore do
  subject(:store) { described_class.new }

  let(:make_idea) do
    lambda do |seeds: %i[ruby testing], desc: 'a test idea', mode: :divergent|
      Legion::Extensions::Creativity::Helpers::Idea.new(
        mode:          mode,
        seed_concepts: seeds,
        description:   desc
      )
    end
  end

  describe '#initialize' do
    it 'starts with empty ideas' do
      expect(store.ideas).to be_empty
    end

    it 'starts with empty seed buffer' do
      expect(store.seed_buffer).to be_empty
    end

    it 'starts with tick_count 0' do
      expect(store.tick_count).to eq(0)
    end
  end

  describe '#add' do
    it 'adds an idea to the store' do
      idea = make_idea.call
      store.add(idea)
      expect(store.ideas).to include(idea)
    end

    it 'returns the idea' do
      idea = make_idea.call
      expect(store.add(idea)).to be(idea)
    end

    it 'caps at MAX_IDEAS' do
      max = Legion::Extensions::Creativity::Helpers::Constants::MAX_IDEAS
      (max + 5).times { store.add(make_idea.call) }
      expect(store.ideas.size).to eq(max)
    end
  end

  describe '#tick' do
    it 'increments tick_count' do
      store.tick
      expect(store.tick_count).to eq(1)
    end

    it 'decrements incubation ticks on incubating ideas' do
      idea = make_idea.call
      store.add(idea)
      initial = idea.incubation_ticks_remaining
      store.tick
      expect(idea.incubation_ticks_remaining).to eq(initial - 1)
    end

    it 'does not decrement incubation ticks on emerged ideas' do
      idea = make_idea.call
      store.add(idea)
      # drain incubation to zero
      Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { store.tick }
      store.emerge_ready
      expect(idea.state).to eq(:emerged)
      # ticking further should not change incubation_ticks_remaining (already 0)
      store.tick
      expect(idea.incubation_ticks_remaining).to eq(0)
    end
  end

  describe '#ingest_seeds' do
    it 'adds seeds to the buffer' do
      store.ingest_seeds(%i[ruby testing])
      expect(store.seed_buffer).to include(:ruby, :testing)
    end

    it 'converts strings to symbols' do
      store.ingest_seeds(['networking'])
      expect(store.seed_buffer).to include(:networking)
    end

    it 'does not add duplicates' do
      store.ingest_seeds(%i[ruby ruby])
      expect(store.seed_buffer.count(:ruby)).to eq(1)
    end

    it 'caps at MAX_ACTIVE_SEEDS' do
      max = Legion::Extensions::Creativity::Helpers::Constants::MAX_ACTIVE_SEEDS
      (max + 5).times { |i| store.ingest_seeds([:"seed_#{i}"]) }
      expect(store.seed_buffer.size).to eq(max)
    end
  end

  describe '#emerge_ready' do
    it 'returns empty when no ideas are ready' do
      expect(store.emerge_ready).to be_empty
    end

    it 'emerges ideas that have completed incubation' do
      idea = make_idea.call
      store.add(idea)
      Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { store.tick }
      emerged = store.emerge_ready
      expect(emerged).to include(idea)
      expect(idea.state).to eq(:emerged)
    end

    it 'does not emerge ideas still incubating' do
      idea = make_idea.call
      store.add(idea)
      store.tick
      expect(store.emerge_ready).to be_empty
    end
  end

  describe '#by_state' do
    it 'returns ideas matching the state' do
      idea = make_idea.call
      store.add(idea)
      expect(store.by_state(:incubating)).to include(idea)
    end

    it 'returns empty for states with no ideas' do
      expect(store.by_state(:adopted)).to be_empty
    end
  end

  describe '#best_ideas' do
    it 'returns empty when no evaluated ideas exist' do
      expect(store.best_ideas).to be_empty
    end

    it 'returns top ideas sorted by composite quality' do
      ideas = [
        Legion::Extensions::Creativity::Helpers::Idea.new(
          mode: :divergent, seed_concepts: %i[a], description: 'low',
          quality_scores: { fluency: 0.1, flexibility: 0.1, originality: 0.1, elaboration: 0.1 }
        ),
        Legion::Extensions::Creativity::Helpers::Idea.new(
          mode: :divergent, seed_concepts: %i[b], description: 'high',
          quality_scores: { fluency: 0.9, flexibility: 0.9, originality: 0.9, elaboration: 0.9 }
        )
      ]
      ideas.each do |idea|
        store.add(idea)
        Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { store.tick }
        store.emerge_ready
        idea.evaluate!
      end
      best = store.best_ideas(limit: 1)
      expect(best.first.description).to eq('high')
    end

    it 'respects limit parameter' do
      3.times do |i|
        idea = Legion::Extensions::Creativity::Helpers::Idea.new(
          mode: :divergent, seed_concepts: [:"concept_#{i}"], description: "idea #{i}"
        )
        store.add(idea)
        Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { store.tick }
        store.emerge_ready
        idea.evaluate!
      end
      expect(store.best_ideas(limit: 2).size).to eq(2)
    end
  end

  describe '#compute_novelty' do
    it 'returns 1.0 for the first idea (no existing comparison)' do
      idea = make_idea.call
      expect(store.compute_novelty(idea)).to eq(1.0)
    end

    it 'returns lower novelty for identical seed concepts' do
      idea1 = make_idea.call(seeds: %i[ruby testing])
      idea2 = make_idea.call(seeds: %i[ruby testing])
      store.add(idea1)
      novelty = store.compute_novelty(idea2)
      expect(novelty).to be < 1.0
    end

    it 'returns higher novelty for very different seed concepts' do
      idea1 = make_idea.call(seeds: %i[ruby testing])
      idea2 = make_idea.call(seeds: %i[ocean sailing])
      store.add(idea1)
      novelty = store.compute_novelty(idea2)
      expect(novelty).to eq(1.0)
    end
  end

  describe '#active_count' do
    it 'returns 0 initially' do
      expect(store.active_count).to eq(0)
    end

    it 'counts incubating and emerged ideas' do
      idea = make_idea.call
      store.add(idea)
      expect(store.active_count).to eq(1)
    end

    it 'does not count adopted ideas' do
      idea = make_idea.call
      store.add(idea)
      Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { store.tick }
      store.emerge_ready
      idea.evaluate!
      idea.adopt!
      expect(store.active_count).to eq(0)
    end
  end

  describe '#stats' do
    it 'returns a hash with all state counts' do
      stats = store.stats
      expect(stats).to include(:total, :incubating, :emerged, :evaluated, :adopted, :discarded, :seeds, :tick_count)
    end

    it 'reflects added ideas' do
      store.add(make_idea.call)
      expect(store.stats[:total]).to eq(1)
      expect(store.stats[:incubating]).to eq(1)
    end
  end
end
