# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module RiskAssessor
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          extend self

          HIGH_BLAST_CATEGORIES   = %i[safety coordination].freeze
          MEDIUM_BLAST_CATEGORIES = %i[cognition].freeze
          HOT_PATH_CATEGORIES     = %i[perception memory].freeze

          def assess_risk(proposal_id:, **)
            proposal = Runners::Proposer.get_proposal_object(proposal_id)
            return { success: false, error: :not_found } unless proposal

            dimensions = evaluate_dimensions(proposal)
            tier       = calculate_tier(dimensions)
            recommendation = Helpers::Constants::RISK_RECOMMENDATIONS[tier]

            { success: true, proposal_id: proposal_id, risk_tier: tier,
              dimensions: dimensions, recommendation: recommendation }
          end

          def risk_summary(proposals: nil, **)
            ids = if proposals
                    Array(proposals).map { |p| p.is_a?(Hash) ? p[:id] : p.to_s }
                  else
                    Runners::Proposer.list_proposals(limit: 100)[:proposals].map { |p| p[:id] }
                  end

            results = ids.filter_map do |id|
              result = assess_risk(proposal_id: id)
              next unless result[:success]

              result
            end

            grouped = Helpers::Constants::RISK_TIERS.to_h { |tier| [tier, []] }
            results.each { |r| grouped[r[:risk_tier]] << r }

            { success: true, total: results.size, by_tier: grouped }
          end

          private

          def evaluate_dimensions(proposal)
            helper_count  = Array(proposal.helpers).size
            category      = proposal.category.to_sym

            {
              complexity:         complexity_level(helper_count, Array(proposal.runner_methods).size),
              blast_radius:       blast_radius_level(category),
              reversibility:      :high,
              performance_impact: performance_impact_level(category)
            }
          end

          def complexity_level(helper_count, runner_count)
            total = helper_count + runner_count
            if total >= 7
              :high
            elsif total >= 4
              :medium
            else
              :low
            end
          end

          def blast_radius_level(category)
            if HIGH_BLAST_CATEGORIES.include?(category)
              :high
            elsif MEDIUM_BLAST_CATEGORIES.include?(category)
              :medium
            else
              :low
            end
          end

          def performance_impact_level(category)
            HOT_PATH_CATEGORIES.include?(category) ? :medium : :low
          end

          def calculate_tier(dimensions)
            # Reversibility is a positive attribute (high = easily reversed) — exclude from risk calc
            risk_values = dimensions.except(:reversibility).values

            if risk_values.include?(:critical)
              :critical
            elsif risk_values.include?(:high)
              :high
            elsif risk_values.include?(:medium)
              :medium
            else
              :low
            end
          end
        end
      end
    end
  end
end
