# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Orchestrator
          extend self

          def run_growth_cycle(existing_extensions: nil, base_path: nil, max_proposals: 3, **)
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
            evaluated = evaluate_proposals(proposals)
            trace[:steps] << { step: :evaluate, evaluated: evaluated.size,
                               approved: evaluated.count { |e| e[:approved] },
                               rejected: evaluated.count { |e| !e[:approved] } }

            approved = evaluated.select { |e| e[:approved] }
            return failure(trace, 'no proposals approved') if approved.empty?

            # Step 4: Build approved proposals
            builds = build_approved(approved, base_path)
            trace[:steps] << { step: :build, attempted: builds.size,
                               succeeded: builds.count { |b| b[:success] },
                               failed: builds.count { |b| !b[:success] } }

            trace[:completed_at] = Time.now.utc
            trace[:duration_ms] = ((trace[:completed_at] - trace[:started_at]) * 1000).round

            log_cycle_summary(trace)
            { success: true, trace: trace }
          rescue StandardError => e
            { success: false, error: e.message, trace: trace }
          end

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
                description: "Cognitive extension for #{priority_name} (recommended by gap analysis)"
              )
              result if result[:success]
            end
          end

          def evaluate_proposals(proposals)
            proposals.filter_map do |p|
              result = Runners::Proposer.evaluate_proposal(proposal_id: p[:proposal][:id])
              result if result[:success]
            end
          end

          def build_approved(approved, base_path)
            approved.filter_map do |a|
              result = Runners::Builder.build_extension(
                proposal_id: a[:proposal][:id],
                base_path:   base_path
              )
              result
            end
          end

          def failure(trace, reason)
            trace[:completed_at] = Time.now.utc
            trace[:duration_ms] = ((trace[:completed_at] - trace[:started_at]) * 1000).round
            trace[:failure_reason] = reason
            { success: false, trace: trace, error: reason }
          end

          def log_cycle_summary(trace)
            return unless defined?(Legion::Logging)

            build_step = trace[:steps].find { |s| s[:step] == :build }
            succeeded = build_step ? build_step[:succeeded] : 0
            Legion::Logging.info "[mind_growth:orchestrator] cycle complete: #{succeeded} extensions built"
          end
        end
      end
    end
  end
end
