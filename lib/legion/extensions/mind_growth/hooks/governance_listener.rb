# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Hooks
        module GovernanceListener
          module_function

          def register
            return unless defined?(Legion::Events)

            Legion::Events.on('governance.quorum_reached') do |event|
              next unless event[:verdict] == :approved

              Runners::Governance.governance_resolved(proposal_id: event[:proposal_id])
            end
          end
        end
      end
    end
  end
end
