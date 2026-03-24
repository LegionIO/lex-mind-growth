# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Dashboard do
  subject(:dashboard) { described_class }

  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  let(:cognition_ext) do
    { name: 'lex-cognition', category: :cognition, invocation_count: 500,
      impact_score: 0.8, health_score: 0.9, error_rate: 0.0, avg_latency_ms: 100 }
  end

  let(:memory_ext) do
    { name: 'lex-memory', category: :memory, invocation_count: 200,
      impact_score: 0.6, health_score: 0.7, error_rate: 0.05, avg_latency_ms: 150 }
  end

  let(:low_ext) do
    { name: 'lex-low', category: :perception, invocation_count: 1,
      impact_score: 0.1, health_score: 0.1, error_rate: 0.8, avg_latency_ms: 3000 }
  end

  let(:all_exts) { [cognition_ext, memory_ext, low_ext] }

  # ─── extension_timeline ────────────────────────────────────────────────────

  describe '.extension_timeline' do
    it 'returns success: true' do
      result = dashboard.extension_timeline(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'returns a series array' do
      result = dashboard.extension_timeline(extensions: all_exts)
      expect(result[:series]).to be_an(Array)
    end

    it 'returns at least one series point' do
      result = dashboard.extension_timeline(extensions: all_exts)
      expect(result[:series].size).to be >= 1
    end

    it 'returns range_days matching requested days' do
      result = dashboard.extension_timeline(extensions: all_exts, days: 7)
      expect(result[:range_days]).to eq(7)
    end

    it 'series points include date and count keys' do
      result = dashboard.extension_timeline(extensions: all_exts)
      result[:series].each do |point|
        expect(point).to have_key(:date)
        expect(point).to have_key(:count)
      end
    end

    it 'reflects current extension count in the series' do
      result = dashboard.extension_timeline(extensions: all_exts)
      expect(result[:series].last[:count]).to eq(3)
    end

    it 'returns count 0 for empty extensions' do
      result = dashboard.extension_timeline(extensions: [])
      expect(result[:series].last[:count]).to eq(0)
    end
  end

  # ─── category_distribution ─────────────────────────────────────────────────

  describe '.category_distribution' do
    it 'returns success: true' do
      result = dashboard.category_distribution(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'returns a distribution hash' do
      result = dashboard.category_distribution(extensions: all_exts)
      expect(result[:distribution]).to be_a(Hash)
    end

    it 'returns total equal to extension count' do
      result = dashboard.category_distribution(extensions: all_exts)
      expect(result[:total]).to eq(3)
    end

    it 'includes all CATEGORIES keys in distribution' do
      result = dashboard.category_distribution(extensions: all_exts)
      Legion::Extensions::MindGrowth::Helpers::Constants::CATEGORIES.each do |cat|
        expect(result[:distribution]).to have_key(cat)
      end
    end

    it 'counts extensions per category correctly' do
      result = dashboard.category_distribution(extensions: all_exts)
      expect(result[:distribution][:cognition]).to eq(1)
      expect(result[:distribution][:memory]).to eq(1)
      expect(result[:distribution][:perception]).to eq(1)
    end

    it 'returns zero counts for unpopulated categories' do
      result = dashboard.category_distribution(extensions: [cognition_ext])
      expect(result[:distribution][:memory]).to eq(0)
    end

    it 'defaults missing category to :cognition' do
      ext    = { name: 'lex-bare' }
      result = dashboard.category_distribution(extensions: [ext])
      expect(result[:distribution][:cognition]).to eq(1)
    end

    it 'returns total: 0 for empty extensions' do
      result = dashboard.category_distribution(extensions: [])
      expect(result[:total]).to eq(0)
    end
  end

  # ─── build_metrics ─────────────────────────────────────────────────────────

  describe '.build_metrics' do
    it 'returns success: true' do
      result = dashboard.build_metrics
      expect(result[:success]).to be true
    end

    it 'returns total_proposals' do
      result = dashboard.build_metrics
      expect(result).to have_key(:total_proposals)
    end

    it 'returns approved count' do
      result = dashboard.build_metrics
      expect(result).to have_key(:approved)
    end

    it 'returns rejected count' do
      result = dashboard.build_metrics
      expect(result).to have_key(:rejected)
    end

    it 'returns built count' do
      result = dashboard.build_metrics
      expect(result).to have_key(:built)
    end

    it 'returns failed count' do
      result = dashboard.build_metrics
      expect(result).to have_key(:failed)
    end

    it 'returns success_rate as a numeric' do
      result = dashboard.build_metrics
      expect(result[:success_rate]).to be_a(Numeric)
    end

    it 'returns approval_rate as a numeric' do
      result = dashboard.build_metrics
      expect(result[:approval_rate]).to be_a(Numeric)
    end

    it 'returns success_rate 0.0 when no builds attempted' do
      result = dashboard.build_metrics
      expect(result[:success_rate]).to eq(0.0)
    end

    it 'returns approval_rate 0.0 when no proposals evaluated' do
      result = dashboard.build_metrics
      expect(result[:approval_rate]).to eq(0.0)
    end
  end

  # ─── top_extensions ────────────────────────────────────────────────────────

  describe '.top_extensions' do
    it 'returns success: true' do
      result = dashboard.top_extensions(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'returns a top array' do
      result = dashboard.top_extensions(extensions: all_exts)
      expect(result[:top]).to be_an(Array)
    end

    it 'returns limit in response' do
      result = dashboard.top_extensions(extensions: all_exts, limit: 2)
      expect(result[:limit]).to eq(2)
    end

    it 'respects the limit parameter' do
      result = dashboard.top_extensions(extensions: all_exts, limit: 2)
      expect(result[:top].size).to be <= 2
    end

    it 'returns highest-fitness extension first' do
      result = dashboard.top_extensions(extensions: all_exts, limit: 1)
      expect(result[:top].first[:name]).to eq('lex-cognition')
    end

    it 'each entry includes name, invocation_count, and fitness' do
      result = dashboard.top_extensions(extensions: all_exts)
      result[:top].each do |entry|
        expect(entry).to have_key(:name)
        expect(entry).to have_key(:invocation_count)
        expect(entry).to have_key(:fitness)
      end
    end

    it 'returns empty top array for empty extensions' do
      result = dashboard.top_extensions(extensions: [])
      expect(result[:top]).to be_empty
    end
  end

  # ─── bottom_extensions ─────────────────────────────────────────────────────

  describe '.bottom_extensions' do
    it 'returns success: true' do
      result = dashboard.bottom_extensions(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'returns a bottom array' do
      result = dashboard.bottom_extensions(extensions: all_exts)
      expect(result[:bottom]).to be_an(Array)
    end

    it 'returns limit in response' do
      result = dashboard.bottom_extensions(extensions: all_exts, limit: 2)
      expect(result[:limit]).to eq(2)
    end

    it 'respects the limit parameter' do
      result = dashboard.bottom_extensions(extensions: all_exts, limit: 2)
      expect(result[:bottom].size).to be <= 2
    end

    it 'returns lowest-fitness extension first' do
      result = dashboard.bottom_extensions(extensions: all_exts, limit: 1)
      expect(result[:bottom].first[:name]).to eq('lex-low')
    end

    it 'each entry includes name, invocation_count, and fitness' do
      result = dashboard.bottom_extensions(extensions: all_exts)
      result[:bottom].each do |entry|
        expect(entry).to have_key(:name)
        expect(entry).to have_key(:invocation_count)
        expect(entry).to have_key(:fitness)
      end
    end

    it 'returns empty bottom array for empty extensions' do
      result = dashboard.bottom_extensions(extensions: [])
      expect(result[:bottom]).to be_empty
    end
  end

  # ─── recent_proposals ──────────────────────────────────────────────────────

  describe '.recent_proposals' do
    it 'returns success: true' do
      result = dashboard.recent_proposals
      expect(result[:success]).to be true
    end

    it 'returns a proposals array' do
      result = dashboard.recent_proposals
      expect(result[:proposals]).to be_an(Array)
    end

    it 'returns count matching proposals array size' do
      result = dashboard.recent_proposals
      expect(result[:count]).to eq(result[:proposals].size)
    end

    it 'delegates to Proposer.list_proposals' do
      allow(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to receive(:list_proposals).with(limit: 5).and_call_original
      dashboard.recent_proposals(limit: 5)
      expect(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to have_received(:list_proposals).with(limit: 5)
    end

    it 'returns proposals when store has entries' do
      Legion::Extensions::MindGrowth::Runners::Proposer.propose_concept(
        name: 'lex-dash-test', category: :cognition, description: 'dashboard test', enrich: false
      )
      result = dashboard.recent_proposals(limit: 10)
      expect(result[:count]).to be >= 1
    end

    it 'returns empty list when no proposals exist' do
      result = dashboard.recent_proposals
      expect(result[:proposals]).to be_an(Array)
    end
  end

  # ─── full_dashboard ────────────────────────────────────────────────────────

  describe '.full_dashboard' do
    it 'returns success: true' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'includes category_distribution' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:category_distribution]).to be_a(Hash)
    end

    it 'includes build_metrics' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:build_metrics]).to be_a(Hash)
    end

    it 'includes top_extensions array' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:top_extensions]).to be_an(Array)
    end

    it 'includes bottom_extensions array' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:bottom_extensions]).to be_an(Array)
    end

    it 'includes recent_proposals array' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:recent_proposals]).to be_an(Array)
    end

    it 'includes health_summary hash' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:health_summary]).to be_a(Hash)
    end

    it 'includes a timestamp string' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:timestamp]).to be_a(String)
    end

    it 'health_summary reflects extension count' do
      result = dashboard.full_dashboard(extensions: all_exts)
      expect(result[:health_summary][:total]).to eq(3)
    end

    it 'returns empty arrays and zero counts for empty extensions' do
      result = dashboard.full_dashboard(extensions: [])
      expect(result[:top_extensions]).to be_empty
      expect(result[:bottom_extensions]).to be_empty
    end
  end
end
