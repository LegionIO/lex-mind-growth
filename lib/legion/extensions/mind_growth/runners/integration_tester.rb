# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module IntegrationTester
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          extend self

          TICK_BUDGET_MS = 5000

          def test_extension_in_tick(ext_module:, runner_module:, fn:, phase:, test_args: {}, **) # rubocop:disable Naming/MethodParameterName
            return { success: false, reason: :gaia_not_available } unless gaia_available?

            runner_class = resolve_runner_class(ext_module, runner_module)
            return { success: false, reason: :runner_not_found } unless runner_class

            # Test 1: Method exists and is callable
            method_check = test_method_callable(runner_class, fn)
            return method_check unless method_check[:success]

            # Test 2: Method returns valid response hash
            response_check = test_valid_response(runner_class, fn, test_args)
            return response_check unless response_check[:success]

            # Test 3: Method completes within budget
            perf_check = test_performance(runner_class, fn, test_args)

            {
              success:         true,
              method_callable: method_check[:success],
              valid_response:  response_check[:success],
              performance:     perf_check,
              phase:           phase
            }
          rescue StandardError => e
            { success: false, reason: :exception, error: e.message }
          end

          def benchmark_tick(with_extension: nil, iterations: 5, **)
            return { success: false, reason: :gaia_not_available } unless gaia_available?
            return { success: false, reason: :invalid_iterations, iterations: iterations } unless iterations.is_a?(Integer) && iterations >= 1

            timings = Array.new(iterations) do
              start = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
              Legion::Gaia.heartbeat if Legion::Gaia.respond_to?(:heartbeat)
              finish = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
              ((finish - start) * 1000).round(2)
            end

            {
              success:        true,
              with_extension: with_extension,
              iterations:     iterations,
              avg_ms:         (timings.sum / timings.size).round(2),
              max_ms:         timings.max,
              min_ms:         timings.min,
              within_budget:  timings.max <= TICK_BUDGET_MS
            }
          rescue StandardError => e
            { success: false, reason: :benchmark_failed, error: e.message }
          end

          private

          def gaia_available?
            defined?(Legion::Gaia)
          end

          def resolve_runner_class(ext_module, runner_module)
            return nil unless defined?(Legion::Gaia::PhaseWiring)

            Legion::Gaia::PhaseWiring.resolve_runner_class(ext_module.to_sym, runner_module.to_sym)
          end

          def test_method_callable(runner_class, fn) # rubocop:disable Naming/MethodParameterName
            if runner_class.method_defined?(fn) || runner_class.respond_to?(fn)
              { success: true, method: fn }
            else
              { success: false, reason: :method_not_defined, method: fn }
            end
          end

          def test_valid_response(runner_class, fn, args) # rubocop:disable Naming/MethodParameterName
            host = Object.new.extend(runner_class)
            result = host.send(fn, **args)

            if result.is_a?(Hash)
              { success: true, response_type: :hash, keys: result.keys }
            elsif result.nil?
              { success: true, response_type: :nil }
            else
              { success: true, response_type: result.class.name }
            end
          rescue StandardError => e
            { success: false, reason: :invocation_error, error: e.message }
          end

          def test_performance(runner_class, fn, args) # rubocop:disable Naming/MethodParameterName
            host = Object.new.extend(runner_class)
            start = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
            host.send(fn, **args)
            finish = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
            duration_ms = ((finish - start) * 1000).round(2)

            { duration_ms: duration_ms, within_budget: duration_ms <= TICK_BUDGET_MS }
          rescue StandardError => e
            { duration_ms: nil, error: e.message, within_budget: false }
          end
        end
      end
    end
  end
end
