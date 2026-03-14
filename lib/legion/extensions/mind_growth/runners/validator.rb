# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Validator
          extend self

          def validate_proposal(proposal_id:, **)
            proposal = find_proposal(proposal_id)
            return { success: false, error: :not_found } unless proposal

            issues = []
            issues << 'missing name'        if proposal.name.nil? || proposal.name.empty?
            issues << 'missing module_name' if proposal.module_name.nil? || proposal.module_name.empty?
            issues << 'missing category'    unless Helpers::Constants::CATEGORIES.include?(proposal.category&.to_sym)
            issues << 'missing description' if proposal.description.nil? || proposal.description.empty?

            { success: issues.empty?, valid: issues.empty?, issues: issues, proposal_id: proposal_id }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def validate_scores(scores:, **)
            issues = []
            Helpers::Constants::EVALUATION_DIMENSIONS.each do |dim|
              value = scores[dim]
              issues << "missing #{dim}" if value.nil?
              issues << "#{dim} out of range (#{value})" if value && (value < 0.0 || value > 1.0)
            end
            { success: issues.empty?, valid: issues.empty?, issues: issues }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def validate_fitness(extensions:, **)
            ranked  = Helpers::FitnessEvaluator.rank(extensions)
            prune   = Helpers::FitnessEvaluator.prune_candidates(extensions)
            improve = Helpers::FitnessEvaluator.improvement_candidates(extensions)
            { success: true, ranked: ranked, prune_candidates: prune.size, improvement_candidates: improve.size }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          private

          def find_proposal(proposal_id)
            return nil unless defined?(Runners::Proposer) && Runners::Proposer.respond_to?(:get_proposal_object)

            Runners::Proposer.get_proposal_object(proposal_id)
          end
        end
      end
    end
  end
end
