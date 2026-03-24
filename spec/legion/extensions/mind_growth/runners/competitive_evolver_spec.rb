# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::CompetitiveEvolver do
  subject(:evolver) { described_class }

  # Reset internal state between tests
  after do
    described_class.instance_variable_set(:@competitions, {})
  end

  # ─── helpers ──────────────────────────────────────────────────────────────

  def build_extension(name:, invocation_count: 100, error_rate: 0.01, avg_latency_ms: 50,
                      impact_score: 0.7, health_score: 0.8, category: :cognition)
    { name: name, invocation_count: invocation_count, error_rate: error_rate,
      avg_latency_ms: avg_latency_ms, impact_score: impact_score,
      health_score: health_score, category: category }
  end

  def create_and_return_id(gap: 'working_memory', proposal_ids: %w[p1 p2])
    result = evolver.create_competition(gap: gap, proposal_ids: proposal_ids)
    result[:competition_id]
  end

  # ─── constants ───────────────────────────────────────────────────────────

  describe 'constants' do
    it 'defines COMPETITION_STATUSES' do
      expect(described_class::COMPETITION_STATUSES).to contain_exactly(
        :pending, :active, :evaluating, :decided, :cancelled
      )
    end

    it 'defines MIN_TRIAL_ITERATIONS as 10' do
      expect(described_class::MIN_TRIAL_ITERATIONS).to eq(10)
    end
  end

  # ─── create_competition ─────────────────────────────────────────────────

  describe '.create_competition' do
    it 'returns success: true with a competition_id' do
      result = evolver.create_competition(gap: 'attention', proposal_ids: %w[p1 p2])
      expect(result[:success]).to be true
      expect(result[:competition_id]).to be_a(String)
    end

    it 'returns the gap and competitor count' do
      result = evolver.create_competition(gap: 'attention', proposal_ids: %w[p1 p2 p3])
      expect(result[:gap]).to eq('attention')
      expect(result[:competitors]).to eq(3)
    end

    it 'requires at least 2 competitors' do
      result = evolver.create_competition(gap: 'attention', proposal_ids: ['p1'])
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:insufficient_competitors)
    end

    it 'returns failure for empty proposal_ids' do
      result = evolver.create_competition(gap: 'attention', proposal_ids: [])
      expect(result[:success]).to be false
    end

    it 'creates competition in :pending status' do
      cid = create_and_return_id
      status = evolver.competition_status(competition_id: cid)
      expect(status[:status]).to eq(:pending)
    end
  end

  # ─── run_trial ──────────────────────────────────────────────────────────

  describe '.run_trial' do
    let(:competition_id) { create_and_return_id }

    it 'returns success: true with trial data' do
      ext = build_extension(name: 'ext-a')
      result = evolver.run_trial(competition_id: competition_id, extension: ext)
      expect(result[:success]).to be true
      expect(result[:trial][:extension_name]).to eq('ext-a')
    end

    it 'records the fitness score from FitnessEvaluator' do
      ext = build_extension(name: 'ext-a', invocation_count: 1000, impact_score: 0.9, health_score: 1.0)
      result = evolver.run_trial(competition_id: competition_id, extension: ext)
      expect(result[:trial][:fitness]).to be > 0
    end

    it 'transitions competition to :active on first trial' do
      ext = build_extension(name: 'ext-a')
      evolver.run_trial(competition_id: competition_id, extension: ext)
      status = evolver.competition_status(competition_id: competition_id)
      expect(status[:status]).to eq(:active)
    end

    it 'returns failure for nonexistent competition' do
      ext = build_extension(name: 'ext-a')
      result = evolver.run_trial(competition_id: 'bogus', extension: ext)
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:not_found)
    end

    it 'returns failure for decided competition' do
      cid = create_and_return_id
      ext_a = build_extension(name: 'ext-a', invocation_count: 1000, impact_score: 0.9)
      ext_b = build_extension(name: 'ext-b', invocation_count: 10, impact_score: 0.1)
      evolver.run_trial(competition_id: cid, extension: ext_a)
      evolver.run_trial(competition_id: cid, extension: ext_b)
      evolver.declare_winner(competition_id: cid)

      result = evolver.run_trial(competition_id: cid, extension: ext_a)
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:already_decided)
    end

    it 'uses extension_name if name is not present' do
      ext = { extension_name: 'ext-fallback', invocation_count: 50, error_rate: 0.0,
              avg_latency_ms: 10, impact_score: 0.5, health_score: 0.7 }
      result = evolver.run_trial(competition_id: competition_id, extension: ext)
      expect(result[:trial][:extension_name]).to eq('ext-fallback')
    end

    it 'records custom iteration count' do
      ext = build_extension(name: 'ext-a')
      result = evolver.run_trial(competition_id: competition_id, extension: ext, iterations: 50)
      expect(result[:trial][:iterations]).to eq(50)
    end
  end

  # ─── compare_results ────────────────────────────────────────────────────

  describe '.compare_results' do
    let(:competition_id) { create_and_return_id }

    it 'returns empty comparison when no trials exist' do
      result = evolver.compare_results(competition_id: competition_id)
      expect(result[:success]).to be true
      expect(result[:comparison]).to be_empty
      expect(result[:leader]).to be_nil
    end

    it 'ranks extensions by fitness descending' do
      ext_high = build_extension(name: 'winner', invocation_count: 1000, impact_score: 0.9, health_score: 1.0)
      ext_low  = build_extension(name: 'loser', invocation_count: 10, impact_score: 0.1, health_score: 0.3)
      evolver.run_trial(competition_id: competition_id, extension: ext_low)
      evolver.run_trial(competition_id: competition_id, extension: ext_high)

      result = evolver.compare_results(competition_id: competition_id)
      expect(result[:leader]).to eq('winner')
      expect(result[:comparison].first[:rank]).to eq(1)
      expect(result[:comparison].first[:extension_name]).to eq('winner')
    end

    it 'breaks ties by lower latency' do
      ext_a = build_extension(name: 'fast', invocation_count: 100, impact_score: 0.7,
                              health_score: 0.8, avg_latency_ms: 10)
      ext_b = build_extension(name: 'slow', invocation_count: 100, impact_score: 0.7,
                              health_score: 0.8, avg_latency_ms: 500)
      evolver.run_trial(competition_id: competition_id, extension: ext_a)
      evolver.run_trial(competition_id: competition_id, extension: ext_b)

      result = evolver.compare_results(competition_id: competition_id)
      expect(result[:leader]).to eq('fast')
    end

    it 'returns failure for nonexistent competition' do
      result = evolver.compare_results(competition_id: 'bogus')
      expect(result[:success]).to be false
    end

    it 'includes all trial data in comparison' do
      ext = build_extension(name: 'solo', error_rate: 0.05, avg_latency_ms: 42)
      evolver.run_trial(competition_id: competition_id, extension: ext)
      result = evolver.compare_results(competition_id: competition_id)
      entry = result[:comparison].first
      expect(entry).to include(:fitness, :error_rate, :avg_latency_ms, :rank)
    end
  end

  # ─── declare_winner ─────────────────────────────────────────────────────

  describe '.declare_winner' do
    let(:competition_id) { create_and_return_id }

    before do
      ext_a = build_extension(name: 'champion', invocation_count: 1000, impact_score: 0.9, health_score: 1.0)
      ext_b = build_extension(name: 'challenger', invocation_count: 10, impact_score: 0.1, health_score: 0.3)
      evolver.run_trial(competition_id: competition_id, extension: ext_a)
      evolver.run_trial(competition_id: competition_id, extension: ext_b)
    end

    it 'returns success: true with the winner' do
      result = evolver.declare_winner(competition_id: competition_id)
      expect(result[:success]).to be true
      expect(result[:winner]).to eq('champion')
    end

    it 'returns the losers list' do
      result = evolver.declare_winner(competition_id: competition_id)
      expect(result[:losers]).to contain_exactly('challenger')
    end

    it 'transitions competition to :decided' do
      evolver.declare_winner(competition_id: competition_id)
      status = evolver.competition_status(competition_id: competition_id)
      expect(status[:status]).to eq(:decided)
    end

    it 'sets the winner on the competition' do
      evolver.declare_winner(competition_id: competition_id)
      status = evolver.competition_status(competition_id: competition_id)
      expect(status[:winner]).to eq('champion')
    end

    it 'calls Evolver.replace_extension for each loser' do
      expect(Legion::Extensions::MindGrowth::Runners::Evolver).to receive(:replace_extension)
        .with(old_name: 'challenger', new_proposal_id: 'winner:champion')
        .and_return({ success: true, replaced: 'challenger' })
      evolver.declare_winner(competition_id: competition_id)
    end

    it 'returns failure for nonexistent competition' do
      result = evolver.declare_winner(competition_id: 'bogus')
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:not_found)
    end

    it 'returns failure when already decided' do
      evolver.declare_winner(competition_id: competition_id)
      result = evolver.declare_winner(competition_id: competition_id)
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:already_decided)
    end

    it 'returns failure when no trials exist' do
      cid = create_and_return_id(proposal_ids: %w[x y])
      result = evolver.declare_winner(competition_id: cid)
      expect(result[:success]).to be false
      expect(result[:reason]).to eq(:no_trials)
    end
  end

  # ─── competition_status ─────────────────────────────────────────────────

  describe '.competition_status' do
    it 'returns competition details' do
      cid = create_and_return_id(gap: 'prediction', proposal_ids: %w[a b c])
      result = evolver.competition_status(competition_id: cid)
      expect(result[:success]).to be true
      expect(result[:gap]).to eq('prediction')
      expect(result[:competitors]).to eq(%w[a b c])
      expect(result[:trial_count]).to eq(0)
    end

    it 'returns failure for nonexistent competition' do
      result = evolver.competition_status(competition_id: 'missing')
      expect(result[:success]).to be false
    end
  end

  # ─── active_competitions ────────────────────────────────────────────────

  describe '.active_competitions' do
    it 'returns empty list when no competitions exist' do
      result = evolver.active_competitions
      expect(result[:success]).to be true
      expect(result[:count]).to eq(0)
    end

    it 'includes pending and active competitions' do
      create_and_return_id(gap: 'gap1')
      cid2 = create_and_return_id(gap: 'gap2')
      evolver.run_trial(competition_id: cid2, extension: build_extension(name: 'e1'))

      result = evolver.active_competitions
      expect(result[:count]).to eq(2)
    end

    it 'excludes decided competitions' do
      cid = create_and_return_id
      evolver.run_trial(competition_id: cid, extension: build_extension(name: 'a', invocation_count: 1000))
      evolver.run_trial(competition_id: cid, extension: build_extension(name: 'b', invocation_count: 1))
      evolver.declare_winner(competition_id: cid)

      result = evolver.active_competitions
      expect(result[:count]).to eq(0)
    end
  end

  # ─── competition_history ────────────────────────────────────────────────

  describe '.competition_history' do
    it 'returns empty list when no competitions exist' do
      result = evolver.competition_history
      expect(result[:success]).to be true
      expect(result[:count]).to eq(0)
    end

    it 'returns competitions sorted by most recent first' do
      create_and_return_id(gap: 'first')
      _cid2 = create_and_return_id(gap: 'second')

      result = evolver.competition_history
      expect(result[:count]).to eq(2)
      expect(result[:competitions].first[:gap]).to eq('second')
    end

    it 'respects the limit parameter' do
      3.times { |i| create_and_return_id(gap: "gap-#{i}") }
      result = evolver.competition_history(limit: 2)
      expect(result[:count]).to eq(2)
    end

    it 'includes winner and trial_count for decided competitions' do
      cid = create_and_return_id
      evolver.run_trial(competition_id: cid, extension: build_extension(name: 'w', invocation_count: 1000))
      evolver.run_trial(competition_id: cid, extension: build_extension(name: 'l', invocation_count: 1))
      evolver.declare_winner(competition_id: cid)

      result = evolver.competition_history
      entry = result[:competitions].find { |c| c[:id] == cid }
      expect(entry[:winner]).to eq('w')
      expect(entry[:trial_count]).to eq(2)
    end
  end

  # ─── thread safety ─────────────────────────────────────────────────────

  describe 'thread safety' do
    it 'handles concurrent competition creation' do
      threads = 10.times.map do |i|
        Thread.new { evolver.create_competition(gap: "gap-#{i}", proposal_ids: %w[a b]) }
      end
      results = threads.map(&:value)
      expect(results.count { |r| r[:success] }).to eq(10)
      expect(evolver.competition_history[:count]).to eq(10)
    end
  end
end
