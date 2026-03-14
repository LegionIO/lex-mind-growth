# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Analyzer
          extend self

          def cognitive_profile(existing_extensions: nil, **)
            extensions = existing_extensions || current_extensions
            gap_data   = Helpers::CognitiveModels.gap_analysis(extensions)
            {
              success:          true,
              total_extensions: extensions.size,
              model_coverage:   gap_data,
              overall_coverage: (gap_data.sum { |g| g[:coverage] } / gap_data.size.to_f).round(2)
            }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def identify_weak_links(extensions: [], **)
            weak = extensions.select { |e| Helpers::FitnessEvaluator.fitness(e) < Helpers::Constants::IMPROVEMENT_THRESHOLD }
            { success: true, weak_links: Helpers::FitnessEvaluator.rank(weak), count: weak.size }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def recommend_priorities(existing_extensions: nil, **)
            gaps = Helpers::CognitiveModels.recommend_from_gaps(
              Helpers::CognitiveModels.gap_analysis(existing_extensions || current_extensions)
            )
            { success: true, priorities: gaps.first(10), rationale: 'Based on cognitive model gap analysis' }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          private

          def current_extensions
            if defined?(Legion::Extensions::Metacognition::Helpers::Constants::SUBSYSTEMS)
              Legion::Extensions::Metacognition::Helpers::Constants::SUBSYSTEMS
            else
              []
            end
          end
        end
      end
    end
  end
end
