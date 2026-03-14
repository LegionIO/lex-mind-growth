# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Helpers
        module CognitiveModels
          module_function

          MODELS = {
            global_workspace: {
              name:        'Global Workspace Theory (Baars)',
              required:    %i[attention global_workspace broadcasting working_memory consciousness],
              description: 'Conscious access via global broadcasting to specialized processors'
            },
            free_energy:      {
              name:        'Free Energy Principle (Friston)',
              required:    %i[prediction free_energy predictive_coding belief_revision active_inference error_monitoring],
              description: 'Minimize surprise through predictive models and active inference'
            },
            dual_process:     {
              name:        'Dual Process Theory (Kahneman)',
              required:    %i[intuition dual_process inhibition executive_function cognitive_control],
              description: 'System 1 (fast/automatic) vs System 2 (slow/deliberate) processing'
            },
            somatic_marker:   {
              name:        'Somatic Marker Hypothesis (Damasio)',
              required:    %i[emotion somatic_marker interoception appraisal embodied_simulation],
              description: 'Emotion-cognition integration for decision making'
            },
            working_memory:   {
              name:        'Working Memory Model (Baddeley)',
              required:    %i[working_memory episodic_buffer attention executive_function cognitive_load],
              description: 'Multi-component model with central executive and slave systems'
            }
          }.freeze

          def gap_analysis(existing_extensions)
            existing_names = existing_extensions.map { |e| e.to_s.downcase.to_sym }
            MODELS.map do |key, model|
              missing  = model[:required] - existing_names
              coverage = 1.0 - (missing.size.to_f / model[:required].size)
              {
                model:          key,
                name:           model[:name],
                coverage:       coverage.round(2),
                missing:        missing,
                total_required: model[:required].size
              }
            end
          end

          def recommend_from_gaps(gap_results)
            gap_results.flat_map { |g| g[:missing] }.tally.sort_by { |_, count| -count }.map(&:first)
          end
        end
      end
    end
  end
end
