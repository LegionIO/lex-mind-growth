# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::ConceptProposal do
  let(:valid_params) do
    {
      name:        'lex-attention',
      module_name: 'Attention',
      category:    :cognition,
      description: 'Attention gating for cognitive load management'
    }
  end

  subject(:proposal) { described_class.new(**valid_params) }

  describe '#initialize' do
    it 'assigns a UUID id' do
      expect(proposal.id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'sets name' do
      expect(proposal.name).to eq('lex-attention')
    end

    it 'sets module_name' do
      expect(proposal.module_name).to eq('Attention')
    end

    it 'converts category to symbol' do
      expect(proposal.category).to eq(:cognition)
    end

    it 'sets description' do
      expect(proposal.description).to eq('Attention gating for cognitive load management')
    end

    it 'defaults metaphor to nil' do
      expect(proposal.metaphor).to be_nil
    end

    it 'defaults helpers to empty array' do
      expect(proposal.helpers).to eq([])
    end

    it 'defaults runner_methods to empty array' do
      expect(proposal.runner_methods).to eq([])
    end

    it 'defaults rationale to nil' do
      expect(proposal.rationale).to be_nil
    end

    it 'initializes scores to empty hash' do
      expect(proposal.scores).to eq({})
    end

    it 'sets initial status to :proposed' do
      expect(proposal.status).to eq(:proposed)
    end

    it 'defaults origin to :proposer' do
      expect(proposal.origin).to eq(:proposer)
    end

    it 'sets created_at to a Time' do
      expect(proposal.created_at).to be_a(Time)
    end

    it 'leaves evaluated_at nil' do
      expect(proposal.evaluated_at).to be_nil
    end

    it 'leaves built_at nil' do
      expect(proposal.built_at).to be_nil
    end

    it 'accepts optional metaphor' do
      p = described_class.new(**valid_params, metaphor: 'spotlight')
      expect(p.metaphor).to eq('spotlight')
    end

    it 'accepts optional rationale' do
      p = described_class.new(**valid_params, rationale: 'fills gap in model')
      expect(p.rationale).to eq('fills gap in model')
    end

    it 'accepts custom origin' do
      p = described_class.new(**valid_params, origin: :manual)
      expect(p.origin).to eq(:manual)
    end
  end

  describe '#evaluate!' do
    let(:passing_scores) do
      Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.75] }
    end

    let(:failing_scores) do
      Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.5] }
    end

    it 'sets scores' do
      proposal.evaluate!(passing_scores)
      expect(proposal.scores).to eq(passing_scores)
    end

    it 'sets evaluated_at' do
      proposal.evaluate!(passing_scores)
      expect(proposal.evaluated_at).to be_a(Time)
    end

    it 'approves when all scores >= MIN_DIMENSION_SCORE' do
      proposal.evaluate!(passing_scores)
      expect(proposal.status).to eq(:approved)
    end

    it 'rejects when any score < MIN_DIMENSION_SCORE' do
      proposal.evaluate!(failing_scores)
      expect(proposal.status).to eq(:rejected)
    end
  end

  describe '#passing_evaluation?' do
    it 'returns false with empty scores' do
      expect(proposal.passing_evaluation?).to be false
    end

    it 'returns true when all dimensions meet threshold' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.65] }
      proposal.evaluate!(scores)
      expect(proposal.passing_evaluation?).to be true
    end

    it 'returns false when any dimension is below threshold' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.65] }
      scores[scores.keys.first] = 0.4
      proposal.evaluate!(scores)
      expect(proposal.passing_evaluation?).to be false
    end
  end

  describe '#auto_approvable?' do
    it 'returns false with empty scores' do
      expect(proposal.auto_approvable?).to be false
    end

    it 'returns true when all dimensions meet AUTO_APPROVE_THRESHOLD' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.95] }
      proposal.evaluate!(scores)
      expect(proposal.auto_approvable?).to be true
    end

    it 'returns false when any dimension is below AUTO_APPROVE_THRESHOLD' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.95] }
      scores[scores.keys.first] = 0.8
      proposal.evaluate!(scores)
      expect(proposal.auto_approvable?).to be false
    end
  end

  describe '#transition!' do
    it 'updates status' do
      proposal.transition!(:building)
      expect(proposal.status).to eq(:building)
    end

    it 'sets built_at when transitioning to :passing' do
      proposal.transition!(:passing)
      expect(proposal.built_at).to be_a(Time)
    end

    it 'does not set built_at for other statuses' do
      proposal.transition!(:building)
      expect(proposal.built_at).to be_nil
    end
  end

  describe '#to_h' do
    it 'returns a hash with all FIELDS' do
      h = proposal.to_h
      described_class::FIELDS.each do |f|
        expect(h).to have_key(f)
      end
    end

    it 'includes the id' do
      expect(proposal.to_h[:id]).to eq(proposal.id)
    end

    it 'includes category as symbol' do
      expect(proposal.to_h[:category]).to eq(:cognition)
    end
  end
end
