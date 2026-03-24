# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Governance
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          extend self

          VOTE_VALUES = %i[approve reject].freeze

          def submit_proposal(proposal_id:, **)
            proposal = Runners::Proposer.get_proposal_object(proposal_id)
            return { success: false, error: :not_found } unless proposal

            return { success: false, error: :invalid_status, current_status: proposal.status } unless %i[proposed evaluating].include?(proposal.status)

            proposal.transition!(:evaluating)
            { success: true, proposal_id: proposal_id, status: :evaluating }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def vote_on_proposal(proposal_id:, vote:, agent_id: 'default', rationale: nil, **)
            vote_sym = vote.to_sym
            return { success: false, error: :invalid_vote } unless VOTE_VALUES.include?(vote_sym)

            votes_mutex.synchronize do
              votes_store[proposal_id] ||= []
              votes_store[proposal_id] << { vote: vote_sym, agent_id: agent_id.to_s, rationale: rationale,
                                            cast_at: Time.now.utc }
            end

            { success: true, proposal_id: proposal_id, vote: vote_sym, agent_id: agent_id.to_s }
          end

          def tally_votes(proposal_id:, **)
            ballots = votes_mutex.synchronize { (votes_store[proposal_id] || []).dup }

            approve_count = ballots.count { |b| b[:vote] == :approve }
            reject_count  = ballots.count { |b| b[:vote] == :reject }
            total         = ballots.size

            verdict = if total < Helpers::Constants::QUORUM
                        :pending
                      elsif approve_count > reject_count
                        :approved
                      else
                        :rejected
                      end

            { success: true, proposal_id: proposal_id, approve_count: approve_count,
              reject_count: reject_count, total: total, verdict: verdict }
          end

          def approve_proposal(proposal_id:, _reason: nil, **)
            proposal = Runners::Proposer.get_proposal_object(proposal_id)
            return { success: false, error: :not_found } unless proposal

            proposal.transition!(:approved)
            { success: true, proposal_id: proposal_id, status: :approved }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def reject_proposal(proposal_id:, reason: nil, **)
            proposal = Runners::Proposer.get_proposal_object(proposal_id)
            return { success: false, error: :not_found } unless proposal

            proposal.transition!(:rejected)
            { success: true, proposal_id: proposal_id, status: :rejected, reason: reason }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def governance_stats(**)
            all_votes = votes_mutex.synchronize { votes_store.dup }

            total_votes = all_votes.values.sum(&:size)
            proposals_with_votes = all_votes.size

            vote_summary = all_votes.transform_values do |ballots|
              {
                approve: ballots.count { |b| b[:vote] == :approve },
                reject:  ballots.count { |b| b[:vote] == :reject },
                total:   ballots.size
              }
            end

            proposal_stats = Runners::Proposer.proposal_stats
            by_status = proposal_stats[:stats][:by_status]

            governance_breakdown = Helpers::Constants::GOVERNANCE_STATUSES.to_h do |s|
              [s, by_status[s] || 0]
            end

            {
              success:              true,
              total_votes:          total_votes,
              proposals_with_votes: proposals_with_votes,
              vote_summary:         vote_summary,
              governance_breakdown: governance_breakdown
            }
          end

          private

          def votes_store
            @votes_store ||= {}
          end

          def votes_mutex
            @votes_mutex ||= Mutex.new
          end
        end
      end
    end
  end
end
