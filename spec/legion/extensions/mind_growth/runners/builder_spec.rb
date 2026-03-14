# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Builder do
  subject(:builder) { described_class }

  # Reset proposer store before each example
  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  let(:proposal_id) do
    result = Legion::Extensions::MindGrowth::Runners::Proposer.propose_concept(
      name: 'lex-buildable', category: :cognition, description: 'a buildable proposal'
    )
    result[:proposal][:id]
  end

  describe '.build_extension' do
    it 'returns not_found for unknown proposal_id' do
      result = builder.build_extension(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'returns success when proposal exists' do
      result = builder.build_extension(proposal_id: proposal_id)
      expect(result[:success]).to be true
    end

    it 'returns pipeline hash' do
      result = builder.build_extension(proposal_id: proposal_id)
      expect(result[:pipeline]).to be_a(Hash)
      expect(result[:pipeline][:stage]).to eq(:complete)
    end

    it 'returns proposal hash' do
      result = builder.build_extension(proposal_id: proposal_id)
      expect(result[:proposal]).to be_a(Hash)
    end

    it 'transitions proposal to :passing on success' do
      builder.build_extension(proposal_id: proposal_id)
      list = Legion::Extensions::MindGrowth::Runners::Proposer.list_proposals
      p = list[:proposals].find { |pr| pr[:id] == proposal_id }
      expect(p[:status]).to eq(:passing)
    end

    it 'accepts optional base_path parameter' do
      result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
      expect(result[:success]).to be true
    end

    it 'ignores unknown keyword arguments' do
      expect { builder.build_extension(proposal_id: proposal_id, unknown: :value) }.not_to raise_error
    end
  end

  describe '.build_status' do
    it 'returns not_found for unknown proposal_id' do
      result = builder.build_status(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'returns status for existing proposal' do
      result = builder.build_status(proposal_id: proposal_id)
      expect(result[:success]).to be true
      expect(result[:name]).to eq('lex-buildable')
    end

    it 'returns current status symbol' do
      result = builder.build_status(proposal_id: proposal_id)
      expect(result[:status]).to be_a(Symbol)
    end
  end

  describe 'stage stubs' do
    it 'progresses through all pipeline stages without error' do
      result = builder.build_extension(proposal_id: proposal_id)
      pipeline = result[:pipeline]
      expect(pipeline[:errors]).to be_empty
      expect(pipeline[:stage]).to eq(:complete)
    end
  end
end
