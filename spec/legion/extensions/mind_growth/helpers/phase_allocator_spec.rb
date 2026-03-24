# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::PhaseAllocator do
  subject(:allocator) { described_class }

  describe '.allocate_phase' do
    context 'with known categories' do
      {
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
      }.each do |category, expected_phase|
        it "maps #{category} to #{expected_phase}" do
          result = allocator.allocate_phase(category: category)
          expect(result[:phase]).to eq(expected_phase)
          expect(result[:cycle]).to eq(:active)
          expect(result[:confidence]).to eq(:high)
        end
      end
    end

    context 'with unknown category' do
      it 'defaults to working_memory_integration with low confidence' do
        result = allocator.allocate_phase(category: :unknown_thing)
        expect(result[:phase]).to eq(:working_memory_integration)
        expect(result[:cycle]).to eq(:active)
        expect(result[:confidence]).to eq(:low)
      end

      it 'accepts string category' do
        result = allocator.allocate_phase(category: 'cognition')
        expect(result[:phase]).to eq(:working_memory_integration)
        expect(result[:confidence]).to eq(:high)
      end
    end

    context 'method name inference for unknown categories' do
      it 'infers sensory_processing from filter methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[filter_input])
        expect(result[:phase]).to eq(:sensory_processing)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers sensory_processing from sense methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[sense_environment])
        expect(result[:phase]).to eq(:sensory_processing)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers sensory_processing from detect methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[detect_anomaly])
        expect(result[:phase]).to eq(:sensory_processing)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers prediction_engine from predict methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[predict_outcome])
        expect(result[:phase]).to eq(:prediction_engine)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers prediction_engine from forecast methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[forecast_load])
        expect(result[:phase]).to eq(:prediction_engine)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers prediction_engine from estimate methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[estimate_cost])
        expect(result[:phase]).to eq(:prediction_engine)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers post_tick_reflection from reflect methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[reflect_on_tick])
        expect(result[:phase]).to eq(:post_tick_reflection)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers post_tick_reflection from evaluate methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[evaluate_performance])
        expect(result[:phase]).to eq(:post_tick_reflection)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers post_tick_reflection from assess methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[assess_state])
        expect(result[:phase]).to eq(:post_tick_reflection)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers memory_retrieval from store methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[store_result])
        expect(result[:phase]).to eq(:memory_retrieval)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers memory_retrieval from retrieve methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[retrieve_context])
        expect(result[:phase]).to eq(:memory_retrieval)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers memory_retrieval from recall methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[recall_episode])
        expect(result[:phase]).to eq(:memory_retrieval)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers action_selection from decide methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[decide_next_action])
        expect(result[:phase]).to eq(:action_selection)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers action_selection from select methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[select_response])
        expect(result[:phase]).to eq(:action_selection)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'infers action_selection from choose methods' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[choose_strategy])
        expect(result[:phase]).to eq(:action_selection)
        expect(result[:confidence]).to eq(:medium)
      end

      it 'falls through to default when methods provide no signal' do
        result = allocator.allocate_phase(category: :unknown, runner_methods: %i[run process tick])
        expect(result[:phase]).to eq(:working_memory_integration)
        expect(result[:confidence]).to eq(:low)
      end

      it 'known category takes precedence over method inference' do
        result = allocator.allocate_phase(category: :memory, runner_methods: %i[predict_outcome])
        expect(result[:phase]).to eq(:memory_retrieval)
        expect(result[:confidence]).to eq(:high)
      end
    end

    it 'accepts string runner_methods' do
      result = allocator.allocate_phase(category: :unknown, runner_methods: ['filter_input'])
      expect(result[:phase]).to eq(:sensory_processing)
    end

    it 'returns a hash with required keys' do
      result = allocator.allocate_phase(category: :cognition)
      expect(result).to have_key(:phase)
      expect(result).to have_key(:cycle)
      expect(result).to have_key(:confidence)
    end
  end

  describe '.allocate_dream_phase' do
    context 'with known dream categories' do
      {
        memory:        :memory_audit,
        association:   :association_walk,
        conflict:      :contradiction_resolution,
        curiosity:     :agenda_formation,
        consolidation: :consolidation_commit,
        knowledge:     :knowledge_promotion,
        reflection:    :dream_reflection,
        narrative:     :dream_narration
      }.each do |category, expected_phase|
        it "maps #{category} to #{expected_phase}" do
          result = allocator.allocate_dream_phase(category: category)
          expect(result[:phase]).to eq(expected_phase)
          expect(result[:cycle]).to eq(:dream)
          expect(result[:confidence]).to eq(:high)
        end
      end
    end

    it 'returns nil for unknown dream category' do
      result = allocator.allocate_dream_phase(category: :unknown)
      expect(result).to be_nil
    end

    it 'returns nil for a category that has no dream mapping' do
      result = allocator.allocate_dream_phase(category: :safety)
      expect(result).to be_nil
    end

    it 'accepts string category' do
      result = allocator.allocate_dream_phase(category: 'memory')
      expect(result[:phase]).to eq(:memory_audit)
    end
  end

  describe '.valid_phase?' do
    it 'returns true for active phase values' do
      described_class::CATEGORY_PHASE_MAP.values.uniq.each do |phase|
        expect(allocator.valid_phase?(phase)).to be true
      end
    end

    it 'returns true for dream phase values' do
      described_class::DREAM_PHASE_MAP.values.uniq.each do |phase|
        expect(allocator.valid_phase?(phase)).to be true
      end
    end

    it 'returns false for an unknown phase' do
      expect(allocator.valid_phase?(:completely_unknown_phase)).to be false
    end

    it 'returns true for sensory_processing' do
      expect(allocator.valid_phase?(:sensory_processing)).to be true
    end

    it 'returns true for post_tick_reflection' do
      expect(allocator.valid_phase?(:post_tick_reflection)).to be true
    end

    it 'returns true for memory_audit (dream phase)' do
      expect(allocator.valid_phase?(:memory_audit)).to be true
    end
  end

  describe '.phases_for_category' do
    it 'returns active phase for a category with active mapping only' do
      result = allocator.phases_for_category(:safety)
      expect(result).to include(:procedural_check)
    end

    it 'returns dream phase for a category with dream mapping only' do
      result = allocator.phases_for_category(:narrative)
      expect(result).to include(:dream_narration)
    end

    it 'returns both active and dream phases when category maps to both' do
      # reflection maps to both post_tick_reflection and dream_reflection
      result = allocator.phases_for_category(:reflection)
      expect(result).to include(:post_tick_reflection)
      expect(result).to include(:dream_reflection)
    end

    it 'returns both active and dream phases for consolidation' do
      result = allocator.phases_for_category(:consolidation)
      expect(result).to include(:memory_consolidation)
      expect(result).to include(:consolidation_commit)
    end

    it 'returns both active and dream phases for memory' do
      result = allocator.phases_for_category(:memory)
      expect(result).to include(:memory_retrieval)
      expect(result).to include(:memory_audit)
    end

    it 'returns both active and dream phases for knowledge' do
      result = allocator.phases_for_category(:knowledge)
      expect(result).to include(:knowledge_retrieval)
      expect(result).to include(:knowledge_promotion)
    end

    it 'returns empty array for unknown category' do
      result = allocator.phases_for_category(:nonexistent)
      expect(result).to be_empty
    end

    it 'accepts string category' do
      result = allocator.phases_for_category('memory')
      expect(result).to include(:memory_retrieval)
    end
  end

  describe 'CATEGORY_PHASE_MAP' do
    it 'is frozen' do
      expect(described_class::CATEGORY_PHASE_MAP).to be_frozen
    end

    it 'contains only symbol keys' do
      described_class::CATEGORY_PHASE_MAP.each_key do |k|
        expect(k).to be_a(Symbol)
      end
    end

    it 'contains only symbol values' do
      described_class::CATEGORY_PHASE_MAP.each_value do |v|
        expect(v).to be_a(Symbol)
      end
    end
  end

  describe 'DREAM_PHASE_MAP' do
    it 'is frozen' do
      expect(described_class::DREAM_PHASE_MAP).to be_frozen
    end

    it 'contains only symbol keys' do
      described_class::DREAM_PHASE_MAP.each_key do |k|
        expect(k).to be_a(Symbol)
      end
    end

    it 'contains only symbol values' do
      described_class::DREAM_PHASE_MAP.each_value do |v|
        expect(v).to be_a(Symbol)
      end
    end
  end
end
