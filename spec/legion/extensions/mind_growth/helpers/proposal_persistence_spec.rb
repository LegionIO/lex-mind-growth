# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::ProposalPersistence do
  subject(:persistence) { described_class.new(namespace: 'test_proposals') }

  before do
    stub_const('Legion::Cache', Class.new do
      def self.connected? = true
      def self.get(key) = (@store ||= {})[key]
      def self.set_sync(key, value, **) = ((@store ||= {})[key] = value)
      def self.delete_sync(key)      = (@store ||= {}).delete(key)
      def self.flush                 = (@store = {})
    end)
    Legion::Cache.flush
  end

  describe '#save_proposal / #load_proposal' do
    it 'round-trips a proposal hash' do
      proposal_hash = { id: 'p-001', name: 'lex-test', module_name: 'Test',
                        category: :cognition, description: 'test', status: :approved,
                        scores: { novelty: 0.8 }, created_at: Time.now.utc.to_s }
      persistence.save_proposal(proposal_hash)
      loaded = persistence.load_proposal('p-001')
      expect(loaded[:name]).to eq('lex-test')
      # JSON round-trip preserves string values; from_h converts to symbols at rehydration
      expect(loaded[:status].to_sym).to eq(:approved)
    end

    it 'returns nil for an unknown id' do
      expect(persistence.load_proposal('no-such-id')).to be_nil
    end

    it 'adds the id to the index on save' do
      persistence.save_proposal({ id: 'p-001', name: 'one' })
      all = persistence.load_all_proposals
      # IDs are stored as strings; key may be string or symbol depending on JSON parse
      expect(all.transform_keys(&:to_s)).to have_key('p-001')
    end
  end

  describe '#delete_proposal' do
    it 'removes the proposal from cache' do
      persistence.save_proposal({ id: 'p-del', name: 'delete-me' })
      persistence.delete_proposal('p-del')
      expect(persistence.load_proposal('p-del')).to be_nil
    end

    it 'removes the id from the index' do
      persistence.save_proposal({ id: 'p-del', name: 'delete-me' })
      persistence.delete_proposal('p-del')
      expect(persistence.load_all_proposals).not_to have_key(:'p-del')
    end
  end

  describe '#save_votes / #load_votes' do
    it 'round-trips governance votes' do
      votes = { 'p-001' => [{ vote: :approve, agent_id: 'a1', cast_at: Time.now.utc.to_s }] }
      persistence.save_votes(votes)
      loaded = persistence.load_votes
      # JSON round-trip: top-level keys become symbols, vote values are strings
      ballot = (loaded[:'p-001'] || loaded['p-001']).first
      expect(ballot[:vote].to_sym).to eq(:approve)
    end

    it 'returns empty hash when no votes are stored' do
      expect(persistence.load_votes).to eq({})
    end
  end

  describe '#load_all_proposals' do
    it 'returns all persisted proposals' do
      persistence.save_proposal({ id: 'p-001', name: 'one', status: :approved })
      persistence.save_proposal({ id: 'p-002', name: 'two', status: :proposed })
      all = persistence.load_all_proposals
      expect(all.size).to eq(2)
    end

    it 'returns an empty hash when nothing is stored' do
      expect(persistence.load_all_proposals).to eq({})
    end

    it 'does not include deleted proposals' do
      persistence.save_proposal({ id: 'p-001', name: 'one' })
      persistence.save_proposal({ id: 'p-002', name: 'two' })
      persistence.delete_proposal('p-001')
      all = persistence.load_all_proposals
      expect(all.size).to eq(1)
      expect(all.transform_keys(&:to_s)).to have_key('p-002')
    end
  end

  describe 'when cache unavailable' do
    before { allow(Legion::Cache).to receive(:connected?).and_return(false) }

    it 'degrades gracefully on load_proposal' do
      expect(persistence.load_proposal('p-001')).to be_nil
    end

    it 'degrades gracefully on save_proposal' do
      expect(persistence.save_proposal({ id: 'x' })).to be false
    end

    it 'degrades gracefully on delete_proposal' do
      expect(persistence.delete_proposal('x')).to be false
    end

    it 'degrades gracefully on load_votes' do
      expect(persistence.load_votes).to eq({})
    end

    it 'degrades gracefully on save_votes' do
      expect(persistence.save_votes({ 'p' => [] })).to be false
    end

    it 'degrades gracefully on load_all_proposals' do
      expect(persistence.load_all_proposals).to eq({})
    end
  end
end
