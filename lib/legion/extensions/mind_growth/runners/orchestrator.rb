# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Orchestrator
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          extend self

          def run_growth_cycle(existing_extensions: nil, base_path: nil, max_proposals: 3, force: false, **)
            trace = { started_at: Time.now.utc, steps: [] }

            # Step 1: Analyze gaps in the cognitive ecosystem
            gaps = Runners::Analyzer.recommend_priorities(existing_extensions: existing_extensions)
            trace[:steps] << { step: :analyze, result: gaps }
            return failure(trace, 'gap analysis failed') unless gaps[:success]
            return failure(trace, 'no priorities identified') if gaps[:priorities].empty?

            # Step 2: Propose concepts for the top priorities
            proposals = propose_from_priorities(gaps[:priorities], max_proposals)
            trace[:steps] << { step: :propose, count: proposals.size, proposals: proposals.map { |p| p[:proposal][:id] } }
            return failure(trace, 'no proposals created') if proposals.empty?

            # Step 3: Evaluate each proposal
            classify_and_trace_evaluations(evaluate_proposals(proposals), trace)

            # Step 4: Build — auto-approved build immediately; regular approved only when forced
            result = execute_build_step(trace, base_path, force)
            return result if result

            trace[:completed_at] = Time.now.utc
            trace[:duration_ms] = ((trace[:completed_at] - trace[:started_at]) * 1000).round

            log_cycle_summary(trace)
            { success: true, trace: trace }
          rescue StandardError => e
            { success: false, error: e.message, trace: trace }
          end

          REQUIREMENT_CATEGORIES = {
            attention:           :perception,
            global_workspace:    :cognition,
            broadcasting:        :communication,
            working_memory:      :memory,
            consciousness:       :introspection,
            prediction:          :cognition,
            free_energy:         :cognition,
            predictive_coding:   :cognition,
            belief_revision:     :cognition,
            active_inference:    :cognition,
            error_monitoring:    :safety,
            intuition:           :cognition,
            dual_process:        :cognition,
            inhibition:          :safety,
            executive_function:  :cognition,
            cognitive_control:   :cognition,
            emotion:             :introspection,
            somatic_marker:      :introspection,
            interoception:       :perception,
            appraisal:           :introspection,
            embodied_simulation: :perception,
            episodic_buffer:     :memory,
            cognitive_load:      :introspection
          }.freeze

          def growth_status(**)
            stats = Runners::Proposer.proposal_stats
            profile = Runners::Analyzer.cognitive_profile

            { success:        true,
              proposals:      stats[:stats],
              coverage:       profile[:overall_coverage],
              model_coverage: profile[:model_coverage]&.map { |m| { model: m[:model], coverage: m[:coverage] } } }
          end

          private

          def propose_from_priorities(priorities, max)
            priorities.first(max).filter_map do |priority_name|
              name = "lex-#{priority_name.to_s.tr('_', '-')}"
              result = Runners::Proposer.propose_concept(
                name:        name,
                category:    category_for_requirement(priority_name),
                description: "Cognitive extension for #{priority_name} (recommended by gap analysis)"
              )
              result if result[:success]
            end
          end

          def category_for_requirement(requirement)
            REQUIREMENT_CATEGORIES[requirement.to_sym]
          end

          def classify_and_trace_evaluations(evaluated, trace)
            auto_approved = evaluated.select { |e| e[:auto_approved] }
            approved      = evaluated.select { |e| e[:approved] && !e[:auto_approved] }
            rejected      = evaluated.reject { |e| e[:approved] }
            trace[:steps] << { step: :evaluate, evaluated: evaluated.size,
                               auto_approved: auto_approved.size,
                               approved: approved.size,
                               rejected: rejected.size,
                               held_for_review: approved.size }
          end

          def execute_build_step(trace, base_path, force)
            eval_step = trace[:steps].find { |s| s[:step] == :evaluate }
            held_count = eval_step[:approved]

            # Collect buildable proposals from the store
            all_evaluated = proposal_ids_from_trace(trace)
            buildable = select_buildable(all_evaluated, force)

            if buildable.empty? && held_count.positive?
              trace[:steps] << { step: :build, attempted: 0, succeeded: 0, failed: 0,
                                 held: held_count,
                                 message: 'approved proposals held for governance review' }
              nil
            elsif buildable.empty?
              failure(trace, 'no proposals approved')
            else
              builds = build_proposals(buildable, base_path)
              trace[:steps] << { step: :build, attempted: builds.size,
                                 succeeded: builds.count { |b| b[:success] },
                                 failed:    builds.count { |b| !b[:success] },
                                 held:      force ? 0 : held_count }
              nil
            end
          end

          def proposal_ids_from_trace(trace)
            propose_step = trace[:steps].find { |s| s[:step] == :propose }
            propose_step[:proposals]
          end

          def select_buildable(proposal_ids, force)
            proposal_ids.filter_map do |id|
              proposal = Runners::Proposer.get_proposal_object(id)
              next unless proposal&.status == :approved

              { proposal: proposal.to_h } if force || proposal.auto_approvable?
            end
          end

          def evaluate_proposals(proposals)
            proposals.filter_map do |p|
              result = Runners::Proposer.evaluate_proposal(proposal_id: p[:proposal][:id])
              result if result[:success]
            end
          end

          def build_proposals(proposals, base_path)
            proposals.map do |a|
              Runners::Builder.build_extension(
                proposal_id: a[:proposal][:id],
                base_path:   base_path
              )
            end
          end

          def failure(trace, reason)
            trace[:completed_at] = Time.now.utc
            trace[:duration_ms] = ((trace[:completed_at] - trace[:started_at]) * 1000).round
            trace[:failure_reason] = reason
            { success: false, trace: trace, error: reason }
          end

          def log_cycle_summary(trace)
            build_step = trace[:steps].find { |s| s[:step] == :build }
            succeeded = build_step ? build_step[:succeeded] : 0
            log.info "[mind_growth:orchestrator] cycle complete: #{succeeded} extensions built"
          end
        end
      end
    end
  end
end
