# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module DreamIdeation
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          extend self

          DREAM_NOVELTY_BONUS = 0.15

          # Agenda item weight by how underrepresented the category is
          MAX_AGENDA_WEIGHT = 1.0
          MIN_AGENDA_WEIGHT = 0.1

          def generate_dream_proposals(existing_extensions: nil, max_proposals: 2, **)
            gap_result = Runners::Proposer.analyze_gaps(existing_extensions: existing_extensions)
            return { success: false, error: :gap_analysis_failed } unless gap_result[:success]

            recommendations = gap_result[:recommendations] || []
            proposals       = []

            recommendations.first(max_proposals).each do |rec|
              name   = rec.is_a?(Hash) ? rec[:name] : rec.to_s
              result = Runners::Proposer.propose_concept(
                name:        "lex-dream-#{name.to_s.downcase.gsub(/[^a-z0-9]/, '-')}",
                description: "Dream-originated proposal for #{name} cognitive capability",
                enrich:      false
              )
              next unless result[:success]

              proposal_id = result[:proposal][:id]
              proposal    = Runners::Proposer.get_proposal_object(proposal_id)
              proposal&.instance_variable_set(:@origin, :dream)

              proposals << result[:proposal]
            end

            { success: true, proposals: proposals, count: proposals.size,
              gaps_analyzed: recommendations.size }
          end

          def dream_agenda_items(existing_extensions: nil, **)
            gap_result = Runners::Proposer.analyze_gaps(existing_extensions: existing_extensions)
            return { success: false, error: :gap_analysis_failed } unless gap_result[:success]

            target = Helpers::Constants::TARGET_DISTRIBUTION
            models = gap_result[:models] || []

            coverage_by_cat = build_coverage_by_category(models)

            items = target.filter_map do |category, target_pct|
              actual_pct = coverage_by_cat[category] || 0.0
              gap        = (target_pct - actual_pct).clamp(0.0, 1.0)
              next if gap <= 0.0

              weight = ((gap / target_pct) * MAX_AGENDA_WEIGHT).clamp(MIN_AGENDA_WEIGHT, MAX_AGENDA_WEIGHT).round(3)

              { type:    :architectural_gap,
                content: { gap_name: category, model: :target_distribution, coverage: actual_pct },
                weight:  weight }
            end

            { success: true, items: items, count: items.size }
          end

          def enrich_from_dream_context(proposal_id:, dream_context: {}, **)
            proposal = Runners::Proposer.get_proposal_object(proposal_id)
            return { success: false, error: :not_found } unless proposal

            if dream_context && !dream_context.empty?
              existing  = proposal.rationale.to_s
              additions = dream_context.map { |k, v| "#{k}: #{v}" }.join('; ')
              new_rationale = existing.empty? ? additions : "#{existing}. Dream context: #{additions}"
              proposal.instance_variable_set(:@rationale, new_rationale)
              { success: true, proposal_id: proposal_id, enriched: true }
            else
              { success: true, proposal_id: proposal_id, enriched: false }
            end
          end

          private

          def build_coverage_by_category(models)
            coverage = {}
            models.each do |model|
              cat = infer_category_from_model(model[:model])
              next unless cat

              existing = coverage[cat] || 1.0
              coverage[cat] = [existing, model_coverage_fraction(model)].min
            end
            coverage
          end

          def model_coverage_fraction(model)
            total   = model[:total_required] || 1
            missing = (model[:missing] || []).size
            covered = total - missing
            total.positive? ? (covered.to_f / total).round(3) : 0.0
          end

          def infer_category_from_model(model_name)
            mapping = {
              global_workspace: :cognition,
              free_energy:      :introspection,
              dual_process:     :cognition,
              somatic_marker:   :motivation,
              working_memory:   :memory
            }
            mapping[model_name&.to_sym]
          end
        end
      end
    end
  end
end
