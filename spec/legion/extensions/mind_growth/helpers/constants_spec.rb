# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Helpers::Constants do
  describe 'PROPOSAL_STATUSES' do
    subject(:statuses) { described_class::PROPOSAL_STATUSES }

    it 'is frozen' do
      expect(statuses).to be_frozen
    end

    it 'contains only symbols' do
      expect(statuses).to all(be_a(Symbol))
    end

    # Full lifecycle:
    #   proposed → evaluating → approved → building → testing → passing → wired → active
    #                          → rejected                      → build_failed
    #                                                                       → degraded
    #                                                                       → pruned
    let(:full_lifecycle_states) do
      %i[proposed evaluating approved rejected building testing passing wired active degraded pruned build_failed]
    end

    it 'includes every state in the full proposal lifecycle' do
      full_lifecycle_states.each do |state|
        expect(statuses).to include(state), "expected PROPOSAL_STATUSES to include :#{state}"
      end
    end

    it 'includes the primary happy-path states in order' do
      happy_path = %i[proposed evaluating approved building testing passing wired active]
      expect(statuses).to include(*happy_path)
    end

    it 'includes the rejection terminal state' do
      expect(statuses).to include(:rejected)
    end

    it 'includes the build_failed terminal state' do
      expect(statuses).to include(:build_failed)
    end

    it 'includes degraded and pruned operational states' do
      expect(statuses).to include(:degraded, :pruned)
    end
  end
end
