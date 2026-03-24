# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Wirer
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          extend self

          def analyze_fit(extension_name:, category:, runner_module: nil, runner_methods: [], **) # rubocop:disable Lint/UnusedMethodArgument
            allocation = Helpers::PhaseAllocator.allocate_phase(
              category:       category,
              runner_methods: runner_methods
            )

            dream_allocation = Helpers::PhaseAllocator.allocate_dream_phase(category: category)

            {
              success:        true,
              extension:      extension_name,
              active_phase:   allocation,
              dream_phase:    dream_allocation,
              recommendation: build_recommendation(allocation, dream_allocation)
            }
          end

          def wire_extension(extension_name:, ext_module:, runner_module:, fn:, phase:, **) # rubocop:disable Naming/MethodParameterName
            return { success: false, reason: :gaia_not_available } unless gaia_available?
            return { success: false, reason: :invalid_phase } unless Helpers::PhaseAllocator.valid_phase?(phase)

            # Verify the runner class exists and has the method
            runner_class = resolve_runner(ext_module: ext_module, runner_module: runner_module)
            return { success: false, reason: :runner_not_found } unless runner_class

            return { success: false, reason: :method_not_found, method: fn } unless runner_class.method_defined?(fn) || runner_class.respond_to?(fn)

            # Record the wiring in our registry
            wiring_registry[extension_name] = {
              ext_module:    ext_module,
              runner_module: runner_module,
              fn:            fn,
              phase:         phase,
              wired_at:      Time.now,
              enabled:       true
            }

            # Trigger GAIA rediscovery to pick up the new wiring
            rediscover_result = trigger_rediscovery

            {
              success:     true,
              extension:   extension_name,
              phase:       phase,
              fn:          fn,
              rediscovery: rediscover_result
            }
          end

          def unwire_extension(extension_name:, **)
            entry = wiring_registry.delete(extension_name)
            return { success: false, reason: :not_wired } unless entry

            trigger_rediscovery

            { success: true, extension: extension_name, unwired_phase: entry[:phase] }
          end

          def disable_extension(extension_name:, **)
            entry = wiring_registry[extension_name]
            return { success: false, reason: :not_wired } unless entry

            entry[:enabled] = false
            { success: true, extension: extension_name, status: :disabled }
          end

          def enable_extension(extension_name:, **)
            entry = wiring_registry[extension_name]
            return { success: false, reason: :not_wired } unless entry

            entry[:enabled] = true
            trigger_rediscovery
            { success: true, extension: extension_name, status: :enabled }
          end

          def wiring_status(**)
            {
              success:       true,
              wired_count:   wiring_registry.size,
              enabled_count: wiring_registry.count { |_, v| v[:enabled] },
              extensions:    wiring_registry.transform_values { |v| v.slice(:phase, :fn, :enabled, :wired_at) }
            }
          end

          def rewire_all(**)
            return { success: false, reason: :gaia_not_available } unless gaia_available?

            result = trigger_rediscovery
            { success: true, rediscovery: result }
          end

          private

          def gaia_available?
            defined?(Legion::Gaia) && Legion::Gaia.respond_to?(:registry)
          end

          def resolve_runner(ext_module:, runner_module:)
            return nil unless defined?(Legion::Gaia::PhaseWiring)

            Legion::Gaia::PhaseWiring.resolve_runner_class(ext_module.to_sym, runner_module.to_sym)
          end

          def trigger_rediscovery
            return { rediscovered: false, reason: :gaia_not_available } unless gaia_available?

            Legion::Gaia.registry.rediscover
          rescue StandardError => e
            { rediscovered: false, error: e.message }
          end

          def wiring_registry
            @wiring_registry ||= {}
          end

          def build_recommendation(active_alloc, dream_alloc)
            parts = []
            parts << case active_alloc[:confidence]
                     when :high
                       "Wire to #{active_alloc[:phase]} (high confidence)"
                     when :medium
                       "Suggest #{active_alloc[:phase]} (medium confidence, verify manually)"
                     else
                       "Default to #{active_alloc[:phase]} (low confidence, manual review recommended)"
                     end
            parts << "Also wire dream phase: #{dream_alloc[:phase]}" if dream_alloc
            parts.join('. ')
          end
        end
      end
    end
  end
end
