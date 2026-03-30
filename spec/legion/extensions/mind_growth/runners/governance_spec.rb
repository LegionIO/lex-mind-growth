# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Governance do
  subject(:governance) { described_class }

  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }

  before do
    proposer.instance_variable_set(:@proposal_store, nil)
    governance.instance_variable_set(:@votes_store, nil)
    governance.instance_variable_set(:@votes_mutex, nil)
  end

  def create_proposal(name: 'lex-gov-test', category: :cognition, status: nil)
    result = proposer.propose_concept(name: name, category: category, description: 'test proposal', enrich: false)
    proposal = proposer.get_proposal_object(result[:proposal][:id])
    proposal.transition!(status) if status && status != :proposed
    proposal
  end

  # ─── submit_proposal ──────────────────────────────────────────────────────

  describe '.submit_proposal' do
    context 'with a valid proposed proposal' do
      it 'returns success: true' do
        proposal = create_proposal
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:success]).to be true
      end

      it 'returns the proposal_id' do
        proposal = create_proposal
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:proposal_id]).to eq(proposal.id)
      end

      it 'returns status: :evaluating' do
        proposal = create_proposal
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:status]).to eq(:evaluating)
      end

      it 'transitions the proposal to :evaluating' do
        proposal = create_proposal
        governance.submit_proposal(proposal_id: proposal.id)
        expect(proposal.status).to eq(:evaluating)
      end
    end

    context 'with an already-evaluating proposal' do
      it 'returns success: true and keeps :evaluating status' do
        proposal = create_proposal
        governance.submit_proposal(proposal_id: proposal.id)
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:success]).to be true
        expect(result[:status]).to eq(:evaluating)
      end
    end

    context 'with a proposal in an invalid status' do
      it 'returns success: false for :building status' do
        proposal = create_proposal(status: :building)
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:success]).to be false
      end

      it 'returns :invalid_status error' do
        proposal = create_proposal(status: :building)
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:error]).to eq(:invalid_status)
      end

      it 'includes current_status in the error response' do
        proposal = create_proposal(status: :building)
        result = governance.submit_proposal(proposal_id: proposal.id)
        expect(result[:current_status]).to eq(:building)
      end
    end

    context 'with a non-existent proposal_id' do
      it 'returns success: false' do
        result = governance.submit_proposal(proposal_id: 'no-such-id')
        expect(result[:success]).to be false
      end

      it 'returns :not_found error' do
        result = governance.submit_proposal(proposal_id: 'no-such-id')
        expect(result[:error]).to eq(:not_found)
      end
    end

    it 'ignores unknown keyword arguments' do
      proposal = create_proposal
      expect { governance.submit_proposal(proposal_id: proposal.id, extra: true) }.not_to raise_error
    end
  end

  # ─── vote_on_proposal ─────────────────────────────────────────────────────

  describe '.vote_on_proposal' do
    let(:proposal) { create_proposal }

    it 'returns success: true for :approve vote' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve)
      expect(result[:success]).to be true
    end

    it 'returns success: true for :reject vote' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :reject)
      expect(result[:success]).to be true
    end

    it 'returns the proposal_id' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve)
      expect(result[:proposal_id]).to eq(proposal.id)
    end

    it 'returns the vote symbol' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve)
      expect(result[:vote]).to eq(:approve)
    end

    it 'returns the agent_id' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: 'agent-1')
      expect(result[:agent_id]).to eq('agent-1')
    end

    it 'uses "default" as agent_id when not provided' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve)
      expect(result[:agent_id]).to eq('default')
    end

    it 'accepts string vote values and coerces to symbol' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: 'approve')
      expect(result[:success]).to be true
      expect(result[:vote]).to eq(:approve)
    end

    it 'returns success: false for invalid vote' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :maybe)
      expect(result[:success]).to be false
    end

    it 'returns :invalid_vote error for unknown vote' do
      result = governance.vote_on_proposal(proposal_id: proposal.id, vote: :abstain)
      expect(result[:error]).to eq(:invalid_vote)
    end

    it 'accumulates multiple votes for the same proposal' do
      3.times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "agent-#{i}") }
      tally = governance.tally_votes(proposal_id: proposal.id)
      expect(tally[:total]).to eq(3)
    end

    context 'thread safety' do
      it 'records all votes when cast concurrently' do
        threads = Array.new(10) do |i|
          Thread.new { governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "t#{i}") }
        end
        threads.each(&:join)
        tally = governance.tally_votes(proposal_id: proposal.id)
        expect(tally[:total]).to eq(10)
      end

      it 'correctly tallies mixed concurrent votes' do
        threads = []
        5.times { |i| threads << Thread.new { governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}") } }
        5.times { |i| threads << Thread.new { governance.vote_on_proposal(proposal_id: proposal.id, vote: :reject,  agent_id: "r#{i}") } }
        threads.each(&:join)
        tally = governance.tally_votes(proposal_id: proposal.id)
        expect(tally[:approve_count]).to eq(5)
        expect(tally[:reject_count]).to eq(5)
      end
    end
  end

  # ─── tally_votes ──────────────────────────────────────────────────────────

  describe '.tally_votes' do
    let(:proposal) { create_proposal }

    it 'returns success: true' do
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:success]).to be true
    end

    it 'returns the proposal_id' do
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:proposal_id]).to eq(proposal.id)
    end

    it 'returns zero counts with no votes' do
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:approve_count]).to eq(0)
      expect(result[:reject_count]).to eq(0)
      expect(result[:total]).to eq(0)
    end

    it 'returns :pending verdict when total < QUORUM' do
      2.times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}") }
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:verdict]).to eq(:pending)
    end

    it 'returns :approved verdict when approve_count > reject_count and total >= QUORUM' do
      3.times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}") }
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:verdict]).to eq(:approved)
    end

    it 'returns :rejected verdict when reject_count >= approve_count and total >= QUORUM' do
      2.times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :reject,  agent_id: "r#{i}") }
      governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: 'a0')
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:verdict]).to eq(:rejected)
    end

    it 'returns :rejected on a tie when total >= QUORUM' do
      3.times do |i|
        governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}")
        governance.vote_on_proposal(proposal_id: proposal.id, vote: :reject,  agent_id: "r#{i}")
      end
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:verdict]).to eq(:rejected)
    end

    it 'counts approve votes correctly' do
      2.times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}") }
      governance.vote_on_proposal(proposal_id: proposal.id, vote: :reject, agent_id: 'r0')
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:approve_count]).to eq(2)
      expect(result[:reject_count]).to eq(1)
    end

    it 'returns :pending for an unknown proposal_id with no votes' do
      result = governance.tally_votes(proposal_id: 'nonexistent')
      expect(result[:verdict]).to eq(:pending)
      expect(result[:total]).to eq(0)
    end

    it 'requires exactly QUORUM votes for non-pending verdict' do
      quorum = Legion::Extensions::MindGrowth::Helpers::Constants::QUORUM
      (quorum - 1).times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}") }
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:verdict]).to eq(:pending)

      governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: 'final')
      result = governance.tally_votes(proposal_id: proposal.id)
      expect(result[:verdict]).to eq(:approved)
    end
  end

  # ─── approve_proposal ─────────────────────────────────────────────────────

  describe '.approve_proposal' do
    it 'returns success: true' do
      proposal = create_proposal
      result = governance.approve_proposal(proposal_id: proposal.id)
      expect(result[:success]).to be true
    end

    it 'returns status: :approved' do
      proposal = create_proposal
      result = governance.approve_proposal(proposal_id: proposal.id)
      expect(result[:status]).to eq(:approved)
    end

    it 'transitions the proposal to :approved' do
      proposal = create_proposal
      governance.approve_proposal(proposal_id: proposal.id)
      expect(proposal.status).to eq(:approved)
    end

    it 'returns the proposal_id' do
      proposal = create_proposal
      result = governance.approve_proposal(proposal_id: proposal.id)
      expect(result[:proposal_id]).to eq(proposal.id)
    end

    it 'returns success: false for non-existent proposal' do
      result = governance.approve_proposal(proposal_id: 'missing')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'accepts an optional reason keyword' do
      proposal = create_proposal
      expect { governance.approve_proposal(proposal_id: proposal.id, reason: 'looks good') }.not_to raise_error
    end
  end

  # ─── reject_proposal ──────────────────────────────────────────────────────

  describe '.reject_proposal' do
    it 'returns success: true' do
      proposal = create_proposal
      result = governance.reject_proposal(proposal_id: proposal.id)
      expect(result[:success]).to be true
    end

    it 'returns status: :rejected' do
      proposal = create_proposal
      result = governance.reject_proposal(proposal_id: proposal.id)
      expect(result[:status]).to eq(:rejected)
    end

    it 'transitions the proposal to :rejected' do
      proposal = create_proposal
      governance.reject_proposal(proposal_id: proposal.id)
      expect(proposal.status).to eq(:rejected)
    end

    it 'returns the proposal_id' do
      proposal = create_proposal
      result = governance.reject_proposal(proposal_id: proposal.id)
      expect(result[:proposal_id]).to eq(proposal.id)
    end

    it 'includes the reason in the response' do
      proposal = create_proposal
      result = governance.reject_proposal(proposal_id: proposal.id, reason: 'too risky')
      expect(result[:reason]).to eq('too risky')
    end

    it 'returns nil reason when none provided' do
      proposal = create_proposal
      result = governance.reject_proposal(proposal_id: proposal.id)
      expect(result[:reason]).to be_nil
    end

    it 'returns success: false for non-existent proposal' do
      result = governance.reject_proposal(proposal_id: 'missing')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end
  end

  # ─── governance_stats ─────────────────────────────────────────────────────

  describe '.governance_stats' do
    it 'returns success: true' do
      result = governance.governance_stats
      expect(result[:success]).to be true
    end

    it 'includes total_votes key' do
      result = governance.governance_stats
      expect(result).to have_key(:total_votes)
    end

    it 'includes proposals_with_votes key' do
      result = governance.governance_stats
      expect(result).to have_key(:proposals_with_votes)
    end

    it 'includes vote_summary key' do
      result = governance.governance_stats
      expect(result).to have_key(:vote_summary)
    end

    it 'includes governance_breakdown key' do
      result = governance.governance_stats
      expect(result).to have_key(:governance_breakdown)
    end

    it 'reports zero total_votes when no votes cast' do
      result = governance.governance_stats
      expect(result[:total_votes]).to eq(0)
    end

    it 'reports zero proposals_with_votes when no votes cast' do
      result = governance.governance_stats
      expect(result[:proposals_with_votes]).to eq(0)
    end

    it 'governance_breakdown includes all GOVERNANCE_STATUSES' do
      result = governance.governance_stats
      Legion::Extensions::MindGrowth::Helpers::Constants::GOVERNANCE_STATUSES.each do |status|
        expect(result[:governance_breakdown]).to have_key(status)
      end
    end

    context 'after voting' do
      let(:proposal) { create_proposal }

      before do
        3.times { |i| governance.vote_on_proposal(proposal_id: proposal.id, vote: :approve, agent_id: "a#{i}") }
        governance.vote_on_proposal(proposal_id: proposal.id, vote: :reject, agent_id: 'r0')
      end

      it 'reflects total_votes correctly' do
        result = governance.governance_stats
        expect(result[:total_votes]).to eq(4)
      end

      it 'reflects proposals_with_votes correctly' do
        result = governance.governance_stats
        expect(result[:proposals_with_votes]).to eq(1)
      end

      it 'vote_summary for the proposal has correct approve/reject counts' do
        result = governance.governance_stats
        summary = result[:vote_summary][proposal.id]
        expect(summary[:approve]).to eq(3)
        expect(summary[:reject]).to eq(1)
        expect(summary[:total]).to eq(4)
      end
    end

    context 'with multiple proposals' do
      it 'counts votes across proposals correctly' do
        p1 = create_proposal(name: 'lex-g1')
        p2 = create_proposal(name: 'lex-g2')
        2.times { |i| governance.vote_on_proposal(proposal_id: p1.id, vote: :approve, agent_id: "a#{i}") }
        3.times { |i| governance.vote_on_proposal(proposal_id: p2.id, vote: :reject,  agent_id: "r#{i}") }
        result = governance.governance_stats
        expect(result[:total_votes]).to eq(5)
        expect(result[:proposals_with_votes]).to eq(2)
      end
    end
  end

  # ─── constant checks ──────────────────────────────────────────────────────

  describe 'constants' do
    it 'QUORUM is 3' do
      expect(Legion::Extensions::MindGrowth::Helpers::Constants::QUORUM).to eq(3)
    end

    it 'REJECTION_COOLDOWN_HOURS is 24' do
      expect(Legion::Extensions::MindGrowth::Helpers::Constants::REJECTION_COOLDOWN_HOURS).to eq(24)
    end

    it 'GOVERNANCE_STATUSES includes :pending, :approved, :rejected, :expired' do
      statuses = Legion::Extensions::MindGrowth::Helpers::Constants::GOVERNANCE_STATUSES
      expect(statuses).to include(:pending, :approved, :rejected, :expired)
    end
  end
end
