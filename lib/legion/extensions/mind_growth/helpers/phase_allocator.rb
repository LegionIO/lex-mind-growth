# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        module PhaseAllocator
          # Maps cognitive categories to GAIA tick phases
          CATEGORY_PHASE_MAP = {
            perception:    :sensory_processing,
            attention:     :sensory_processing,
            emotion:       :emotional_evaluation,
            affect:        :emotional_evaluation,
            memory:        :memory_retrieval,
            knowledge:     :knowledge_retrieval,
            identity:      :identity_entropy_check,
            cognition:     :working_memory_integration,
            reasoning:     :working_memory_integration,
            safety:        :procedural_check,
            defense:       :procedural_check,
            prediction:    :prediction_engine,
            inference:     :prediction_engine,
            communication: :mesh_interface,
            social:        :mesh_interface,
            coordination:  :mesh_interface,
            motivation:    :action_selection,
            executive:     :action_selection,
            learning:      :memory_consolidation,
            consolidation: :memory_consolidation,
            introspection: :post_tick_reflection,
            self:          :post_tick_reflection,
            reflection:    :post_tick_reflection
          }.freeze

          # Dream cycle phase mappings
          DREAM_PHASE_MAP = {
            memory:        :memory_audit,
            association:   :association_walk,
            conflict:      :contradiction_resolution,
            curiosity:     :agenda_formation,
            consolidation: :consolidation_commit,
            knowledge:     :knowledge_promotion,
            reflection:    :dream_reflection,
            narrative:     :dream_narration
          }.freeze

          # Maps method name substrings to inferred GAIA phases for unknown categories
          METHOD_INFERENCE_MAP = [
            [%w[filter sense detect], :sensory_processing],
            [%w[predict forecast estimate],      :prediction_engine],
            [%w[reflect evaluate assess],        :post_tick_reflection],
            [%w[store retrieve recall],          :memory_retrieval],
            [%w[decide select choose],           :action_selection]
          ].freeze

          module_function

          def allocate_phase(category:, runner_methods: [])
            category_sym = category.to_s.downcase.to_sym

            # Check active phases first
            phase = CATEGORY_PHASE_MAP[category_sym]
            return { phase: phase, cycle: :active, confidence: :high } if phase

            # Try to infer from runner method names
            inferred = infer_from_methods(runner_methods)
            return inferred if inferred

            # Default to working_memory_integration (safest catch-all)
            { phase: :working_memory_integration, cycle: :active, confidence: :low }
          end

          def allocate_dream_phase(category:)
            category_sym = category.to_s.downcase.to_sym
            phase = DREAM_PHASE_MAP[category_sym]
            return { phase: phase, cycle: :dream, confidence: :high } if phase

            nil
          end

          def infer_from_methods(methods)
            method_names = methods.map(&:to_s)
            match = METHOD_INFERENCE_MAP.find do |keywords, _phase|
              method_names.any? { |m| keywords.any? { |kw| m.include?(kw) } }
            end
            return nil unless match

            { phase: match[1], cycle: :active, confidence: :medium }
          end

          def valid_phase?(phase)
            CATEGORY_PHASE_MAP.values.include?(phase) || DREAM_PHASE_MAP.values.include?(phase)
          end

          def phases_for_category(category)
            category_sym = category.to_s.downcase.to_sym
            results = []
            results << CATEGORY_PHASE_MAP[category_sym] if CATEGORY_PHASE_MAP.key?(category_sym)
            results << DREAM_PHASE_MAP[category_sym] if DREAM_PHASE_MAP.key?(category_sym)
            results.compact
          end
        end
      end
    end
  end
end
