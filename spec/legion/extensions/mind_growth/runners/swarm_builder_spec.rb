# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::SwarmBuilder do
  subject(:swarm_builder) { described_class }

  # ─── helpers ──────────────────────────────────────────────────────────────

  def stub_swarm_available
    stub_const('Legion::Extensions::Swarm::Runners::Swarm',     Module.new)
    stub_const('Legion::Extensions::Swarm::Runners::Workspace', Module.new)
  end

  def stub_create_swarm(charter_id: 'charter-abc-123')
    allow(Legion::Extensions::Swarm::Runners::Swarm).to receive(:create_swarm)
      .and_return({ success: true, charter: { id: charter_id } })
    allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
      .and_return({ success: true, version: 1 })
    charter_id
  end

  def stub_active_swarms(swarms = [])
    allow(Legion::Extensions::Swarm::Runners::Swarm).to receive(:active_swarms)
      .and_return({ success: true, swarms: swarms })
  end

  # ─── CHARTER_TYPES / ACTIVITY_ROLES ───────────────────────────────────────

  describe 'constants' do
    it 'defines CHARTER_TYPES as frozen array of symbols' do
      expect(described_class::CHARTER_TYPES).to contain_exactly(
        :concept_exploration, :parallel_build, :adversarial_review, :integration_sweep
      )
    end

    it 'maps concept_exploration to finder/reviewer/coordinator roles' do
      expect(described_class::ACTIVITY_ROLES[:concept_exploration])
        .to contain_exactly(:finder, :reviewer, :coordinator)
    end

    it 'maps parallel_build to fixer/validator/coordinator roles' do
      expect(described_class::ACTIVITY_ROLES[:parallel_build])
        .to contain_exactly(:fixer, :validator, :coordinator)
    end

    it 'maps adversarial_review to reviewer/fixer/coordinator roles' do
      expect(described_class::ACTIVITY_ROLES[:adversarial_review])
        .to contain_exactly(:reviewer, :fixer, :coordinator)
    end

    it 'maps integration_sweep to validator/fixer/coordinator roles' do
      expect(described_class::ACTIVITY_ROLES[:integration_sweep])
        .to contain_exactly(:validator, :fixer, :coordinator)
    end
  end

  # ─── create_build_swarm ───────────────────────────────────────────────────

  describe '.create_build_swarm' do
    context 'when lex-swarm is unavailable' do
      it 'returns success: false with reason: :swarm_unavailable' do
        result = swarm_builder.create_build_swarm(
          charter_type: :concept_exploration,
          objective:    'explore gaps'
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:swarm_unavailable)
      end
    end

    context 'when lex-swarm is available' do
      before { stub_swarm_available }

      it 'returns success: false for an invalid charter_type' do
        result = swarm_builder.create_build_swarm(
          charter_type: :unknown_type,
          objective:    'test'
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:invalid_charter_type)
      end

      it 'returns success: true for a valid charter_type' do
        stub_create_swarm
        result = swarm_builder.create_build_swarm(
          charter_type: :concept_exploration,
          objective:    'explore cognitive gaps'
        )
        expect(result[:success]).to be true
      end

      it 'returns the charter_id from lex-swarm' do
        id = stub_create_swarm(charter_id: 'my-charter-99')
        result = swarm_builder.create_build_swarm(
          charter_type: :parallel_build,
          objective:    'build in parallel'
        )
        expect(result[:charter_id]).to eq(id)
      end

      it 'returns the charter_type as a symbol' do
        stub_create_swarm
        result = swarm_builder.create_build_swarm(
          charter_type: :adversarial_review,
          objective:    'review proposals'
        )
        expect(result[:charter_type]).to eq(:adversarial_review)
      end

      it 'returns the correct roles for the charter type' do
        stub_create_swarm
        result = swarm_builder.create_build_swarm(
          charter_type: :integration_sweep,
          objective:    'sweep integrations'
        )
        expect(result[:roles]).to contain_exactly(:validator, :fixer, :coordinator)
      end

      it 'stores proposal_ids in the workspace' do
        stub_create_swarm(charter_id: 'cid-001')
        expect(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
          .with(hash_including(key: 'proposals', value: %w[p1 p2]))
          .and_return({ success: true, version: 1 })
        swarm_builder.create_build_swarm(
          charter_type: :parallel_build,
          objective:    'build',
          proposal_ids: %w[p1 p2]
        )
      end

      it 'delegates to Swarm.create_swarm with name and roles' do
        expect(Legion::Extensions::Swarm::Runners::Swarm).to receive(:create_swarm)
          .with(hash_including(name: 'mind-growth-concept_exploration', roles: %i[finder reviewer coordinator]))
          .and_return({ success: true, charter: { id: 'c1' } })
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
          .and_return({ success: true, version: 1 })
        swarm_builder.create_build_swarm(charter_type: :concept_exploration, objective: 'test')
      end

      it 'returns success: false when swarm creation fails' do
        allow(Legion::Extensions::Swarm::Runners::Swarm).to receive(:create_swarm)
          .and_return({ success: false })
        result = swarm_builder.create_build_swarm(
          charter_type: :parallel_build,
          objective:    'test'
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:swarm_creation_failed)
      end
    end
  end

  # ─── join_build_swarm ─────────────────────────────────────────────────────

  describe '.join_build_swarm' do
    context 'when lex-swarm is unavailable' do
      it 'returns success: false' do
        result = swarm_builder.join_build_swarm(
          charter_id: 'c1', agent_id: 'agent-1', role: :finder
        )
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:swarm_unavailable)
      end
    end

    context 'when lex-swarm is available' do
      before { stub_swarm_available }

      it 'delegates to Swarm.join_swarm' do
        expect(Legion::Extensions::Swarm::Runners::Swarm).to receive(:join_swarm)
          .with(charter_id: 'c1', agent_id: 'agent-1', role: :finder)
          .and_return({ success: true, joined: true })
        swarm_builder.join_build_swarm(charter_id: 'c1', agent_id: 'agent-1', role: :finder)
      end

      it 'returns the delegated result' do
        allow(Legion::Extensions::Swarm::Runners::Swarm).to receive(:join_swarm)
          .and_return({ success: true, joined: true })
        result = swarm_builder.join_build_swarm(
          charter_id: 'c1', agent_id: 'agent-1', role: :finder
        )
        expect(result[:success]).to be true
        expect(result[:joined]).to be true
      end
    end
  end

  # ─── execute_swarm_build ──────────────────────────────────────────────────

  describe '.execute_swarm_build' do
    context 'when lex-swarm is unavailable' do
      it 'returns success: false' do
        result = swarm_builder.execute_swarm_build(charter_id: 'c1', agent_id: 'a1')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:swarm_unavailable)
      end
    end

    context 'when lex-swarm is available' do
      before do
        stub_swarm_available
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_put)
          .and_return({ success: true, version: 1 })
      end

      def stub_charter_status(charter_id, name)
        allow(Legion::Extensions::Swarm::Runners::Swarm).to receive(:swarm_status)
          .with(charter_id: charter_id)
          .and_return({ success: true, status: :active, name: name })
      end

      it 'dispatches to concept_exploration for that charter type' do
        stub_charter_status('c1', 'mind-growth-concept_exploration')
        allow(Legion::Extensions::MindGrowth::Runners::Proposer).to receive(:analyze_gaps)
          .and_return({ success: true, recommendations: [] })
        result = swarm_builder.execute_swarm_build(charter_id: 'c1', agent_id: 'a1')
        expect(result[:success]).to be true
        expect(result[:charter_type]).to eq(:concept_exploration)
      end

      it 'dispatches to parallel_build for that charter type' do
        stub_charter_status('c2', 'mind-growth-parallel_build')
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .and_return({ success: false })
        result = swarm_builder.execute_swarm_build(charter_id: 'c2', agent_id: 'a1')
        expect(result[:success]).to be true
        expect(result[:charter_type]).to eq(:parallel_build)
      end

      it 'dispatches to adversarial_review for that charter type' do
        stub_charter_status('c3', 'mind-growth-adversarial_review')
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .and_return({ success: false })
        result = swarm_builder.execute_swarm_build(charter_id: 'c3', agent_id: 'a1')
        expect(result[:success]).to be true
        expect(result[:charter_type]).to eq(:adversarial_review)
      end

      it 'dispatches to integration_sweep for that charter type' do
        stub_charter_status('c4', 'mind-growth-integration_sweep')
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .and_return({ success: false })
        result = swarm_builder.execute_swarm_build(charter_id: 'c4', agent_id: 'a1')
        expect(result[:success]).to be true
        expect(result[:charter_type]).to eq(:integration_sweep)
      end

      it 'returns results as an array' do
        stub_charter_status('c5', 'mind-growth-parallel_build')
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_get)
          .and_return({ success: false })
        result = swarm_builder.execute_swarm_build(charter_id: 'c5', agent_id: 'a1')
        expect(result[:results]).to be_an(Array)
      end

      it 'returns unknown_charter_type when swarm name does not match' do
        stub_charter_status('c6', 'other-system-swarm')
        result = swarm_builder.execute_swarm_build(charter_id: 'c6', agent_id: 'a1')
        expect(result[:success]).to be false
        expect(result[:reason]).to eq(:unknown_charter_type)
      end
    end
  end

  # ─── complete_build_swarm ─────────────────────────────────────────────────

  describe '.complete_build_swarm' do
    context 'when lex-swarm is unavailable' do
      it 'returns success: false' do
        result = swarm_builder.complete_build_swarm(charter_id: 'c1')
        expect(result[:success]).to be false
      end
    end

    context 'when lex-swarm is available' do
      before { stub_swarm_available }

      it 'delegates to Swarm.complete_swarm' do
        expect(Legion::Extensions::Swarm::Runners::Swarm).to receive(:complete_swarm)
          .with(charter_id: 'c1', outcome: :success)
          .and_return({ success: true })
        swarm_builder.complete_build_swarm(charter_id: 'c1')
      end

      it 'passes custom outcome to complete_swarm' do
        expect(Legion::Extensions::Swarm::Runners::Swarm).to receive(:complete_swarm)
          .with(charter_id: 'c1', outcome: :failure)
          .and_return({ success: true })
        swarm_builder.complete_build_swarm(charter_id: 'c1', outcome: :failure)
      end
    end
  end

  # ─── swarm_build_status ───────────────────────────────────────────────────

  describe '.swarm_build_status' do
    context 'when lex-swarm is unavailable' do
      it 'returns success: false' do
        result = swarm_builder.swarm_build_status(charter_id: 'c1')
        expect(result[:success]).to be false
      end
    end

    context 'when lex-swarm is available' do
      before { stub_swarm_available }

      before do
        allow(Legion::Extensions::Swarm::Runners::Swarm).to receive(:swarm_status)
          .and_return({ success: true, status: :active })
        allow(Legion::Extensions::Swarm::Runners::Workspace).to receive(:workspace_list)
          .and_return({ success: true, entries: { 'proposals' => [], 'build_results' => [] } })
      end

      it 'returns success: true' do
        result = swarm_builder.swarm_build_status(charter_id: 'c1')
        expect(result[:success]).to be true
      end

      it 'returns the swarm status' do
        result = swarm_builder.swarm_build_status(charter_id: 'c1')
        expect(result[:status]).to eq(:active)
      end

      it 'returns workspace_keys as an array' do
        result = swarm_builder.swarm_build_status(charter_id: 'c1')
        expect(result[:workspace_keys]).to be_an(Array)
      end
    end
  end

  # ─── active_build_swarms ──────────────────────────────────────────────────

  describe '.active_build_swarms' do
    context 'when lex-swarm is unavailable' do
      it 'returns success: false' do
        result = swarm_builder.active_build_swarms
        expect(result[:success]).to be false
      end
    end

    context 'when lex-swarm is available' do
      before { stub_swarm_available }

      it 'returns success: true' do
        stub_active_swarms
        result = swarm_builder.active_build_swarms
        expect(result[:success]).to be true
      end

      it 'returns count of mind-growth swarms' do
        stub_active_swarms([
                             { name: 'mind-growth-parallel_build', id: 'c1' },
                             { name: 'other-swarm', id: 'c2' },
                             { name: 'mind-growth-adversarial_review', id: 'c3' }
                           ])
        result = swarm_builder.active_build_swarms
        expect(result[:count]).to eq(2)
      end

      it 'filters out non-mind-growth swarms' do
        stub_active_swarms([
                             { name: 'mind-growth-integration_sweep', id: 'c1' },
                             { name: 'unrelated-swarm', id: 'c2' }
                           ])
        result = swarm_builder.active_build_swarms
        names = result[:swarms].map { |s| s[:name] }
        expect(names).not_to include('unrelated-swarm')
      end

      it 'returns empty swarms array when no mind-growth swarms exist' do
        stub_active_swarms([{ name: 'other-system', id: 'c1' }])
        result = swarm_builder.active_build_swarms
        expect(result[:swarms]).to be_empty
        expect(result[:count]).to eq(0)
      end
    end
  end
end
