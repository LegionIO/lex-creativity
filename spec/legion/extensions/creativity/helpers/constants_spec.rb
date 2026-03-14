# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Creativity::Helpers::Constants do
  describe 'CREATIVITY_MODES' do
    it 'defines 3 modes' do
      expect(described_class::CREATIVITY_MODES.size).to eq(3)
    end

    it 'includes divergent' do
      expect(described_class::CREATIVITY_MODES).to include(:divergent)
    end

    it 'includes convergent' do
      expect(described_class::CREATIVITY_MODES).to include(:convergent)
    end

    it 'includes combinational' do
      expect(described_class::CREATIVITY_MODES).to include(:combinational)
    end

    it 'is frozen' do
      expect(described_class::CREATIVITY_MODES).to be_frozen
    end
  end

  describe 'IDEA_QUALITIES' do
    it 'defines 4 Guilford factors' do
      expect(described_class::IDEA_QUALITIES.size).to eq(4)
    end

    it 'includes fluency' do
      expect(described_class::IDEA_QUALITIES).to include(:fluency)
    end

    it 'includes flexibility' do
      expect(described_class::IDEA_QUALITIES).to include(:flexibility)
    end

    it 'includes originality' do
      expect(described_class::IDEA_QUALITIES).to include(:originality)
    end

    it 'includes elaboration' do
      expect(described_class::IDEA_QUALITIES).to include(:elaboration)
    end

    it 'is frozen' do
      expect(described_class::IDEA_QUALITIES).to be_frozen
    end
  end

  describe 'QUALITY_WEIGHTS' do
    it 'has weights summing to 1.0' do
      total = described_class::QUALITY_WEIGHTS.values.sum
      expect(total).to be_within(0.001).of(1.0)
    end

    it 'assigns highest weight to originality' do
      weights = described_class::QUALITY_WEIGHTS
      expect(weights[:originality]).to be > weights[:fluency]
      expect(weights[:originality]).to be > weights[:elaboration]
      expect(weights[:originality]).to be > weights[:flexibility]
    end

    it 'is frozen' do
      expect(described_class::QUALITY_WEIGHTS).to be_frozen
    end

    it 'covers all IDEA_QUALITIES factors' do
      described_class::IDEA_QUALITIES.each do |factor|
        expect(described_class::QUALITY_WEIGHTS).to have_key(factor)
      end
    end
  end

  describe 'CREATIVITY_ALPHA' do
    it 'is 0.1' do
      expect(described_class::CREATIVITY_ALPHA).to eq(0.1)
    end
  end

  describe 'NOVELTY_THRESHOLD' do
    it 'is 0.5' do
      expect(described_class::NOVELTY_THRESHOLD).to eq(0.5)
    end
  end

  describe 'BLEND_DISTANCE_MIN' do
    it 'is 0.3' do
      expect(described_class::BLEND_DISTANCE_MIN).to eq(0.3)
    end
  end

  describe 'MAX_IDEAS' do
    it 'is 200' do
      expect(described_class::MAX_IDEAS).to eq(200)
    end
  end

  describe 'MAX_ACTIVE_SEEDS' do
    it 'is 10' do
      expect(described_class::MAX_ACTIVE_SEEDS).to eq(10)
    end
  end

  describe 'INCUBATION_TICKS' do
    it 'is 20' do
      expect(described_class::INCUBATION_TICKS).to eq(20)
    end
  end

  describe 'IDEA_STATES' do
    it 'defines 5 states' do
      expect(described_class::IDEA_STATES.size).to eq(5)
    end

    it 'includes all lifecycle states' do
      %i[incubating emerged evaluated adopted discarded].each do |state|
        expect(described_class::IDEA_STATES).to include(state)
      end
    end

    it 'is frozen' do
      expect(described_class::IDEA_STATES).to be_frozen
    end
  end
end
