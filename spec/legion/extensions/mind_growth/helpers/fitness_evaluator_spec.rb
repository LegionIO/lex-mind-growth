# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::FitnessEvaluator do
  subject(:evaluator) { described_class }

  let(:healthy_extension) do
    {
      invocation_count: 500,
      impact_score:     0.8,
      health_score:     0.95,
      error_rate:       0.02,
      avg_latency_ms:   100
    }
  end

  let(:poor_extension) do
    {
      invocation_count: 0,
      impact_score:     0.1,
      health_score:     0.3,
      error_rate:       0.8,
      avg_latency_ms:   4000
    }
  end

  let(:default_extension) { {} }

  describe '.fitness' do
    it 'returns a float between 0 and 1' do
      score = evaluator.fitness(healthy_extension)
      expect(score).to be_between(0.0, 1.0)
    end

    it 'returns higher score for healthy extension' do
      healthy_score = evaluator.fitness(healthy_extension)
      poor_score    = evaluator.fitness(poor_extension)
      expect(healthy_score).to be > poor_score
    end

    it 'returns a score for default extension with all defaults' do
      score = evaluator.fitness(default_extension)
      expect(score).to be_between(0.0, 1.0)
    end

    it 'returns a rounded value (3 decimal places)' do
      score = evaluator.fitness(healthy_extension)
      expect(score.to_s.split('.').last.length).to be <= 3
    end

    it 'clamps score to 0.0 minimum' do
      very_bad = { invocation_count: 0, impact_score: 0.0, health_score: 0.0, error_rate: 1.0, avg_latency_ms: 5000 }
      expect(evaluator.fitness(very_bad)).to be >= 0.0
    end

    it 'clamps score to 1.0 maximum' do
      perfect = { invocation_count: 10_000, impact_score: 1.0, health_score: 1.0, error_rate: 0.0, avg_latency_ms: 0 }
      expect(evaluator.fitness(perfect)).to be <= 1.0
    end
  end

  describe '.rank' do
    let(:extensions) { [poor_extension, healthy_extension] }

    it 'returns extensions sorted by fitness descending' do
      ranked = evaluator.rank(extensions)
      expect(ranked.first[:fitness]).to be > ranked.last[:fitness]
    end

    it 'adds fitness key to each extension' do
      ranked = evaluator.rank(extensions)
      ranked.each do |e|
        expect(e).to have_key(:fitness)
      end
    end

    it 'does not modify original extensions' do
      evaluator.rank(extensions)
      expect(healthy_extension).not_to have_key(:fitness)
    end
  end

  describe '.prune_candidates' do
    it 'returns extensions with fitness below PRUNE_THRESHOLD' do
      result = evaluator.prune_candidates([poor_extension, healthy_extension])
      expect(result).to include(poor_extension)
      expect(result).not_to include(healthy_extension)
    end

    it 'returns empty array when none qualify' do
      expect(evaluator.prune_candidates([healthy_extension])).to be_empty
    end
  end

  describe '.improvement_candidates' do
    let(:mediocre_extension) do
      {
        invocation_count: 10,
        impact_score:     0.35,
        health_score:     0.6,
        error_rate:       0.15,
        avg_latency_ms:   500
      }
    end

    it 'returns extensions between PRUNE_THRESHOLD and IMPROVEMENT_THRESHOLD' do
      result = evaluator.improvement_candidates([mediocre_extension, poor_extension, healthy_extension])
      # mediocre should fall in the improvement range; poor below prune; healthy above improvement
      fitness_values = result.map { |e| evaluator.fitness(e) }
      fitness_values.each do |f|
        expect(f).to be >= Legion::Extensions::MindGrowth::Helpers::Constants::PRUNE_THRESHOLD
        expect(f).to be < Legion::Extensions::MindGrowth::Helpers::Constants::IMPROVEMENT_THRESHOLD
      end
    end
  end

  describe 'log-scale invocation normalization' do
    it 'maps zero invocations to 0.0' do
      score_zero = evaluator.fitness({ invocation_count: 0, impact_score: 0.5, health_score: 1.0, error_rate: 0.0, avg_latency_ms: 0 })
      score_some = evaluator.fitness({ invocation_count: 100, impact_score: 0.5, health_score: 1.0, error_rate: 0.0, avg_latency_ms: 0 })
      expect(score_some).to be > score_zero
    end
  end
end
