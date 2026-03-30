# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Retrospective
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          extend self

          BUILT_STATUSES       = %i[passing wired active].freeze
          FAILED_STATUSES      = %i[build_failed rejected pruned].freeze
          IN_PROGRESS_STATUSES = %i[proposed evaluating approved building testing].freeze
          SUCCEEDED_STATUSES   = BUILT_STATUSES

          # Generates a summary of growth activity: proposals by status, recent builds, failures
          def session_report(**)
            proposals = Runners::Proposer.proposal_stats
            recent = Runners::Proposer.list_proposals(limit: 10)

            built       = recent[:proposals].select { |p| BUILT_STATUSES.include?(p[:status]) }
            failed      = recent[:proposals].select { |p| FAILED_STATUSES.include?(p[:status]) }
            in_progress = recent[:proposals].select { |p| IN_PROGRESS_STATUSES.include?(p[:status]) }

            {
              success:      true,
              summary:      {
                total_proposals: proposals[:stats][:total],
                by_status:       proposals[:stats][:by_status],
                recent_built:    built.map { |p| { id: p[:id], name: p[:name], status: p[:status] } },
                recent_failed:   failed.map { |p| { id: p[:id], name: p[:name], status: p[:status] } },
                in_progress:     in_progress.map { |p| { id: p[:id], name: p[:name], status: p[:status] } }
              },
              generated_at: Time.now.utc
            }
          end

          # Tracks extension count, quality, coverage over time
          # Returns snapshot metrics suitable for time-series storage
          def trend_analysis(extensions: [], **)
            profile = Runners::Analyzer.cognitive_profile(existing_extensions: extensions.empty? ? nil : extensions)
            ranked = extensions.empty? ? [] : Helpers::FitnessEvaluator.rank(extensions)

            avg_fitness = ranked.empty? ? 0.0 : (ranked.sum { |e| e[:fitness] } / ranked.size).round(3)
            prune_count = ranked.count { |e| e[:fitness] < Helpers::Constants::PRUNE_THRESHOLD }
            healthy_count = ranked.count { |e| e[:fitness] >= Helpers::Constants::IMPROVEMENT_THRESHOLD }

            {
              success:      true,
              snapshot:     {
                extension_count:        ranked.size,
                overall_coverage:       profile[:overall_coverage],
                model_coverage:         profile[:model_coverage]&.map { |m| { model: m[:model], coverage: m[:coverage] } },
                avg_fitness:            avg_fitness,
                healthy_extensions:     healthy_count,
                prune_candidates:       prune_count,
                improvement_candidates: ranked.size - healthy_count - prune_count
              },
              generated_at: Time.now.utc
            }
          end

          # Identifies patterns from build failures to improve future LLM prompts
          def learning_extraction(**)
            all_proposals = Runners::Proposer.list_proposals(limit: 100)
            proposals = all_proposals[:proposals]

            failed = proposals.select { |p| p[:status] == :build_failed }
            rejected = proposals.select { |p| p[:status] == :rejected }
            succeeded = proposals.select { |p| SUCCEEDED_STATUSES.include?(p[:status]) }

            # Category success rates
            category_stats = compute_category_stats(proposals)

            # Extract patterns from failures
            failure_patterns = extract_failure_patterns(failed)

            {
              success:      true,
              learnings:    {
                total_analyzed:     proposals.size,
                success_rate:       proposals.empty? ? 0.0 : (succeeded.size.to_f / proposals.size).round(3),
                rejection_rate:     proposals.empty? ? 0.0 : (rejected.size.to_f / proposals.size).round(3),
                build_failure_rate: proposals.empty? ? 0.0 : (failed.size.to_f / proposals.size).round(3),
                category_stats:     category_stats,
                failure_patterns:   failure_patterns,
                recommendations:    generate_recommendations(category_stats, failure_patterns)
              },
              generated_at: Time.now.utc
            }
          end

          private

          def compute_category_stats(proposals)
            by_category = proposals.group_by { |p| p[:category] }
            by_category.transform_values do |cat_proposals|
              succeeded = cat_proposals.count { |p| SUCCEEDED_STATUSES.include?(p[:status]) }
              {
                total:        cat_proposals.size,
                succeeded:    succeeded,
                success_rate: cat_proposals.empty? ? 0.0 : (succeeded.to_f / cat_proposals.size).round(3)
              }
            end
          end

          def extract_failure_patterns(failed_proposals)
            return [] if failed_proposals.empty?

            # Group failures by category to identify problematic areas
            by_category = failed_proposals.group_by { |p| p[:category] }
            patterns = by_category.map do |category, proposals|
              { category: category, failure_count: proposals.size,
                names: proposals.map { |p| p[:name] } }
            end
            patterns.sort_by { |p| -p[:failure_count] }
          end

          def generate_recommendations(category_stats, failure_patterns)
            recs = []

            # Recommend avoiding categories with high failure rates
            category_stats.each do |category, stats|
              if stats[:total] >= 3 && stats[:success_rate] < 0.3
                recs << { type: :avoid_category, category: category,
                          reason: "low success rate (#{(stats[:success_rate] * 100).round}%)" }
              end

              # Recommend focus on categories with high success rates
              if stats[:total] >= 3 && stats[:success_rate] > 0.8
                recs << { type: :focus_category, category: category,
                          reason: "high success rate (#{(stats[:success_rate] * 100).round}%)" }
              end
            end

            # Flag recurring failure patterns
            failure_patterns.each do |pattern|
              if pattern[:failure_count] >= 3
                recs << { type: :investigate_failures, category: pattern[:category],
                          reason: "#{pattern[:failure_count]} build failures" }
              end
            end

            recs
          end
        end
      end
    end
  end
end
