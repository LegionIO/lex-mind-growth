# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Composer
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          extend self

          # Category adjacency used for heuristic suggestions
          CATEGORY_FLOW = [
            %i[perception cognition],
            %i[cognition memory],
            %i[cognition introspection],
            %i[memory cognition],
            %i[introspection safety],
            %i[motivation cognition],
            %i[cognition communication],
            %i[communication coordination]
          ].freeze

          def add_composition(source_extension:, output_key:, target_extension:, target_method:,
                              transform: nil, **)
            Helpers::CompositionMap.add_rule(
              source_extension: source_extension,
              output_key:       output_key,
              target_extension: target_extension,
              target_method:    target_method,
              transform:        transform
            )
          end

          def remove_composition(rule_id:, **)
            result = Helpers::CompositionMap.remove_rule(rule_id: rule_id)
            { success: result[:success] }
          end

          def evaluate_output(source_extension:, output:, **)
            matches = Helpers::CompositionMap.match_output(
              source_extension: source_extension,
              output:           output
            )

            dispatches = matches.map do |match|
              rule  = match[:rule]
              value = match[:matched_value]
              input = rule[:transform] ? rule[:transform].call(value) : value

              { target_extension: rule[:target_extension],
                target_method:    rule[:target_method],
                input:            input }
            end

            { success: true, dispatches: dispatches, count: dispatches.size }
          end

          def composition_stats(**)
            { success: true, **Helpers::CompositionMap.stats }
          end

          def suggest_compositions(extensions:, **)
            exts = Array(extensions)

            return suggest_with_llm(exts) if defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?

            suggestions = heuristic_suggestions(exts)
            { success: true, suggestions: suggestions, count: suggestions.size }
          end

          def list_compositions(**)
            rules = Helpers::CompositionMap.all_rules
            { success: true, rules: rules, count: rules.size }
          end

          private

          def heuristic_suggestions(extensions)
            ext_by_category = {}
            extensions.each do |ext|
              cat = (ext[:category] || :cognition).to_sym
              (ext_by_category[cat] ||= []) << ext
            end

            suggestions = []
            CATEGORY_FLOW.each do |src_cat, tgt_cat|
              src_exts = ext_by_category[src_cat] || []
              tgt_exts = ext_by_category[tgt_cat] || []

              src_exts.each do |src|
                tgt_exts.each do |tgt|
                  suggestions << {
                    source_extension: src[:name] || src[:extension_name],
                    output_key:       :result,
                    target_extension: tgt[:name] || tgt[:extension_name],
                    target_method:    :process,
                    rationale:        "#{src_cat} -> #{tgt_cat} flow"
                  }
                end
              end
            end

            suggestions
          end

          def suggest_with_llm(extensions)
            suggestions = heuristic_suggestions(extensions)
            { success: true, suggestions: suggestions, count: suggestions.size }
          rescue StandardError => _e
            { success: true, suggestions: [], count: 0 }
          end
        end
      end
    end
  end
end
