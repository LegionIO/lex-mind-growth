# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module CompetitiveEvolver
          extend self

          COMPETITION_STATUSES  = %i[pending active evaluating decided cancelled].freeze
          ACTIVE_STATUSES       = %i[pending active evaluating].freeze
          MIN_TRIAL_ITERATIONS = 10

          def create_competition(gap:, proposal_ids:, **)
            ids = Array(proposal_ids)
            return { success: false, reason: :insufficient_competitors } if ids.size < 2

            competition_id = SecureRandom.uuid
            competition = {
              id:           competition_id,
              gap:          gap.to_s,
              proposal_ids: ids,
              status:       :pending,
              trials:       {},
              winner:       nil,
              created_at:   Time.now.utc,
              decided_at:   nil
            }

            store_competition(competition)
            { success: true, competition_id: competition_id, gap: gap.to_s, competitors: ids.size }
          end

          def run_trial(competition_id:, extension:, iterations: MIN_TRIAL_ITERATIONS, **)
            competition = get_competition(competition_id)
            return { success: false, reason: :not_found } unless competition
            return { success: false, reason: :already_decided } if competition[:status] == :decided

            transition_competition(competition_id, :active) if competition[:status] == :pending

            fitness = Helpers::FitnessEvaluator.fitness(extension)
            name = extension[:name] || extension[:extension_name]

            trial = {
              extension_name: name,
              fitness:        fitness,
              error_rate:     extension[:error_rate] || 0.0,
              avg_latency_ms: extension[:avg_latency_ms] || 0,
              invocations:    extension[:invocation_count] || 0,
              iterations:     iterations,
              recorded_at:    Time.now.utc
            }

            record_trial(competition_id, name, trial)
            { success: true, competition_id: competition_id, trial: trial }
          end

          def compare_results(competition_id:, **)
            competition = get_competition(competition_id)
            return { success: false, reason: :not_found } unless competition

            trials = competition[:trials]
            return { success: true, comparison: [], leader: nil } if trials.empty?

            ranked = trials.values.sort_by { |t| [-t[:fitness], t[:avg_latency_ms]] }
            leader = ranked.first

            comparison = ranked.map.with_index(1) do |trial, rank|
              {
                extension_name: trial[:extension_name],
                fitness:        trial[:fitness],
                error_rate:     trial[:error_rate],
                avg_latency_ms: trial[:avg_latency_ms],
                rank:           rank
              }
            end

            { success: true, comparison: comparison, leader: leader[:extension_name] }
          end

          def declare_winner(competition_id:, **)
            competition = get_competition(competition_id)
            return { success: false, reason: :not_found } unless competition
            return { success: false, reason: :already_decided } if competition[:status] == :decided
            return { success: false, reason: :no_trials } if competition[:trials].empty?

            comparison = compare_results(competition_id: competition_id)
            winner_name = comparison[:leader]

            losers = competition[:trials].keys.reject { |name| name == winner_name }

            losers.each do |loser_name|
              Runners::Evolver.replace_extension(old_name: loser_name, new_proposal_id: "winner:#{winner_name}")
            end

            transition_competition(competition_id, :decided)
            set_winner(competition_id, winner_name)

            { success: true, winner: winner_name, losers: losers, competition_id: competition_id }
          end

          def competition_status(competition_id:, **)
            competition = get_competition(competition_id)
            return { success: false, reason: :not_found } unless competition

            { success: true, id: competition[:id], gap: competition[:gap],
              status: competition[:status], competitors: competition[:proposal_ids],
              trial_count: competition[:trials].size, winner: competition[:winner] }
          end

          def active_competitions(**)
            comps = all_competitions.select { |c| ACTIVE_STATUSES.include?(c[:status]) }
            { success: true, competitions: comps.map { |c| { id: c[:id], gap: c[:gap], status: c[:status] } },
              count: comps.size }
          end

          def competition_history(limit: 20, **)
            comps = all_competitions.sort_by { |c| c[:created_at] }.reverse.first(limit)
            entries = comps.map do |c|
              { id: c[:id], gap: c[:gap], status: c[:status], winner: c[:winner],
                competitors: c[:proposal_ids].size, trial_count: c[:trials].size }
            end
            { success: true, competitions: entries, count: entries.size }
          end

          private

          def competitions
            @competitions ||= {}
          end

          def mutex
            @mutex ||= Mutex.new
          end

          def store_competition(competition)
            mutex.synchronize { competitions[competition[:id]] = competition }
          end

          def get_competition(id)
            mutex.synchronize { competitions[id]&.dup }
          end

          def all_competitions
            mutex.synchronize { competitions.values.map(&:dup) }
          end

          def transition_competition(id, new_status)
            mutex.synchronize do
              competitions[id][:status] = new_status
              competitions[id][:decided_at] = Time.now.utc if new_status == :decided
            end
          end

          def set_winner(id, winner_name)
            mutex.synchronize { competitions[id][:winner] = winner_name }
          end

          def record_trial(competition_id, name, trial)
            mutex.synchronize { competitions[competition_id][:trials][name] = trial }
          end
        end
      end
    end
  end
end
