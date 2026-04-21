# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        class ProposalStore
          MAX_PROPOSALS = 500

          def initialize
            @proposals   = {}
            @mutex       = Mutex.new
            @persistence = ProposalPersistence.new
            rehydrate_from_cache
          end

          def store(proposal)
            @mutex.synchronize do
              evict_oldest if @proposals.size >= MAX_PROPOSALS
              @proposals[proposal.id] = proposal
              @persistence.save_proposal(proposal.to_h)
            end
          end

          def get(id)
            @mutex.synchronize { @proposals[id] }
          end

          def update(proposal)
            @mutex.synchronize do
              @proposals[proposal.id] = proposal
              @persistence.save_proposal(proposal.to_h)
            end
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

          private

          def evict_oldest
            oldest = @proposals.values.min_by { |p| p.created_at.to_f }
            return unless oldest

            @proposals.delete(oldest.id)
            @persistence.delete_proposal(oldest.id)
          end

          def rehydrate_from_cache
            cached = @persistence.load_all_proposals
            cached.each do |id, hash|
              proposal = ConceptProposal.from_h(hash)
              @proposals[id] = proposal
            end
            log.info "[proposal_store] rehydrated #{cached.size} proposals from cache" unless cached.empty?
          rescue StandardError => e
            log.error "[proposal_store] rehydrate_from_cache failed: #{e.message}"
          end

          def log
            Legion::Logging
          end
        end
      end
    end
  end
end
