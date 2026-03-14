# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Creativity::Client do
  describe '#initialize' do
    it 'creates a default creative engine' do
      client = described_class.new
      expect(client.creative_engine).to be_a(Legion::Extensions::Creativity::Helpers::CreativeEngine)
    end

    it 'accepts an injected creative engine' do
      engine = Legion::Extensions::Creativity::Helpers::CreativeEngine.new
      client = described_class.new(creative_engine: engine)
      expect(client.creative_engine).to be(engine)
    end

    it 'ignores unknown kwargs' do
      expect { described_class.new(unknown: true, extra: :value) }.not_to raise_error
    end
  end

  describe 'runner integration' do
    let(:client) { described_class.new }

    it { expect(client).to respond_to(:creative_tick) }
    it { expect(client).to respond_to(:diverge) }
    it { expect(client).to respond_to(:blend_concepts) }
    it { expect(client).to respond_to(:evaluate_ideas) }
    it { expect(client).to respond_to(:adopt_idea) }
    it { expect(client).to respond_to(:creative_status) }
    it { expect(client).to respond_to(:creativity_stats) }
  end

  describe 'shared state across calls' do
    it 'accumulates ideas across multiple diverge calls' do
      client = described_class.new
      client.diverge(prompt: 'first prompt', count: 3)
      client.diverge(prompt: 'second prompt', count: 2)
      expect(client.creative_engine.idea_store.ideas.size).to eq(5)
    end

    it 'maintains seed buffer across tick calls' do
      client = described_class.new
      tick1 = { memory_retrieval: { domains: %i[caching] } }
      tick2 = { attention: { focus_domain: :networking } }
      client.creative_tick(tick_results: tick1)
      client.creative_tick(tick_results: tick2)
      expect(client.creative_engine.idea_store.seed_buffer).not_to be_empty
    end

    it 'creative_potential increases after generating ideas' do
      client = described_class.new
      expect(client.creative_engine.creative_potential).to eq(0.0)
      client.diverge(prompt: 'innovation test', count: 5)
      expect(client.creative_engine.creative_potential).to be > 0.0
    end
  end

  describe 'injected engine isolation' do
    it 'two clients with separate engines do not share state' do
      client1 = described_class.new
      client2 = described_class.new
      client1.diverge(prompt: 'shared test', count: 3)
      expect(client2.creative_engine.idea_store.ideas).to be_empty
    end
  end
end
