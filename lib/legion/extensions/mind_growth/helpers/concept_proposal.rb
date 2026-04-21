# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        class ConceptProposal
          FIELDS = %i[
            id name module_name category description metaphor helpers runner_methods
            rationale scores status origin created_at evaluated_at built_at
          ].freeze

          attr_reader(*FIELDS)

          def initialize(name:, module_name:, category:, description:, metaphor: nil, helpers: [], # rubocop:disable Metrics/ParameterLists
                         runner_methods: [], rationale: nil, origin: :proposer)
            @id             = SecureRandom.uuid
            @name           = name
            @module_name    = module_name
            @category       = category.to_sym
            @description    = description
            @metaphor       = metaphor
            @helpers        = helpers         # array of { name:, methods: [] }
            @runner_methods = runner_methods  # array of { name:, params: [], returns: '' }
            @rationale      = rationale
            @scores         = {}              # { novelty: 0.0..1.0, fit: 0.0..1.0, ... }
            @status         = :proposed
            @origin         = origin
            @created_at     = Time.now.utc
            @evaluated_at   = nil
            @built_at       = nil
          end

          def evaluate!(scores)
            @scores       = scores
            @evaluated_at = Time.now.utc
            @status       = passing_evaluation? ? :approved : :rejected
          end

          def passing_evaluation?
            return false if @scores.empty?

            Helpers::Constants::EVALUATION_DIMENSIONS.all? { |dim| (@scores[dim] || 0) >= Helpers::Constants::MIN_DIMENSION_SCORE }
          end

          def auto_approvable?
            return false if @scores.empty?

            Helpers::Constants::EVALUATION_DIMENSIONS.all? { |dim| (@scores[dim] || 0) >= Helpers::Constants::AUTO_APPROVE_THRESHOLD }
          end

          def transition!(new_status)
            new_status = new_status.to_sym
            unless Helpers::Constants::PROPOSAL_STATUSES.include?(new_status)
              raise ArgumentError, "invalid status: #{new_status} (valid: #{Helpers::Constants::PROPOSAL_STATUSES.join(', ')})"
            end

            @status   = new_status
            @built_at = Time.now.utc if new_status == :passing
          end

          def self.from_h(hash)
            proposal = allocate
            proposal.instance_variable_set(:@id,             hash[:id])
            proposal.instance_variable_set(:@name,           hash[:name])
            proposal.instance_variable_set(:@module_name,    hash[:module_name])
            proposal.instance_variable_set(:@category,       hash[:category]&.to_sym)
            proposal.instance_variable_set(:@description,    hash[:description])
            proposal.instance_variable_set(:@metaphor,       hash[:metaphor])
            proposal.instance_variable_set(:@helpers,        hash[:helpers] || [])
            proposal.instance_variable_set(:@runner_methods, hash[:runner_methods] || [])
            proposal.instance_variable_set(:@rationale,      hash[:rationale])
            proposal.instance_variable_set(:@scores,         (hash[:scores] || {}).transform_keys(&:to_sym))
            proposal.instance_variable_set(:@status,         hash[:status]&.to_sym || :proposed)
            proposal.instance_variable_set(:@origin,         hash[:origin]&.to_sym || :proposer)
            proposal.instance_variable_set(:@created_at,     hash[:created_at] ? Time.parse(hash[:created_at].to_s) : Time.now.utc)
            proposal.instance_variable_set(:@evaluated_at,   hash[:evaluated_at] ? Time.parse(hash[:evaluated_at].to_s) : nil)
            proposal.instance_variable_set(:@built_at,       hash[:built_at] ? Time.parse(hash[:built_at].to_s) : nil)
            proposal
          end

          def to_h
            FIELDS.to_h { |f| [f, send(f)] }
          end
        end
      end
    end
  end
end
