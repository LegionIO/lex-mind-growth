# frozen_string_literal: true

RSpec.describe 'Orchestrator full cycle with wire + test + activate' do
  let(:orchestrator) { Legion::Extensions::MindGrowth::Runners::Orchestrator }
  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }

  before { proposer.instance_variable_set(:@proposal_store, nil) }

  describe '.post_build_pipeline' do
    it 'calls wire_extension after successful build' do
      prop_result = proposer.propose_concept(name: 'lex-test-wire', category: :cognition,
                                             description: 'test wiring', enrich: false)
      proposal_id = prop_result[:proposal][:id]
      proposer.evaluate_proposal(
        proposal_id: proposal_id,
        scores:      { novelty: 0.95, fit: 0.95, cognitive_value: 0.95,
                       implementability: 0.95, composability: 0.95 }
      )
      proposal = proposer.get_proposal_object(proposal_id)
      proposal.transition!(:building)
      proposal.transition!(:passing)

      result = orchestrator.post_build_pipeline(proposal_id: proposal_id)
      expect(result).to have_key(:wire)
      expect(result).to have_key(:integration_test)
    end

    it 'skips wire for non-passing proposals' do
      prop_result = proposer.propose_concept(name: 'lex-test-skip', category: :cognition,
                                             description: 'test skip', enrich: false)
      proposal_id = prop_result[:proposal][:id]
      result = orchestrator.post_build_pipeline(proposal_id: proposal_id)
      expect(result[:skipped]).to be true
      expect(result[:reason]).to include('not in :passing')
    end

    it 'returns skipped: true for unknown proposal_id' do
      result = orchestrator.post_build_pipeline(proposal_id: 'nonexistent-id')
      expect(result[:skipped]).to be true
      expect(result[:reason]).to include('proposal not found')
    end

    it 'includes proposal_id in the result' do
      prop_result = proposer.propose_concept(name: 'lex-test-id', category: :cognition,
                                             description: 'test id tracking', enrich: false)
      proposal_id = prop_result[:proposal][:id]
      proposal = proposer.get_proposal_object(proposal_id)
      proposal.transition!(:building)
      proposal.transition!(:passing)

      result = orchestrator.post_build_pipeline(proposal_id: proposal_id)
      expect(result[:proposal_id]).to eq(proposal_id)
    end

    it 'transitions to :active when integration test succeeds' do
      prop_result = proposer.propose_concept(name: 'lex-test-active', category: :cognition,
                                             description: 'test activation', enrich: false)
      proposal_id = prop_result[:proposal][:id]
      proposal = proposer.get_proposal_object(proposal_id)
      proposal.transition!(:building)
      proposal.transition!(:passing)

      allow(Legion::Extensions::MindGrowth::Runners::Wirer)
        .to receive(:wire_extension)
        .and_return({ success: true, extension: proposal.name, phase: :working_memory })
      allow(Legion::Extensions::MindGrowth::Runners::IntegrationTester)
        .to receive(:test_extension_in_tick)
        .and_return({ success: true, phase: :working_memory_integration })

      result = orchestrator.post_build_pipeline(proposal_id: proposal_id)
      expect(result[:activated]).to be true
      expect(proposal.status).to eq(:active)
    end

    it 'transitions to :degraded when integration test fails' do
      prop_result = proposer.propose_concept(name: 'lex-test-degraded', category: :cognition,
                                             description: 'test degraded path', enrich: false)
      proposal_id = prop_result[:proposal][:id]
      proposal = proposer.get_proposal_object(proposal_id)
      proposal.transition!(:building)
      proposal.transition!(:passing)

      allow(Legion::Extensions::MindGrowth::Runners::Wirer)
        .to receive(:wire_extension)
        .and_return({ success: true, extension: proposal.name, phase: :working_memory })
      allow(Legion::Extensions::MindGrowth::Runners::IntegrationTester)
        .to receive(:test_extension_in_tick)
        .and_return({ success: false, reason: :runner_not_found })

      result = orchestrator.post_build_pipeline(proposal_id: proposal_id)
      expect(result[:activated]).to be false
      expect(proposal.status).to eq(:degraded)
    end

    it 'ignores unknown keyword arguments' do
      prop_result = proposer.propose_concept(name: 'lex-test-kwargs', category: :cognition,
                                             description: 'test kwargs', enrich: false)
      proposal_id = prop_result[:proposal][:id]
      proposal = proposer.get_proposal_object(proposal_id)
      proposal.transition!(:building)
      proposal.transition!(:passing)

      expect { orchestrator.post_build_pipeline(proposal_id: proposal_id, unknown: :val) }.not_to raise_error
    end
  end
end
