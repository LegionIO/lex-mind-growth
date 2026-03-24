# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::CompositionMap do
  subject(:map) { described_class }

  before { map.clear! }

  def add_rule(src: 'lex-a', key: :result, tgt: 'lex-b', method: :process)
    map.add_rule(source_extension: src, output_key: key,
                 target_extension: tgt, target_method: method)
  end

  # ─── add_rule ─────────────────────────────────────────────────────────────

  describe '.add_rule' do
    it 'returns success: true' do
      result = add_rule
      expect(result[:success]).to be true
    end

    it 'returns a rule_id' do
      result = add_rule
      expect(result[:rule_id]).not_to be_nil
    end

    it 'rule_id is a string UUID' do
      result = add_rule
      expect(result[:rule_id]).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'stores the rule retrievable via all_rules' do
      result = add_rule
      expect(map.all_rules.map { |r| r[:id] }).to include(result[:rule_id])
    end

    it 'stores source_extension as string' do
      add_rule(src: :lex_sym)
      rule = map.all_rules.first
      expect(rule[:source_extension]).to be_a(String)
    end

    it 'stores output_key as symbol' do
      add_rule(key: 'my_key')
      rule = map.all_rules.first
      expect(rule[:output_key]).to eq(:my_key)
    end

    it 'stores target_method as symbol' do
      add_rule(method: 'do_thing')
      rule = map.all_rules.first
      expect(rule[:target_method]).to eq(:do_thing)
    end

    it 'stores optional transform' do
      xf = lambda(&:to_s)
      map.add_rule(source_extension: 'lex-a', output_key: :x,
                   target_extension: 'lex-b', target_method: :run, transform: xf)
      rule = map.all_rules.first
      expect(rule[:transform]).to eq(xf)
    end

    it 'stores nil transform when not provided' do
      add_rule
      rule = map.all_rules.first
      expect(rule[:transform]).to be_nil
    end

    it 'accumulates multiple rules' do
      add_rule(src: 'lex-a', tgt: 'lex-b')
      add_rule(src: 'lex-c', tgt: 'lex-d')
      expect(map.all_rules.size).to eq(2)
    end
  end

  # ─── remove_rule ──────────────────────────────────────────────────────────

  describe '.remove_rule' do
    it 'returns success: true for existing rule' do
      rule_id = add_rule[:rule_id]
      result  = map.remove_rule(rule_id: rule_id)
      expect(result[:success]).to be true
    end

    it 'removes the rule from all_rules' do
      rule_id = add_rule[:rule_id]
      map.remove_rule(rule_id: rule_id)
      expect(map.all_rules.map { |r| r[:id] }).not_to include(rule_id)
    end

    it 'returns success: false for unknown rule_id' do
      result = map.remove_rule(rule_id: 'nonexistent-id')
      expect(result[:success]).to be false
    end

    it 'returns the rule_id in the response' do
      rule_id = add_rule[:rule_id]
      result  = map.remove_rule(rule_id: rule_id)
      expect(result[:rule_id]).to eq(rule_id)
    end
  end

  # ─── rules_for ────────────────────────────────────────────────────────────

  describe '.rules_for' do
    before do
      add_rule(src: 'lex-a', tgt: 'lex-b')
      add_rule(src: 'lex-a', tgt: 'lex-c')
      add_rule(src: 'lex-x', tgt: 'lex-y')
    end

    it 'returns only rules for the given source_extension' do
      rules = map.rules_for(source_extension: 'lex-a')
      expect(rules.size).to eq(2)
      rules.each { |r| expect(r[:source_extension]).to eq('lex-a') }
    end

    it 'returns empty array when no rules match' do
      rules = map.rules_for(source_extension: 'lex-unknown')
      expect(rules).to eq([])
    end
  end

  # ─── all_rules ────────────────────────────────────────────────────────────

  describe '.all_rules' do
    it 'returns empty array when no rules' do
      expect(map.all_rules).to eq([])
    end

    it 'returns all stored rules' do
      add_rule(src: 'lex-a')
      add_rule(src: 'lex-b')
      expect(map.all_rules.size).to eq(2)
    end

    it 'returns a duplicate array (not the internal store)' do
      add_rule
      arr = map.all_rules
      arr << { fake: true }
      expect(map.all_rules.size).to eq(1)
    end
  end

  # ─── match_output ─────────────────────────────────────────────────────────

  describe '.match_output' do
    before do
      add_rule(src: 'lex-src', key: :score, tgt: 'lex-tgt', method: :apply_score)
      add_rule(src: 'lex-src', key: :label, tgt: 'lex-tgt', method: :apply_label)
    end

    it 'returns matches for keys present in the output' do
      matches = map.match_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(matches.size).to eq(1)
      expect(matches.first[:rule][:output_key]).to eq(:score)
    end

    it 'returns matched_value from output' do
      matches = map.match_output(source_extension: 'lex-src', output: { score: 0.9 })
      expect(matches.first[:matched_value]).to eq(0.9)
    end

    it 'returns multiple matches when output has multiple matching keys' do
      matches = map.match_output(source_extension: 'lex-src',
                                 output:           { score: 0.9, label: 'high' })
      expect(matches.size).to eq(2)
    end

    it 'returns empty array when no keys match' do
      matches = map.match_output(source_extension: 'lex-src', output: { unrelated: 42 })
      expect(matches).to eq([])
    end

    it 'returns empty array when source_extension has no rules' do
      matches = map.match_output(source_extension: 'lex-other', output: { score: 1.0 })
      expect(matches).to eq([])
    end

    it 'handles non-hash output gracefully' do
      expect { map.match_output(source_extension: 'lex-src', output: nil) }.not_to raise_error
    end
  end

  # ─── clear! ───────────────────────────────────────────────────────────────

  describe '.clear!' do
    it 'removes all rules' do
      add_rule
      add_rule(src: 'lex-b')
      map.clear!
      expect(map.all_rules).to be_empty
    end
  end

  # ─── stats ────────────────────────────────────────────────────────────────

  describe '.stats' do
    it 'returns total_rules: 0 when empty' do
      result = map.stats
      expect(result[:total_rules]).to eq(0)
    end

    it 'returns correct total_rules count' do
      add_rule(src: 'lex-a')
      add_rule(src: 'lex-a')
      result = map.stats
      expect(result[:total_rules]).to eq(2)
    end

    it 'returns by_source hash' do
      add_rule(src: 'lex-a')
      add_rule(src: 'lex-b')
      result = map.stats
      expect(result[:by_source]).to be_a(Hash)
    end

    it 'by_source counts per source correctly' do
      add_rule(src: 'lex-a')
      add_rule(src: 'lex-a')
      add_rule(src: 'lex-b')
      result = map.stats
      expect(result[:by_source]['lex-a']).to eq(2)
      expect(result[:by_source]['lex-b']).to eq(1)
    end

    it 'returns by_target hash' do
      add_rule(tgt: 'lex-b')
      result = map.stats
      expect(result[:by_target]).to be_a(Hash)
      expect(result[:by_target]['lex-b']).to eq(1)
    end
  end

  # ─── thread safety ────────────────────────────────────────────────────────

  describe 'thread safety' do
    it 'records all rules when added concurrently' do
      threads = 20.times.map do |i|
        Thread.new do
          map.add_rule(source_extension: "lex-#{i}", output_key: :result,
                       target_extension: 'lex-target', target_method: :run)
        end
      end
      threads.each(&:join)
      expect(map.all_rules.size).to eq(20)
    end
  end
end
