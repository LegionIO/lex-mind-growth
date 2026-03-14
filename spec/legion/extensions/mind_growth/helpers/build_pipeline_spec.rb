# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::BuildPipeline do
  let(:proposal) do
    Legion::Extensions::MindGrowth::Helpers::ConceptProposal.new(
      name:        'lex-pipeline-test',
      module_name: 'PipelineTest',
      category:    :cognition,
      description: 'Test proposal for build pipeline'
    )
  end

  subject(:pipeline) { described_class.new(proposal) }

  describe '#initialize' do
    it 'starts at scaffold stage' do
      expect(pipeline.stage).to eq(:scaffold)
    end

    it 'has empty errors' do
      expect(pipeline.errors).to be_empty
    end

    it 'records started_at' do
      expect(pipeline.started_at).to be_a(Time)
    end

    it 'leaves completed_at nil' do
      expect(pipeline.completed_at).to be_nil
    end
  end

  describe '#advance!' do
    context 'with successful result' do
      it 'advances to next stage' do
        pipeline.advance!({ success: true })
        expect(pipeline.stage).to eq(:implement)
      end

      it 'progresses through all stages' do
        described_class::STAGES[0...-2].each do
          pipeline.advance!({ success: true })
        end
        expect(pipeline.stage).to eq(:complete)
      end

      it 'sets completed_at on :complete' do
        described_class::STAGES[0...-2].each do
          pipeline.advance!({ success: true })
        end
        expect(pipeline.completed_at).to be_a(Time)
      end
    end

    context 'with failed result' do
      it 'records the error' do
        pipeline.advance!({ success: false, error: 'something went wrong' })
        expect(pipeline.errors.size).to eq(1)
        expect(pipeline.errors.first[:error]).to eq('something went wrong')
      end

      it 'does not advance stage on failure' do
        pipeline.advance!({ success: false, error: 'err' })
        expect(pipeline.stage).to eq(:scaffold)
      end

      it 'transitions to :failed after MAX_FIX_ATTEMPTS errors' do
        Legion::Extensions::MindGrowth::Helpers::Constants::MAX_FIX_ATTEMPTS.times do
          pipeline.advance!({ success: false, error: 'repeated error' })
        end
        expect(pipeline.stage).to eq(:failed)
      end

      it 'records stage in each error entry' do
        pipeline.advance!({ success: false, error: 'err' })
        expect(pipeline.errors.first[:stage]).to eq(:scaffold)
      end

      it 'records timestamp in each error entry' do
        pipeline.advance!({ success: false, error: 'err' })
        expect(pipeline.errors.first[:at]).to be_a(Time)
      end
    end
  end

  describe '#complete?' do
    it 'returns false initially' do
      expect(pipeline.complete?).to be false
    end

    it 'returns true after all stages complete' do
      described_class::STAGES[0...-2].each do
        pipeline.advance!({ success: true })
      end
      expect(pipeline.complete?).to be true
    end
  end

  describe '#failed?' do
    it 'returns false initially' do
      expect(pipeline.failed?).to be false
    end

    it 'returns true after MAX_FIX_ATTEMPTS failures' do
      Legion::Extensions::MindGrowth::Helpers::Constants::MAX_FIX_ATTEMPTS.times do
        pipeline.advance!({ success: false, error: 'err' })
      end
      expect(pipeline.failed?).to be true
    end
  end

  describe '#duration_ms' do
    it 'returns a non-negative integer' do
      expect(pipeline.duration_ms).to be >= 0
    end
  end

  describe '#to_h' do
    it 'includes proposal_id' do
      expect(pipeline.to_h[:proposal_id]).to eq(proposal.id)
    end

    it 'includes current stage' do
      expect(pipeline.to_h[:stage]).to eq(:scaffold)
    end

    it 'includes errors array' do
      expect(pipeline.to_h[:errors]).to eq([])
    end

    it 'includes duration_ms' do
      expect(pipeline.to_h[:duration_ms]).to be >= 0
    end
  end
end
