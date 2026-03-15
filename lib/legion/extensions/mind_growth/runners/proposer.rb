# frozen_string_literal: true

require 'json'

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

          def propose_concept(category: nil, description: nil, name: nil, enrich: true, **)
            cat          = category&.to_sym || suggest_category
            gem_name     = name || "lex-#{SecureRandom.hex(4)}"
            mod_name     = derive_module_name(gem_name)
            desc         = description || "Proposed #{cat} extension"

            enrichment = enrich ? enrich_proposal(gem_name, cat, desc) : {}

            proposal = Helpers::ConceptProposal.new(
              name:           gem_name,
              module_name:    mod_name,
              category:       cat,
              description:    desc,
              helpers:        enrichment[:helpers] || [],
              runner_methods: enrichment[:runner_methods] || [],
              metaphor:       enrichment[:metaphor],
              rationale:      enrichment[:rationale],
              origin:         :manual
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

            eval_scores = scores || score_with_llm(proposal) || default_scores
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

          def derive_module_name(gem_name)
            gem_name.to_s.sub(/\Alex-/, '').split('-').map(&:capitalize).join
          end

          def suggest_category
            target = Helpers::Constants::TARGET_DISTRIBUTION
            actual = category_distribution
            # Pick the category with the largest gap between target and actual proportion
            target.max_by { |cat, pct| pct - (actual[cat] || 0.0) }[0]
          end

          def category_distribution
            proposals = proposal_store.all
            return {} if proposals.empty?

            total = proposals.size.to_f
            proposals.group_by(&:category).transform_values { |v| v.size / total }
          end

          def enrich_proposal(name, category, description)
            return {} unless llm_available?

            response = Legion::LLM.chat.ask(enrichment_prompt(name, category, description))
            parse_enrichment(response.content)
          rescue StandardError => e
            Legion::Logging.debug "[mind_growth:proposer] LLM enrichment failed: #{e.message}" if defined?(Legion::Logging)
            {}
          end

          def enrichment_prompt(name, category, description)
            <<~PROMPT
              Design a LegionIO cognitive extension called "#{name}" in the #{category} category.
              Description: #{description}

              Return a JSON object (no markdown fencing) with these keys:
              - "metaphor": a one-sentence metaphor for how this extension works
              - "rationale": why this extension is needed (one sentence)
              - "helpers": array of objects with "name" (snake_case) and "methods" (array of objects with "name" and "params" array)
              - "runner_methods": array of objects with "name" (snake_case), "params" (array of strings), and "returns" (description string)

              Keep it focused: 1-2 helpers, 2-4 runner methods. Use in-memory state patterns.
            PROMPT
          end

          def parse_enrichment(content)
            cleaned = content.gsub(/```(?:json)?\s*\n?/, '').strip
            data = ::JSON.parse(cleaned, symbolize_names: true)
            {
              metaphor:       data[:metaphor],
              rationale:      data[:rationale],
              helpers:        Array(data[:helpers]).map { |h| { name: h[:name].to_s, methods: Array(h[:methods]) } },
              runner_methods: Array(data[:runner_methods]).map do |r|
                { name: r[:name].to_s, params: Array(r[:params]).map(&:to_s), returns: r[:returns].to_s }
              end
            }
          rescue ::JSON::ParserError, NoMethodError
            {}
          end

          def llm_available?
            defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
          end

          def score_with_llm(proposal)
            return nil unless llm_available?

            response = Legion::LLM.chat.ask(scoring_prompt(proposal))
            parse_scores(response.content)
          rescue StandardError => e
            Legion::Logging.debug "[mind_growth:proposer] LLM scoring failed: #{e.message}" if defined?(Legion::Logging)
            nil
          end

          def scoring_prompt(proposal)
            <<~PROMPT
              Score this proposed LegionIO cognitive extension on five dimensions.
              Each score must be a float between 0.0 and 1.0.

              Extension: #{proposal.name}
              Category: #{proposal.category}
              Description: #{proposal.description}
              #{"Metaphor: #{proposal.metaphor}" if proposal.metaphor}
              #{"Rationale: #{proposal.rationale}" if proposal.rationale}
              Helpers: #{proposal.helpers.map { |h| h[:name] }.join(', ').then { |s| s.empty? ? 'none' : s }}
              Runner methods: #{proposal.runner_methods.map { |r| r[:name] }.join(', ').then { |s| s.empty? ? 'none' : s }}

              Scoring dimensions:
              - novelty: How unique is this extension relative to existing cognitive capabilities?
              - fit: How well does it fill a gap in the current extension ecosystem?
              - cognitive_value: How much does it add to the cognitive architecture?
              - implementability: How feasible is it to implement with current infrastructure?
              - composability: How well does it compose with other extensions?

              Return ONLY a JSON object (no markdown fencing) with these five keys and float values:
              {"novelty": 0.0, "fit": 0.0, "cognitive_value": 0.0, "implementability": 0.0, "composability": 0.0}
            PROMPT
          end

          def parse_scores(content)
            cleaned = content.gsub(/```(?:json)?\s*\n?/, '').strip
            data = ::JSON.parse(cleaned, symbolize_names: true)
            Helpers::Constants::EVALUATION_DIMENSIONS.to_h do |dim|
              val = data[dim]
              return nil unless val.is_a?(Numeric)

              [dim, val.to_f.clamp(0.0, 1.0)]
            end
          rescue ::JSON::ParserError, NoMethodError
            nil
          end

          def default_scores
            Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.7] }
          end
        end
      end
    end
  end
end
