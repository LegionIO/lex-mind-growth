# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::ProposalStore do
  subject(:store) { described_class.new }

  let(:proposal) do
    Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
      name:        'lex-focus',
      module_name: 'Focus',
      category:    :cognition,
      description: 'Focus management'
    )
  end

  let(:approved_proposal) do
    p = Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
      name:        'lex-approved',
      module_name: 'Approved',
      category:    :memory,
      description: 'Memory management'
    )
    scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.75] }
    p.evaluate!(scores)
    p
  end

  describe '#store and #get' do
    it 'stores and retrieves a proposal by id' do
      store.store(proposal)
      expect(store.get(proposal.id)).to eq(proposal)
    end

    it 'returns nil for unknown id' do
      expect(store.get('nonexistent')).to be_nil
    end
  end

  describe '#all' do
    it 'returns all proposals' do
      store.store(proposal)
      store.store(approved_proposal)
      expect(store.all.size).to eq(2)
    end

    it 'returns empty array for empty store' do
      expect(store.all).to eq([])
    end

    it 'returns a copy (not the internal array)' do
      store.store(proposal)
      all = store.all
      all.clear
      expect(store.all.size).to eq(1)
    end
  end

  describe '#by_status' do
    it 'returns proposals matching the status' do
      store.store(proposal)
      store.store(approved_proposal)
      proposed = store.by_status(:proposed)
      expect(proposed.map(&:id)).to include(proposal.id)
      expect(proposed.map(&:id)).not_to include(approved_proposal.id)
    end

    it 'returns empty array when no matches' do
      expect(store.by_status(:building)).to eq([])
    end

    it 'accepts string status and converts to symbol' do
      store.store(proposal)
      expect(store.by_status('proposed')).to include(proposal)
    end
  end

  describe '#by_category' do
    it 'returns proposals matching the category' do
      store.store(proposal)
      store.store(approved_proposal)
      cognition = store.by_category(:cognition)
      expect(cognition.map(&:id)).to include(proposal.id)
    end

    it 'accepts string category' do
      store.store(proposal)
      expect(store.by_category('cognition')).to include(proposal)
    end
  end

  describe '#approved' do
    it 'returns only approved proposals' do
      store.store(proposal)
      store.store(approved_proposal)
      expect(store.approved.map(&:id)).to eq([approved_proposal.id])
    end
  end

  describe '#build_queue' do
    it 'returns approved proposals sorted by average score descending' do
      p1 = Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
        name: 'lex-low', module_name: 'Low', category: :memory, description: 'low'
      )
      p2 = Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
        name: 'lex-high', module_name: 'High', category: :cognition, description: 'high'
      )
      low_scores  = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.65] }
      high_scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.85] }
      p1.evaluate!(low_scores)
      p2.evaluate!(high_scores)
      store.store(p1)
      store.store(p2)
      queue = store.build_queue
      expect(queue.first.id).to eq(p2.id)
    end
  end

  describe '#recent' do
    it 'returns proposals sorted by created_at descending' do
      store.store(proposal)
      store.store(approved_proposal)
      recent = store.recent(limit: 5)
      expect(recent.size).to eq(2)
    end

    it 'limits results' do
      5.times do |i|
        p = Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
          name: "lex-#{i}", module_name: "P#{i}", category: :cognition, description: "desc #{i}"
        )
        store.store(p)
      end
      expect(store.recent(limit: 3).size).to eq(3)
    end
  end

  describe '#stats' do
    it 'returns total count' do
      store.store(proposal)
      expect(store.stats[:total]).to eq(1)
    end

    it 'returns by_status breakdown' do
      store.store(proposal)
      store.store(approved_proposal)
      stats = store.stats
      expect(stats[:by_status][:proposed]).to eq(1)
      expect(stats[:by_status][:approved]).to eq(1)
    end
  end

  describe '#clear' do
    it 'removes all proposals' do
      store.store(proposal)
      store.clear
      expect(store.stats[:total]).to eq(0)
    end
  end

  describe 'MAX_PROPOSALS eviction' do
    it 'evicts the oldest proposal when at capacity' do
      stub_const("#{described_class}::MAX_PROPOSALS", 3)
      small_store = described_class.new
      proposals = 4.times.map do |i|
        Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
          name: "lex-evict-#{i}", module_name: "E#{i}", category: :cognition, description: "evict #{i}"
        )
      end
      proposals.each { |p| small_store.store(p) }
      expect(small_store.stats[:total]).to eq(3)
      expect(small_store.get(proposals[0].id)).to be_nil
      expect(small_store.get(proposals[3].id)).not_to be_nil
    end

    it 'keeps the most recent proposals' do
      stub_const("#{described_class}::MAX_PROPOSALS", 2)
      small_store = described_class.new
      3.times do |i|
        p = Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
          name: "lex-keep-#{i}", module_name: "K#{i}", category: :cognition, description: "keep #{i}"
        )
        small_store.store(p)
      end
      names = small_store.all.map(&:name)
      expect(names).to include('lex-keep-1', 'lex-keep-2')
      expect(names).not_to include('lex-keep-0')
    end
  end

  describe 'thread safety' do
    it 'handles concurrent stores without error' do
      threads = 10.times.map do |i|
        Thread.new do
          p = Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
            name: "lex-thread-#{i}", module_name: "T#{i}", category: :cognition, description: "thread #{i}"
          )
          store.store(p)
        end
      end
      threads.each(&:join)
      expect(store.stats[:total]).to eq(10)
    end
  end
end
