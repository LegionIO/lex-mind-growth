# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::CognitiveModels do
  subject(:models) { described_class }

  describe '.gap_analysis' do
    context 'with no existing extensions' do
      it 'returns analysis for all cognitive models' do
        result = models.gap_analysis([])
        expect(result.size).to eq(5)
      end

      it 'reports zero coverage for all models' do
        result = models.gap_analysis([])
        result.each do |entry|
          expect(entry[:coverage]).to eq(0.0)
        end
      end

      it 'lists all required components as missing' do
        result = models.gap_analysis([])
        entry = result.find { |r| r[:model] == :global_workspace }
        expect(entry[:missing]).to eq(%i[attention global_workspace broadcasting working_memory consciousness])
      end
    end

    context 'with partial extensions' do
      it 'calculates partial coverage' do
        result = models.gap_analysis(%i[attention working_memory])
        gw = result.find { |r| r[:model] == :global_workspace }
        # has attention + working_memory out of 5 required = 0.40
        expect(gw[:coverage]).to eq(0.4)
      end

      it 'removes matched components from missing list' do
        result = models.gap_analysis(%i[attention])
        gw = result.find { |r| r[:model] == :global_workspace }
        expect(gw[:missing]).not_to include(:attention)
      end
    end

    context 'with full coverage' do
      it 'reports coverage of 1.0 when all required present' do
        result = models.gap_analysis(%i[attention global_workspace broadcasting working_memory consciousness])
        gw = result.find { |r| r[:model] == :global_workspace }
        expect(gw[:coverage]).to eq(1.0)
        expect(gw[:missing]).to be_empty
      end
    end

    it 'includes model name in each entry' do
      result = models.gap_analysis([])
      result.each do |entry|
        expect(entry[:name]).to be_a(String)
        expect(entry[:name]).not_to be_empty
      end
    end

    it 'includes total_required in each entry' do
      result = models.gap_analysis([])
      gw = result.find { |r| r[:model] == :global_workspace }
      expect(gw[:total_required]).to eq(5)
    end
  end

  describe '.recommend_from_gaps' do
    it 'returns symbols most commonly missing across models' do
      gaps = models.gap_analysis([])
      recommendations = models.recommend_from_gaps(gaps)
      expect(recommendations).to be_an(Array)
      expect(recommendations).not_to be_empty
      expect(recommendations.first).to be_a(Symbol)
    end

    it 'returns components missing in multiple models first' do
      # attention appears in global_workspace and working_memory
      gaps = models.gap_analysis([])
      recommendations = models.recommend_from_gaps(gaps)
      expect(recommendations).to include(:attention)
      expect(recommendations).to include(:working_memory)
    end

    it 'returns empty array when no gaps' do
      all_required = described_class::MODELS.values.flat_map { |m| m[:required] }.uniq
      gaps = models.gap_analysis(all_required)
      recommendations = models.recommend_from_gaps(gaps)
      expect(recommendations).to be_empty
    end
  end

  describe 'MODELS constant' do
    it 'contains all five reference models' do
      expect(described_class::MODELS.keys).to contain_exactly(
        :global_workspace, :free_energy, :dual_process, :somatic_marker, :working_memory
      )
    end

    it 'each model has required, name, and description' do
      described_class::MODELS.each_value do |model|
        expect(model[:required]).to be_an(Array)
        expect(model[:name]).to be_a(String)
        expect(model[:description]).to be_a(String)
      end
    end
  end
end
