# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Creativity::Runners::Creativity do
  let(:client) { Legion::Extensions::Creativity::Client.new }

  let(:rich_tick) do
    {
      memory_retrieval:  { domains: %i[caching networking] },
      attention:         { focus_domain: :performance },
      prediction_engine: { active_domains: %i[latency throughput] },
      volition:          { current_domain: :optimization }
    }
  end

  let(:empty_tick) { {} }

  describe '#creative_tick' do
    it 'returns a structured result hash' do
      result = client.creative_tick(tick_results: rich_tick)
      expect(result).to include(:emerged_count, :active_count, :seeds_ingested,
                                :creative_potential, :emerged_ideas)
    end

    it 'ingests seeds from tick_results' do
      client.creative_tick(tick_results: rich_tick)
      expect(client.creative_engine.idea_store.seed_buffer).not_to be_empty
    end

    it 'handles empty tick_results' do
      result = client.creative_tick(tick_results: empty_tick)
      expect(result[:seeds_ingested]).to eq(0)
    end

    it 'returns integer emerged_count' do
      result = client.creative_tick(tick_results: rich_tick)
      expect(result[:emerged_count]).to be_a(Integer)
    end

    it 'returns emerged ideas as array of hashes' do
      result = client.creative_tick(tick_results: rich_tick)
      expect(result[:emerged_ideas]).to be_an(Array)
    end

    it 'accepts extra kwargs' do
      expect { client.creative_tick(tick_results: {}, extra: true) }.not_to raise_error
    end

    it 'increments tick count on the store' do
      client.creative_tick(tick_results: empty_tick)
      expect(client.creative_engine.idea_store.tick_count).to eq(1)
    end
  end

  describe '#diverge' do
    it 'returns a structured result hash' do
      result = client.diverge(prompt: 'improve caching strategy')
      expect(result).to include(:mode, :prompt, :ideas, :count, :potential)
    end

    it 'uses divergent mode' do
      result = client.diverge(prompt: 'test')
      expect(result[:mode]).to eq(:divergent)
    end

    it 'generates the requested count' do
      result = client.diverge(prompt: 'test prompt', count: 3)
      expect(result[:count]).to eq(3)
      expect(result[:ideas].size).to eq(3)
    end

    it 'defaults to count 5' do
      result = client.diverge(prompt: 'test')
      expect(result[:count]).to eq(5)
    end

    it 'returns ideas as array of hashes' do
      result = client.diverge(prompt: 'networking improvements')
      result[:ideas].each do |idea|
        expect(idea).to include(:id, :mode, :description, :state, :novelty_score, :composite_quality)
      end
    end

    it 'accepts extra kwargs' do
      expect { client.diverge(prompt: 'test', extra: :ignored) }.not_to raise_error
    end
  end

  describe '#blend_concepts' do
    it 'returns ok for sufficiently different concepts' do
      result = client.blend_concepts(concept_a: %i[ocean waves], concept_b: %i[machine_learning data])
      expect(result[:status]).to eq(:ok)
    end

    it 'returns too_similar for similar concepts' do
      # Large overlap: intersection={ruby,rails,web}, union={ruby,rails,web,server}, distance < 0.3
      result = client.blend_concepts(concept_a: %i[ruby rails web], concept_b: %i[ruby rails web server])
      expect(result[:status]).to eq(:too_similar)
    end

    it 'returns combinational mode on success' do
      result = client.blend_concepts(concept_a: %i[music harmony], concept_b: %i[graph algorithms])
      expect(result[:mode]).to eq(:combinational) if result[:status] == :ok
    end

    it 'includes idea hash on success' do
      result = client.blend_concepts(concept_a: %i[forest ecology], concept_b: %i[distributed_systems consensus])
      expect(result[:idea]).to include(:id, :description) if result[:status] == :ok
    end

    it 'accepts extra kwargs' do
      expect { client.blend_concepts(concept_a: %i[a], concept_b: %i[b c d], debug: true) }.not_to raise_error
    end
  end

  describe '#evaluate_ideas' do
    it 'returns zero evaluated count when no ideas have emerged' do
      result = client.evaluate_ideas
      expect(result[:evaluated_count]).to eq(0)
    end

    it 'evaluates emerged ideas' do
      client.diverge(prompt: 'test evaluation', count: 2)
      constants = Legion::Extensions::Creativity::Helpers::Constants
      constants::INCUBATION_TICKS.times { client.creative_engine.incubate }
      result = client.evaluate_ideas
      expect(result[:evaluated_count]).to eq(2)
    end

    it 'returns best idea when ideas are evaluated' do
      client.diverge(prompt: 'best idea test', count: 2)
      Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { client.creative_engine.incubate }
      result = client.evaluate_ideas
      expect(result[:best]).not_to be_nil if result[:evaluated_count] > 0
    end

    it 'returns ideas array' do
      result = client.evaluate_ideas
      expect(result[:ideas]).to be_an(Array)
    end

    it 'accepts extra kwargs' do
      expect { client.evaluate_ideas(verbose: true) }.not_to raise_error
    end
  end

  describe '#adopt_idea' do
    it 'returns not_found for unknown idea_id' do
      result = client.adopt_idea(idea_id: 'nonexistent_id')
      expect(result[:status]).to eq(:not_found)
    end

    it 'adopts an evaluated idea' do
      client.diverge(prompt: 'adoptable idea', count: 1)
      constants = Legion::Extensions::Creativity::Helpers::Constants
      constants::INCUBATION_TICKS.times { client.creative_engine.incubate }
      client.evaluate_ideas
      idea   = client.creative_engine.idea_store.by_state(:evaluated).first
      result = client.adopt_idea(idea_id: idea.id)
      expect(result[:status]).to eq(:adopted)
    end

    it 'returns not_adoptable for incubating idea' do
      client.diverge(prompt: 'not ready', count: 1)
      idea   = client.creative_engine.idea_store.by_state(:incubating).first
      result = client.adopt_idea(idea_id: idea.id)
      expect(result[:status]).to eq(:not_adoptable)
    end

    it 'includes idea hash on successful adoption' do
      client.diverge(prompt: 'check hash', count: 1)
      Legion::Extensions::Creativity::Helpers::Constants::INCUBATION_TICKS.times { client.creative_engine.incubate }
      client.evaluate_ideas
      idea   = client.creative_engine.idea_store.by_state(:evaluated).first
      result = client.adopt_idea(idea_id: idea.id)
      expect(result[:idea]).to include(:id, :state) if result[:status] == :adopted
    end

    it 'accepts extra kwargs' do
      expect { client.adopt_idea(idea_id: 'x', reason: 'test') }.not_to raise_error
    end
  end

  describe '#creative_status' do
    it 'returns a structured status hash' do
      result = client.creative_status
      expect(result).to include(:creative_potential, :active_count, :seed_buffer, :best_ideas, :stats)
    end

    it 'returns empty best_ideas initially' do
      result = client.creative_status
      expect(result[:best_ideas]).to be_empty
    end

    it 'returns seed_buffer as array' do
      client.creative_tick(tick_results: rich_tick)
      result = client.creative_status
      expect(result[:seed_buffer]).to be_an(Array)
    end

    it 'accepts extra kwargs' do
      expect { client.creative_status(extra: :param) }.not_to raise_error
    end
  end

  describe '#creativity_stats' do
    it 'returns comprehensive stats hash' do
      result = client.creativity_stats
      expect(result).to include(
        :creative_potential, :total_ideas, :active_count,
        :adopted_count, :discarded_count, :adoption_rate,
        :modes, :average_quality, :tick_count, :seed_buffer_size
      )
    end

    it 'has all three modes in modes breakdown' do
      result = client.creativity_stats
      expect(result[:modes]).to include(:divergent, :convergent, :combinational)
    end

    it 'returns zero adoption_rate initially' do
      result = client.creativity_stats
      expect(result[:adoption_rate]).to eq(0.0)
    end

    it 'reflects generated ideas in total_ideas' do
      client.diverge(prompt: 'stat test', count: 3)
      result = client.creativity_stats
      expect(result[:total_ideas]).to eq(3)
    end

    it 'accepts extra kwargs' do
      expect { client.creativity_stats(full: true) }.not_to raise_error
    end
  end
end
