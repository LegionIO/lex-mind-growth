# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        class ProposalStore
          MAX_PROPOSALS = 500

          def initialize
            @proposals = {}
            @mutex     = Mutex.new
          end

          def store(proposal)
            @mutex.synchronize { @proposals[proposal.id] = proposal }
          end

          def get(id)
            @mutex.synchronize { @proposals[id] }
          end

          def all
            @mutex.synchronize { @proposals.values.dup }
          end

          def by_status(status)
            @mutex.synchronize { @proposals.values.select { |p| p.status == status.to_sym } }
          end

          def by_category(category)
            @mutex.synchronize { @proposals.values.select { |p| p.category == category.to_sym } }
          end

          def approved
            by_status(:approved)
          end

          def build_queue
            by_status(:approved).sort_by { |p| -(p.scores.values.sum / p.scores.size.to_f) }
          end

          def recent(limit: 20)
            @mutex.synchronize { @proposals.values.sort_by { |p| -p.created_at.to_f }.first(limit) }
          end

          def stats
            @mutex.synchronize do
              statuses = @proposals.values.group_by(&:status).transform_values(&:count)
              { total: @proposals.size, by_status: statuses }
            end
          end

          def clear
            @mutex.synchronize { @proposals.clear }
          end
        end
      end
    end
  end
end
