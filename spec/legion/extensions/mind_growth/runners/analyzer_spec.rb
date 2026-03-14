# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Analyzer do
  subject(:analyzer) { described_class }

  describe '.cognitive_profile' do
    it 'returns success: true' do
      result = analyzer.cognitive_profile
      expect(result[:success]).to be true
    end

    it 'returns total_extensions count' do
      result = analyzer.cognitive_profile(existing_extensions: %i[attention memory])
      expect(result[:total_extensions]).to eq(2)
    end

    it 'returns model_coverage array' do
      result = analyzer.cognitive_profile(existing_extensions: [])
      expect(result[:model_coverage]).to be_an(Array)
      expect(result[:model_coverage].size).to eq(5)
    end

    it 'returns overall_coverage as a float' do
      result = analyzer.cognitive_profile(existing_extensions: [])
      expect(result[:overall_coverage]).to be_a(Float)
      expect(result[:overall_coverage]).to be_between(0.0, 1.0)
    end

    it 'returns higher overall coverage with more extensions' do
      empty_result = analyzer.cognitive_profile(existing_extensions: [])
      full_required = Legion::Extensions::MindGrowth::Helpers::CognitiveModels::MODELS.values.flat_map { |m| m[:required] }.uniq
      full_result = analyzer.cognitive_profile(existing_extensions: full_required)
      expect(full_result[:overall_coverage]).to be > empty_result[:overall_coverage]
    end

    it 'uses empty list when no extensions provided and metacognition constants absent' do
      result = analyzer.cognitive_profile
      expect(result[:total_extensions]).to eq(0)
    end

    it 'ignores unknown keyword arguments' do
      expect { analyzer.cognitive_profile(unknown: :value) }.not_to raise_error
    end
  end

  describe '.identify_weak_links' do
    let(:healthy) { { invocation_count: 500, impact_score: 0.9, health_score: 1.0, error_rate: 0.0, avg_latency_ms: 50 } }
    let(:weak)    { { invocation_count: 0, impact_score: 0.1, health_score: 0.2, error_rate: 0.9, avg_latency_ms: 3000 } }

    it 'returns success: true' do
      result = analyzer.identify_weak_links(extensions: [])
      expect(result[:success]).to be true
    end

    it 'identifies weak links below IMPROVEMENT_THRESHOLD' do
      result = analyzer.identify_weak_links(extensions: [healthy, weak])
      # The healthy extension should not appear as a weak link
      weak_fitnesses = result[:weak_links].map { |e| e[:fitness] }
      weak_fitnesses.each do |f|
        expect(f).to be < Legion::Extensions::MindGrowth::Helpers::Constants::IMPROVEMENT_THRESHOLD
      end
    end

    it 'returns ranked weak links' do
      result = analyzer.identify_weak_links(extensions: [weak])
      expect(result[:weak_links]).to be_an(Array)
    end

    it 'returns count of weak links' do
      result = analyzer.identify_weak_links(extensions: [healthy, weak])
      expect(result[:count]).to be_a(Integer)
    end

    it 'defaults to empty extensions array' do
      result = analyzer.identify_weak_links
      expect(result[:count]).to eq(0)
    end
  end

  describe '.recommend_priorities' do
    it 'returns success: true' do
      result = analyzer.recommend_priorities(existing_extensions: [])
      expect(result[:success]).to be true
    end

    it 'returns priorities array' do
      result = analyzer.recommend_priorities(existing_extensions: [])
      expect(result[:priorities]).to be_an(Array)
    end

    it 'limits priorities to 10' do
      result = analyzer.recommend_priorities(existing_extensions: [])
      expect(result[:priorities].size).to be <= 10
    end

    it 'includes rationale' do
      result = analyzer.recommend_priorities(existing_extensions: [])
      expect(result[:rationale]).to be_a(String)
      expect(result[:rationale]).not_to be_empty
    end

    it 'returns fewer priorities when extensions cover more requirements' do
      all_required = Legion::Extensions::MindGrowth::Helpers::CognitiveModels::MODELS.values.flat_map { |m| m[:required] }.uniq
      result = analyzer.recommend_priorities(existing_extensions: all_required)
      expect(result[:priorities]).to be_empty
    end
  end
end
