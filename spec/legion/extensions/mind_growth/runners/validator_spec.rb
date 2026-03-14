# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Validator do
  subject(:validator) { described_class }

  # Reset proposer store before each example
  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  let(:proposal_id) do
    result = Legion::Extensions::MindGrowth::Runners::Proposer.propose_concept(
      name: 'lex-valid', category: :cognition, description: 'valid proposal'
    )
    result[:proposal][:id]
  end

  describe '.validate_proposal' do
    it 'returns not_found for unknown id' do
      result = validator.validate_proposal(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'validates a well-formed proposal successfully' do
      result = validator.validate_proposal(proposal_id: proposal_id)
      expect(result[:success]).to be true
      expect(result[:valid]).to be true
      expect(result[:issues]).to be_empty
    end

    it 'returns the proposal_id in the result' do
      result = validator.validate_proposal(proposal_id: proposal_id)
      expect(result[:proposal_id]).to eq(proposal_id)
    end

    it 'ignores unknown keyword arguments' do
      expect { validator.validate_proposal(proposal_id: proposal_id, extra: true) }.not_to raise_error
    end
  end

  describe '.validate_scores' do
    let(:valid_scores) do
      Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.75] }
    end

    it 'returns success: true for valid scores' do
      result = validator.validate_scores(scores: valid_scores)
      expect(result[:success]).to be true
      expect(result[:valid]).to be true
    end

    it 'reports missing dimensions' do
      incomplete = valid_scores.except(:novelty)
      result     = validator.validate_scores(scores: incomplete)
      expect(result[:success]).to be false
      expect(result[:issues]).to include('missing novelty')
    end

    it 'reports out-of-range values' do
      bad = valid_scores.merge(novelty: 1.5)
      result = validator.validate_scores(scores: bad)
      expect(result[:success]).to be false
      expect(result[:issues].any? { |i| i.include?('novelty out of range') }).to be true
    end

    it 'reports negative out-of-range values' do
      bad = valid_scores.merge(fit: -0.1)
      result = validator.validate_scores(scores: bad)
      expect(result[:success]).to be false
    end

    it 'returns issues array even when valid' do
      result = validator.validate_scores(scores: valid_scores)
      expect(result[:issues]).to be_an(Array)
    end

    it 'ignores unknown keyword arguments' do
      expect { validator.validate_scores(scores: valid_scores, extra: true) }.not_to raise_error
    end
  end

  describe '.validate_fitness' do
    let(:extensions) do
      [
        { invocation_count: 500, impact_score: 0.9, health_score: 1.0, error_rate: 0.0, avg_latency_ms: 50 },
        { invocation_count: 0, impact_score: 0.1, health_score: 0.2, error_rate: 0.9, avg_latency_ms: 4000 }
      ]
    end

    it 'returns success: true' do
      result = validator.validate_fitness(extensions: extensions)
      expect(result[:success]).to be true
    end

    it 'returns ranked extensions' do
      result = validator.validate_fitness(extensions: extensions)
      expect(result[:ranked]).to be_an(Array)
      expect(result[:ranked].size).to eq(2)
    end

    it 'returns prune_candidates count' do
      result = validator.validate_fitness(extensions: extensions)
      expect(result[:prune_candidates]).to be_a(Integer)
    end

    it 'returns improvement_candidates count' do
      result = validator.validate_fitness(extensions: extensions)
      expect(result[:improvement_candidates]).to be_a(Integer)
    end

    it 'handles empty extensions array' do
      result = validator.validate_fitness(extensions: [])
      expect(result[:success]).to be true
      expect(result[:ranked]).to be_empty
    end

    it 'ignores unknown keyword arguments' do
      expect { validator.validate_fitness(extensions: [], extra: true) }.not_to raise_error
    end
  end
end
