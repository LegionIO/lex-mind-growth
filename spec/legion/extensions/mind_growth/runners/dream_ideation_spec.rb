# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::DreamIdeation do
  subject(:dream) { described_class }

  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }

  before { proposer.instance_variable_set(:@proposal_store, nil) }

  # ─── generate_dream_proposals ─────────────────────────────────────────────

  describe '.generate_dream_proposals' do
    it 'returns success: true' do
      result = dream.generate_dream_proposals
      expect(result[:success]).to be true
    end

    it 'returns a proposals array' do
      result = dream.generate_dream_proposals
      expect(result[:proposals]).to be_an(Array)
    end

    it 'returns count matching proposals size' do
      result = dream.generate_dream_proposals
      expect(result[:count]).to eq(result[:proposals].size)
    end

    it 'returns gaps_analyzed count' do
      result = dream.generate_dream_proposals
      expect(result).to have_key(:gaps_analyzed)
    end

    it 'generates at most max_proposals proposals' do
      result = dream.generate_dream_proposals(max_proposals: 1)
      expect(result[:count]).to be <= 1
    end

    it 'defaults max_proposals to 2' do
      result = dream.generate_dream_proposals
      expect(result[:count]).to be <= 2
    end

    it 'sets origin to :dream on generated proposals' do
      result = dream.generate_dream_proposals(max_proposals: 1)
      next if result[:proposals].empty?

      proposal_id = result[:proposals].first[:id]
      obj = proposer.get_proposal_object(proposal_id)
      expect(obj.origin).to eq(:dream)
    end

    it 'accepts existing_extensions parameter' do
      exts = %w[attention perception]
      expect { dream.generate_dream_proposals(existing_extensions: exts) }.not_to raise_error
    end

    it 'returns count: 0 when gap analysis returns no recommendations' do
      allow(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to receive(:analyze_gaps).and_return({ success: true, models: [], recommendations: [] })
      result = dream.generate_dream_proposals
      expect(result[:count]).to eq(0)
    end
  end

  # ─── dream_agenda_items ───────────────────────────────────────────────────

  describe '.dream_agenda_items' do
    it 'returns success: true' do
      result = dream.dream_agenda_items
      expect(result[:success]).to be true
    end

    it 'returns an items array' do
      result = dream.dream_agenda_items
      expect(result[:items]).to be_an(Array)
    end

    it 'returns count matching items size' do
      result = dream.dream_agenda_items
      expect(result[:count]).to eq(result[:items].size)
    end

    it 'each item has a :type key' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item).to have_key(:type) }
    end

    it 'item type is :architectural_gap' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item[:type]).to eq(:architectural_gap) }
    end

    it 'each item has a :content key' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item).to have_key(:content) }
    end

    it 'each item content has :gap_name' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item[:content]).to have_key(:gap_name) }
    end

    it 'each item content has :model' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item[:content]).to have_key(:model) }
    end

    it 'each item content has :coverage' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item[:content]).to have_key(:coverage) }
    end

    it 'each item has a :weight key' do
      result = dream.dream_agenda_items
      result[:items].each { |item| expect(item).to have_key(:weight) }
    end

    it 'weight is between MIN and MAX bounds' do
      result = dream.dream_agenda_items
      result[:items].each do |item|
        expect(item[:weight]).to be_between(described_class::MIN_AGENDA_WEIGHT,
                                            described_class::MAX_AGENDA_WEIGHT)
      end
    end

    it 'accepts existing_extensions parameter' do
      expect { dream.dream_agenda_items(existing_extensions: []) }.not_to raise_error
    end

    it 'returns success: false when gap analysis fails' do
      allow(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to receive(:analyze_gaps).and_return({ success: false, error: :test_error })
      result = dream.dream_agenda_items
      expect(result[:success]).to be false
    end
  end

  # ─── enrich_from_dream_context ────────────────────────────────────────────

  describe '.enrich_from_dream_context' do
    def create_proposal(name: 'lex-dream-enrich')
      result = proposer.propose_concept(name: name, description: 'test', enrich: false)
      proposer.get_proposal_object(result[:proposal][:id])
    end

    it 'returns success: true for an existing proposal' do
      p = create_proposal
      result = dream.enrich_from_dream_context(proposal_id: p.id, dream_context: { theme: 'memory' })
      expect(result[:success]).to be true
    end

    it 'returns the proposal_id' do
      p = create_proposal
      result = dream.enrich_from_dream_context(proposal_id: p.id, dream_context: {})
      expect(result[:proposal_id]).to eq(p.id)
    end

    it 'returns enriched: true when context is provided' do
      p = create_proposal
      result = dream.enrich_from_dream_context(proposal_id: p.id, dream_context: { theme: 'focus' })
      expect(result[:enriched]).to be true
    end

    it 'returns enriched: false when dream_context is empty' do
      p = create_proposal
      result = dream.enrich_from_dream_context(proposal_id: p.id, dream_context: {})
      expect(result[:enriched]).to be false
    end

    it 'updates the proposal rationale with dream context' do
      p = create_proposal
      dream.enrich_from_dream_context(proposal_id: p.id, dream_context: { theme: 'binding' })
      expect(p.rationale).to include('binding')
    end

    it 'appends to existing rationale' do
      p = create_proposal
      p.instance_variable_set(:@rationale, 'original rationale')
      dream.enrich_from_dream_context(proposal_id: p.id, dream_context: { association: 'hub' })
      expect(p.rationale).to include('original rationale')
      expect(p.rationale).to include('hub')
    end

    it 'returns success: false for non-existent proposal_id' do
      result = dream.enrich_from_dream_context(proposal_id: 'no-such-id', dream_context: {})
      expect(result[:success]).to be false
    end

    it 'returns :not_found error for missing proposal' do
      result = dream.enrich_from_dream_context(proposal_id: 'missing', dream_context: {})
      expect(result[:error]).to eq(:not_found)
    end

    it 'ignores unknown keyword arguments' do
      p = create_proposal
      expect { dream.enrich_from_dream_context(proposal_id: p.id, dream_context: {}, extra: true) }.not_to raise_error
    end
  end

  # ─── DREAM_NOVELTY_BONUS ──────────────────────────────────────────────────

  describe 'DREAM_NOVELTY_BONUS' do
    it 'is 0.15' do
      expect(described_class::DREAM_NOVELTY_BONUS).to eq(0.15)
    end
  end
end
