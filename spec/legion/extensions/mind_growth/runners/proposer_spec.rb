# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Proposer do
  subject(:proposer) { described_class }

  # Reset the memoized proposal store between examples
  before { proposer.instance_variable_set(:@proposal_store, nil) }

  describe '.analyze_gaps' do
    it 'returns success: true' do
      result = proposer.analyze_gaps
      expect(result[:success]).to be true
    end

    it 'returns models array' do
      result = proposer.analyze_gaps
      expect(result[:models]).to be_an(Array)
    end

    it 'returns recommendations array' do
      result = proposer.analyze_gaps
      expect(result[:recommendations]).to be_an(Array)
    end

    it 'accepts existing_extensions parameter' do
      result = proposer.analyze_gaps(existing_extensions: %i[attention memory])
      expect(result[:success]).to be true
    end

    it 'limits recommendations to 10' do
      result = proposer.analyze_gaps(existing_extensions: [])
      expect(result[:recommendations].size).to be <= 10
    end

    it 'ignores unknown keyword arguments' do
      expect { proposer.analyze_gaps(unknown_key: true) }.not_to raise_error
    end
  end

  describe '.propose_concept' do
    it 'returns success: true' do
      result = proposer.propose_concept(name: 'lex-test', category: :cognition, description: 'test')
      expect(result[:success]).to be true
    end

    it 'includes proposal hash' do
      result = proposer.propose_concept(name: 'lex-test', category: :cognition, description: 'test')
      expect(result[:proposal]).to be_a(Hash)
      expect(result[:proposal][:id]).to be_a(String)
    end

    it 'uses provided name' do
      result = proposer.propose_concept(name: 'lex-custom', category: :cognition, description: 'test')
      expect(result[:proposal][:name]).to eq('lex-custom')
    end

    it 'generates a name when none provided' do
      result = proposer.propose_concept(category: :cognition, description: 'test')
      expect(result[:proposal][:name]).to start_with('lex-')
    end

    it 'uses provided category' do
      result = proposer.propose_concept(name: 'lex-cat', category: :safety, description: 'test')
      expect(result[:proposal][:category]).to eq(:safety)
    end

    it 'falls back to suggested category when none given' do
      result = proposer.propose_concept(description: 'auto category')
      expect(Legion::Extensions::MindGrowth::Helpers::Constants::CATEGORIES).to include(result[:proposal][:category])
    end

    it 'stores proposal in the proposal store' do
      result = proposer.propose_concept(name: 'lex-stored', category: :cognition, description: 'test')
      id     = result[:proposal][:id]
      stats  = proposer.proposal_stats
      expect(stats[:stats][:total]).to eq(1)
      get_result = proposer.list_proposals
      expect(get_result[:proposals].map { |p| p[:id] }).to include(id)
    end
  end

  describe '.evaluate_proposal' do
    let!(:proposal_id) do
      result = proposer.propose_concept(name: 'lex-eval', category: :cognition, description: 'to evaluate')
      result[:proposal][:id]
    end

    it 'returns not_found for unknown id' do
      result = proposer.evaluate_proposal(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'evaluates with default scores' do
      result = proposer.evaluate_proposal(proposal_id: proposal_id)
      expect(result[:success]).to be true
    end

    it 'evaluates with provided scores' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.8] }
      result = proposer.evaluate_proposal(proposal_id: proposal_id, scores: scores)
      expect(result[:success]).to be true
      expect(result[:approved]).to be true
    end

    it 'rejects when scores are below threshold' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.4] }
      result = proposer.evaluate_proposal(proposal_id: proposal_id, scores: scores)
      expect(result[:approved]).to be false
    end

    it 'returns proposal hash' do
      result = proposer.evaluate_proposal(proposal_id: proposal_id)
      expect(result[:proposal]).to be_a(Hash)
    end
  end

  describe '.list_proposals' do
    it 'returns success: true with empty store' do
      result = proposer.list_proposals
      expect(result[:success]).to be true
      expect(result[:proposals]).to be_an(Array)
    end

    it 'returns all proposals when no status filter' do
      proposer.propose_concept(name: 'lex-a', category: :cognition, description: 'a')
      proposer.propose_concept(name: 'lex-b', category: :memory, description: 'b')
      result = proposer.list_proposals
      expect(result[:count]).to eq(2)
    end

    it 'filters by status' do
      proposer.propose_concept(name: 'lex-filter', category: :cognition, description: 'filter')
      result = proposer.list_proposals(status: :proposed)
      expect(result[:proposals]).not_to be_empty
      result[:proposals].each do |p|
        expect(p[:status]).to eq(:proposed)
      end
    end

    it 'respects limit parameter' do
      5.times { |i| proposer.propose_concept(name: "lex-lim-#{i}", category: :cognition, description: "limit #{i}") }
      result = proposer.list_proposals(limit: 3)
      expect(result[:proposals].size).to be <= 3
    end
  end

  describe '.proposal_stats' do
    it 'returns success: true' do
      expect(proposer.proposal_stats[:success]).to be true
    end

    it 'includes total count' do
      proposer.propose_concept(name: 'lex-stat', category: :cognition, description: 'stat')
      expect(proposer.proposal_stats[:stats][:total]).to eq(1)
    end
  end
end
