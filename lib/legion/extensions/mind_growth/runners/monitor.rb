# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Monitor
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          extend self

          HEALTH_LEVELS = {
            excellent: 0.8,
            good:      0.6,
            fair:      0.4,
            degraded:  0.2,
            critical:  0.0
          }.freeze

          def health_check(extension:, **)
            name    = extension[:name] || extension[:extension_name]
            fitness = Helpers::FitnessEvaluator.fitness(extension)
            level   = classify_health(fitness)
            alert   = %i[degraded critical].include?(level)

            { success: true, extension_name: name, fitness: fitness,
              health_level: level, alert: alert }
          end

          def usage_stats(extensions:, **)
            stats = Array(extensions).map do |ext|
              { extension_name:   ext[:name] || ext[:extension_name],
                invocation_count: ext[:invocation_count] || 0,
                error_rate:       ext[:error_rate] || 0.0,
                avg_latency_ms:   ext[:avg_latency_ms] || 0 }
            end

            { success: true, stats: stats, count: stats.size }
          end

          def impact_score(extension:, extensions: nil, **)
            name   = extension[:name] || extension[:extension_name]
            impact = extension[:impact_score] || 0.5

            percentile = if extensions && !Array(extensions).empty?
                           all_impacts = Array(extensions).map { |e| e[:impact_score] || 0.5 }.sort
                           rank = all_impacts.count { |i| i <= impact }
                           (rank.to_f / all_impacts.size * 100).round(1)
                         else
                           50.0
                         end

            { success: true, extension_name: name, impact: impact, rank_percentile: percentile }
          end

          def decay_check(extensions:, **)
            threshold = Helpers::Constants::DECAY_INVOCATION_THRESHOLD
            decayed = Array(extensions).select do |ext|
              count   = ext[:invocation_count] || 0
              fitness = Helpers::FitnessEvaluator.fitness(ext)
              count < threshold || fitness < Helpers::Constants::PRUNE_THRESHOLD
            end

            { success: true, decayed: decayed, count: decayed.size }
          end

          def auto_prune(extensions:, **)
            pruned = Helpers::FitnessEvaluator.prune_candidates(Array(extensions))
            { success: true, pruned: pruned, count: pruned.size }
          end

          def health_summary(extensions:, **)
            exts = Array(extensions)

            by_health_level = HEALTH_LEVELS.keys.to_h { |level| [level, 0] }
            alerts          = []
            prune_candidates = Helpers::FitnessEvaluator.prune_candidates(exts)

            exts.each do |ext|
              fitness = Helpers::FitnessEvaluator.fitness(ext)
              level   = classify_health(fitness)
              by_health_level[level] += 1
              alerts << ext if %i[degraded critical].include?(level)
            end

            { success: true, total: exts.size, by_health_level: by_health_level,
              alerts: alerts, prune_candidates: prune_candidates }
          end

          private

          def classify_health(fitness)
            HEALTH_LEVELS.each do |level, threshold|
              return level if fitness >= threshold
            end
            :critical
          end
        end
      end
    end
  end
end
