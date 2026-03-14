# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        class BuildPipeline
          STAGES = %i[scaffold implement test validate register complete failed].freeze

          attr_reader :proposal, :stage, :errors, :started_at, :completed_at

          def initialize(proposal)
            @proposal     = proposal
            @stage        = :scaffold
            @errors       = []
            @artifacts    = {}
            @started_at   = Time.now.utc
            @completed_at = nil
          end

          def advance!(result)
            if result[:success]
              @artifacts[@stage] = result
              next_idx      = STAGES.index(@stage) + 1
              @stage        = STAGES[next_idx] || :complete
              @completed_at = Time.now.utc if @stage == :complete
            else
              @errors << { stage: @stage, error: result[:error], at: Time.now.utc }
              @stage = :failed if @errors.size >= Helpers::Constants::MAX_FIX_ATTEMPTS
            end
          end

          def complete?
            @stage == :complete
          end

          def failed?
            @stage == :failed
          end

          def to_h
            {
              proposal_id:  @proposal.id,
              stage:        @stage,
              errors:       @errors,
              started_at:   @started_at,
              completed_at: @completed_at,
              duration_ms:  duration_ms
            }
          end

          def duration_ms
            end_time = @completed_at || Time.now.utc
            ((end_time - @started_at) * 1000).round
          end
        end
      end
    end
  end
end
