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

          def to_h
            FIELDS.to_h { |f| [f, send(f)] }
          end
        end
      end
    end
  end
end
