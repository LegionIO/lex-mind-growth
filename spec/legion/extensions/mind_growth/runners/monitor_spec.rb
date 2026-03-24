# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Monitor do
  subject(:monitor) { described_class }

  # 10 000+ invocations saturates log10 scale; impact+health=1.0, no errors/latency => fitness 0.8 (excellent boundary)
  let(:healthy_ext) do
    { name: 'lex-healthy', invocation_count: 10_000, impact_score: 1.0,
      health_score: 1.0, error_rate: 0.0, avg_latency_ms: 0 }
  end

  let(:good_ext) do
    { name: 'lex-good', invocation_count: 50, impact_score: 0.7,
      health_score: 0.8, error_rate: 0.1, avg_latency_ms: 200 }
  end

  let(:fair_ext) do
    { name: 'lex-fair', invocation_count: 5, impact_score: 0.5,
      health_score: 0.5, error_rate: 0.2, avg_latency_ms: 500 }
  end

  let(:degraded_ext) do
    { name: 'lex-degraded', invocation_count: 1, impact_score: 0.2,
      health_score: 0.2, error_rate: 0.5, avg_latency_ms: 1000 }
  end

  let(:critical_ext) do
    { name: 'lex-critical', invocation_count: 0, impact_score: 0.0,
      health_score: 0.0, error_rate: 1.0, avg_latency_ms: 5000 }
  end

  # ─── health_check ──────────────────────────────────────────────────────────

  describe '.health_check' do
    it 'returns success: true' do
      result = monitor.health_check(extension: healthy_ext)
      expect(result[:success]).to be true
    end

    it 'returns the extension_name' do
      result = monitor.health_check(extension: healthy_ext)
      expect(result[:extension_name]).to eq('lex-healthy')
    end

    it 'returns a numeric fitness value' do
      result = monitor.health_check(extension: healthy_ext)
      expect(result[:fitness]).to be_a(Numeric)
    end

    it 'returns a health_level symbol' do
      result = monitor.health_check(extension: healthy_ext)
      expect(described_class::HEALTH_LEVELS.keys).to include(result[:health_level])
    end

    it 'classifies a high-fitness extension as :excellent' do
      result = monitor.health_check(extension: healthy_ext)
      expect(result[:health_level]).to eq(:excellent)
    end

    it 'classifies a moderate-fitness extension as :good or :fair' do
      result = monitor.health_check(extension: good_ext)
      expect(%i[good fair]).to include(result[:health_level])
    end

    it 'classifies a zero-invocation zero-impact extension as :critical or :degraded' do
      result = monitor.health_check(extension: critical_ext)
      expect(%i[critical degraded]).to include(result[:health_level])
    end

    it 'returns alert: false for excellent health' do
      result = monitor.health_check(extension: healthy_ext)
      expect(result[:alert]).to be false
    end

    it 'returns alert: true for critical health' do
      result = monitor.health_check(extension: critical_ext)
      expect(result[:alert]).to be true
    end

    it 'returns alert: true for degraded health' do
      result = monitor.health_check(extension: degraded_ext)
      expect(result[:alert]).to be true
    end

    it 'accepts extension_name key as the name field' do
      ext = { extension_name: 'lex-alt', invocation_count: 100, impact_score: 0.8,
              health_score: 1.0, error_rate: 0.0, avg_latency_ms: 0 }
      result = monitor.health_check(extension: ext)
      expect(result[:extension_name]).to eq('lex-alt')
    end

    it 'ignores unknown keyword arguments' do
      expect { monitor.health_check(extension: healthy_ext, extra: true) }.not_to raise_error
    end
  end

  # ─── usage_stats ──────────────────────────────────────────────────────────

  describe '.usage_stats' do
    let(:exts) { [healthy_ext, good_ext] }

    it 'returns success: true' do
      result = monitor.usage_stats(extensions: exts)
      expect(result[:success]).to be true
    end

    it 'returns a stats array' do
      result = monitor.usage_stats(extensions: exts)
      expect(result[:stats]).to be_an(Array)
    end

    it 'returns count equal to number of extensions' do
      result = monitor.usage_stats(extensions: exts)
      expect(result[:count]).to eq(2)
    end

    it 'each stat entry includes extension_name' do
      result = monitor.usage_stats(extensions: exts)
      result[:stats].each { |s| expect(s).to have_key(:extension_name) }
    end

    it 'each stat entry includes invocation_count' do
      result = monitor.usage_stats(extensions: exts)
      result[:stats].each { |s| expect(s).to have_key(:invocation_count) }
    end

    it 'each stat entry includes error_rate' do
      result = monitor.usage_stats(extensions: exts)
      result[:stats].each { |s| expect(s).to have_key(:error_rate) }
    end

    it 'each stat entry includes avg_latency_ms' do
      result = monitor.usage_stats(extensions: exts)
      result[:stats].each { |s| expect(s).to have_key(:avg_latency_ms) }
    end

    it 'returns count: 0 for empty extensions list' do
      result = monitor.usage_stats(extensions: [])
      expect(result[:count]).to eq(0)
      expect(result[:stats]).to eq([])
    end

    it 'defaults invocation_count to 0 when missing' do
      ext = { name: 'lex-bare' }
      result = monitor.usage_stats(extensions: [ext])
      expect(result[:stats].first[:invocation_count]).to eq(0)
    end
  end

  # ─── impact_score ─────────────────────────────────────────────────────────

  describe '.impact_score' do
    it 'returns success: true' do
      result = monitor.impact_score(extension: healthy_ext)
      expect(result[:success]).to be true
    end

    it 'returns the extension_name' do
      result = monitor.impact_score(extension: healthy_ext)
      expect(result[:extension_name]).to eq('lex-healthy')
    end

    it 'returns the impact value' do
      result = monitor.impact_score(extension: healthy_ext)
      expect(result[:impact]).to eq(1.0)
    end

    it 'returns a rank_percentile' do
      result = monitor.impact_score(extension: healthy_ext)
      expect(result[:rank_percentile]).to be_a(Numeric)
    end

    it 'returns 50.0 percentile when no extensions list provided' do
      result = monitor.impact_score(extension: healthy_ext)
      expect(result[:rank_percentile]).to eq(50.0)
    end

    it 'returns 100.0 percentile for top extension in list' do
      exts = [
        { name: 'low', impact_score: 0.1 },
        { name: 'mid', impact_score: 0.5 },
        healthy_ext
      ]
      result = monitor.impact_score(extension: healthy_ext, extensions: exts)
      expect(result[:rank_percentile]).to eq(100.0)
    end

    it 'defaults impact to 0.5 when missing' do
      ext = { name: 'lex-noimpact' }
      result = monitor.impact_score(extension: ext)
      expect(result[:impact]).to eq(0.5)
    end
  end

  # ─── decay_check ──────────────────────────────────────────────────────────

  describe '.decay_check' do
    it 'returns success: true' do
      result = monitor.decay_check(extensions: [healthy_ext, critical_ext])
      expect(result[:success]).to be true
    end

    it 'returns a decayed array' do
      result = monitor.decay_check(extensions: [healthy_ext, critical_ext])
      expect(result[:decayed]).to be_an(Array)
    end

    it 'returns count matching decayed array size' do
      result = monitor.decay_check(extensions: [healthy_ext, critical_ext])
      expect(result[:count]).to eq(result[:decayed].size)
    end

    it 'identifies a zero-invocation extension as decayed' do
      result = monitor.decay_check(extensions: [critical_ext])
      expect(result[:count]).to eq(1)
    end

    it 'does not flag a healthy high-invocation extension as decayed' do
      result = monitor.decay_check(extensions: [healthy_ext])
      expect(result[:count]).to eq(0)
    end

    it 'returns count: 0 for empty list' do
      result = monitor.decay_check(extensions: [])
      expect(result[:count]).to eq(0)
    end
  end

  # ─── auto_prune ───────────────────────────────────────────────────────────

  describe '.auto_prune' do
    it 'returns success: true' do
      result = monitor.auto_prune(extensions: [healthy_ext, critical_ext])
      expect(result[:success]).to be true
    end

    it 'returns a pruned array' do
      result = monitor.auto_prune(extensions: [healthy_ext, critical_ext])
      expect(result[:pruned]).to be_an(Array)
    end

    it 'delegates to FitnessEvaluator.prune_candidates' do
      allow(Legion::Extensions::MindGrowth::Helpers::FitnessEvaluator)
        .to receive(:prune_candidates).with([critical_ext]).and_return([critical_ext])
      result = monitor.auto_prune(extensions: [critical_ext])
      expect(result[:pruned]).to include(critical_ext)
    end

    it 'does not prune healthy extensions' do
      result = monitor.auto_prune(extensions: [healthy_ext])
      expect(result[:pruned]).to be_empty
    end

    it 'returns count: 0 for empty list' do
      result = monitor.auto_prune(extensions: [])
      expect(result[:count]).to eq(0)
    end
  end

  # ─── health_summary ───────────────────────────────────────────────────────

  describe '.health_summary' do
    let(:all_exts) { [healthy_ext, good_ext, critical_ext] }

    it 'returns success: true' do
      result = monitor.health_summary(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'returns total equal to extension count' do
      result = monitor.health_summary(extensions: all_exts)
      expect(result[:total]).to eq(3)
    end

    it 'returns by_health_level hash' do
      result = monitor.health_summary(extensions: all_exts)
      expect(result[:by_health_level]).to be_a(Hash)
    end

    it 'by_health_level includes all HEALTH_LEVELS keys' do
      result = monitor.health_summary(extensions: all_exts)
      described_class::HEALTH_LEVELS.each_key do |level|
        expect(result[:by_health_level]).to have_key(level)
      end
    end

    it 'returns alerts array' do
      result = monitor.health_summary(extensions: all_exts)
      expect(result[:alerts]).to be_an(Array)
    end

    it 'includes critical extension in alerts' do
      result = monitor.health_summary(extensions: [critical_ext])
      expect(result[:alerts]).to include(critical_ext)
    end

    it 'does not include healthy extension in alerts' do
      result = monitor.health_summary(extensions: [healthy_ext])
      expect(result[:alerts]).to be_empty
    end

    it 'returns prune_candidates array' do
      result = monitor.health_summary(extensions: all_exts)
      expect(result[:prune_candidates]).to be_an(Array)
    end

    it 'by_health_level values sum to total' do
      result = monitor.health_summary(extensions: all_exts)
      sum = result[:by_health_level].values.sum
      expect(sum).to eq(result[:total])
    end

    it 'returns total: 0 for empty list' do
      result = monitor.health_summary(extensions: [])
      expect(result[:total]).to eq(0)
      expect(result[:alerts]).to be_empty
    end
  end

  # ─── HEALTH_LEVELS constant ───────────────────────────────────────────────

  describe 'HEALTH_LEVELS' do
    it 'includes all five levels' do
      expect(described_class::HEALTH_LEVELS.keys)
        .to contain_exactly(:excellent, :good, :fair, :degraded, :critical)
    end

    it 'sets excellent threshold to 0.8' do
      expect(described_class::HEALTH_LEVELS[:excellent]).to eq(0.8)
    end

    it 'sets critical threshold to 0.0' do
      expect(described_class::HEALTH_LEVELS[:critical]).to eq(0.0)
    end
  end
end
