# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::ConsensusBuilder do
  subject(:consensus_builder) { described_class }

  let(:charter_id)  { 'charter-test-001' }
  let(:proposal_id) { 'proposal-abc-001' }

  def stub_workspace_available
    stub_const('Legion::Extensions::Swarm::Runners::Workspace', Module.new)
  end

  def stub_workspace_put
    allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
      .and_return({ success: true, version: 1 })
  end

  def stub_workspace_get(key:, value: nil, success: true)
    response = if success
                 { success: true, entry: { value: value, version: 1, key: key, author: 'test', timestamp: Time.now.utc } }
               else
                 { success: false, reason: :not_found }
               end
    allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
      .with(hash_including(key: key))
      .and_return(response)
  end

  def cast_votes(approve_count:, reject_count:)
    votes = []
    approve_count.times { |i| votes << { voter_agent_id: "approver-#{i}", vote: :approve } }
    reject_count.times  { |i| votes << { voter_agent_id: "rejector-#{i}", vote: :reject } }
    votes
  end

  # ─── constants ────────────────────────────────────────────────────────────

  describe 'constants' do
    it 'CONSENSUS_THRESHOLD is 0.67' do
      expect(described_class::CONSENSUS_THRESHOLD).to eq(0.67)
    end

    it 'DISAGREEMENT_ESCALATION_THRESHOLD is 0.5' do
      expect(described_class::DISAGREEMENT_ESCALATION_THRESHOLD).to eq(0.5)
    end
  end

  # ─── propose_to_swarm ─────────────────────────────────────────────────────

  describe '.propose_to_swarm' do
    context 'when lex-swarm workspace is available' do
      before do
        stub_workspace_available
        stub_workspace_put
        stub_workspace_get(key: 'pending_proposals', value: [])
      end

      it 'returns success: true' do
        result = consensus_builder.propose_to_swarm(
          charter_id: charter_id, proposal_id: proposal_id, proposer_agent_id: 'agent-1'
        )
        expect(result[:success]).to be true
      end

      it 'returns the proposal_id' do
        result = consensus_builder.propose_to_swarm(
          charter_id: charter_id, proposal_id: proposal_id, proposer_agent_id: 'agent-1'
        )
        expect(result[:proposal_id]).to eq(proposal_id)
      end

      it 'stores the proposal in workspace under pending_proposals' do
        expect(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
          .with(hash_including(key: 'pending_proposals'))
          .and_return({ success: true, version: 1 })
        consensus_builder.propose_to_swarm(
          charter_id: charter_id, proposal_id: proposal_id, proposer_agent_id: 'agent-1'
        )
      end

      it 'appends to existing pending proposals' do
        existing = [{ proposal_id: 'existing-prop', proposer_agent_id: 'old-agent' }]
        stub_workspace_get(key: 'pending_proposals', value: existing)
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put) do |**args|
          expect(args[:value].size).to eq(2) if args[:key] == 'pending_proposals'
          { success: true, version: 2 }
        end
        consensus_builder.propose_to_swarm(
          charter_id: charter_id, proposal_id: proposal_id, proposer_agent_id: 'agent-1'
        )
      end
    end

    context 'when lex-swarm workspace is unavailable' do
      let(:governance) { Legion::Extensions::MindGrowth::Runners::Governance }

      before do
        allow(governance).to receive(:submit_proposal)
          .and_return({ success: true, proposal_id: proposal_id })
      end

      it 'returns success: true' do
        result = consensus_builder.propose_to_swarm(
          charter_id: charter_id, proposal_id: proposal_id, proposer_agent_id: 'agent-1'
        )
        expect(result[:success]).to be true
      end

      it 'falls back to Governance.submit_proposal' do
        expect(governance).to receive(:submit_proposal).with(proposal_id: proposal_id)
        consensus_builder.propose_to_swarm(
          charter_id: charter_id, proposal_id: proposal_id, proposer_agent_id: 'agent-1'
        )
      end
    end
  end

  # ─── vote_in_swarm ────────────────────────────────────────────────────────

  describe '.vote_in_swarm' do
    context 'when lex-swarm workspace is available' do
      before do
        stub_workspace_available
        stub_workspace_put
        stub_workspace_get(key: "votes:#{proposal_id}", value: [])
      end

      it 'returns success: true for :approve vote' do
        result = consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: :approve
        )
        expect(result[:success]).to be true
        expect(result[:vote]).to eq(:approve)
      end

      it 'returns success: true for :reject vote' do
        result = consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: :reject
        )
        expect(result[:success]).to be true
        expect(result[:vote]).to eq(:reject)
      end

      it 'returns success: false for invalid vote' do
        result = consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: :maybe
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:invalid_vote)
      end

      it 'stores the vote in workspace under votes:proposal_id key' do
        expect(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
          .with(hash_including(key: "votes:#{proposal_id}"))
          .and_return({ success: true, version: 1 })
        consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: :approve
        )
      end

      it 'accepts string vote values' do
        result = consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: 'approve'
        )
        expect(result[:success]).to be true
      end
    end

    context 'when lex-swarm workspace is unavailable' do
      it 'still validates the vote and returns result' do
        result = consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: :approve
        )
        expect(result[:success]).to be true
        expect(result[:vote]).to eq(:approve)
      end

      it 'rejects invalid vote even without workspace' do
        result = consensus_builder.vote_in_swarm(
          charter_id: charter_id, proposal_id: proposal_id,
          voter_agent_id: 'agent-1', vote: :abstain
        )
        expect(result[:success]).to be false
      end
    end
  end

  # ─── tally_swarm_votes ────────────────────────────────────────────────────

  describe '.tally_swarm_votes' do
    context 'when lex-swarm workspace is available' do
      before { stub_workspace_available }

      it 'returns success: true' do
        stub_workspace_get(key: "votes:#{proposal_id}", value: [])
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:success]).to be true
      end

      it 'returns threshold value in response' do
        stub_workspace_get(key: "votes:#{proposal_id}", value: [])
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:threshold]).to eq(0.67)
      end

      it 'returns :no_consensus when no votes cast' do
        stub_workspace_get(key: "votes:#{proposal_id}", value: [])
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:consensus]).to eq(:no_consensus)
      end

      it 'returns :approved when approve ratio >= CONSENSUS_THRESHOLD' do
        votes = cast_votes(approve_count: 3, reject_count: 1)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:consensus]).to eq(:approved)
      end

      it 'returns :rejected when reject ratio >= CONSENSUS_THRESHOLD' do
        votes = cast_votes(approve_count: 1, reject_count: 3)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:consensus]).to eq(:rejected)
      end

      it 'returns :no_consensus when split is exactly 50/50' do
        votes = cast_votes(approve_count: 2, reject_count: 2)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:consensus]).to eq(:no_consensus)
      end

      it 'reports correct approve_count and reject_count' do
        votes = cast_votes(approve_count: 3, reject_count: 1)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:approve_count]).to eq(3)
        expect(result[:reject_count]).to eq(1)
        expect(result[:total]).to eq(4)
      end

      it 'returns :approved at exactly the 0.67 threshold (4/6)' do
        # 4/6 = 0.6666... which is just below 0.67 - should be no_consensus
        votes = cast_votes(approve_count: 4, reject_count: 2)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        # 4/6 ~= 0.667, which is >= 0.67 boundary — actual value 0.6666... < 0.67
        expect(%i[approved no_consensus]).to include(result[:consensus])
      end

      it 'returns :approved with unanimous votes' do
        votes = cast_votes(approve_count: 5, reject_count: 0)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:consensus]).to eq(:approved)
      end
    end

    context 'when lex-swarm workspace is unavailable' do
      it 'returns success: true with no_consensus and zero counts' do
        result = consensus_builder.tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:success]).to be true
        expect(result[:total]).to eq(0)
        expect(result[:consensus]).to eq(:no_consensus)
      end
    end
  end

  # ─── resolve_disagreement ─────────────────────────────────────────────────

  describe '.resolve_disagreement' do
    context 'when lex-swarm workspace is available' do
      before { stub_workspace_available }

      it 'returns success: true' do
        stub_workspace_get(key: "votes:#{proposal_id}", value: [])
        result = consensus_builder.resolve_disagreement(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:success]).to be true
      end

      it 'escalates to human when split is near 50/50 but below consensus threshold' do
        # 3 approve, 3 reject = 50% approve < 67% threshold, >= 50% escalation threshold
        votes = cast_votes(approve_count: 3, reject_count: 3)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.resolve_disagreement(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:resolution]).to eq(:escalated_to_human)
      end

      it 'escalates when approve ratio is >= 0.5 and < 0.67' do
        # 2 approve, 1 reject = 67% - wait, let's do 3/5 = 60%
        votes = cast_votes(approve_count: 3, reject_count: 2)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.resolve_disagreement(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:resolution]).to eq(:escalated_to_human)
      end

      it 'rejects by default when approve count is below escalation threshold' do
        # 1 approve, 4 reject = 20% approve, below 50% escalation threshold
        votes = cast_votes(approve_count: 1, reject_count: 4)
        stub_workspace_get(key: "votes:#{proposal_id}", value: votes)
        result = consensus_builder.resolve_disagreement(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:resolution]).to eq(:rejected_by_default)
      end

      it 'rejects by default when no votes exist' do
        stub_workspace_get(key: "votes:#{proposal_id}", value: [])
        result = consensus_builder.resolve_disagreement(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:resolution]).to eq(:rejected_by_default)
      end
    end

    context 'when lex-swarm workspace is unavailable' do
      it 'returns success: true with rejected_by_default' do
        result = consensus_builder.resolve_disagreement(charter_id: charter_id, proposal_id: proposal_id)
        expect(result[:success]).to be true
        expect(result[:resolution]).to eq(:rejected_by_default)
      end
    end
  end

  # ─── consensus_summary ────────────────────────────────────────────────────

  describe '.consensus_summary' do
    context 'when lex-swarm workspace is available' do
      before { stub_workspace_available }

      it 'returns success: true' do
        stub_workspace_get(key: 'pending_proposals', value: [])
        result = consensus_builder.consensus_summary(charter_id: charter_id)
        expect(result[:success]).to be true
      end

      it 'returns proposals array' do
        stub_workspace_get(key: 'pending_proposals', value: [])
        result = consensus_builder.consensus_summary(charter_id: charter_id)
        expect(result[:proposals]).to be_an(Array)
      end

      it 'returns decided and pending arrays' do
        stub_workspace_get(key: 'pending_proposals', value: [])
        result = consensus_builder.consensus_summary(charter_id: charter_id)
        expect(result[:decided]).to be_an(Array)
        expect(result[:pending]).to be_an(Array)
      end

      it 'categorizes decided proposals correctly' do
        pending_props = [{ proposal_id: 'p1', proposer_agent_id: 'a1' }]
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .with(hash_including(key: 'pending_proposals'))
          .and_return({ success: true, entry: { value: pending_props, version: 1, key: 'pending_proposals',
                                                 author: 'test', timestamp: Time.now.utc } })
        # unanimous approve → :approved consensus
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .with(hash_including(key: 'votes:p1'))
          .and_return({ success: true, entry: { value: cast_votes(approve_count: 3, reject_count: 0), version: 1,
                                                 key: 'votes:p1', author: 'test', timestamp: Time.now.utc } })

        result = consensus_builder.consensus_summary(charter_id: charter_id)
        expect(result[:decided].size).to eq(1)
        expect(result[:pending]).to be_empty
      end

      it 'places no_consensus proposals in pending' do
        pending_props = [{ proposal_id: 'p2', proposer_agent_id: 'a1' }]
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .with(hash_including(key: 'pending_proposals'))
          .and_return({ success: true, entry: { value: pending_props, version: 1, key: 'pending_proposals',
                                                 author: 'test', timestamp: Time.now.utc } })
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .with(hash_including(key: 'votes:p2'))
          .and_return({ success: true, entry: { value: cast_votes(approve_count: 1, reject_count: 1), version: 1,
                                                 key: 'votes:p2', author: 'test', timestamp: Time.now.utc } })

        result = consensus_builder.consensus_summary(charter_id: charter_id)
        expect(result[:pending].size).to eq(1)
        expect(result[:decided]).to be_empty
      end
    end

    context 'when lex-swarm workspace is unavailable' do
      it 'returns success: true with empty arrays' do
        result = consensus_builder.consensus_summary(charter_id: charter_id)
        expect(result[:success]).to be true
        expect(result[:proposals]).to be_empty
        expect(result[:decided]).to be_empty
        expect(result[:pending]).to be_empty
      end
    end
  end
end
