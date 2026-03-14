# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Creativity::Helpers::CreativeEngine do
  subject(:engine) { described_class.new }

  let(:constants) { Legion::Extensions::Creativity::Helpers::Constants }

  describe '#initialize' do
    it 'starts with zero creative potential' do
      expect(engine.creative_potential).to eq(0.0)
    end

    it 'creates a default IdeaStore' do
      expect(engine.idea_store).to be_a(Legion::Extensions::Creativity::Helpers::IdeaStore)
    end

    it 'accepts an injected idea_store' do
      store  = Legion::Extensions::Creativity::Helpers::IdeaStore.new
      engine = described_class.new(idea_store: store)
      expect(engine.idea_store).to be(store)
    end
  end

  describe '#diverge' do
    it 'generates the requested number of ideas' do
      ideas = engine.diverge(prompt: 'build a better notification system', count: 4)
      expect(ideas.size).to eq(4)
    end

    it 'defaults to 5 ideas' do
      ideas = engine.diverge(prompt: 'test prompt')
      expect(ideas.size).to eq(5)
    end

    it 'generates divergent-mode ideas' do
      ideas = engine.diverge(prompt: 'automate deployment', count: 2)
      expect(ideas.map(&:mode).uniq).to eq([:divergent])
    end

    it 'adds ideas to the store' do
      engine.diverge(prompt: 'cache optimization', count: 3)
      expect(engine.idea_store.ideas.size).to eq(3)
    end

    it 'updates creative potential' do
      engine.diverge(prompt: 'test', count: 3)
      expect(engine.creative_potential).to be > 0.0
    end

    it 'generates ideas starting in incubating state' do
      ideas = engine.diverge(prompt: 'refactor services', count: 2)
      expect(ideas.all? { |i| i.state == :incubating }).to be true
    end

    it 'handles minimum count of 1' do
      ideas = engine.diverge(prompt: 'test', count: 0)
      expect(ideas.size).to eq(1)
    end

    it 'assigns novelty scores to generated ideas' do
      ideas = engine.diverge(prompt: 'mesh routing algorithm', count: 3)
      expect(ideas.all? { |i| i.novelty_score >= 0.0 }).to be true
    end
  end

  describe '#converge' do
    let(:emerged_idea) do
      idea = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[ruby async], description: 'async ruby idea',
        quality_scores: { fluency: 0.7, flexibility: 0.6, originality: 0.8, elaboration: 0.5 }
      )
      constants::INCUBATION_TICKS.times { idea.tick_incubation }
      idea.emerge!
      idea
    end

    it 'returns empty for empty ideas list' do
      expect(engine.converge(ideas: [])).to be_empty
    end

    it 'returns empty for nil ideas' do
      expect(engine.converge(ideas: nil)).to be_empty
    end

    it 'ranks ideas by composite quality' do
      low_idea = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[a], description: 'low quality',
        quality_scores: { fluency: 0.1, flexibility: 0.1, originality: 0.1, elaboration: 0.1 }
      )
      high_idea = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[b], description: 'high quality',
        quality_scores: { fluency: 0.9, flexibility: 0.9, originality: 0.9, elaboration: 0.9 }
      )
      [low_idea, high_idea].each do |idea|
        constants::INCUBATION_TICKS.times { idea.tick_incubation }
        idea.emerge!
      end
      ranked = engine.converge(ideas: [low_idea, high_idea])
      expect(ranked.first.description).to eq('high quality')
    end

    it 'evaluates emerged ideas during convergence' do
      ranked = engine.converge(ideas: [emerged_idea])
      expect(ranked.first.state).to eq(:evaluated)
    end

    it 'skips incubating ideas' do
      incubating = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[x], description: 'not ready'
      )
      expect(engine.converge(ideas: [incubating])).to be_empty
    end
  end

  describe '#blend' do
    it 'returns too_similar for concepts with low Jaccard distance' do
      # intersection={ruby,rails}, union={ruby,rails,web}, similarity=2/3 > 0.7, distance < 0.3
      result = engine.blend(concept_a: %i[ruby rails web], concept_b: %i[ruby rails web server])
      expect(result[:status]).to eq(:too_similar)
    end

    it 'creates a combinational idea for sufficiently distinct concepts' do
      result = engine.blend(concept_a: %i[ocean waves tide], concept_b: %i[cpu memory cache])
      expect(result[:status]).to eq(:ok)
      expect(result[:idea].mode).to eq(:combinational)
    end

    it 'adds blended idea to the store' do
      engine.blend(concept_a: %i[ocean sailing], concept_b: %i[machine_learning inference])
      expect(engine.idea_store.ideas.size).to eq(1)
    end

    it 'updates creative potential on successful blend' do
      engine.blend(concept_a: %i[ocean sailing], concept_b: %i[machine_learning inference])
      expect(engine.creative_potential).to be > 0.0
    end

    it 'combines seed concepts from both inputs' do
      result = engine.blend(concept_a: %i[music rhythm], concept_b: %i[math topology])
      idea   = result[:idea]
      expect(idea.seed_concepts).to include(:music, :math)
    end

    it 'includes message in too_similar response' do
      result = engine.blend(concept_a: %i[ruby rails web], concept_b: %i[ruby rails web server])
      expect(result[:message]).to be_a(String)
    end
  end

  describe '#incubate' do
    it 'advances incubation ticks' do
      ideas = engine.diverge(prompt: 'test prompt', count: 2)
      initial = ideas.first.incubation_ticks_remaining
      engine.incubate
      expect(ideas.first.incubation_ticks_remaining).to eq(initial - 1)
    end

    it 'returns empty when no ideas are ready' do
      engine.diverge(prompt: 'test', count: 1)
      expect(engine.incubate).to be_empty
    end

    it 'returns emerged ideas when incubation completes' do
      engine.diverge(prompt: 'test', count: 2)
      emerged = nil
      constants::INCUBATION_TICKS.times { emerged = engine.incubate }
      expect(emerged.size).to eq(2)
    end

    it 'transitions ideas to emerged state' do
      engine.diverge(prompt: 'test', count: 1)
      constants::INCUBATION_TICKS.times { engine.incubate }
      expect(engine.idea_store.by_state(:emerged).size).to eq(1)
    end
  end

  describe '#compute_novelty' do
    it 'computes novelty against provided existing list' do
      idea = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[a b], description: 'test'
      )
      existing = [Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[c d], description: 'other'
      )]
      novelty = engine.compute_novelty(idea, existing)
      expect(novelty).to eq(1.0)
    end

    it 'delegates to idea_store when no existing provided' do
      idea = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[a b], description: 'test'
      )
      expect(engine.compute_novelty(idea)).to eq(1.0)
    end

    it 'returns 1.0 for empty existing list' do
      idea = Legion::Extensions::Creativity::Helpers::Idea.new(
        mode: :divergent, seed_concepts: %i[a], description: 'test'
      )
      expect(engine.compute_novelty(idea, [])).to eq(1.0)
    end
  end

  describe 'creative potential EMA' do
    it 'increases after generating good ideas' do
      engine.diverge(prompt: 'test', count: 5)
      expect(engine.creative_potential).to be > 0.0
    end

    it 'updates slowly (EMA with low alpha)' do
      10.times { engine.diverge(prompt: 'test', count: 5) }
      potential_after_ten = engine.creative_potential
      10.times { engine.diverge(prompt: 'more test', count: 5) }
      potential_after_twenty = engine.creative_potential
      expect((potential_after_twenty - potential_after_ten).abs).to be < 0.5
    end
  end
end
