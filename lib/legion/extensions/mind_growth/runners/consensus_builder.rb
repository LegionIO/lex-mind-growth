# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module ConsensusBuilder
          extend self

          CONSENSUS_THRESHOLD               = 0.67
          DISAGREEMENT_ESCALATION_THRESHOLD = 0.5
          DECIDED_CONSENSUSES               = %i[approved rejected].freeze

          def propose_to_swarm(charter_id:, proposal_id:, proposer_agent_id:, **)
            if swarm_available?
              pending = fetch_pending_proposals(charter_id)
              pending << { proposal_id: proposal_id, proposer_agent_id: proposer_agent_id,
                           proposed_at: Time.now.utc.iso8601 }

              Legion::Extensions::Swarm::Runners::Workspace.workspace_put(
                charter_id: charter_id,
                key:        'pending_proposals',
                value:      pending,
                author:     'mind-growth'
              )
            else
              Runners::Governance.submit_proposal(proposal_id: proposal_id)
            end

            { success: true, proposal_id: proposal_id }
          end

          def vote_in_swarm(charter_id:, proposal_id:, voter_agent_id:, vote:, rationale: nil, **)
            vote_sym = vote.to_sym
            return { success: false, reason: :invalid_vote } unless %i[approve reject].include?(vote_sym)

            if swarm_available?
              votes = fetch_votes(charter_id, proposal_id)
              votes << { voter_agent_id: voter_agent_id, vote: vote_sym, rationale: rationale,
                         cast_at: Time.now.utc.iso8601 }

              Legion::Extensions::Swarm::Runners::Workspace.workspace_put(
                charter_id: charter_id,
                key:        "votes:#{proposal_id}",
                value:      votes,
                author:     'mind-growth'
              )
            end

            { success: true, vote: vote_sym }
          end

          def tally_swarm_votes(charter_id:, proposal_id:, **)
            votes = fetch_votes(charter_id, proposal_id)

            approve_count = votes.count { |v| v[:vote].to_s == 'approve' }
            reject_count  = votes.count { |v| v[:vote].to_s == 'reject' }
            total         = votes.size

            consensus = if !total.zero? && (approve_count.to_f / total) >= CONSENSUS_THRESHOLD
                          :approved
                        elsif !total.zero? && (reject_count.to_f / total) >= CONSENSUS_THRESHOLD
                          :rejected
                        else
                          :no_consensus
                        end

            { success: true, approve_count: approve_count, reject_count: reject_count,
              total: total, consensus: consensus, threshold: CONSENSUS_THRESHOLD }
          end

          def resolve_disagreement(charter_id:, proposal_id:, **)
            tally = tally_swarm_votes(charter_id: charter_id, proposal_id: proposal_id)

            resolution = if tally[:total].positive? &&
                            (tally[:approve_count].to_f / tally[:total]) >= DISAGREEMENT_ESCALATION_THRESHOLD &&
                            (tally[:approve_count].to_f / tally[:total]) < CONSENSUS_THRESHOLD
                           :escalated_to_human
                         else
                           :rejected_by_default
                         end

            { success: true, resolution: resolution }
          end

          def consensus_summary(charter_id:, **)
            proposals = fetch_pending_proposals(charter_id)

            decided = []
            pending = []

            proposals.each do |entry|
              pid = entry[:proposal_id]
              tally = tally_swarm_votes(charter_id: charter_id, proposal_id: pid)

              record = { proposal_id: pid, consensus: tally[:consensus],
                         approve_count: tally[:approve_count], reject_count: tally[:reject_count] }

              if DECIDED_CONSENSUSES.include?(tally[:consensus])
                decided << record
              else
                pending << record
              end
            end

            { success: true, proposals: proposals, decided: decided, pending: pending }
          end

          private

          def swarm_available?
            defined?(Legion::Extensions::Swarm::Runners::Workspace)
          end

          def fetch_pending_proposals(charter_id)
            return [] unless swarm_available?

            result = Legion::Extensions::Swarm::Runners::Workspace.workspace_get(
              charter_id: charter_id,
              key:        'pending_proposals'
            )

            result[:success] ? Array(result.dig(:entry, :value)) : []
          end

          def fetch_votes(charter_id, proposal_id)
            return [] unless swarm_available?

            result = Legion::Extensions::Swarm::Runners::Workspace.workspace_get(
              charter_id: charter_id,
              key:        "votes:#{proposal_id}"
            )

            result[:success] ? Array(result.dig(:entry, :value)) : []
          end
        end
      end
    end
  end
end
