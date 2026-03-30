# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Dashboard
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          module_function

          def extension_timeline(extensions:, days: 30, **)
            count = Array(extensions).size
            today = Time.now.utc.strftime('%Y-%m-%d')
            series = [{ date: today, count: count }]

            { success: true, series: series, range_days: days }
          end

          def category_distribution(extensions:, **)
            exts = Array(extensions)
            dist = Helpers::Constants::CATEGORIES.to_h { |c| [c, 0] }

            exts.each do |ext|
              cat = (ext[:category] || :cognition).to_sym
              dist[cat] = (dist[cat] || 0) + 1
            end

            { success: true, distribution: dist, total: exts.size }
          end

          def build_metrics(**)
            stats = Runners::Proposer.proposal_stats[:stats]
            by_status = stats[:by_status] || {}
            total     = stats[:total] || 0

            approved = by_status[:approved].to_i
            rejected = by_status[:rejected].to_i
            built    = (by_status[:passing].to_i + by_status[:wired].to_i + by_status[:active].to_i)
            failed   = by_status[:build_failed].to_i

            attempted    = built + failed
            success_rate = attempted.positive? ? (built.to_f / attempted).round(3) : 0.0

            evaluated = approved + rejected
            approval_rate = evaluated.positive? ? (approved.to_f / evaluated).round(3) : 0.0

            { success:         true,
              total_proposals: total,
              approved:        approved,
              rejected:        rejected,
              built:           built,
              failed:          failed,
              success_rate:    success_rate,
              approval_rate:   approval_rate }
          end

          def top_extensions(extensions:, limit: 10, **)
            exts = Array(extensions)
            ranked = Helpers::FitnessEvaluator.rank(exts)
            top = ranked.first(limit).map do |e|
              { name:             e[:name] || e[:extension_name],
                invocation_count: e[:invocation_count] || 0,
                fitness:          e[:fitness] }
            end

            { success: true, top: top, limit: limit }
          end

          def bottom_extensions(extensions:, limit: 10, **)
            exts = Array(extensions)
            ranked = Helpers::FitnessEvaluator.rank(exts)
            bottom = ranked.last(limit).reverse.map do |e|
              { name:             e[:name] || e[:extension_name],
                invocation_count: e[:invocation_count] || 0,
                fitness:          e[:fitness] }
            end

            { success: true, bottom: bottom, limit: limit }
          end

          def recent_proposals(limit: 10, **)
            result = Runners::Proposer.list_proposals(limit: limit)
            { success: true, proposals: result[:proposals], count: result[:count] }
          end

          def full_dashboard(extensions:, **)
            exts = Array(extensions)

            { success:               true,
              category_distribution: category_distribution(extensions: exts)[:distribution],
              build_metrics:         build_metrics,
              top_extensions:        top_extensions(extensions: exts)[:top],
              bottom_extensions:     bottom_extensions(extensions: exts)[:bottom],
              recent_proposals:      recent_proposals[:proposals],
              health_summary:        Runners::Monitor.health_summary(extensions: exts),
              timestamp:             Time.now.utc.iso8601 }
          end
        end
      end
    end
  end
end
