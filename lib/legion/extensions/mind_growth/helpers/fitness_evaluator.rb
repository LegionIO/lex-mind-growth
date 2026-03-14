# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        module FitnessEvaluator
          extend self

          def fitness(extension)
            w             = Helpers::Constants::FITNESS_WEIGHTS
            invocation    = normalize_invocations(extension[:invocation_count] || 0)
            impact        = extension[:impact_score] || 0.5
            health        = extension[:health_score] || 1.0
            error_rate    = extension[:error_rate] || 0.0
            latency       = normalize_latency(extension[:avg_latency_ms] || 0)

            score = (w[:invocation_rate] * invocation) +
                    (w[:impact_score] * impact) +
                    (w[:health] * health) +
                    (w[:error_penalty] * error_rate) +
                    (w[:latency_penalty] * latency)
            score.clamp(0.0, 1.0).round(3)
          end

          def rank(extensions)
            extensions.map { |e| e.merge(fitness: fitness(e)) }.sort_by { |e| -e[:fitness] }
          end

          def prune_candidates(extensions)
            extensions.select { |e| fitness(e) < Helpers::Constants::PRUNE_THRESHOLD }
          end

          def improvement_candidates(extensions)
            extensions.select do |e|
              f = fitness(e)
              f >= Helpers::Constants::PRUNE_THRESHOLD && f < Helpers::Constants::IMPROVEMENT_THRESHOLD
            end
          end

          private

          def normalize_invocations(count)
            # Log scale: 0 invocations = 0.0, 1000+ = 1.0
            return 0.0 if count.zero?

            (Math.log10(count + 1) / 3.0).clamp(0.0, 1.0)
          end

          def normalize_latency(ms_val)
            # Higher latency = higher penalty (0-1 scale, 5000ms = 1.0)
            (ms_val / 5000.0).clamp(0.0, 1.0)
          end
        end
      end
    end
  end
end
