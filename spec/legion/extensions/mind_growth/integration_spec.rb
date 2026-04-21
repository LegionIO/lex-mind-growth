# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Self-Improvement Pipeline Integration' do
  let(:orchestrator) { Legion::Extensions::MindGrowth::Runners::Orchestrator }
  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }
  let(:governance) { Legion::Extensions::MindGrowth::Runners::Governance }

  before do
    proposer.instance_variable_set(:@proposal_store, nil)
    governance.instance_variable_set(:@votes_store, nil)
    governance.instance_variable_set(:@votes_mutex, nil)
  end

  describe 'auto-approve path (force: true bypasses governance)' do
    it 'runs analyze → propose → evaluate → build' do
      result = orchestrator.run_growth_cycle(
        existing_extensions: [],
        max_proposals:       1,
        force:               true
      )

      expect(result[:success]).to be true
      trace = result[:trace]

      step_names = trace[:steps].map { |s| s[:step] }
      expect(step_names).to include(:analyze)
      expect(step_names).to include(:propose)
      expect(step_names).to include(:evaluate)
      expect(step_names).to include(:build)
    end

    it 'build step attempts at least one build when force: true' do
      result = orchestrator.run_growth_cycle(
        existing_extensions: [],
        max_proposals:       1,
        force:               true
      )
      build_step = result[:trace][:steps].find { |s| s[:step] == :build }
      expect(build_step[:attempted]).to be > 0
    end

    it 'holds proposals for governance review when force is false (default scores 0.7)' do
      result = orchestrator.run_growth_cycle(
        existing_extensions: [],
        max_proposals:       1,
        force:               false
      )

      expect(result[:success]).to be true
      build_step = result[:trace][:steps].find { |s| s[:step] == :build }
      expect(build_step[:held]).to be > 0
      expect(build_step[:attempted]).to eq(0)
    end
  end

  describe 'governance path (scores 0.6-0.9)' do
    it 'holds proposal, then resolves to build_triggered on approve quorum' do
      prop = proposer.propose_concept(
        name: 'lex-gov-test', category: :cognition,
        description: 'governance path test', enrich: false
      )
      proposal_id = prop[:proposal][:id]

      proposer.evaluate_proposal(
        proposal_id: proposal_id,
        scores:      { novelty: 0.7, fit: 0.7, cognitive_value: 0.7,
                  implementability: 0.7, composability: 0.7 }
      )

      proposal = proposer.get_proposal_object(proposal_id)
      expect(proposal.status).to eq(:approved)
      expect(proposal.auto_approvable?).to be false

      governance.vote_on_proposal(proposal_id: proposal_id, vote: :approve, agent_id: 'a1')
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :approve, agent_id: 'a2')
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :approve, agent_id: 'a3')

      resolved = governance.governance_resolved(proposal_id: proposal_id)
      expect(resolved[:action]).to eq(:build_triggered)
    end
  end

  describe 'post-build pipeline' do
    it 'transitions from passing through wire to activation' do
      prop = proposer.propose_concept(
        name: 'lex-postbuild-test', category: :safety,
        description: 'post-build test', enrich: false
      )
      proposal_id = prop[:proposal][:id]

      proposer.evaluate_proposal(proposal_id: proposal_id,
                                 scores:      { novelty: 0.95, fit: 0.95, cognitive_value: 0.95,
                                           implementability: 0.95, composability: 0.95 })

      proposal = proposer.get_proposal_object(proposal_id)
      proposal.transition!(:building)
      proposal.transition!(:passing)

      result = orchestrator.post_build_pipeline(proposal_id: proposal_id)
      expect(result).to have_key(:wire)
      expect(result).to have_key(:integration_test)

      proposal = proposer.get_proposal_object(proposal_id)
      expect(%i[active degraded wired]).to include(proposal.status)
    end
  end

  describe 'rejection path' do
    it 'rejects proposal when governance votes against' do
      prop = proposer.propose_concept(
        name: 'lex-reject-test', category: :cognition,
        description: 'rejection test', enrich: false
      )
      proposal_id = prop[:proposal][:id]

      proposer.evaluate_proposal(proposal_id: proposal_id,
                                 scores:      { novelty: 0.7, fit: 0.7, cognitive_value: 0.7,
                                           implementability: 0.7, composability: 0.7 })

      governance.vote_on_proposal(proposal_id: proposal_id, vote: :reject, agent_id: 'a1')
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :reject, agent_id: 'a2')
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :reject, agent_id: 'a3')

      resolved = governance.governance_resolved(proposal_id: proposal_id)
      expect(resolved[:action]).to eq(:rejected)

      proposal = proposer.get_proposal_object(proposal_id)
      expect(proposal.status).to eq(:rejected)
    end
  end
end
