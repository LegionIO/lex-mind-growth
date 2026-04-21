# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        # Cache-backed persistence for proposals and governance votes.
        # Best-effort: degrades to in-memory-only when cache is unavailable.
        class ProposalPersistence
          PROPOSAL_TTL     = 604_800 # 7 days
          VOTES_KEY_SUFFIX = ':votes'
          INDEX_KEY_SUFFIX = ':index'

          def initialize(namespace: 'legion_mind_growth')
            @namespace = namespace
          end

          def save_proposal(proposal_hash)
            return false unless cache_available?

            key = proposal_key(proposal_hash[:id])
            Legion::Cache.set_sync(key, serialize(proposal_hash), ttl: PROPOSAL_TTL)
            update_index(proposal_hash[:id], :add)
            true
          rescue StandardError => _e
            false
          end

          def load_proposal(id)
            return nil unless cache_available?

            raw = Legion::Cache.get(proposal_key(id)) # rubocop:disable Legion/HelperMigration/DirectCache
            return nil unless raw

            deserialize(raw)
          rescue StandardError => _e
            nil
          end

          def delete_proposal(id)
            return false unless cache_available?

            Legion::Cache.delete_sync(proposal_key(id))
            update_index(id, :remove)
            true
          rescue StandardError => _e
            false
          end

          def load_all_proposals
            return {} unless cache_available?

            ids = load_index
            return {} if ids.empty?

            ids.each_with_object({}) do |id, result|
              p = load_proposal(id)
              result[id] = p if p
            end
          rescue StandardError => _e
            {}
          end

          def save_votes(votes_hash)
            return false unless cache_available?

            Legion::Cache.set_sync(votes_key, serialize(votes_hash), ttl: PROPOSAL_TTL)
            true
          rescue StandardError => _e
            false
          end

          def load_votes
            return {} unless cache_available?

            raw = Legion::Cache.get(votes_key) # rubocop:disable Legion/HelperMigration/DirectCache
            return {} unless raw

            deserialize(raw)
          rescue StandardError => _e
            {}
          end

          private

          def cache_available?
            defined?(Legion::Cache) && Legion::Cache.connected? # rubocop:disable Legion/HelperMigration/DirectCache
          end

          def proposal_key(id) = "#{@namespace}:proposal:#{id}"
          def votes_key        = "#{@namespace}#{VOTES_KEY_SUFFIX}"
          def index_key        = "#{@namespace}#{INDEX_KEY_SUFFIX}"

          def update_index(id, operation)
            ids = load_index
            case operation
            when :add    then ids << id unless ids.include?(id)
            when :remove then ids.delete(id)
            end
            Legion::Cache.set_sync(index_key, serialize(ids), ttl: PROPOSAL_TTL)
          end

          def load_index
            raw = Legion::Cache.get(index_key) # rubocop:disable Legion/HelperMigration/DirectCache
            return [] unless raw

            result = deserialize(raw)
            result.is_a?(Array) ? result : []
          rescue StandardError => _e
            []
          end

          def serialize(obj)
            ::JSON.generate(obj)
          end

          def deserialize(raw)
            return raw if raw.is_a?(Hash) || raw.is_a?(Array)

            ::JSON.parse(raw, symbolize_names: true)
          rescue ::JSON::ParserError => _e
            nil
          end
        end
      end
    end
  end
end
