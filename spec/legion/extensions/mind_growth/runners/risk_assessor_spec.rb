# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::RiskAssessor do
  subject(:risk_assessor) { described_class }

  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }

  before { proposer.instance_variable_set(:@proposal_store, nil) }

  def create_proposal(name: 'lex-risk-test', category: :cognition, helpers: [], runner_methods: [])
    result = proposer.propose_concept(name: name, category: category, description: 'risk test', enrich: false)
    proposal = proposer.get_proposal_object(result[:proposal][:id])
    # Inject helpers and runner_methods via instance variables for test control
    proposal.instance_variable_set(:@helpers, helpers)
    proposal.instance_variable_set(:@runner_methods, runner_methods)
    proposal
  end

  # ─── assess_risk ──────────────────────────────────────────────────────────

  describe '.assess_risk' do
    context 'with a basic cognition proposal' do
      let(:proposal) { create_proposal }

      it 'returns success: true' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:success]).to be true
      end

      it 'returns the proposal_id' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:proposal_id]).to eq(proposal.id)
      end

      it 'returns a risk_tier' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(Legion::Extensions::MindGrowth::Helpers::Constants::RISK_TIERS).to include(result[:risk_tier])
      end

      it 'returns a dimensions hash' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions]).to be_a(Hash)
      end

      it 'dimensions includes :complexity' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions]).to have_key(:complexity)
      end

      it 'dimensions includes :blast_radius' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions]).to have_key(:blast_radius)
      end

      it 'dimensions includes :reversibility' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions]).to have_key(:reversibility)
      end

      it 'dimensions includes :performance_impact' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions]).to have_key(:performance_impact)
      end

      it 'reversibility is always :high' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:reversibility]).to eq(:high)
      end

      it 'returns a recommendation' do
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(Legion::Extensions::MindGrowth::Helpers::Constants::RISK_RECOMMENDATIONS.values).to include(result[:recommendation])
      end
    end

    context 'with a non-existent proposal_id' do
      it 'returns success: false' do
        result = risk_assessor.assess_risk(proposal_id: 'no-such-id')
        expect(result[:success]).to be false
      end

      it 'returns :not_found error' do
        result = risk_assessor.assess_risk(proposal_id: 'no-such-id')
        expect(result[:error]).to eq(:not_found)
      end
    end

    it 'ignores unknown keyword arguments' do
      proposal = create_proposal
      expect { risk_assessor.assess_risk(proposal_id: proposal.id, extra: true) }.not_to raise_error
    end

    # ── complexity dimension ──────────────────────────────────────────────

    context 'complexity based on helpers + runner_methods count' do
      it 'is :low when total < 4 (0 helpers, 0 runner_methods)' do
        proposal = create_proposal(helpers: [], runner_methods: [])
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:complexity]).to eq(:low)
      end

      it 'is :low when total is 3' do
        proposal = create_proposal(helpers: [{ name: 'h1' }, { name: 'h2' }], runner_methods: [{ name: 'r1' }])
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:complexity]).to eq(:low)
      end

      it 'is :medium when total is 4' do
        helpers = Array.new(2) { |i| { name: "h#{i}" } }
        runners = Array.new(2) { |i| { name: "r#{i}" } }
        proposal = create_proposal(helpers: helpers, runner_methods: runners)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:complexity]).to eq(:medium)
      end

      it 'is :medium when total is 6' do
        helpers = Array.new(3) { |i| { name: "h#{i}" } }
        runners = Array.new(3) { |i| { name: "r#{i}" } }
        proposal = create_proposal(helpers: helpers, runner_methods: runners)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:complexity]).to eq(:medium)
      end

      it 'is :high when total is 7' do
        helpers = Array.new(4) { |i| { name: "h#{i}" } }
        runners = Array.new(3) { |i| { name: "r#{i}" } }
        proposal = create_proposal(helpers: helpers, runner_methods: runners)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:complexity]).to eq(:high)
      end

      it 'is :high when total > 7' do
        helpers = Array.new(5) { |i| { name: "h#{i}" } }
        runners = Array.new(5) { |i| { name: "r#{i}" } }
        proposal = create_proposal(helpers: helpers, runner_methods: runners)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:complexity]).to eq(:high)
      end
    end

    # ── blast_radius dimension ────────────────────────────────────────────

    context 'blast_radius based on category' do
      it 'is :high for :safety category' do
        proposal = create_proposal(category: :safety)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:blast_radius]).to eq(:high)
      end

      it 'is :high for :coordination category' do
        proposal = create_proposal(name: 'lex-coord', category: :coordination)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:blast_radius]).to eq(:high)
      end

      it 'is :medium for :cognition category' do
        proposal = create_proposal(category: :cognition)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:blast_radius]).to eq(:medium)
      end

      it 'is :low for :communication category' do
        proposal = create_proposal(name: 'lex-comm', category: :communication)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:blast_radius]).to eq(:low)
      end

      it 'is :low for :motivation category' do
        proposal = create_proposal(name: 'lex-motiv', category: :motivation)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:blast_radius]).to eq(:low)
      end

      it 'is :low for :introspection category' do
        proposal = create_proposal(name: 'lex-intro', category: :introspection)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:blast_radius]).to eq(:low)
      end
    end

    # ── performance_impact dimension ──────────────────────────────────────

    context 'performance_impact based on category' do
      it 'is :medium for :perception category (hot path)' do
        proposal = create_proposal(name: 'lex-perc', category: :perception)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:performance_impact]).to eq(:medium)
      end

      it 'is :medium for :memory category (hot path)' do
        proposal = create_proposal(name: 'lex-mem', category: :memory)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:performance_impact]).to eq(:medium)
      end

      it 'is :low for :cognition category' do
        proposal = create_proposal(category: :cognition)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:performance_impact]).to eq(:low)
      end

      it 'is :low for :safety category' do
        proposal = create_proposal(category: :safety)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:dimensions][:performance_impact]).to eq(:low)
      end
    end

    # ── risk_tier calculation ─────────────────────────────────────────────

    context 'risk tier calculation' do
      it 'is :low when all dimensions are low (communication, few helpers)' do
        proposal = create_proposal(name: 'lex-low', category: :communication,
                                   helpers: [], runner_methods: [])
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:risk_tier]).to eq(:low)
        expect(result[:recommendation]).to eq(:auto_approve)
      end

      it 'is :medium when any dimension is medium (cognition with low complexity)' do
        proposal = create_proposal(category: :cognition, helpers: [], runner_methods: [])
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        # cognition => blast_radius :medium
        expect(result[:risk_tier]).to eq(:medium)
        expect(result[:recommendation]).to eq(:governance)
      end

      it 'is :medium when perception category with low complexity' do
        proposal = create_proposal(name: 'lex-perc2', category: :perception,
                                   helpers: [], runner_methods: [])
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        # perception => performance_impact :medium
        expect(result[:risk_tier]).to eq(:medium)
      end

      it 'is :high when blast_radius is :high (safety category)' do
        proposal = create_proposal(category: :safety)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:risk_tier]).to eq(:high)
        expect(result[:recommendation]).to eq(:human_required)
      end

      it 'is :high when blast_radius is :high (coordination category)' do
        proposal = create_proposal(name: 'lex-coord2', category: :coordination)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:risk_tier]).to eq(:high)
      end

      it 'is :high when complexity is :high (7+ helpers+runners)' do
        helpers = Array.new(4) { |i| { name: "h#{i}" } }
        runners = Array.new(4) { |i| { name: "r#{i}" } }
        proposal = create_proposal(name: 'lex-complex', category: :communication,
                                   helpers: helpers, runner_methods: runners)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:risk_tier]).to eq(:high)
      end

      it 'is :high (not :medium) when both blast_radius and complexity are high' do
        helpers = Array.new(4) { |i| { name: "h#{i}" } }
        runners = Array.new(4) { |i| { name: "r#{i}" } }
        proposal = create_proposal(name: 'lex-worst', category: :safety,
                                   helpers: helpers, runner_methods: runners)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:risk_tier]).to eq(:high)
      end
    end

    # ── recommendation mapping ────────────────────────────────────────────

    context 'recommendation mapping' do
      it 'maps :low tier to :auto_approve' do
        proposal = create_proposal(name: 'lex-auto', category: :communication,
                                   helpers: [], runner_methods: [])
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:recommendation]).to eq(:auto_approve)
      end

      it 'maps :medium tier to :governance' do
        proposal = create_proposal(category: :cognition)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:recommendation]).to eq(:governance)
      end

      it 'maps :high tier to :human_required' do
        proposal = create_proposal(category: :safety)
        result = risk_assessor.assess_risk(proposal_id: proposal.id)
        expect(result[:recommendation]).to eq(:human_required)
      end
    end
  end

  # ─── risk_summary ─────────────────────────────────────────────────────────

  describe '.risk_summary' do
    before { proposer.instance_variable_set(:@proposal_store, nil) }

    it 'returns success: true' do
      result = risk_assessor.risk_summary
      expect(result[:success]).to be true
    end

    it 'includes total count' do
      result = risk_assessor.risk_summary
      expect(result).to have_key(:total)
    end

    it 'includes by_tier hash' do
      result = risk_assessor.risk_summary
      expect(result[:by_tier]).to be_a(Hash)
    end

    it 'by_tier includes all risk tiers' do
      result = risk_assessor.risk_summary
      Legion::Extensions::MindGrowth::Helpers::Constants::RISK_TIERS.each do |tier|
        expect(result[:by_tier]).to have_key(tier)
      end
    end

    it 'returns total 0 when no proposals exist' do
      result = risk_assessor.risk_summary
      expect(result[:total]).to eq(0)
    end

    it 'all tier arrays are empty when no proposals' do
      result = risk_assessor.risk_summary
      result[:by_tier].each_value { |arr| expect(arr).to eq([]) }
    end

    context 'with proposals in the store' do
      before do
        create_proposal(name: 'lex-rs1', category: :communication, helpers: [], runner_methods: [])
        create_proposal(name: 'lex-rs2', category: :safety, helpers: [], runner_methods: [])
        create_proposal(name: 'lex-rs3', category: :cognition, helpers: [], runner_methods: [])
      end

      it 'counts total proposals assessed' do
        result = risk_assessor.risk_summary
        expect(result[:total]).to eq(3)
      end

      it 'places low-risk proposal in :low tier' do
        result = risk_assessor.risk_summary
        low_names = result[:by_tier][:low].map { |r| r[:proposal_id] }
        proposal  = proposer.list_proposals[:proposals].find { |p| p[:name] == 'lex-rs1' }
        expect(low_names).to include(proposal[:id])
      end

      it 'places high-risk proposal in :high tier' do
        result = risk_assessor.risk_summary
        expect(result[:by_tier][:high].size).to eq(1)
      end

      it 'places medium-risk proposal in :medium tier' do
        result = risk_assessor.risk_summary
        expect(result[:by_tier][:medium].size).to eq(1)
      end
    end

    context 'with explicit proposals array' do
      it 'accepts proposals as array of hashes with :id keys' do
        proposal = create_proposal(name: 'lex-explicit', category: :communication)
        result = risk_assessor.risk_summary(proposals: [{ id: proposal.id }])
        expect(result[:total]).to eq(1)
      end

      it 'accepts proposals as array of plain id strings' do
        proposal = create_proposal(name: 'lex-str', category: :communication)
        result = risk_assessor.risk_summary(proposals: [proposal.id])
        expect(result[:total]).to eq(1)
      end

      it 'skips unknown ids gracefully' do
        result = risk_assessor.risk_summary(proposals: ['nonexistent-id'])
        expect(result[:total]).to eq(0)
      end
    end
  end

  # ─── constant checks ──────────────────────────────────────────────────────

  describe 'constants' do
    it 'RISK_TIERS contains :low, :medium, :high, :critical' do
      expect(Legion::Extensions::MindGrowth::Helpers::Constants::RISK_TIERS)
        .to contain_exactly(:low, :medium, :high, :critical)
    end

    it 'RISK_RECOMMENDATIONS maps all tiers' do
      recs = Legion::Extensions::MindGrowth::Helpers::Constants::RISK_RECOMMENDATIONS
      expect(recs[:low]).to eq(:auto_approve)
      expect(recs[:medium]).to eq(:governance)
      expect(recs[:high]).to eq(:human_required)
      expect(recs[:critical]).to eq(:blocked)
    end
  end
end
