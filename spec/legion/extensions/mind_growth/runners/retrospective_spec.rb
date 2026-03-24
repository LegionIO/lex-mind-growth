# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Retrospective do
  subject(:retrospective) { described_class }

  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  describe '.session_report' do
    context 'with an empty proposal store' do
      it 'returns success: true' do
        result = retrospective.session_report
        expect(result[:success]).to be true
      end

      it 'includes a summary key' do
        result = retrospective.session_report
        expect(result).to have_key(:summary)
      end

      it 'summary includes total_proposals' do
        result = retrospective.session_report
        expect(result[:summary]).to have_key(:total_proposals)
      end

      it 'summary includes by_status' do
        result = retrospective.session_report
        expect(result[:summary]).to have_key(:by_status)
      end

      it 'summary includes recent_built' do
        result = retrospective.session_report
        expect(result[:summary]).to have_key(:recent_built)
      end

      it 'summary includes recent_failed' do
        result = retrospective.session_report
        expect(result[:summary]).to have_key(:recent_failed)
      end

      it 'summary includes in_progress' do
        result = retrospective.session_report
        expect(result[:summary]).to have_key(:in_progress)
      end

      it 'reports zero total_proposals for empty store' do
        result = retrospective.session_report
        expect(result[:summary][:total_proposals]).to eq(0)
      end

      it 'returns empty arrays for built, failed, and in_progress' do
        result = retrospective.session_report
        expect(result[:summary][:recent_built]).to eq([])
        expect(result[:summary][:recent_failed]).to eq([])
        expect(result[:summary][:in_progress]).to eq([])
      end

      it 'includes generated_at timestamp' do
        result = retrospective.session_report
        expect(result[:generated_at]).to be_a(Time)
      end
    end

    context 'with proposals in the store' do
      before do
        proposer = Legion::Extensions::MindGrowth::Runners::Proposer
        proposer.propose_concept(name: 'lex-in-progress', category: :cognition, description: 'in progress')
      end

      it 'reports the correct total_proposals count' do
        result = retrospective.session_report
        expect(result[:summary][:total_proposals]).to eq(1)
      end

      it 'includes proposed proposals in in_progress' do
        result = retrospective.session_report
        expect(result[:summary][:in_progress].size).to eq(1)
      end

      it 'in_progress entries include id, name, and status keys' do
        result = retrospective.session_report
        entry = result[:summary][:in_progress].first
        expect(entry).to have_key(:id)
        expect(entry).to have_key(:name)
        expect(entry).to have_key(:status)
      end

      it 'in_progress entry name matches the proposal name' do
        result = retrospective.session_report
        expect(result[:summary][:in_progress].first[:name]).to eq('lex-in-progress')
      end
    end

    context 'stubbing proposal data' do
      let(:proposal_stats) do
        { success: true, stats: { total: 5, by_status: { proposed: 2, approved: 1, build_failed: 1, active: 1 } } }
      end

      let(:list_result) do
        {
          success:   true,
          proposals: [
            { id: 'a1', name: 'lex-active', status: :active },
            { id: 'b2', name: 'lex-failed', status: :build_failed },
            { id: 'c3', name: 'lex-proposed', status: :proposed }
          ],
          count:     3
        }
      end

      before do
        allow(Legion::Extensions::MindGrowth::Runners::Proposer).to receive(:proposal_stats).and_return(proposal_stats)
        allow(Legion::Extensions::MindGrowth::Runners::Proposer).to receive(:list_proposals).and_return(list_result)
      end

      it 'categorises active proposals into recent_built' do
        result = retrospective.session_report
        expect(result[:summary][:recent_built].map { |p| p[:name] }).to include('lex-active')
      end

      it 'categorises build_failed proposals into recent_failed' do
        result = retrospective.session_report
        expect(result[:summary][:recent_failed].map { |p| p[:name] }).to include('lex-failed')
      end

      it 'categorises proposed proposals into in_progress' do
        result = retrospective.session_report
        expect(result[:summary][:in_progress].map { |p| p[:name] }).to include('lex-proposed')
      end

      it 'reflects total_proposals from proposal_stats' do
        result = retrospective.session_report
        expect(result[:summary][:total_proposals]).to eq(5)
      end
    end
  end

  describe '.trend_analysis' do
    context 'with no extensions' do
      it 'returns success: true' do
        result = retrospective.trend_analysis
        expect(result[:success]).to be true
      end

      it 'includes a snapshot key' do
        result = retrospective.trend_analysis
        expect(result).to have_key(:snapshot)
      end

      it 'snapshot includes extension_count' do
        result = retrospective.trend_analysis
        expect(result[:snapshot]).to have_key(:extension_count)
      end

      it 'snapshot includes overall_coverage' do
        result = retrospective.trend_analysis
        expect(result[:snapshot]).to have_key(:overall_coverage)
      end

      it 'snapshot includes avg_fitness' do
        result = retrospective.trend_analysis
        expect(result[:snapshot]).to have_key(:avg_fitness)
      end

      it 'snapshot includes healthy_extensions' do
        result = retrospective.trend_analysis
        expect(result[:snapshot]).to have_key(:healthy_extensions)
      end

      it 'snapshot includes prune_candidates' do
        result = retrospective.trend_analysis
        expect(result[:snapshot]).to have_key(:prune_candidates)
      end

      it 'snapshot includes improvement_candidates' do
        result = retrospective.trend_analysis
        expect(result[:snapshot]).to have_key(:improvement_candidates)
      end

      it 'reports zero extension_count when no extensions given' do
        result = retrospective.trend_analysis
        expect(result[:snapshot][:extension_count]).to eq(0)
      end

      it 'reports 0.0 avg_fitness when no extensions given' do
        result = retrospective.trend_analysis
        expect(result[:snapshot][:avg_fitness]).to eq(0.0)
      end

      it 'includes generated_at timestamp' do
        result = retrospective.trend_analysis
        expect(result[:generated_at]).to be_a(Time)
      end
    end

    context 'with extensions list' do
      let(:extensions) do
        [
          { name: 'lex-a', invocation_rate: 500, impact_score: 0.8, health: 0.9, error_rate: 0.0, avg_latency_ms: 100 },
          { name: 'lex-b', invocation_rate: 5,   impact_score: 0.2, health: 0.5, error_rate: 0.5, avg_latency_ms: 6000 },
          { name: 'lex-c', invocation_rate: 100, impact_score: 0.5, health: 0.7, error_rate: 0.1, avg_latency_ms: 200 }
        ]
      end

      it 'reports correct extension_count' do
        result = retrospective.trend_analysis(extensions: extensions)
        expect(result[:snapshot][:extension_count]).to eq(3)
      end

      it 'calculates avg_fitness as a Float' do
        result = retrospective.trend_analysis(extensions: extensions)
        expect(result[:snapshot][:avg_fitness]).to be_a(Float)
      end

      it 'avg_fitness is within 0.0–1.0 range' do
        result = retrospective.trend_analysis(extensions: extensions)
        expect(result[:snapshot][:avg_fitness]).to be_between(0.0, 1.0)
      end

      it 'calculates avg_fitness correctly from ranked extensions' do
        ranked = Legion::Extensions::MindGrowth::Helpers::FitnessEvaluator.rank(extensions)
        expected_avg = (ranked.sum { |e| e[:fitness] } / ranked.size).round(3)
        result = retrospective.trend_analysis(extensions: extensions)
        expect(result[:snapshot][:avg_fitness]).to eq(expected_avg)
      end

      it 'includes model_coverage array' do
        result = retrospective.trend_analysis(extensions: extensions)
        expect(result[:snapshot][:model_coverage]).to be_an(Array).or be_nil
      end

      it 'model_coverage entries include model and coverage keys when present' do
        result = retrospective.trend_analysis(extensions: extensions)
        next if result[:snapshot][:model_coverage].nil?

        result[:snapshot][:model_coverage].each do |entry|
          expect(entry).to have_key(:model)
          expect(entry).to have_key(:coverage)
        end
      end

      it 'improvement_candidates + healthy_extensions + prune_candidates sums to extension_count' do
        result = retrospective.trend_analysis(extensions: extensions)
        snapshot = result[:snapshot]
        total = snapshot[:healthy_extensions] + snapshot[:prune_candidates] + snapshot[:improvement_candidates]
        expect(total).to eq(snapshot[:extension_count])
      end
    end

    context 'stubbing analyzer' do
      let(:mock_profile) do
        {
          success:          true,
          total_extensions: 0,
          overall_coverage: 0.42,
          model_coverage:   [
            { model: :global_workspace, coverage: 0.6 },
            { model: :free_energy, coverage: 0.3 }
          ]
        }
      end

      before do
        allow(Legion::Extensions::MindGrowth::Runners::Analyzer)
          .to receive(:cognitive_profile)
          .and_return(mock_profile)
      end

      it 'reflects overall_coverage from analyzer' do
        result = retrospective.trend_analysis
        expect(result[:snapshot][:overall_coverage]).to eq(0.42)
      end
    end
  end

  describe '.learning_extraction' do
    context 'with an empty proposal store' do
      it 'returns success: true' do
        result = retrospective.learning_extraction
        expect(result[:success]).to be true
      end

      it 'includes a learnings key' do
        result = retrospective.learning_extraction
        expect(result).to have_key(:learnings)
      end

      it 'learnings includes total_analyzed' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:total_analyzed)
      end

      it 'learnings includes success_rate' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:success_rate)
      end

      it 'learnings includes rejection_rate' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:rejection_rate)
      end

      it 'learnings includes build_failure_rate' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:build_failure_rate)
      end

      it 'learnings includes category_stats' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:category_stats)
      end

      it 'learnings includes failure_patterns' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:failure_patterns)
      end

      it 'learnings includes recommendations' do
        result = retrospective.learning_extraction
        expect(result[:learnings]).to have_key(:recommendations)
      end

      it 'reports 0 total_analyzed for empty store' do
        result = retrospective.learning_extraction
        expect(result[:learnings][:total_analyzed]).to eq(0)
      end

      it 'reports 0.0 rates for empty store' do
        result = retrospective.learning_extraction
        expect(result[:learnings][:success_rate]).to eq(0.0)
        expect(result[:learnings][:rejection_rate]).to eq(0.0)
        expect(result[:learnings][:build_failure_rate]).to eq(0.0)
      end

      it 'returns empty failure_patterns for empty store' do
        result = retrospective.learning_extraction
        expect(result[:learnings][:failure_patterns]).to eq([])
      end

      it 'returns empty recommendations for empty store' do
        result = retrospective.learning_extraction
        expect(result[:learnings][:recommendations]).to eq([])
      end

      it 'includes generated_at timestamp' do
        result = retrospective.learning_extraction
        expect(result[:generated_at]).to be_a(Time)
      end
    end

    context 'with stubbed proposal data' do
      let(:proposals_with_failures) do
        cognition_fails = Array.new(4) { |i| { id: "f#{i}", name: "lex-cog-fail-#{i}", category: :cognition, status: :build_failed } }
        # 5 memory successes out of 5 => success_rate = 1.0 (> 0.8), triggers focus_category
        memory_successes = Array.new(5) { |i| { id: "s#{i}", name: "lex-mem-#{i}", category: :memory, status: :active } }
        cognition_fails + memory_successes
      end

      let(:list_result) { { success: true, proposals: proposals_with_failures, count: proposals_with_failures.size } }

      before do
        allow(Legion::Extensions::MindGrowth::Runners::Proposer)
          .to receive(:list_proposals)
          .and_return(list_result)
      end

      it 'computes total_analyzed correctly' do
        result = retrospective.learning_extraction
        expect(result[:learnings][:total_analyzed]).to eq(proposals_with_failures.size)
      end

      it 'computes success_rate correctly' do
        result = retrospective.learning_extraction
        # 5 active out of 9 total
        expect(result[:learnings][:success_rate]).to eq((5.0 / 9).round(3))
      end

      it 'computes rejection_rate correctly' do
        result = retrospective.learning_extraction
        # 0 rejected
        expect(result[:learnings][:rejection_rate]).to eq(0.0)
      end

      it 'computes build_failure_rate correctly' do
        result = retrospective.learning_extraction
        expect(result[:learnings][:build_failure_rate]).to eq((4.0 / 9).round(3))
      end

      it 'computes category_stats for cognition' do
        result = retrospective.learning_extraction
        cognition = result[:learnings][:category_stats][:cognition]
        expect(cognition[:total]).to eq(4)
        expect(cognition[:succeeded]).to eq(0)
        expect(cognition[:success_rate]).to eq(0.0)
      end

      it 'computes category_stats for memory' do
        result = retrospective.learning_extraction
        memory = result[:learnings][:category_stats][:memory]
        expect(memory[:total]).to eq(5)
        expect(memory[:succeeded]).to eq(5)
        expect(memory[:success_rate]).to eq(1.0)
      end

      it 'extracts failure_patterns for cognition' do
        result = retrospective.learning_extraction
        pattern = result[:learnings][:failure_patterns].find { |p| p[:category] == :cognition }
        expect(pattern).not_to be_nil
        expect(pattern[:failure_count]).to eq(4)
      end

      it 'failure_patterns are sorted by failure_count descending' do
        result = retrospective.learning_extraction
        counts = result[:learnings][:failure_patterns].map { |p| p[:failure_count] }
        expect(counts).to eq(counts.sort.reverse)
      end

      it 'generates avoid_category recommendation for high-failure cognition' do
        result = retrospective.learning_extraction
        rec = result[:learnings][:recommendations].find { |r| r[:type] == :avoid_category && r[:category] == :cognition }
        expect(rec).not_to be_nil
        expect(rec[:reason]).to include('0%')
      end

      it 'generates focus_category recommendation for high-success memory' do
        result = retrospective.learning_extraction
        rec = result[:learnings][:recommendations].find { |r| r[:type] == :focus_category && r[:category] == :memory }
        expect(rec).not_to be_nil
        expect(rec[:reason]).to include('%')
      end

      it 'generates investigate_failures recommendation when failures >= 3' do
        result = retrospective.learning_extraction
        rec = result[:learnings][:recommendations].find { |r| r[:type] == :investigate_failures && r[:category] == :cognition }
        expect(rec).not_to be_nil
        expect(rec[:reason]).to include('build failures')
      end
    end

    context 'recommendation thresholds' do
      let(:proposals_below_threshold) do
        # Only 2 failures — below the 3-failure threshold for investigate_failures
        Array.new(2) { |i| { id: "f#{i}", name: "lex-fail-#{i}", category: :safety, status: :build_failed } }
      end

      let(:list_result) { { success: true, proposals: proposals_below_threshold, count: 2 } }

      before do
        allow(Legion::Extensions::MindGrowth::Runners::Proposer)
          .to receive(:list_proposals)
          .and_return(list_result)
      end

      it 'does not generate investigate_failures recommendation for fewer than 3 failures' do
        result = retrospective.learning_extraction
        recs = result[:learnings][:recommendations].select { |r| r[:type] == :investigate_failures }
        expect(recs).to be_empty
      end

      it 'does not generate avoid_category for category with fewer than 3 total proposals' do
        result = retrospective.learning_extraction
        recs = result[:learnings][:recommendations].select { |r| r[:type] == :avoid_category }
        expect(recs).to be_empty
      end
    end
  end
end
