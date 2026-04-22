# frozen_string_literal: true

RSpec.describe 'Governance callback triggers build' do
  let(:governance) { Legion::Extensions::MindGrowth::Runners::Governance }
  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }

  before { proposer.instance_variable_set(:@proposal_store, nil) }

  describe '.governance_resolved' do
    it 'triggers build when quorum approves' do
      proposal = proposer.propose_concept(name: 'lex-test-governance', category: :cognition,
                                          description: 'test governance callback', enrich: false)
      proposal_id = proposal[:proposal][:id]
      proposer.evaluate_proposal(proposal_id: proposal_id,
                                 scores:      { novelty: 0.7, fit: 0.7, cognitive_value: 0.7,
                                           implementability: 0.7, composability: 0.7 })
      governance.instance_variable_set(:@votes_store, {})
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :approve, agent_id: 'agent-1')
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :approve, agent_id: 'agent-2')
      governance.vote_on_proposal(proposal_id: proposal_id, vote: :approve, agent_id: 'agent-3')

      resolved = governance.governance_resolved(proposal_id: proposal_id)
      expect(resolved[:action]).to eq(:build_triggered)
    end

    it 'does not trigger build when quorum rejects' do
      proposal = proposer.propose_concept(name: 'lex-test-rejected', category: :cognition,
                                          description: 'test rejected', enrich: false)
      proposal_id = proposal[:proposal][:id]
      proposer.evaluate_proposal(proposal_id: proposal_id,
                                 scores:      { novelty: 0.7, fit: 0.7, cognitive_value: 0.7,
                                           implementability: 0.7, composability: 0.7 })
      governance.instance_variable_set(:@votes_store, {})
      3.times { |i| governance.vote_on_proposal(proposal_id: proposal_id, vote: :reject, agent_id: "a#{i}") }
      resolved = governance.governance_resolved(proposal_id: proposal_id)
      expect(resolved[:action]).to eq(:rejected)
    end

    it 'returns pending when quorum not reached' do
      governance.instance_variable_set(:@votes_store, {})
      governance.vote_on_proposal(proposal_id: 'fake-id', vote: :approve, agent_id: 'agent-1')
      resolved = governance.governance_resolved(proposal_id: 'fake-id')
      expect(resolved[:action]).to eq(:pending)
    end
  end

  describe 'event listener registration' do
    it 'registers a listener for governance.quorum_reached' do
      events_spy = Class.new do
        attr_reader :registered

        def initialize
          @registered = []
        end

        def on(event, &block)
          @registered << { event: event, block: block }
        end

        def emit(*)
          nil
        end
      end.new
      stub_const('Legion::Events', events_spy)
      Legion::Extensions::MindGrowth::Hooks::GovernanceListener.register
      expect(events_spy.registered.map { |r| r[:event] }).to include('governance.quorum_reached')
    end
  end
end
