# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Client do
  subject(:client) { described_class.new }

  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  describe '#initialize' do
    it 'instantiates without arguments' do
      expect { described_class.new }.not_to raise_error
    end
  end

  describe 'Proposer methods' do
    it 'responds to analyze_gaps' do
      expect(client).to respond_to(:analyze_gaps)
    end

    it 'responds to propose_concept' do
      expect(client).to respond_to(:propose_concept)
    end

    it 'responds to evaluate_proposal' do
      expect(client).to respond_to(:evaluate_proposal)
    end

    it 'responds to list_proposals' do
      expect(client).to respond_to(:list_proposals)
    end

    it 'responds to proposal_stats' do
      expect(client).to respond_to(:proposal_stats)
    end
  end

  describe 'Analyzer methods' do
    it 'responds to cognitive_profile' do
      expect(client).to respond_to(:cognitive_profile)
    end

    it 'responds to identify_weak_links' do
      expect(client).to respond_to(:identify_weak_links)
    end

    it 'responds to recommend_priorities' do
      expect(client).to respond_to(:recommend_priorities)
    end
  end

  describe 'Builder methods' do
    it 'responds to build_extension' do
      expect(client).to respond_to(:build_extension)
    end

    it 'responds to build_status' do
      expect(client).to respond_to(:build_status)
    end
  end

  describe 'Validator methods' do
    it 'responds to validate_proposal' do
      expect(client).to respond_to(:validate_proposal)
    end

    it 'responds to validate_scores' do
      expect(client).to respond_to(:validate_scores)
    end

    it 'responds to validate_fitness' do
      expect(client).to respond_to(:validate_fitness)
    end
  end

  describe 'end-to-end workflow' do
    it 'proposes, evaluates, and validates a concept' do
      propose_result = client.propose_concept(name: 'lex-e2e', category: :cognition, description: 'end-to-end test')
      expect(propose_result[:success]).to be true

      proposal_id = propose_result[:proposal][:id]

      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.8] }
      evaluate_result = client.evaluate_proposal(proposal_id: proposal_id, scores: scores)
      expect(evaluate_result[:approved]).to be true

      validate_result = client.validate_proposal(proposal_id: proposal_id)
      expect(validate_result[:valid]).to be true
    end

    it 'provides gap analysis and prioritized recommendations' do
      profile = client.cognitive_profile(existing_extensions: %i[attention memory])
      expect(profile[:overall_coverage]).to be < 1.0

      priorities = client.recommend_priorities(existing_extensions: %i[attention memory])
      expect(priorities[:priorities]).to be_an(Array)
    end

    it 'builds a proposal end-to-end' do
      propose_result = client.propose_concept(name: 'lex-build-e2e', category: :safety, description: 'build e2e')
      proposal_id    = propose_result[:proposal][:id]
      build_result   = client.build_extension(proposal_id: proposal_id)
      expect(build_result[:success]).to be true
      expect(build_result[:pipeline][:stage]).to eq(:complete)
    end

    it 'validates scores before evaluation' do
      valid_scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.7] }
      validation   = client.validate_scores(scores: valid_scores)
      expect(validation[:valid]).to be true
    end
  end
end
