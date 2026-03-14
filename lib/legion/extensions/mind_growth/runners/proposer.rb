# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Proposer
          extend self

          def analyze_gaps(existing_extensions: nil, **)
            extensions    = existing_extensions || current_extensions
            analysis      = Helpers::CognitiveModels.gap_analysis(extensions)
            recommendations = Helpers::CognitiveModels.recommend_from_gaps(analysis)
            Legion::Logging.debug "[mind_growth:proposer] gap analysis: #{recommendations.size} recommendations" if defined?(Legion::Logging)
            { success: true, models: analysis, recommendations: recommendations.first(10) }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def propose_concept(category: nil, description: nil, name: nil, **)
            cat      = category&.to_sym || suggest_category
            proposal = Helpers::ConceptProposal.new(
              name:        name || "lex-#{SecureRandom.hex(4)}",
              module_name: name ? name.split('-').map(&:capitalize).join : 'Unnamed',
              category:    cat,
              description: description || "Proposed #{cat} extension",
              origin:      :manual
            )
            proposal_store.store(proposal)
            Legion::Logging.info "[mind_growth:proposer] proposed: #{proposal.name} (#{cat})" if defined?(Legion::Logging)
            { success: true, proposal: proposal.to_h }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def evaluate_proposal(proposal_id:, scores: nil, **)
            proposal = proposal_store.get(proposal_id)
            return { success: false, error: :not_found } unless proposal

            eval_scores = scores || default_scores
            proposal.evaluate!(eval_scores)
            Legion::Logging.info "[mind_growth:proposer] evaluated #{proposal.name}: #{proposal.status}" if defined?(Legion::Logging)
            { success: true, proposal: proposal.to_h, approved: proposal.status == :approved }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def list_proposals(status: nil, limit: 20, **)
            proposals = status ? proposal_store.by_status(status) : proposal_store.recent(limit: limit)
            { success: true, proposals: proposals.map(&:to_h), count: proposals.size }
          end

          def proposal_stats(**)
            { success: true, stats: proposal_store.stats }
          end

          def get_proposal_object(id)
            proposal_store.get(id)
          end

          private

          def proposal_store
            @proposal_store ||= Helpers::ProposalStore.new
          end

          def current_extensions
            if defined?(Legion::Extensions::Metacognition::Helpers::Constants::SUBSYSTEMS)
              Legion::Extensions::Metacognition::Helpers::Constants::SUBSYSTEMS
            else
              []
            end
          end

          def suggest_category
            dist = Helpers::Constants::TARGET_DISTRIBUTION
            # Pick the most underrepresented category
            dist.min_by { |_, target| target }[0]
          end

          def default_scores
            Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.7] }
          end
        end
      end
    end
  end
end
