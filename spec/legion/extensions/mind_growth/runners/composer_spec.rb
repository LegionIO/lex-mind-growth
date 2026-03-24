# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Composer do
  subject(:composer) { described_class }

  let(:map) { Legion::Extensions::MindGrowth::Helpers::CompositionMap }

  before { map.clear! }

  def add_comp(src: 'lex-a', key: :result, tgt: 'lex-b', method: :process)
    composer.add_composition(source_extension: src, output_key: key,
                             target_extension: tgt, target_method: method)
  end

  # ─── add_composition ──────────────────────────────────────────────────────

  describe '.add_composition' do
    it 'returns success: true' do
      result = add_comp
      expect(result[:success]).to be true
    end

    it 'returns a rule_id' do
      result = add_comp
      expect(result[:rule_id]).not_to be_nil
    end

    it 'stores the rule in CompositionMap' do
      result = add_comp
      expect(map.all_rules.map { |r| r[:id] }).to include(result[:rule_id])
    end

    it 'accepts an optional transform lambda' do
      xf = ->(v) { v * 2 }
      result = composer.add_composition(source_extension: 'lex-a', output_key: :val,
                                        target_extension: 'lex-b', target_method: :run,
                                        transform: xf)
      expect(result[:success]).to be true
    end
  end

  # ─── remove_composition ───────────────────────────────────────────────────

  describe '.remove_composition' do
    it 'returns success: true when rule exists' do
      rule_id = add_comp[:rule_id]
      result  = composer.remove_composition(rule_id: rule_id)
      expect(result[:success]).to be true
    end

    it 'returns success: false for unknown rule_id' do
      result = composer.remove_composition(rule_id: 'no-such-rule')
      expect(result[:success]).to be false
    end

    it 'removes the rule from the map' do
      rule_id = add_comp[:rule_id]
      composer.remove_composition(rule_id: rule_id)
      expect(map.all_rules.map { |r| r[:id] }).not_to include(rule_id)
    end
  end

  # ─── evaluate_output ──────────────────────────────────────────────────────

  describe '.evaluate_output' do
    before do
      add_comp(src: 'lex-src', key: :score, tgt: 'lex-tgt', method: :apply_score)
    end

    it 'returns success: true' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(result[:success]).to be true
    end

    it 'returns dispatches array' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(result[:dispatches]).to be_an(Array)
    end

    it 'returns count matching dispatches size' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(result[:count]).to eq(result[:dispatches].size)
    end

    it 'dispatch includes target_extension' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(result[:dispatches].first[:target_extension]).to eq('lex-tgt')
    end

    it 'dispatch includes target_method' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(result[:dispatches].first[:target_method]).to eq(:apply_score)
    end

    it 'dispatch input is the matched value when no transform' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(result[:dispatches].first[:input]).to eq(0.9)
    end

    it 'applies transform to the matched value' do
      map.clear!
      xf = ->(v) { v * 10 }
      map.add_rule(source_extension: 'lex-src', output_key: :score,
                   target_extension: 'lex-tgt', target_method: :apply, transform: xf)
      result = composer.evaluate_output(source_extension: 'lex-src', output: { score: 5 })
      expect(result[:dispatches].first[:input]).to eq(50)
    end

    it 'returns empty dispatches when output has no matching keys' do
      result = composer.evaluate_output(source_extension: 'lex-src', output: { unrelated: 1 })
      expect(result[:count]).to eq(0)
    end

    it 'returns empty dispatches when source has no rules' do
      result = composer.evaluate_output(source_extension: 'lex-unknown', output: { score: 1 })
      expect(result[:count]).to eq(0)
    end
  end

  # ─── composition_stats ────────────────────────────────────────────────────

  describe '.composition_stats' do
    it 'returns success: true' do
      result = composer.composition_stats
      expect(result[:success]).to be true
    end

    it 'includes total_rules' do
      result = composer.composition_stats
      expect(result).to have_key(:total_rules)
    end

    it 'includes by_source' do
      result = composer.composition_stats
      expect(result).to have_key(:by_source)
    end

    it 'reflects added rules' do
      add_comp(src: 'lex-a')
      add_comp(src: 'lex-a')
      result = composer.composition_stats
      expect(result[:total_rules]).to eq(2)
    end
  end

  # ─── suggest_compositions ─────────────────────────────────────────────────

  describe '.suggest_compositions' do
    let(:perception_ext) { { name: 'lex-sense', category: :perception } }
    let(:cognition_ext)  { { name: 'lex-think', category: :cognition } }
    let(:memory_ext)     { { name: 'lex-recall', category: :memory } }

    it 'returns success: true' do
      result = composer.suggest_compositions(extensions: [perception_ext, cognition_ext])
      expect(result[:success]).to be true
    end

    it 'returns a suggestions array' do
      result = composer.suggest_compositions(extensions: [perception_ext, cognition_ext])
      expect(result[:suggestions]).to be_an(Array)
    end

    it 'returns count matching suggestions size' do
      result = composer.suggest_compositions(extensions: [perception_ext, cognition_ext])
      expect(result[:count]).to eq(result[:suggestions].size)
    end

    it 'suggests perception -> cognition composition' do
      result = composer.suggest_compositions(extensions: [perception_ext, cognition_ext])
      names = result[:suggestions].map { |s| [s[:source_extension], s[:target_extension]] }
      expect(names).to include(%w[lex-sense lex-think])
    end

    it 'suggests cognition -> memory composition' do
      result = composer.suggest_compositions(extensions: [cognition_ext, memory_ext])
      names = result[:suggestions].map { |s| [s[:source_extension], s[:target_extension]] }
      expect(names).to include(%w[lex-think lex-recall])
    end

    it 'each suggestion includes rationale' do
      result = composer.suggest_compositions(extensions: [perception_ext, cognition_ext])
      result[:suggestions].each { |s| expect(s).to have_key(:rationale) }
    end

    it 'returns count: 0 for empty extensions' do
      result = composer.suggest_compositions(extensions: [])
      expect(result[:count]).to eq(0)
    end

    it 'returns count: 0 when no category pairs match' do
      exts = [{ name: 'lex-x', category: :cognition }, { name: 'lex-y', category: :cognition }]
      # same category — no cognition->cognition rule in CATEGORY_FLOW
      result = composer.suggest_compositions(extensions: exts)
      expect(result[:count]).to eq(0)
    end
  end

  # ─── list_compositions ────────────────────────────────────────────────────

  describe '.list_compositions' do
    it 'returns success: true' do
      result = composer.list_compositions
      expect(result[:success]).to be true
    end

    it 'returns rules array' do
      result = composer.list_compositions
      expect(result[:rules]).to be_an(Array)
    end

    it 'returns count: 0 when no rules' do
      result = composer.list_compositions
      expect(result[:count]).to eq(0)
    end

    it 'reflects added compositions' do
      add_comp
      add_comp(src: 'lex-b')
      result = composer.list_compositions
      expect(result[:count]).to eq(2)
    end
  end
end
