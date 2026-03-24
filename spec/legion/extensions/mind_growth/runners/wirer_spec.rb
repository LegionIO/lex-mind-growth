# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Wirer do
  subject(:wirer) { described_class }

  # Reset wiring registry before each example
  before { described_class.instance_variable_set(:@wiring_registry, nil) }

  describe '.analyze_fit' do
    it 'returns success: true' do
      result = wirer.analyze_fit(
        extension_name: 'lex-test',
        category:       :cognition,
        runner_module:  :Cognition
      )
      expect(result[:success]).to be true
    end

    it 'returns the extension name' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :cognition, runner_module: :Cognition)
      expect(result[:extension]).to eq('lex-test')
    end

    it 'returns an active phase allocation' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :memory, runner_module: :Memory)
      expect(result[:active_phase]).to be_a(Hash)
      expect(result[:active_phase][:phase]).to eq(:memory_retrieval)
      expect(result[:active_phase][:confidence]).to eq(:high)
    end

    it 'returns a dream phase allocation when category has one' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :memory, runner_module: :Memory)
      expect(result[:dream_phase]).to be_a(Hash)
      expect(result[:dream_phase][:phase]).to eq(:memory_audit)
    end

    it 'returns nil dream phase when category has no dream mapping' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :safety, runner_module: :Safety)
      expect(result[:dream_phase]).to be_nil
    end

    it 'returns a recommendation string' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :cognition, runner_module: :Cognition)
      expect(result[:recommendation]).to be_a(String)
      expect(result[:recommendation]).not_to be_empty
    end

    it 'includes phase name in recommendation' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :cognition, runner_module: :Cognition)
      expect(result[:recommendation]).to include('working_memory_integration')
    end

    it 'includes confidence level in recommendation' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :cognition, runner_module: :Cognition)
      expect(result[:recommendation]).to include('high confidence')
    end

    it 'includes dream phase in recommendation when applicable' do
      result = wirer.analyze_fit(extension_name: 'lex-test', category: :reflection, runner_module: :Reflection)
      expect(result[:recommendation]).to include('dream phase')
    end

    it 'uses runner_methods for inference when category is unknown' do
      result = wirer.analyze_fit(
        extension_name: 'lex-test',
        category:       :unknown_thing,
        runner_module:  :Unknown,
        runner_methods: %i[predict_outcome]
      )
      expect(result[:active_phase][:phase]).to eq(:prediction_engine)
      expect(result[:active_phase][:confidence]).to eq(:medium)
    end

    it 'includes medium confidence in recommendation for inferred phase' do
      result = wirer.analyze_fit(
        extension_name: 'lex-test',
        category:       :unknown_thing,
        runner_module:  :Unknown,
        runner_methods: %i[predict_outcome]
      )
      expect(result[:recommendation]).to include('medium confidence')
    end

    it 'ignores unknown keyword arguments' do
      expect do
        wirer.analyze_fit(extension_name: 'lex-x', category: :cognition, runner_module: :X, extra: true)
      end.not_to raise_error
    end
  end

  describe '.wire_extension' do
    context 'when GAIA is not available' do
      before { hide_const('Legion::Gaia') }

      it 'returns failure with gaia_not_available reason' do
        result = wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:gaia_not_available)
      end
    end

    context 'when GAIA is available' do
      let(:fake_registry) { double('registry', rediscover: { rediscovered: true }) }
      let(:fake_runner) { Module.new { def think(**) = { success: true } } }
      let(:fake_phase_wiring) do
        pw = Module.new
        allow(pw).to receive(:resolve_runner_class).and_return(fake_runner)
        pw
      end

      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:registry).and_return(true)
        allow(fake_gaia).to receive(:registry).and_return(fake_registry)
        stub_const('Legion::Gaia', fake_gaia)
        stub_const('Legion::Gaia::PhaseWiring', fake_phase_wiring)
      end

      it 'succeeds when runner exists and method is defined' do
        result = wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        expect(result[:success]).to be true
        expect(result[:extension]).to eq('lex-test')
        expect(result[:phase]).to eq(:working_memory_integration)
        expect(result[:fn]).to eq(:think)
      end

      it 'triggers rediscovery after wiring' do
        wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        expect(fake_registry).to have_received(:rediscover)
      end

      it 'returns the rediscovery result' do
        result = wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        expect(result[:rediscovery]).to eq({ rediscovered: true })
      end

      it 'returns invalid_phase for unknown phase' do
        result = wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :nonexistent_phase
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:invalid_phase)
      end

      it 'returns runner_not_found when PhaseWiring returns nil' do
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(nil)
        result = wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Missing,
          fn:             :think,
          phase:          :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:runner_not_found)
      end

      it 'returns method_not_found when method is not defined on runner' do
        empty_runner = Module.new
        allow(fake_phase_wiring).to receive(:resolve_runner_class).and_return(empty_runner)
        result = wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :nonexistent_method,
          phase:          :working_memory_integration
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:method_not_found)
        expect(result[:method]).to eq(:nonexistent_method)
      end

      it 'stores the wiring in the registry' do
        wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        status = wirer.wiring_status
        expect(status[:wired_count]).to eq(1)
        expect(status[:extensions]).to have_key('lex-test')
      end
    end
  end

  describe '.unwire_extension' do
    context 'when extension is not wired' do
      it 'returns failure with not_wired reason' do
        result = wirer.unwire_extension(extension_name: 'lex-nonexistent')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:not_wired)
      end
    end

    context 'when extension is wired' do
      let(:fake_registry) { double('registry', rediscover: { rediscovered: true }) }
      let(:fake_runner) { Module.new { def think(**) = { success: true } } }
      let(:fake_phase_wiring) do
        pw = Module.new
        allow(pw).to receive(:resolve_runner_class).and_return(fake_runner)
        pw
      end

      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:registry).and_return(true)
        allow(fake_gaia).to receive(:registry).and_return(fake_registry)
        stub_const('Legion::Gaia', fake_gaia)
        stub_const('Legion::Gaia::PhaseWiring', fake_phase_wiring)

        wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
      end

      it 'returns success' do
        result = wirer.unwire_extension(extension_name: 'lex-test')
        expect(result[:success]).to be true
      end

      it 'returns the extension name' do
        result = wirer.unwire_extension(extension_name: 'lex-test')
        expect(result[:extension]).to eq('lex-test')
      end

      it 'returns the unwired phase' do
        result = wirer.unwire_extension(extension_name: 'lex-test')
        expect(result[:unwired_phase]).to eq(:working_memory_integration)
      end

      it 'removes the extension from the registry' do
        wirer.unwire_extension(extension_name: 'lex-test')
        status = wirer.wiring_status
        expect(status[:wired_count]).to eq(0)
      end

      it 'triggers rediscovery after unwiring' do
        wirer.unwire_extension(extension_name: 'lex-test')
        # rediscover called once for wire, once for unwire
        expect(fake_registry).to have_received(:rediscover).twice
      end
    end
  end

  describe '.disable_extension' do
    context 'when extension is not wired' do
      it 'returns failure with not_wired reason' do
        result = wirer.disable_extension(extension_name: 'lex-nonexistent')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:not_wired)
      end
    end

    context 'when extension is wired' do
      let(:fake_registry) { double('registry', rediscover: { rediscovered: true }) }
      let(:fake_runner) { Module.new { def think(**) = { success: true } } }
      let(:fake_phase_wiring) do
        pw = Module.new
        allow(pw).to receive(:resolve_runner_class).and_return(fake_runner)
        pw
      end

      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:registry).and_return(true)
        allow(fake_gaia).to receive(:registry).and_return(fake_registry)
        stub_const('Legion::Gaia', fake_gaia)
        stub_const('Legion::Gaia::PhaseWiring', fake_phase_wiring)

        wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
      end

      it 'returns success' do
        result = wirer.disable_extension(extension_name: 'lex-test')
        expect(result[:success]).to be true
      end

      it 'returns disabled status' do
        result = wirer.disable_extension(extension_name: 'lex-test')
        expect(result[:status]).to eq(:disabled)
      end

      it 'reflects disabled in wiring_status' do
        wirer.disable_extension(extension_name: 'lex-test')
        status = wirer.wiring_status
        expect(status[:enabled_count]).to eq(0)
        expect(status[:wired_count]).to eq(1)
      end

      it 'does not trigger rediscovery on disable' do
        fake_registry.instance_variable_get(:@receive_message_count) || 0
        wirer.disable_extension(extension_name: 'lex-test')
        # rediscover was called once for wire_extension; disable should not call it again
        expect(fake_registry).to have_received(:rediscover).once
      end
    end
  end

  describe '.enable_extension' do
    context 'when extension is not wired' do
      it 'returns failure with not_wired reason' do
        result = wirer.enable_extension(extension_name: 'lex-nonexistent')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:not_wired)
      end
    end

    context 'when extension is wired and disabled' do
      let(:fake_registry) { double('registry', rediscover: { rediscovered: true }) }
      let(:fake_runner) { Module.new { def think(**) = { success: true } } }
      let(:fake_phase_wiring) do
        pw = Module.new
        allow(pw).to receive(:resolve_runner_class).and_return(fake_runner)
        pw
      end

      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:registry).and_return(true)
        allow(fake_gaia).to receive(:registry).and_return(fake_registry)
        stub_const('Legion::Gaia', fake_gaia)
        stub_const('Legion::Gaia::PhaseWiring', fake_phase_wiring)

        wirer.wire_extension(
          extension_name: 'lex-test',
          ext_module:     :Test,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        wirer.disable_extension(extension_name: 'lex-test')
      end

      it 'returns success' do
        result = wirer.enable_extension(extension_name: 'lex-test')
        expect(result[:success]).to be true
      end

      it 'returns enabled status' do
        result = wirer.enable_extension(extension_name: 'lex-test')
        expect(result[:status]).to eq(:enabled)
      end

      it 'reflects enabled in wiring_status' do
        wirer.enable_extension(extension_name: 'lex-test')
        status = wirer.wiring_status
        expect(status[:enabled_count]).to eq(1)
      end

      it 'triggers rediscovery on enable' do
        wirer.enable_extension(extension_name: 'lex-test')
        # called for wire + enable (not for disable)
        expect(fake_registry).to have_received(:rediscover).twice
      end
    end
  end

  describe '.wiring_status' do
    it 'returns success: true with empty registry' do
      result = wirer.wiring_status
      expect(result[:success]).to be true
    end

    it 'returns wired_count of zero initially' do
      result = wirer.wiring_status
      expect(result[:wired_count]).to eq(0)
    end

    it 'returns enabled_count of zero initially' do
      result = wirer.wiring_status
      expect(result[:enabled_count]).to eq(0)
    end

    it 'returns empty extensions hash initially' do
      result = wirer.wiring_status
      expect(result[:extensions]).to be_empty
    end

    it 'ignores unknown keyword arguments' do
      expect { wirer.wiring_status(extra: true) }.not_to raise_error
    end

    context 'with entries in registry' do
      let(:fake_registry) { double('registry', rediscover: { rediscovered: true }) }
      let(:fake_runner) { Module.new { def think(**) = { success: true } } }
      let(:fake_phase_wiring) do
        pw = Module.new
        allow(pw).to receive(:resolve_runner_class).and_return(fake_runner)
        pw
      end

      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:registry).and_return(true)
        allow(fake_gaia).to receive(:registry).and_return(fake_registry)
        stub_const('Legion::Gaia', fake_gaia)
        stub_const('Legion::Gaia::PhaseWiring', fake_phase_wiring)

        wirer.wire_extension(
          extension_name: 'lex-alpha',
          ext_module:     :Alpha,
          runner_module:  :Cognition,
          fn:             :think,
          phase:          :working_memory_integration
        )
        wirer.wire_extension(
          extension_name: 'lex-beta',
          ext_module:     :Beta,
          runner_module:  :Memory,
          fn:             :think,
          phase:          :memory_retrieval
        )
      end

      it 'returns correct wired_count' do
        expect(wirer.wiring_status[:wired_count]).to eq(2)
      end

      it 'returns correct enabled_count when all enabled' do
        expect(wirer.wiring_status[:enabled_count]).to eq(2)
      end

      it 'returns extension details in extensions hash' do
        extensions = wirer.wiring_status[:extensions]
        expect(extensions).to have_key('lex-alpha')
        expect(extensions['lex-alpha'][:phase]).to eq(:working_memory_integration)
        expect(extensions['lex-alpha'][:fn]).to eq(:think)
        expect(extensions['lex-alpha'][:enabled]).to be true
        expect(extensions['lex-alpha']).to have_key(:wired_at)
      end

      it 'does not expose internal fields (ext_module, runner_module)' do
        extensions = wirer.wiring_status[:extensions]
        expect(extensions['lex-alpha']).not_to have_key(:ext_module)
        expect(extensions['lex-alpha']).not_to have_key(:runner_module)
      end

      it 'reduces enabled_count when one is disabled' do
        wirer.disable_extension(extension_name: 'lex-alpha')
        expect(wirer.wiring_status[:enabled_count]).to eq(1)
      end
    end
  end

  describe '.rewire_all' do
    context 'when GAIA is not available' do
      before { hide_const('Legion::Gaia') }

      it 'returns failure with gaia_not_available reason' do
        result = wirer.rewire_all
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:gaia_not_available)
      end
    end

    context 'when GAIA is available' do
      let(:fake_registry) { double('registry', rediscover: { rediscovered: true, count: 5 }) }

      before do
        fake_gaia = Module.new
        allow(fake_gaia).to receive(:respond_to?).with(:registry).and_return(true)
        allow(fake_gaia).to receive(:registry).and_return(fake_registry)
        stub_const('Legion::Gaia', fake_gaia)
      end

      it 'returns success: true' do
        result = wirer.rewire_all
        expect(result[:success]).to be true
      end

      it 'triggers rediscovery' do
        wirer.rewire_all
        expect(fake_registry).to have_received(:rediscover)
      end

      it 'returns the rediscovery result' do
        result = wirer.rewire_all
        expect(result[:rediscovery]).to eq({ rediscovered: true, count: 5 })
      end

      it 'ignores unknown keyword arguments' do
        expect { wirer.rewire_all(extra: true) }.not_to raise_error
      end
    end
  end
end
