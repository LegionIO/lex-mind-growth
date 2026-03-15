# frozen_string_literal: true

# Stub the framework actor base class since legionio gem is not available in test
module Legion
  module Extensions
    module Actors
      class Every # rubocop:disable Lint/EmptyClass
      end
    end
  end
end

# Intercept the require in the actor file so it doesn't fail
$LOADED_FEATURES << 'legion/extensions/actors/every'

require 'legion/extensions/mind_growth/actors/growth_cycle'

RSpec.describe Legion::Extensions::MindGrowth::Actor::GrowthCycle do
  subject(:actor) { described_class.new }

  describe '#runner_class' do
    it 'returns the Orchestrator module' do
      expect(actor.runner_class).to eq(Legion::Extensions::MindGrowth::Runners::Orchestrator)
    end
  end

  describe '#runner_function' do
    it 'returns run_growth_cycle' do
      expect(actor.runner_function).to eq('run_growth_cycle')
    end
  end

  describe '#time' do
    it 'returns 3600 seconds (1 hour)' do
      expect(actor.time).to eq(3600)
    end
  end

  describe '#enabled?' do
    it 'returns false when neither codegen nor exec is loaded' do
      hide_const('Legion::Extensions::Codegen') if defined?(Legion::Extensions::Codegen)
      hide_const('Legion::Extensions::Exec') if defined?(Legion::Extensions::Exec)
      expect(actor.enabled?).to be_falsey
    end

    it 'returns truthy when codegen is loaded' do
      stub_const('Legion::Extensions::Codegen', Module.new)
      expect(actor.enabled?).to be_truthy
    end

    it 'returns truthy when exec is loaded' do
      hide_const('Legion::Extensions::Codegen') if defined?(Legion::Extensions::Codegen)
      stub_const('Legion::Extensions::Exec', Module.new)
      expect(actor.enabled?).to be_truthy
    end
  end

  describe '#run_now?' do
    it 'returns false' do
      expect(actor.run_now?).to be false
    end
  end

  describe '#use_runner?' do
    it 'returns false' do
      expect(actor.use_runner?).to be false
    end
  end

  describe '#check_subtask?' do
    it 'returns false' do
      expect(actor.check_subtask?).to be false
    end
  end

  describe '#generate_task?' do
    it 'returns false' do
      expect(actor.generate_task?).to be false
    end
  end
end
