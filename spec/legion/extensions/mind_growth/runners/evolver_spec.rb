# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Evolver do
  subject(:evolver) { described_class }

  before do
    Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil)
    evolver.instance_variable_set(:@status_store, nil)
    evolver.instance_variable_set(:@replacement_map, nil)
  end

  let(:high_ext) do
    { name: 'lex-high', invocation_count: 5000, impact_score: 0.9,
      health_score: 1.0, error_rate: 0.0, avg_latency_ms: 0, status: :active }
  end

  let(:mid_ext) do
    { name: 'lex-mid', invocation_count: 50, impact_score: 0.5,
      health_score: 0.7, error_rate: 0.1, avg_latency_ms: 200, status: :active }
  end

  let(:low_ext) do
    { name: 'lex-low', invocation_count: 1, impact_score: 0.1,
      health_score: 0.1, error_rate: 0.5, avg_latency_ms: 2000, status: :active }
  end

  let(:building_ext) do
    { name: 'lex-building', invocation_count: 0, impact_score: 0.0,
      health_score: 0.0, error_rate: 1.0, avg_latency_ms: 5000, status: :building }
  end

  let(:testing_ext) do
    { name: 'lex-testing', invocation_count: 0, impact_score: 0.0,
      health_score: 0.0, error_rate: 1.0, avg_latency_ms: 5000, status: :testing }
  end

  # ─── select_for_improvement ────────────────────────────────────────────────

  describe '.select_for_improvement' do
    it 'returns success: true' do
      result = evolver.select_for_improvement(extensions: [high_ext, mid_ext, low_ext])
      expect(result[:success]).to be true
    end

    it 'returns a candidates array' do
      result = evolver.select_for_improvement(extensions: [high_ext, mid_ext, low_ext])
      expect(result[:candidates]).to be_an(Array)
    end

    it 'returns count matching candidates array size' do
      result = evolver.select_for_improvement(extensions: [high_ext, mid_ext, low_ext])
      expect(result[:count]).to eq(result[:candidates].size)
    end

    it 'returns total_evaluated count' do
      result = evolver.select_for_improvement(extensions: [high_ext, mid_ext, low_ext])
      expect(result[:total_evaluated]).to eq(3)
    end

    it 'selects the bottom N extensions by fitness' do
      result = evolver.select_for_improvement(extensions: [high_ext, mid_ext, low_ext], count: 1)
      expect(result[:candidates].first[:name]).to eq('lex-low')
    end

    it 'respects the count parameter' do
      result = evolver.select_for_improvement(extensions: [high_ext, mid_ext, low_ext], count: 2)
      expect(result[:count]).to eq(2)
    end

    it 'skips extensions with :building status' do
      result = evolver.select_for_improvement(extensions: [high_ext, building_ext], count: 2)
      names = result[:candidates].map { |c| c[:name] }
      expect(names).not_to include('lex-building')
    end

    it 'skips extensions with :testing status' do
      result = evolver.select_for_improvement(extensions: [high_ext, testing_ext], count: 2)
      names = result[:candidates].map { |c| c[:name] }
      expect(names).not_to include('lex-testing')
    end

    it 'does not count skipped extensions in total_evaluated' do
      result = evolver.select_for_improvement(extensions: [high_ext, building_ext, low_ext], count: 2)
      expect(result[:total_evaluated]).to eq(2)
    end

    it 'returns empty candidates for empty extensions list' do
      result = evolver.select_for_improvement(extensions: [])
      expect(result[:candidates]).to be_empty
      expect(result[:count]).to eq(0)
    end

    it 'handles count greater than total extensions' do
      result = evolver.select_for_improvement(extensions: [high_ext], count: 10)
      expect(result[:count]).to eq(1)
    end

    it 'returns all extensions when count equals list size' do
      result = evolver.select_for_improvement(extensions: [high_ext, low_ext], count: 2)
      expect(result[:count]).to eq(2)
    end
  end

  # ─── propose_improvement ───────────────────────────────────────────────────

  describe '.propose_improvement' do
    it 'returns success: true' do
      result = evolver.propose_improvement(extension: low_ext)
      expect(result[:success]).to be true
    end

    it 'returns the extension_name' do
      result = evolver.propose_improvement(extension: low_ext)
      expect(result[:extension_name]).to eq('lex-low')
    end

    it 'returns a numeric fitness' do
      result = evolver.propose_improvement(extension: low_ext)
      expect(result[:fitness]).to be_a(Numeric)
    end

    it 'returns a weaknesses array' do
      result = evolver.propose_improvement(extension: low_ext)
      expect(result[:weaknesses]).to be_an(Array)
    end

    it 'returns a suggestions array' do
      begin
        evolver.propose_improve(extension: low_ext)
      rescue StandardError
        nil
      end
      result = evolver.propose_improvement(extension: low_ext)
      expect(result[:suggestions]).to be_an(Array)
    end

    it 'identifies :low_invocations weakness for zero-invocation extension' do
      ext    = { name: 'lex-zero', invocation_count: 0, impact_score: 0.5, error_rate: 0.0, avg_latency_ms: 0 }
      result = evolver.propose_improvement(extension: ext)
      expect(result[:weaknesses]).to include(:low_invocations)
    end

    it 'identifies :high_error_rate weakness when error_rate > 0.2' do
      ext    = { name: 'lex-err', invocation_count: 100, impact_score: 0.5, error_rate: 0.5, avg_latency_ms: 0 }
      result = evolver.propose_improvement(extension: ext)
      expect(result[:weaknesses]).to include(:high_error_rate)
    end

    it 'identifies :high_latency weakness when avg_latency_ms > 1000' do
      ext    = { name: 'lex-slow', invocation_count: 100, impact_score: 0.5, error_rate: 0.0, avg_latency_ms: 2000 }
      result = evolver.propose_improvement(extension: ext)
      expect(result[:weaknesses]).to include(:high_latency)
    end

    it 'identifies :low_impact weakness when impact_score < 0.3' do
      ext    = { name: 'lex-lowin', invocation_count: 100, impact_score: 0.1, error_rate: 0.0, avg_latency_ms: 0 }
      result = evolver.propose_improvement(extension: ext)
      expect(result[:weaknesses]).to include(:low_impact)
    end

    it 'returns generic suggestion when no specific weaknesses detected' do
      result = evolver.propose_improvement(extension: high_ext)
      expect(result[:suggestions]).not_to be_empty
    end

    if defined?(Legion::LLM)
      it 'returns LLM-enriched suggestions when LLM is available' do
        mock_llm_session = double('session')
        mock_response    = double('response', content: '["fix error handling", "add caching"]')
        allow(mock_llm_session).to receive(:ask).and_return(mock_response)
        allow(Legion::LLM).to receive(:started?).and_return(true)
        allow(Legion::LLM).to receive(:chat).and_return(mock_llm_session)

        result = evolver.propose_improvement(extension: low_ext)
        expect(result[:suggestions]).to include('fix error handling')
      end
    end

    it 'falls back to heuristic suggestions when LLM is unavailable' do
      begin
        allow(Legion).to receive(:const_defined?).with(:LLM).and_return(false)
      rescue StandardError
        nil
      end
      result = evolver.propose_improvement(extension: low_ext)
      expect(result[:suggestions]).to be_an(Array)
      expect(result[:suggestions]).not_to be_empty
    end
  end

  # ─── replace_extension ─────────────────────────────────────────────────────

  describe '.replace_extension' do
    it 'returns success: true' do
      result = evolver.replace_extension(old_name: 'lex-old', new_proposal_id: 'abc-123')
      expect(result[:success]).to be true
    end

    it 'returns the replaced name' do
      result = evolver.replace_extension(old_name: 'lex-old', new_proposal_id: 'abc-123')
      expect(result[:replaced]).to eq('lex-old')
    end

    it 'returns the replacement_proposal_id' do
      result = evolver.replace_extension(old_name: 'lex-old', new_proposal_id: 'abc-123')
      expect(result[:replacement_proposal_id]).to eq('abc-123')
    end

    it 'marks the old extension as :pruned in the status store' do
      evolver.replace_extension(old_name: 'lex-prunable', new_proposal_id: 'xyz-999')
      expect(evolver.instance_variable_get(:@status_store)['lex-prunable']).to eq(:pruned)
    end

    it 'stores the replacement mapping' do
      evolver.replace_extension(old_name: 'lex-old2', new_proposal_id: 'new-id')
      expect(evolver.instance_variable_get(:@replacement_map)['lex-old2']).to eq('new-id')
    end
  end

  # ─── merge_extensions ──────────────────────────────────────────────────────

  describe '.merge_extensions' do
    let(:ext_a) { { name: 'lex-alpha', category: :cognition } }
    let(:ext_b) { { name: 'lex-beta',  category: :memory } }

    it 'returns success: true' do
      result = evolver.merge_extensions(extension_a: ext_a, extension_b: ext_b)
      expect(result[:success]).to be true
    end

    it 'returns a merged_proposal' do
      result = evolver.merge_extensions(extension_a: ext_a, extension_b: ext_b)
      expect(result[:merged_proposal]).to be_a(Hash)
    end

    it 'returns sources with both extension names' do
      result = evolver.merge_extensions(extension_a: ext_a, extension_b: ext_b)
      expect(result[:sources]).to contain_exactly('lex-alpha', 'lex-beta')
    end

    it 'calls Proposer.propose_concept to create the merged proposal' do
      allow(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to receive(:propose_concept).and_call_original
      evolver.merge_extensions(extension_a: ext_a, extension_b: ext_b)
      expect(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to have_received(:propose_concept)
    end

    it 'uses provided merged_name when given' do
      result = evolver.merge_extensions(extension_a: ext_a, extension_b: ext_b, merged_name: 'lex-custom')
      proposal = result[:merged_proposal]
      expect(proposal[:success]).to be true
    end

    it 'auto-generates merged name from source names when none provided' do
      allow(Legion::Extensions::MindGrowth::Runners::Proposer)
        .to receive(:propose_concept) do |**args|
          expect(args[:name]).to include('alpha')
          { success: true, proposal: { name: args[:name] } }
        end
      evolver.merge_extensions(extension_a: ext_a, extension_b: ext_b)
    end
  end

  # ─── evolution_summary ─────────────────────────────────────────────────────

  describe '.evolution_summary' do
    let(:all_exts) { [high_ext, mid_ext, low_ext] }

    it 'returns success: true' do
      result = evolver.evolution_summary(extensions: all_exts)
      expect(result[:success]).to be true
    end

    it 'returns improvement_candidates array' do
      result = evolver.evolution_summary(extensions: all_exts)
      expect(result[:improvement_candidates]).to be_an(Array)
    end

    it 'returns prune_candidates array' do
      result = evolver.evolution_summary(extensions: all_exts)
      expect(result[:prune_candidates]).to be_an(Array)
    end

    it 'returns speciation_candidates array' do
      result = evolver.evolution_summary(extensions: all_exts)
      expect(result[:speciation_candidates]).to be_an(Array)
    end

    it 'returns fitness_distribution hash with min/max/mean/median' do
      result = evolver.evolution_summary(extensions: all_exts)
      dist = result[:fitness_distribution]
      expect(dist).to have_key(:min)
      expect(dist).to have_key(:max)
      expect(dist).to have_key(:mean)
      expect(dist).to have_key(:median)
    end

    it 'fitness_distribution min <= mean <= max' do
      result = evolver.evolution_summary(extensions: all_exts)
      dist = result[:fitness_distribution]
      expect(dist[:min]).to be <= dist[:mean]
      expect(dist[:mean]).to be <= dist[:max]
    end

    it 'includes low-fitness extension in improvement_candidates' do
      result = evolver.evolution_summary(extensions: [high_ext, low_ext], count: 1)
      names = result[:improvement_candidates].map { |c| c[:name] }
      expect(names).to include('lex-low')
    end

    it 'identifies speciation candidates by drift_score' do
      drifted = { name: 'lex-drifted', drift_score: 0.8, invocation_count: 10,
                  impact_score: 0.5, health_score: 0.5, error_rate: 0.0, avg_latency_ms: 0 }
      result  = evolver.evolution_summary(extensions: [drifted])
      expect(result[:speciation_candidates]).to include('lex-drifted')
    end

    it 'does not flag extension with drift_score below threshold as speciation candidate' do
      stable = { name: 'lex-stable', drift_score: 0.1, invocation_count: 100,
                 impact_score: 0.7, health_score: 0.9, error_rate: 0.0, avg_latency_ms: 0 }
      result = evolver.evolution_summary(extensions: [stable])
      expect(result[:speciation_candidates]).to be_empty
    end

    it 'returns all-zero distribution for empty extensions' do
      result = evolver.evolution_summary(extensions: [])
      dist = result[:fitness_distribution]
      expect(dist[:min]).to eq(0.0)
      expect(dist[:max]).to eq(0.0)
      expect(dist[:mean]).to eq(0.0)
      expect(dist[:median]).to eq(0.0)
    end

    it 'handles all extensions having the same fitness' do
      same = Array.new(3) do |i|
        { name: "lex-same-#{i}", invocation_count: 0, impact_score: 0.0,
          health_score: 0.0, error_rate: 0.0, avg_latency_ms: 0 }
      end
      result = evolver.evolution_summary(extensions: same)
      dist = result[:fitness_distribution]
      expect(dist[:min]).to eq(dist[:max])
    end
  end

  # ─── constants ─────────────────────────────────────────────────────────────

  describe 'constants' do
    it 'defines BOTTOM_PERCENTILE as 0.05' do
      expect(described_class::BOTTOM_PERCENTILE).to eq(0.05)
    end

    it 'defines SPECIATION_DRIFT_THRESHOLD as 0.5' do
      expect(described_class::SPECIATION_DRIFT_THRESHOLD).to eq(0.5)
    end
  end
end
