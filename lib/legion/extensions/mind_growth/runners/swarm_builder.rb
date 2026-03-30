# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module SwarmBuilder
          extend self

          ACTIVITY_ROLES = {
            concept_exploration: %i[finder reviewer coordinator],
            parallel_build:      %i[fixer validator coordinator],
            adversarial_review:  %i[reviewer fixer coordinator],
            integration_sweep:   %i[validator fixer coordinator]
          }.freeze

          CHARTER_TYPES = ACTIVITY_ROLES.keys.freeze

          def create_build_swarm(charter_type:, objective:, proposal_ids: [], **)
            return { success: false, reason: :invalid_charter_type } unless CHARTER_TYPES.include?(charter_type.to_sym)

            return { success: false, reason: :swarm_unavailable } unless swarm_available?

            charter_type_sym = charter_type.to_sym
            roles = ACTIVITY_ROLES[charter_type_sym]

            result = Legion::Extensions::Swarm::Runners::Swarm.create_swarm(
              name:      "mind-growth-#{charter_type_sym}",
              objective: objective,
              roles:     roles
            )

            return { success: false, reason: :swarm_creation_failed } unless result[:success]

            charter_id = result[:charter][:id]

            Legion::Extensions::Swarm::Runners::Workspace.workspace_put(
              charter_id: charter_id,
              key:        'proposals',
              value:      proposal_ids,
              author:     'mind-growth'
            )

            { success: true, charter_id: charter_id, charter_type: charter_type_sym, roles: roles }
          end

          def join_build_swarm(charter_id:, agent_id:, role:, **)
            return { success: false, reason: :swarm_unavailable } unless swarm_available?

            Legion::Extensions::Swarm::Runners::Swarm.join_swarm(
              charter_id: charter_id,
              agent_id:   agent_id,
              role:       role
            )
          end

          def execute_swarm_build(charter_id:, **)
            return { success: false, reason: :swarm_unavailable } unless swarm_available?

            charter_type = resolve_charter_type(charter_id)
            return { success: false, reason: :unknown_charter_type } unless charter_type

            results = case charter_type
                      when :concept_exploration then execute_concept_exploration(charter_id)
                      when :parallel_build      then execute_parallel_build(charter_id)
                      when :adversarial_review  then execute_adversarial_review(charter_id)
                      when :integration_sweep   then execute_integration_sweep(charter_id)
                      end

            { success: true, charter_id: charter_id, charter_type: charter_type, results: Array(results) }
          end

          def complete_build_swarm(charter_id:, outcome: :success, **)
            return { success: false, reason: :swarm_unavailable } unless swarm_available?

            Legion::Extensions::Swarm::Runners::Swarm.complete_swarm(
              charter_id: charter_id,
              outcome:    outcome
            )
          end

          def swarm_build_status(charter_id:, **)
            return { success: false, reason: :swarm_unavailable } unless swarm_available?

            status_result = Legion::Extensions::Swarm::Runners::Swarm.swarm_status(charter_id: charter_id)
            workspace_result = Legion::Extensions::Swarm::Runners::Workspace.workspace_list(charter_id: charter_id)

            workspace_keys = workspace_result[:success] ? workspace_result[:entries].keys : []

            { success: true, status: status_result[:status], workspace_keys: workspace_keys }
          end

          def active_build_swarms(**)
            return { success: false, reason: :swarm_unavailable } unless swarm_available?

            all_swarms = Legion::Extensions::Swarm::Runners::Swarm.active_swarms
            swarms = Array(all_swarms[:swarms]).select { |s| mind_growth_swarm?(s) }

            { success: true, swarms: swarms, count: swarms.size }
          end

          private

          def swarm_available?
            defined?(Legion::Extensions::Swarm::Runners::Swarm)
          end

          def mind_growth_swarm?(swarm)
            name = swarm[:name].to_s
            name.start_with?('mind-growth-')
          end

          def resolve_charter_type(charter_id)
            result = Legion::Extensions::Swarm::Runners::Swarm.swarm_status(charter_id: charter_id)
            return nil unless result[:success]

            name = result[:name].to_s
            CHARTER_TYPES.find { |ct| name.include?(ct.to_s) }
          end

          def execute_concept_exploration(charter_id)
            gaps_result = Runners::Proposer.analyze_gaps
            return [] unless gaps_result[:success]

            proposals = gaps_result[:recommendations].first(3).map do |rec|
              Runners::Proposer.propose_concept(
                name:     "lex-#{rec.to_s.tr('_', '-')}",
                category: :cognition,
                enrich:   false
              )
            end

            proposal_ids = proposals.filter_map { |p| p.dig(:proposal, :id) if p[:success] }

            Legion::Extensions::Swarm::Runners::Workspace.workspace_put(
              charter_id: charter_id,
              key:        'explored_proposals',
              value:      proposal_ids,
              author:     'mind-growth'
            )

            proposals
          end

          def execute_parallel_build(charter_id)
            proposals_entry = Legion::Extensions::Swarm::Runners::Workspace.workspace_get(
              charter_id: charter_id,
              key:        'proposals'
            )

            proposal_ids = proposals_entry[:success] ? Array(proposals_entry.dig(:entry, :value)) : []
            return [] if proposal_ids.empty?

            results = proposal_ids.map do |proposal_id|
              Runners::Builder.build_extension(proposal_id: proposal_id)
            end

            Legion::Extensions::Swarm::Runners::Workspace.workspace_put(
              charter_id: charter_id,
              key:        'build_results',
              value:      results.map { |r| { success: r[:success] } },
              author:     'mind-growth'
            )

            results
          end

          def execute_adversarial_review(charter_id)
            proposals_entry = Legion::Extensions::Swarm::Runners::Workspace.workspace_get(
              charter_id: charter_id,
              key:        'proposals'
            )

            proposal_ids = proposals_entry[:success] ? Array(proposals_entry.dig(:entry, :value)) : []
            return [] if proposal_ids.empty?

            results = proposal_ids.map do |proposal_id|
              Runners::Validator.validate_proposal(proposal_id: proposal_id)
            end

            Legion::Extensions::Swarm::Runners::Workspace.workspace_put(
              charter_id: charter_id,
              key:        'review_results',
              value:      results.map { |r| { success: r[:success], valid: r[:valid] } },
              author:     'mind-growth'
            )

            results
          end

          def execute_integration_sweep(charter_id)
            proposals_entry = Legion::Extensions::Swarm::Runners::Workspace.workspace_get(
              charter_id: charter_id,
              key:        'proposals'
            )

            proposal_ids = proposals_entry[:success] ? Array(proposals_entry.dig(:entry, :value)) : []
            return [] if proposal_ids.size < 2

            results = []
            proposal_ids.each_cons(2) do |id_a, id_b|
              ext_a = { name: id_a }
              ext_b = { name: id_b }
              results << Runners::IntegrationTester.test_cross_extension(extension_a: ext_a, extension_b: ext_b)
            end

            results
          end
        end
      end
    end
  end
end
