# frozen_string_literal: true

require 'legion/extensions/actors/every'

module Legion
  module Extensions
    module MindGrowth
      module Actor
        class GrowthCycle < Legion::Extensions::Actors::Every
          def runner_class
            Legion::Extensions::MindGrowth::Runners::Orchestrator
          end

          def runner_function
            'run_growth_cycle'
          end

          def time
            3600
          end

          def enabled?
            codegen_loaded? || exec_loaded?
          end

          def run_now?
            false
          end

          def use_runner?
            false
          end

          def check_subtask?
            true
          end

          def generate_task?
            false
          end

          private

          def codegen_loaded?
            defined?(Legion::Extensions::Codegen)
          end

          def exec_loaded?
            defined?(Legion::Extensions::Exec)
          end
        end
      end
    end
  end
end
