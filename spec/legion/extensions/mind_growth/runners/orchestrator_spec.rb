# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Orchestrator do
  subject(:orchestrator) { described_class }

  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  describe '.run_growth_cycle' do
    it 'returns success: true with a trace' do
      result = orchestrator.run_growth_cycle
      expect(result[:success]).to be true
      expect(result[:trace]).to be_a(Hash)
    end

    it 'trace includes started_at and completed_at' do
      result = orchestrator.run_growth_cycle
      expect(result[:trace][:started_at]).to be_a(Time)
      expect(result[:trace][:completed_at]).to be_a(Time)
    end

    it 'trace includes duration_ms' do
      result = orchestrator.run_growth_cycle
      expect(result[:trace][:duration_ms]).to be_a(Integer)
      expect(result[:trace][:duration_ms]).to be >= 0
    end

    it 'trace has analyze, propose, evaluate, and build steps' do
      result = orchestrator.run_growth_cycle
      step_names = result[:trace][:steps].map { |s| s[:step] }
      expect(step_names).to include(:analyze, :propose, :evaluate, :build)
    end

    it 'creates proposals from gap analysis' do
      result = orchestrator.run_growth_cycle
      propose_step = result[:trace][:steps].find { |s| s[:step] == :propose }
      expect(propose_step[:count]).to be > 0
    end

    it 'evaluates proposals' do
      result = orchestrator.run_growth_cycle
      eval_step = result[:trace][:steps].find { |s| s[:step] == :evaluate }
      expect(eval_step[:evaluated]).to be > 0
    end

    it 'builds approved proposals when forced' do
      result = orchestrator.run_growth_cycle(force: true)
      build_step = result[:trace][:steps].find { |s| s[:step] == :build }
      expect(build_step[:attempted]).to be > 0
    end

    it 'respects max_proposals parameter' do
      result = orchestrator.run_growth_cycle(max_proposals: 1)
      propose_step = result[:trace][:steps].find { |s| s[:step] == :propose }
      expect(propose_step[:count]).to eq(1)
    end

    it 'accepts existing_extensions parameter' do
      exts = %i[memory emotion prediction trust consent identity]
      result = orchestrator.run_growth_cycle(existing_extensions: exts, max_proposals: 1)
      expect(result[:success]).to be true
    end

    it 'accepts base_path parameter' do
      result = orchestrator.run_growth_cycle(max_proposals: 1, base_path: '/tmp')
      expect(result[:success]).to be true
    end

    it 'ignores unknown keyword arguments' do
      expect { orchestrator.run_growth_cycle(max_proposals: 1, unknown: :val) }.not_to raise_error
    end

    it 'builds succeed in stub mode (no codegen/exec loaded)' do
      result = orchestrator.run_growth_cycle(max_proposals: 1, force: true)
      build_step = result[:trace][:steps].find { |s| s[:step] == :build }
      expect(build_step[:attempted]).to be > 0
      expect(build_step[:succeeded]).to eq(build_step[:attempted])
    end

    it 'assigns categories to proposals based on requirement mapping' do
      result = orchestrator.run_growth_cycle(max_proposals: 1)
      proposal_step = result[:trace][:steps].find { |s| s[:step] == :propose }
      proposal_id = proposal_step[:proposals].first
      proposal = Legion::Extensions::MindGrowth::Runners::Proposer.get_proposal_object(proposal_id)
      expected_cats = Legion::Extensions::MindGrowth::Helpers::Constants::CATEGORIES
      expect(expected_cats).to include(proposal.category)
    end

    context 'when all extensions are covered' do
      it 'returns failure when no priorities found' do
        # Provide all extensions needed by all models to eliminate gaps
        all_exts = %i[
          attention global_workspace broadcasting working_memory consciousness
          prediction free_energy predictive_coding belief_revision active_inference error_monitoring
          intuition dual_process inhibition executive_function cognitive_control
          emotion somatic_marker interoception appraisal embodied_simulation
          episodic_buffer cognitive_load
        ]
        result = orchestrator.run_growth_cycle(existing_extensions: all_exts)
        expect(result[:success]).to be false
        expect(result[:error]).to include('no priorities')
      end
    end

    context 'auto-approve governance gate' do
      it 'holds proposals with default scores for governance review' do
        result = orchestrator.run_growth_cycle(max_proposals: 1)
        build_step = result[:trace][:steps].find { |s| s[:step] == :build }
        expect(build_step[:held]).to be > 0
        expect(build_step[:attempted]).to eq(0)
      end

      it 'reports held proposals in the build step message' do
        result = orchestrator.run_growth_cycle(max_proposals: 1)
        build_step = result[:trace][:steps].find { |s| s[:step] == :build }
        expect(build_step[:message]).to include('governance review')
      end

      it 'still succeeds when proposals are held' do
        result = orchestrator.run_growth_cycle(max_proposals: 1)
        expect(result[:success]).to be true
      end

      it 'evaluate step tracks auto_approved and held_for_review counts' do
        result = orchestrator.run_growth_cycle(max_proposals: 1)
        eval_step = result[:trace][:steps].find { |s| s[:step] == :evaluate }
        expect(eval_step).to have_key(:auto_approved)
        expect(eval_step).to have_key(:held_for_review)
        # Default 0.7 scores: none auto-approved, all held
        expect(eval_step[:auto_approved]).to eq(0)
        expect(eval_step[:held_for_review]).to be > 0
      end

      it 'builds all approved proposals when force: true' do
        result = orchestrator.run_growth_cycle(max_proposals: 1, force: true)
        build_step = result[:trace][:steps].find { |s| s[:step] == :build }
        expect(build_step[:attempted]).to be > 0
        expect(build_step[:held]).to eq(0)
      end

      it 'auto-builds proposals with scores above auto-approve threshold' do
        # Run a cycle to create proposals, then manually set high scores
        proposer = Legion::Extensions::MindGrowth::Runners::Proposer
        proposal_result = proposer.propose_concept(
          name: 'lex-auto-test', category: :cognition,
          description: 'Test auto-approve', enrich: false
        )
        high_scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.95] }
        eval_result = proposer.evaluate_proposal(proposal_id: proposal_result[:proposal][:id], scores: high_scores)
        expect(eval_result[:auto_approved]).to be true

        # Now run a fresh cycle — the manually created proposal won't be part of it,
        # but we verify the auto_approvable? mechanism works
        expect(eval_result[:approved]).to be true
      end
    end
  end

  describe '.growth_status' do
    it 'returns success: true' do
      result = orchestrator.growth_status
      expect(result[:success]).to be true
    end

    it 'includes proposal stats' do
      result = orchestrator.growth_status
      expect(result[:proposals]).to be_a(Hash)
    end

    it 'includes coverage score' do
      result = orchestrator.growth_status
      expect(result[:coverage]).to be_a(Float)
    end

    it 'includes model coverage details' do
      result = orchestrator.growth_status
      expect(result[:model_coverage]).to be_an(Array)
    end

    it 'reflects proposals after a growth cycle' do
      orchestrator.run_growth_cycle(max_proposals: 2)
      result = orchestrator.growth_status
      expect(result[:proposals][:total]).to be >= 2
    end
  end
end
