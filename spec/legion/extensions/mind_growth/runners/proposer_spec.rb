# frozen_string_literal: true

RSpec.describe Legion::Extensions::MindGrowth::Runners::Proposer do
  subject(:proposer) { described_class }

  # Reset the memoized proposal store between examples
  before { proposer.instance_variable_set(:@proposal_store, nil) }

  describe '.analyze_gaps' do
    it 'returns success: true' do
      result = proposer.analyze_gaps
      expect(result[:success]).to be true
    end

    it 'returns models array' do
      result = proposer.analyze_gaps
      expect(result[:models]).to be_an(Array)
    end

    it 'returns recommendations array' do
      result = proposer.analyze_gaps
      expect(result[:recommendations]).to be_an(Array)
    end

    it 'accepts existing_extensions parameter' do
      result = proposer.analyze_gaps(existing_extensions: %i[attention memory])
      expect(result[:success]).to be true
    end

    it 'limits recommendations to 10' do
      result = proposer.analyze_gaps(existing_extensions: [])
      expect(result[:recommendations].size).to be <= 10
    end

    it 'ignores unknown keyword arguments' do
      expect { proposer.analyze_gaps(unknown_key: true) }.not_to raise_error
    end
  end

  describe '.propose_concept' do
    it 'returns success: true' do
      result = proposer.propose_concept(name: 'lex-test', category: :cognition, description: 'test')
      expect(result[:success]).to be true
    end

    it 'includes proposal hash' do
      result = proposer.propose_concept(name: 'lex-test', category: :cognition, description: 'test')
      expect(result[:proposal]).to be_a(Hash)
      expect(result[:proposal][:id]).to be_a(String)
    end

    it 'uses provided name' do
      result = proposer.propose_concept(name: 'lex-custom', category: :cognition, description: 'test')
      expect(result[:proposal][:name]).to eq('lex-custom')
    end

    it 'generates a name when none provided' do
      result = proposer.propose_concept(category: :cognition, description: 'test')
      expect(result[:proposal][:name]).to start_with('lex-')
    end

    it 'uses provided category' do
      result = proposer.propose_concept(name: 'lex-cat', category: :safety, description: 'test')
      expect(result[:proposal][:category]).to eq(:safety)
    end

    it 'falls back to suggested category when none given' do
      result = proposer.propose_concept(description: 'auto category')
      expect(Legion::Extensions::MindGrowth::Helpers::Constants::CATEGORIES).to include(result[:proposal][:category])
    end

    it 'suggests the most underrepresented category based on target distribution' do
      # With no proposals, cognition has the highest target (0.30) so it gets suggested
      result = proposer.propose_concept(description: 'first auto')
      expect(result[:proposal][:category]).to eq(:cognition)
    end

    it 'shifts suggestion after filling a category' do
      3.times { proposer.propose_concept(category: :cognition, description: 'cog') }
      result = proposer.propose_concept(description: 'next auto')
      # cognition is now overrepresented relative to target, so it should suggest something else
      expect(result[:proposal][:category]).not_to eq(:cognition)
    end

    it 'stores proposal in the proposal store' do
      result = proposer.propose_concept(name: 'lex-stored', category: :cognition, description: 'test')
      id     = result[:proposal][:id]
      stats  = proposer.proposal_stats
      expect(stats[:stats][:total]).to eq(1)
      get_result = proposer.list_proposals
      expect(get_result[:proposals].map { |p| p[:id] }).to include(id)
    end

    it 'derives module_name correctly from lex- prefixed name' do
      result = proposer.propose_concept(name: 'lex-working-memory', category: :memory, description: 'test')
      expect(result[:proposal][:module_name]).to eq('WorkingMemory')
    end

    it 'derives module_name from non-lex name' do
      result = proposer.propose_concept(name: 'emotion-engine', category: :cognition, description: 'test')
      expect(result[:proposal][:module_name]).to eq('EmotionEngine')
    end

    it 'derives module_name for generated names' do
      result = proposer.propose_concept(category: :cognition, description: 'auto named')
      expect(result[:proposal][:module_name]).to be_a(String)
      expect(result[:proposal][:module_name]).not_to include('-')
    end

    context 'with LLM enrichment' do
      let(:mock_chat) { double('RubyLLM::Chat') }
      let(:enrichment_json) do
        {
          metaphor:       'like a garden growing knowledge',
          rationale:      'fills the working memory gap',
          helpers:        [{ name: 'store', methods: [{ name: 'add', params: %w[key value] }] }],
          runner_methods: [{ name: 'update', params: ['tick_results'], returns: 'status hash' }]
        }.to_json
      end
      let(:mock_response) { double('RubyLLM::Message', content: enrichment_json) }

      before do
        llm_mod = Module.new do
          def self.started? = true
          def self.chat(**) = nil
        end
        stub_const('Legion::LLM', llm_mod)
        allow(Legion::LLM).to receive(:chat).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).and_return(mock_response)
      end

      it 'populates helpers from LLM response' do
        result = proposer.propose_concept(name: 'lex-enriched', category: :cognition, description: 'enriched')
        expect(result[:proposal][:helpers]).not_to be_empty
        expect(result[:proposal][:helpers].first[:name]).to eq('store')
      end

      it 'populates runner_methods from LLM response' do
        result = proposer.propose_concept(name: 'lex-enriched', category: :cognition, description: 'enriched')
        expect(result[:proposal][:runner_methods]).not_to be_empty
        expect(result[:proposal][:runner_methods].first[:name]).to eq('update')
      end

      it 'populates metaphor from LLM response' do
        result = proposer.propose_concept(name: 'lex-enriched', category: :cognition, description: 'enriched')
        expect(result[:proposal][:metaphor]).to eq('like a garden growing knowledge')
      end

      it 'populates rationale from LLM response' do
        result = proposer.propose_concept(name: 'lex-enriched', category: :cognition, description: 'enriched')
        expect(result[:proposal][:rationale]).to eq('fills the working memory gap')
      end

      it 'handles LLM errors gracefully' do
        allow(mock_chat).to receive(:ask).and_raise(StandardError, 'timeout')
        result = proposer.propose_concept(name: 'lex-fallback', category: :cognition, description: 'test')
        expect(result[:success]).to be true
        expect(result[:proposal][:helpers]).to eq([])
      end

      it 'handles malformed JSON gracefully' do
        allow(mock_response).to receive(:content).and_return('not json at all')
        result = proposer.propose_concept(name: 'lex-malformed', category: :cognition, description: 'test')
        expect(result[:success]).to be true
        expect(result[:proposal][:helpers]).to eq([])
      end

      it 'extracts JSON from markdown fences' do
        fenced = "```json\n#{enrichment_json}\n```"
        allow(mock_response).to receive(:content).and_return(fenced)
        result = proposer.propose_concept(name: 'lex-fenced', category: :cognition, description: 'test')
        expect(result[:proposal][:helpers]).not_to be_empty
      end
    end

    context 'without LLM' do
      it 'creates proposal with empty helpers when enrich: true but no LLM' do
        result = proposer.propose_concept(name: 'lex-nollm', category: :cognition, description: 'test')
        expect(result[:success]).to be true
        expect(result[:proposal][:helpers]).to eq([])
      end

      it 'skips enrichment when enrich: false' do
        result = proposer.propose_concept(name: 'lex-noenrich', category: :cognition, description: 'test', enrich: false)
        expect(result[:success]).to be true
        expect(result[:proposal][:helpers]).to eq([])
      end
    end

    context 'redundancy checking' do
      it 'rejects exact name duplicates' do
        proposer.propose_concept(name: 'lex-duplicate', category: :cognition, description: 'first')
        result = proposer.propose_concept(name: 'lex-duplicate', category: :cognition, description: 'second')
        expect(result[:success]).to be false
        expect(result[:error]).to eq(:redundant)
        expect(result[:similar_to]).to eq('lex-duplicate')
        expect(result[:score]).to eq(1.0)
      end

      it 'allows proposals with different names without LLM' do
        proposer.propose_concept(name: 'lex-alpha', category: :cognition, description: 'first')
        result = proposer.propose_concept(name: 'lex-beta', category: :cognition, description: 'second')
        expect(result[:success]).to be true
      end

      it 'allows first proposal without checking' do
        result = proposer.propose_concept(name: 'lex-first', category: :cognition, description: 'first')
        expect(result[:success]).to be true
      end

      context 'with LLM redundancy checking' do
        let(:mock_chat) { double('RubyLLM::Chat') }

        before do
          llm_mod = Module.new do
            def self.started? = true
            def self.chat(**) = nil
          end
          stub_const('Legion::LLM', llm_mod)
          allow(Legion::LLM).to receive(:chat).and_return(mock_chat)
        end

        it 'rejects semantically redundant proposals' do
          proposer.propose_concept(name: 'lex-working-mem', category: :memory, description: 'working memory management', enrich: false)
          redundancy_json = { redundant: true, similar_to: 'lex-working-mem', score: 0.92 }.to_json
          allow(mock_chat).to receive(:ask).and_return(double(content: redundancy_json))

          result = proposer.propose_concept(name: 'lex-work-memory', category: :memory, description: 'manages working memory')
          expect(result[:success]).to be false
          expect(result[:error]).to eq(:redundant)
          expect(result[:similar_to]).to eq('lex-working-mem')
          expect(result[:score]).to eq(0.92)
        end

        it 'allows non-redundant proposals detected by LLM' do
          proposer.propose_concept(name: 'lex-existing', category: :cognition, description: 'existing extension', enrich: false)
          not_redundant_json = { redundant: false, similar_to: nil, score: 0.3 }.to_json
          allow(mock_chat).to receive(:ask).and_return(double(content: not_redundant_json))

          result = proposer.propose_concept(name: 'lex-novel', category: :memory, description: 'totally novel', enrich: false)
          expect(result[:success]).to be true
        end

        it 'uses REDUNDANCY_THRESHOLD for the cutoff' do
          proposer.propose_concept(name: 'lex-base', category: :cognition, description: 'base extension', enrich: false)
          below_threshold = { redundant: false, similar_to: 'lex-base', score: 0.79 }.to_json
          allow(mock_chat).to receive(:ask).and_return(double(content: below_threshold))

          result = proposer.propose_concept(name: 'lex-similar', category: :cognition, description: 'similar', enrich: false)
          expect(result[:success]).to be true
        end

        it 'falls back to non-redundant when LLM returns malformed JSON' do
          proposer.propose_concept(name: 'lex-anchor', category: :cognition, description: 'anchor', enrich: false)
          allow(mock_chat).to receive(:ask).and_return(double(content: 'not json'))

          result = proposer.propose_concept(name: 'lex-different', category: :memory, description: 'different', enrich: false)
          expect(result[:success]).to be true
        end

        it 'falls back to non-redundant when LLM raises an error' do
          proposer.propose_concept(name: 'lex-safe', category: :cognition, description: 'safe', enrich: false)
          allow(mock_chat).to receive(:ask).and_raise(StandardError, 'timeout')

          result = proposer.propose_concept(name: 'lex-new', category: :memory, description: 'new', enrich: false)
          expect(result[:success]).to be true
        end

        it 'includes existing proposals in the redundancy prompt' do
          proposer.propose_concept(name: 'lex-ctx-test', category: :cognition, description: 'context test', enrich: false)
          not_redundant = { redundant: false, similar_to: nil, score: 0.1 }.to_json
          allow(mock_chat).to receive(:ask).and_return(double(content: not_redundant))

          proposer.propose_concept(name: 'lex-check-ctx', category: :memory, description: 'check', enrich: false)
          expect(mock_chat).to have_received(:ask).with(a_string_including('lex-ctx-test'))
          expect(mock_chat).to have_received(:ask).with(a_string_including('context test'))
        end

        it 'parses redundancy from markdown-fenced JSON' do
          proposer.propose_concept(name: 'lex-fenced-base', category: :cognition, description: 'base', enrich: false)
          fenced = "```json\n#{{ redundant: true, similar_to: 'lex-fenced-base', score: 0.85 }.to_json}\n```"
          allow(mock_chat).to receive(:ask).and_return(double(content: fenced))

          result = proposer.propose_concept(name: 'lex-fenced-dup', category: :cognition, description: 'dup')
          expect(result[:success]).to be false
          expect(result[:error]).to eq(:redundant)
        end

        it 'clamps redundancy score to 0.0-1.0' do
          proposer.propose_concept(name: 'lex-clamp-base', category: :cognition, description: 'base', enrich: false)
          clamped = { redundant: true, similar_to: 'lex-clamp-base', score: 1.5 }.to_json
          allow(mock_chat).to receive(:ask).and_return(double(content: clamped))

          result = proposer.propose_concept(name: 'lex-clamp-new', category: :cognition, description: 'new')
          expect(result[:success]).to be false
          expect(result[:score]).to eq(1.0)
        end

        it 'skips LLM check for exact name match (efficiency)' do
          proposer.propose_concept(name: 'lex-exact', category: :cognition, description: 'original', enrich: false)
          allow(mock_chat).to receive(:ask)
          result = proposer.propose_concept(name: 'lex-exact', category: :memory, description: 'different desc')
          expect(result[:error]).to eq(:redundant)
          expect(mock_chat).not_to have_received(:ask)
        end
      end
    end
  end

  describe '.evaluate_proposal' do
    let!(:proposal_id) do
      result = proposer.propose_concept(name: 'lex-eval', category: :cognition, description: 'to evaluate')
      result[:proposal][:id]
    end

    it 'returns not_found for unknown id' do
      result = proposer.evaluate_proposal(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'evaluates with default scores' do
      result = proposer.evaluate_proposal(proposal_id: proposal_id)
      expect(result[:success]).to be true
    end

    it 'evaluates with provided scores' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.8] }
      result = proposer.evaluate_proposal(proposal_id: proposal_id, scores: scores)
      expect(result[:success]).to be true
      expect(result[:approved]).to be true
    end

    it 'rejects when scores are below threshold' do
      scores = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.4] }
      result = proposer.evaluate_proposal(proposal_id: proposal_id, scores: scores)
      expect(result[:approved]).to be false
    end

    it 'returns proposal hash' do
      result = proposer.evaluate_proposal(proposal_id: proposal_id)
      expect(result[:proposal]).to be_a(Hash)
    end

    context 'with LLM scoring' do
      let(:mock_chat) { double('RubyLLM::Chat') }
      let(:score_json) do
        { novelty: 0.85, fit: 0.75, cognitive_value: 0.80, implementability: 0.90, composability: 0.70 }.to_json
      end
      let(:mock_response) { double('RubyLLM::Message', content: score_json) }

      before do
        llm_mod = Module.new do
          def self.started? = true
          def self.chat(**) = nil
        end
        stub_const('Legion::LLM', llm_mod)
        allow(Legion::LLM).to receive(:chat).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).and_return(mock_response)
      end

      it 'uses LLM scores when no explicit scores provided' do
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:success]).to be true
        expect(result[:proposal][:scores][:novelty]).to eq(0.85)
        expect(result[:proposal][:scores][:fit]).to eq(0.75)
      end

      it 'approves when LLM scores are above threshold' do
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:approved]).to be true
      end

      it 'rejects when LLM scores are below threshold' do
        low_scores = { novelty: 0.3, fit: 0.4, cognitive_value: 0.5, implementability: 0.2, composability: 0.1 }.to_json
        allow(mock_response).to receive(:content).and_return(low_scores)
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:approved]).to be false
      end

      it 'clamps scores to 0.0-1.0 range' do
        out_of_range = { novelty: 1.5, fit: -0.3, cognitive_value: 0.8, implementability: 2.0, composability: 0.7 }.to_json
        allow(mock_response).to receive(:content).and_return(out_of_range)
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:proposal][:scores][:novelty]).to eq(1.0)
        expect(result[:proposal][:scores][:fit]).to eq(0.0)
        expect(result[:proposal][:scores][:implementability]).to eq(1.0)
      end

      it 'prefers explicit scores over LLM scores' do
        explicit = Legion::Extensions::MindGrowth::Helpers::Constants::EVALUATION_DIMENSIONS.to_h { |d| [d, 0.65] }
        result = proposer.evaluate_proposal(proposal_id: proposal_id, scores: explicit)
        expect(result[:proposal][:scores][:novelty]).to eq(0.65)
        expect(mock_chat).not_to have_received(:ask)
      end

      it 'falls back to defaults when LLM returns malformed JSON' do
        allow(mock_response).to receive(:content).and_return('not valid json')
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:success]).to be true
        expect(result[:proposal][:scores][:novelty]).to eq(0.7)
      end

      it 'falls back to defaults when LLM returns incomplete scores' do
        partial = { novelty: 0.8, fit: 0.7 }.to_json
        allow(mock_response).to receive(:content).and_return(partial)
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:proposal][:scores][:novelty]).to eq(0.7)
      end

      it 'falls back to defaults when LLM raises an error' do
        allow(mock_chat).to receive(:ask).and_raise(StandardError, 'timeout')
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:success]).to be true
        expect(result[:proposal][:scores][:novelty]).to eq(0.7)
      end

      it 'parses scores from markdown-fenced JSON' do
        fenced = "```json\n#{score_json}\n```"
        allow(mock_response).to receive(:content).and_return(fenced)
        result = proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(result[:proposal][:scores][:novelty]).to eq(0.85)
      end

      it 'includes proposal context in the scoring prompt' do
        proposer.evaluate_proposal(proposal_id: proposal_id)
        expect(mock_chat).to have_received(:ask).with(a_string_including('lex-eval'))
        expect(mock_chat).to have_received(:ask).with(a_string_including('to evaluate'))
        expect(mock_chat).to have_received(:ask).with(a_string_including('cognition'))
      end
    end
  end

  describe '.list_proposals' do
    it 'returns success: true with empty store' do
      result = proposer.list_proposals
      expect(result[:success]).to be true
      expect(result[:proposals]).to be_an(Array)
    end

    it 'returns all proposals when no status filter' do
      proposer.propose_concept(name: 'lex-a', category: :cognition, description: 'a')
      proposer.propose_concept(name: 'lex-b', category: :memory, description: 'b')
      result = proposer.list_proposals
      expect(result[:count]).to eq(2)
    end

    it 'filters by status' do
      proposer.propose_concept(name: 'lex-filter', category: :cognition, description: 'filter')
      result = proposer.list_proposals(status: :proposed)
      expect(result[:proposals]).not_to be_empty
      result[:proposals].each do |p|
        expect(p[:status]).to eq(:proposed)
      end
    end

    it 'respects limit parameter' do
      5.times { |i| proposer.propose_concept(name: "lex-lim-#{i}", category: :cognition, description: "limit #{i}") }
      result = proposer.list_proposals(limit: 3)
      expect(result[:proposals].size).to be <= 3
    end
  end

  describe '.proposal_stats' do
    it 'returns success: true' do
      expect(proposer.proposal_stats[:success]).to be true
    end

    it 'includes total count' do
      proposer.propose_concept(name: 'lex-stat', category: :cognition, description: 'stat')
      expect(proposer.proposal_stats[:stats][:total]).to eq(1)
    end
  end
end
