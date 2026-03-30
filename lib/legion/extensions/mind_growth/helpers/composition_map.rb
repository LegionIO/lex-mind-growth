# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        module CompositionMap
          module_function

          @rules = {} # rubocop:disable ThreadSafety/MutableClassInstanceVariable
          @mutex = Mutex.new

          def add_rule(source_extension:, output_key:, target_extension:, target_method:, transform: nil, **)
            rule_id = SecureRandom.uuid
            rule = {
              id:               rule_id,
              source_extension: source_extension.to_s,
              output_key:       output_key.to_sym,
              target_extension: target_extension.to_s,
              target_method:    target_method.to_sym,
              transform:        transform
            }
            @mutex.synchronize { @rules[rule_id] = rule }
            { success: true, rule_id: rule_id }
          end

          def remove_rule(rule_id:, **)
            removed = @mutex.synchronize { @rules.delete(rule_id) }
            { success: !removed.nil?, rule_id: rule_id }
          end

          def rules_for(source_extension:, **)
            src = source_extension.to_s
            @mutex.synchronize { @rules.values.select { |r| r[:source_extension] == src } }
          end

          def all_rules
            @mutex.synchronize { @rules.values.dup }
          end

          def match_output(source_extension:, output:, **)
            src   = source_extension.to_s
            out_h = output.is_a?(Hash) ? output : {}
            rules = @mutex.synchronize { @rules.values.select { |r| r[:source_extension] == src } }

            rules.filter_map do |rule|
              key = rule[:output_key]
              next unless out_h.key?(key)

              { rule: rule, matched_value: out_h[key] }
            end
          end

          def clear!
            @mutex.synchronize { @rules.clear }
          end

          def stats
            all = @mutex.synchronize { @rules.values.dup }

            by_source = Hash.new(0)
            by_target = Hash.new(0)
            all.each do |r|
              by_source[r[:source_extension]] += 1
              by_target[r[:target_extension]] += 1
            end

            { total_rules: all.size,
              by_source:   by_source.transform_values { |v| v },
              by_target:   by_target.transform_values { |v| v } }
          end
        end
      end
    end
  end
end
