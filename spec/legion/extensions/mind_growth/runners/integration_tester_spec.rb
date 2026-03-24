# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::IntegrationTester do
  subject(:tester) { described_class }

  describe '.test_extension_in_tick' do
    context 'when GAIA is not available' do
      before { hide_const('Legion::Gaia') }

      it 'returns failure with gaia_not_available reason' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:gaia_not_available)
      end
    end

    context 'when GAIA is available but PhaseWiring not defined' do
      before do
        fake_gaia = Module.new
        stub_const('Legion::Gaia', fake_gaia)
      end

      it 'returns failure with runner_not_found reason' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Missing,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:runner_not_found)
      end
    end

    context 'when GAIA and PhaseWiring are available' do
      let(:working_runner) do
        Module.new do
          def think(**) = { success: true, result: 'ok' }
        end
      end

      let(:fake_phase_wiring) do
        pw = Module.new
        allow(pw).to receive(:resolve_runner_class).and_return(working_runner)
        pw
      end

      before do
        fake_gaia = Module.new
        stub_const('Legion::Gaia', fake_gaia)
        stub_const('Legion::Gaia::PhaseWiring', fake_phase_wiring)
      end

      it 'returns success: true when all checks pass' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be true
      end

      it 'returns true for method_callable' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:method_callable]).to be true
      end

      it 'returns true for valid_response' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:valid_response]).to be true
      end

      it 'includes the phase in the result' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:phase]).to eq(:working_memory_integration)
      end

      it 'includes performance metrics' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:performance]).to be_a(Hash)
        expect(result[:performance]).to have_key(:duration_ms)
        expect(result[:performance]).to have_key(:within_budget)
      end

      it 'duration_ms is a non-negative number' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:performance][:duration_ms]).to be >= 0
      end

      it 'marks within_budget true for fast methods' do
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Cognition,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:performance][:within_budget]).to be true
      end

      it 'fails when method is not defined on runner' do
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(Module.new)
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Empty,
          fn:            :nonexistent_method,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:method_not_defined)
      end

      it 'handles runner returning nil' do
        nil_runner = Module.new { def think(**) = nil }
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(nil_runner)
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :NilRunner,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be true
        expect(result[:valid_response]).to be true
      end

      it 'handles runner returning non-hash' do
        string_runner = Module.new { def think(**) = 'a string result' }
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(string_runner)
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :StringRunner,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be true
        expect(result[:valid_response]).to be true
      end

      it 'passes test_args to the runner method' do
        capturing_runner = Module.new do
          def process(value: nil, **) = { success: true, got: value }
        end
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(capturing_runner)
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Capturing,
          fn:            :process,
          phase:         :working_memory_integration,
          test_args:     { value: 42 }
        )
        expect(result[:success]).to be true
      end

      it 'returns runner_not_found when PhaseWiring returns nil' do
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(nil)
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Missing,
          fn:            :think,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:runner_not_found)
      end

      it 'returns exception result when runner raises unexpectedly' do
        raising_runner = Module.new { def boom(**) = raise('exploded') }
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(raising_runner)
        result = tester.test_extension_in_tick(
          ext_module:    :Test,
          runner_module: :Raising,
          fn:            :boom,
          phase:         :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:invocation_error)
        expect(result[:error]).to include('exploded')
      end

      it 'ignores unknown keyword arguments' do
        expect do
          tester.test_extension_in_tick(
            ext_module:    :Test,
            runner_module: :Cognition,
            fn:            :think,
            phase:         :working_memory_integration,
            extra:         true
          )
        end.not_to raise_error
      end
    end
  end

  describe '.benchmark_tick' do
    context 'when GAIA is not available' do
      before { hide_const('Legion::Gaia') }

      it 'returns failure with gaia_not_available reason' do
        result = tester.benchmark_tick
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:gaia_not_available)
      end
    end

    context 'when GAIA is available' do
      before do
        fake_gaia = Module.new
        stub_const('Legion::Gaia', fake_gaia)
      end

      it 'returns success: true' do
        result = tester.benchmark_tick
        expect(result[:success]).to be true
      end

      it 'runs the default number of iterations (5)' do
        result = tester.benchmark_tick
        expect(result[:iterations]).to eq(5)
      end

      it 'respects a custom iterations count' do
        result = tester.benchmark_tick(iterations: 3)
        expect(result[:iterations]).to eq(3)
      end

      it 'returns avg_ms as a float' do
        result = tester.benchmark_tick
        expect(result[:avg_ms]).to be_a(Float).or be_a(Integer)
        expect(result[:avg_ms]).to be >= 0
      end

      it 'returns max_ms' do
        result = tester.benchmark_tick
        expect(result[:max_ms]).to be >= 0
      end

      it 'returns min_ms' do
        result = tester.benchmark_tick
        expect(result[:min_ms]).to be >= 0
      end

      it 'max_ms >= min_ms' do
        result = tester.benchmark_tick
        expect(result[:max_ms]).to be >= result[:min_ms]
      end

      it 'avg_ms is between min_ms and max_ms' do
        result = tester.benchmark_tick(iterations: 10)
        expect(result[:avg_ms]).to be >= result[:min_ms]
        expect(result[:avg_ms]).to be <= result[:max_ms]
      end

      it 'returns within_budget: true for fast ticks' do
        result = tester.benchmark_tick
        expect(result[:within_budget]).to be true
      end

      it 'includes with_extension in result' do
        result = tester.benchmark_tick(with_extension: 'lex-test')
        expect(result[:with_extension]).to eq('lex-test')
      end

      it 'returns nil for with_extension when not provided' do
        result = tester.benchmark_tick
        expect(result[:with_extension]).to be_nil
      end

      it 'calls Legion::Gaia.heartbeat if available' do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:heartbeat).and_return(true)
        allow(fake_gaia).to receive(:heartbeat)
        stub_const('Legion::Gaia', fake_gaia)
        tester.benchmark_tick(iterations: 2)
        expect(fake_gaia).to have_received(:heartbeat).twice
      end

      it 'ignores unknown keyword arguments' do
        expect { tester.benchmark_tick(extra: true) }.not_to raise_error
      end
    end

    context 'when GAIA raises during benchmark' do
      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:heartbeat).and_return(true)
        allow(fake_gaia).to receive(:heartbeat).and_raise(StandardError, 'gaia exploded')
        stub_const('Legion::Gaia', fake_gaia)
      end

      it 'returns failure with benchmark_failed reason' do
        result = tester.benchmark_tick
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:benchmark_failed)
        expect(result[:error]).to include('gaia exploded')
      end
    end
  end

  describe 'TICK_BUDGET_MS' do
    it 'is set to 5000' do
      expect(described_class::TICK_BUDGET_MS).to eq(5000)
    end
  end
end
