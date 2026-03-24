# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        module Constants
          # Proposal status lifecycle
          PROPOSAL_STATUSES = %i[
            proposed evaluating approved rejected building testing passing wired active degraded pruned build_failed
          ].freeze

          # Cognitive categories and target distribution
          CATEGORIES = %i[cognition perception introspection safety communication memory motivation coordination].freeze

          TARGET_DISTRIBUTION = {
            cognition:     0.30,
            perception:    0.15,
            introspection: 0.12,
            safety:        0.12,
            communication: 0.10,
            memory:        0.10,
            motivation:    0.06,
            coordination:  0.05
          }.freeze

          # Evaluation dimensions
          EVALUATION_DIMENSIONS = %i[novelty fit cognitive_value implementability composability].freeze
          MIN_DIMENSION_SCORE   = 0.6
          AUTO_APPROVE_THRESHOLD = 0.9
          REDUNDANCY_THRESHOLD   = 0.8

          # Build pipeline
          MAX_FIX_ATTEMPTS  = 3
          BUILD_TIMEOUT_MS  = 600_000 # 10 minutes

          # Fitness function weights
          FITNESS_WEIGHTS = {
            invocation_rate: 0.25,
            impact_score:    0.30,
            health:          0.25,
            error_penalty:   -0.15,
            latency_penalty: -0.05
          }.freeze

          PRUNE_THRESHOLD       = 0.2
          IMPROVEMENT_THRESHOLD = 0.4

          # Reference cognitive models
          COGNITIVE_MODELS = %i[global_workspace free_energy dual_process somatic_marker working_memory].freeze

          # Governance
          QUORUM                   = 3
          REJECTION_COOLDOWN_HOURS = 24
          GOVERNANCE_STATUSES      = %i[pending approved rejected expired].freeze

          # Health monitoring
          HEALTH_LEVELS = { excellent: 0.8, good: 0.6, fair: 0.4, degraded: 0.2, critical: 0.0 }.freeze
          DECAY_INVOCATION_THRESHOLD = 5

          # Risk assessment
          RISK_TIERS = %i[low medium high critical].freeze
          RISK_RECOMMENDATIONS = {
            low:      :auto_approve,
            medium:   :governance,
            high:     :human_required,
            critical: :blocked
          }.freeze
        end
      end
    end
  end
end
