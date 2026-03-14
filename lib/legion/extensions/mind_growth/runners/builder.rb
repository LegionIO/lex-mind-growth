# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Builder
          extend self

          def build_extension(proposal_id:, base_path: nil, **)
            proposal = find_proposal(proposal_id)
            return { success: false, error: :not_found } unless proposal

            pipeline = Helpers::BuildPipeline.new(proposal)
            proposal.transition!(:building)

            # Each stage returns { success: true/false, ... }
            # Pipeline advances on success, records errors on failure
            run_stage(pipeline, :scaffold, -> { scaffold_stage(proposal, base_path) })
            run_stage(pipeline, :implement, -> { implement_stage(proposal) }) unless pipeline.failed?
            run_stage(pipeline, :test,      -> { test_stage(proposal, base_path) }) unless pipeline.failed?
            run_stage(pipeline, :validate,  -> { validate_stage(proposal, base_path) }) unless pipeline.failed?
            run_stage(pipeline, :register,  -> { register_stage(proposal) }) unless pipeline.failed?

            proposal.transition!(pipeline.complete? ? :passing : :build_failed)
            Legion::Logging.info "[mind_growth:builder] #{proposal.name}: #{pipeline.stage}" if defined?(Legion::Logging)
            { success: pipeline.complete?, pipeline: pipeline.to_h, proposal: proposal.to_h }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def build_status(proposal_id:, **)
            proposal = find_proposal(proposal_id)
            return { success: false, error: :not_found } unless proposal

            { success: true, name: proposal.name, status: proposal.status }
          end

          private

          def find_proposal(proposal_id)
            return nil unless defined?(Runners::Proposer) && Runners::Proposer.respond_to?(:get_proposal_object)

            Runners::Proposer.get_proposal_object(proposal_id)
          end

          def run_stage(pipeline, stage, callable)
            return if pipeline.stage != stage

            result = callable.call
            pipeline.advance!(result)
          end

          # Stub stages — real implementation delegates to lex-codegen and lex-exec
          def scaffold_stage(_proposal, _base_path)
            { success: true, stage: :scaffold, files: 0, message: 'scaffold requires lex-codegen' }
          end

          def implement_stage(_proposal)
            { success: true, stage: :implement, message: 'implementation requires legion-llm' }
          end

          def test_stage(_proposal, _base_path)
            { success: true, stage: :test, message: 'testing requires lex-exec' }
          end

          def validate_stage(_proposal, _base_path)
            { success: true, stage: :validate, message: 'validation requires lex-exec' }
          end

          def register_stage(_proposal)
            { success: true, stage: :register, message: 'registration requires lex-metacognition registry' }
          end
        end
      end
    end
  end
end
