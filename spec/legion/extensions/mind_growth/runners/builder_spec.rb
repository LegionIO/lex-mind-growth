# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'securerandom'

RSpec.describe Legion::Extensions::MindGrowth::Runners::Builder do
  subject(:builder) { described_class }

  # Reset proposer store before each example
  before { Legion::Extensions::MindGrowth::Runners::Proposer.instance_variable_set(:@proposal_store, nil) }

  let(:proposal_id) do
    result = Legion::Extensions::MindGrowth::Runners::Proposer.propose_concept(
      name: 'lex-buildable', category: :cognition, description: 'a buildable proposal'
    )
    result[:proposal][:id]
  end

  describe '.build_extension' do
    it 'returns not_found for unknown proposal_id' do
      result = builder.build_extension(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'returns success when proposal exists' do
      result = builder.build_extension(proposal_id: proposal_id)
      expect(result[:success]).to be true
    end

    it 'returns pipeline hash' do
      result = builder.build_extension(proposal_id: proposal_id)
      expect(result[:pipeline]).to be_a(Hash)
      expect(result[:pipeline][:stage]).to eq(:complete)
    end

    it 'returns proposal hash' do
      result = builder.build_extension(proposal_id: proposal_id)
      expect(result[:proposal]).to be_a(Hash)
    end

    it 'transitions proposal to :passing on success' do
      builder.build_extension(proposal_id: proposal_id)
      list = Legion::Extensions::MindGrowth::Runners::Proposer.list_proposals
      p = list[:proposals].find { |pr| pr[:id] == proposal_id }
      expect(p[:status]).to eq(:passing)
    end

    it 'accepts optional base_path parameter' do
      result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
      expect(result[:success]).to be true
    end

    it 'ignores unknown keyword arguments' do
      expect { builder.build_extension(proposal_id: proposal_id, unknown: :value) }.not_to raise_error
    end
  end

  describe '.build_status' do
    it 'returns not_found for unknown proposal_id' do
      result = builder.build_status(proposal_id: 'nonexistent')
      expect(result[:success]).to be false
      expect(result[:error]).to eq(:not_found)
    end

    it 'returns status for existing proposal' do
      result = builder.build_status(proposal_id: proposal_id)
      expect(result[:success]).to be true
      expect(result[:name]).to eq('lex-buildable')
    end

    it 'returns current status symbol' do
      result = builder.build_status(proposal_id: proposal_id)
      expect(result[:status]).to be_a(Symbol)
    end
  end

  describe 'stage stubs (no dependencies loaded)' do
    it 'progresses through all pipeline stages without error' do
      result = builder.build_extension(proposal_id: proposal_id)
      pipeline = result[:pipeline]
      expect(pipeline[:errors]).to be_empty
      expect(pipeline[:stage]).to eq(:complete)
    end
  end

  describe 'wired stages' do
    describe 'scaffold_stage with codegen' do
      before do
        stub_const('Legion::Extensions::Codegen::Runners::Generate', Module.new)
        stub_const('Legion::Extensions::Codegen::Runners::Validate', Module.new)
        allow(Legion::Extensions::Codegen::Runners::Generate).to receive(:scaffold_extension)
          .and_return({ success: true, path: '/tmp/lex-buildable', files_created: 12, name: 'lex-buildable' })
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_structure)
          .and_return({ valid: true, missing: [], present: %w[Gemfile] })
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_gemspec)
          .and_return({ valid: true, issues: [] })
      end

      it 'delegates scaffold to codegen' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Codegen::Runners::Generate).to have_received(:scaffold_extension)
          .with(hash_including(name: 'buildable', module_name: anything, base_path: '/tmp'))
      end

      it 'passes proposal fields to codegen' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Codegen::Runners::Generate).to have_received(:scaffold_extension)
          .with(hash_including(description: 'a buildable proposal', category: :cognition))
      end

      it 'strips lex- prefix from name before passing to codegen' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Codegen::Runners::Generate).to have_received(:scaffold_extension)
          .with(hash_including(name: 'buildable'))
      end

      it 'pipeline completes when codegen succeeds' do
        result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(result[:pipeline][:stage]).to eq(:complete)
      end

      it 'pipeline fails when scaffold fails' do
        allow(Legion::Extensions::Codegen::Runners::Generate).to receive(:scaffold_extension)
          .and_return({ success: false, error: 'disk full' })
        result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(result[:success]).to be false
        expect(result[:pipeline][:errors]).not_to be_empty
      end
    end

    describe 'test_stage with exec' do
      before do
        stub_const('Legion::Extensions::Exec::Runners::Bundler', Module.new)
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:install)
          .and_return({ success: true, stdout: '', stderr: '', exit_code: 0 })
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:exec_rspec)
          .and_return({ success: true, parsed: { examples: 10, failures: 0, pending: 0, passed: 10 } })
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:exec_rubocop)
          .and_return({ success: true, parsed: { files: 5, offenses: 0, clean: true } })
      end

      it 'runs install, rspec, and rubocop' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Exec::Runners::Bundler).to have_received(:install)
        expect(Legion::Extensions::Exec::Runners::Bundler).to have_received(:exec_rspec)
        expect(Legion::Extensions::Exec::Runners::Bundler).to have_received(:exec_rubocop)
      end

      it 'pipeline fails when rspec has failures' do
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:exec_rspec)
          .and_return({ success: true, parsed: { examples: 10, failures: 2, pending: 0, passed: 8 } })
        result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(result[:success]).to be false
      end

      it 'pipeline fails when bundle install fails' do
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:install)
          .and_return({ success: false, stderr: 'gem not found', exit_code: 1 })
        result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(result[:success]).to be false
      end

      it 'does not run rspec if install fails' do
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:install)
          .and_return({ success: false, stderr: 'error', exit_code: 1 })
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Exec::Runners::Bundler).not_to have_received(:exec_rspec)
      end
    end

    describe 'validate_stage with codegen validators' do
      before do
        stub_const('Legion::Extensions::Codegen::Runners::Generate', Module.new)
        stub_const('Legion::Extensions::Codegen::Runners::Validate', Module.new)
        allow(Legion::Extensions::Codegen::Runners::Generate).to receive(:scaffold_extension)
          .and_return({ success: true, path: '/tmp/lex-buildable', files_created: 12 })
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_structure)
          .and_return({ valid: true, missing: [], present: %w[Gemfile .rubocop.yml] })
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_gemspec)
          .and_return({ valid: true, issues: [] })
      end

      it 'calls structure and gemspec validators' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Codegen::Runners::Validate).to have_received(:validate_structure)
        expect(Legion::Extensions::Codegen::Runners::Validate).to have_received(:validate_gemspec)
      end

      it 'fails when structure is invalid' do
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_structure)
          .and_return({ valid: false, missing: ['Gemfile'], present: [] })
        result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(result[:success]).to be false
      end
    end

    describe 'register_stage with metacognition registry' do
      before do
        stub_const('Legion::Extensions::Metacognition::Runners::Registry', Module.new)
        allow(Legion::Extensions::Metacognition::Runners::Registry).to receive(:register_extension)
          .and_return({ success: true, name: 'lex-buildable', category: 'cognition' })
      end

      it 'registers the extension' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Metacognition::Runners::Registry).to have_received(:register_extension)
          .with(hash_including(name: 'lex-buildable', category: 'cognition'))
      end

      it 'passes module_name and description' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(Legion::Extensions::Metacognition::Runners::Registry).to have_received(:register_extension)
          .with(hash_including(module_name: anything, description: 'a buildable proposal'))
      end
    end

    describe 'implement_stage with legion-llm' do
      let(:mock_chat) { double('RubyLLM::Chat') }
      let(:mock_response) { double('RubyLLM::Message', content: "# frozen_string_literal: true\n\n{ success: true }\n") }
      let(:ext_dir) { File.join(Dir.tmpdir, "lex-mind-growth-llm-test-#{SecureRandom.hex(4)}") }

      before do
        llm_mod = Module.new do
          def self.started? = true
          def self.chat(**) = nil
        end
        stub_const('Legion::LLM', llm_mod)
        allow(Legion::LLM).to receive(:chat).and_return(mock_chat)
        allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
        allow(mock_chat).to receive(:ask).and_return(mock_response)

        # Create a minimal scaffolded extension directory
        runner_dir = File.join(ext_dir, 'lex-buildable', 'lib', 'legion', 'extensions', 'buildable', 'runners')
        helper_dir = File.join(ext_dir, 'lex-buildable', 'lib', 'legion', 'extensions', 'buildable', 'helpers')
        FileUtils.mkdir_p(runner_dir)
        FileUtils.mkdir_p(helper_dir)
        File.write(File.join(runner_dir, 'example.rb'), "# frozen_string_literal: true\n\n{ success: true }\n")
        File.write(File.join(helper_dir, 'store.rb'), "# frozen_string_literal: true\n\nclass Store; end\n")
      end

      after { FileUtils.rm_rf(ext_dir) }

      it 'calls LLM for each target file' do
        builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        expect(mock_chat).to have_received(:ask).twice
      end

      it 'passes system instructions to chat' do
        builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        expect(mock_chat).to have_received(:with_instructions)
          .with(a_string_including('Ruby code generator')).at_least(:once)
      end

      it 'includes proposal description in prompt' do
        builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        expect(mock_chat).to have_received(:ask)
          .with(a_string_including('a buildable proposal')).at_least(:once)
      end

      it 'writes LLM output back to files' do
        allow(mock_response).to receive(:content).and_return("# frozen_string_literal: true\n\n# implemented\n")
        builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        runner_path = File.join(ext_dir, 'lex-buildable', 'lib', 'legion', 'extensions', 'buildable', 'runners', 'example.rb')
        expect(File.read(runner_path)).to include('# implemented')
      end

      it 'extracts code from markdown fences' do
        fenced = "Here's the code:\n```ruby\n# frozen_string_literal: true\n\nreal_code\n```\n"
        allow(mock_response).to receive(:content).and_return(fenced)
        builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        runner_path = File.join(ext_dir, 'lex-buildable', 'lib', 'legion', 'extensions', 'buildable', 'runners', 'example.rb')
        content = File.read(runner_path)
        expect(content).to include('real_code')
        expect(content).not_to include('```')
      end

      it 'skips version.rb and client.rb' do
        version_dir = File.join(ext_dir, 'lex-buildable', 'lib', 'legion', 'extensions', 'buildable')
        File.write(File.join(version_dir, 'version.rb'), "VERSION = '0.1.0'\n")
        File.write(File.join(version_dir, 'client.rb'), "class Client; end\n")
        builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        # Only runner/example.rb and helper/store.rb should be targets (2 calls)
        expect(mock_chat).to have_received(:ask).twice
      end

      it 'handles LLM errors gracefully' do
        allow(mock_chat).to receive(:ask).and_raise(StandardError, 'LLM timeout')
        result = builder.build_extension(proposal_id: proposal_id, base_path: ext_dir)
        expect(result[:pipeline][:errors]).not_to be_empty
      end

      it 'includes metaphor in prompt when present' do
        metaphor_id = Legion::Extensions::MindGrowth::Runners::Proposer.propose_concept(
          name: 'lex-metaphoric', category: :cognition, description: 'test metaphor'
        )[:proposal][:id]
        proposal_obj = Legion::Extensions::MindGrowth::Runners::Proposer.get_proposal_object(metaphor_id)
        proposal_obj.instance_variable_set(:@metaphor, 'like a garden')

        runner_dir = File.join(ext_dir, 'lex-metaphoric', 'lib', 'legion', 'extensions', 'metaphoric', 'runners')
        FileUtils.mkdir_p(runner_dir)
        File.write(File.join(runner_dir, 'grow.rb'), "# stub\n")

        builder.build_extension(proposal_id: metaphor_id, base_path: ext_dir)
        expect(mock_chat).to have_received(:ask).with(a_string_including('like a garden'))
      end
    end

    describe 'full wired pipeline' do
      before do
        stub_const('Legion::Extensions::Codegen::Runners::Generate', Module.new)
        stub_const('Legion::Extensions::Codegen::Runners::Validate', Module.new)
        stub_const('Legion::Extensions::Exec::Runners::Bundler', Module.new)
        stub_const('Legion::Extensions::Metacognition::Runners::Registry', Module.new)

        allow(Legion::Extensions::Codegen::Runners::Generate).to receive(:scaffold_extension)
          .and_return({ success: true, path: '/tmp/lex-buildable', files_created: 12 })
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:install)
          .and_return({ success: true })
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:exec_rspec)
          .and_return({ success: true, parsed: { examples: 5, failures: 0, pending: 0, passed: 5 } })
        allow(Legion::Extensions::Exec::Runners::Bundler).to receive(:exec_rubocop)
          .and_return({ success: true, parsed: { files: 3, offenses: 0, clean: true } })
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_structure)
          .and_return({ valid: true, missing: [], present: %w[Gemfile] })
        allow(Legion::Extensions::Codegen::Runners::Validate).to receive(:validate_gemspec)
          .and_return({ valid: true, issues: [] })
        allow(Legion::Extensions::Metacognition::Runners::Registry).to receive(:register_extension)
          .and_return({ success: true, name: 'lex-buildable' })
      end

      it 'completes all stages successfully' do
        result = builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        expect(result[:success]).to be true
        expect(result[:pipeline][:stage]).to eq(:complete)
        expect(result[:pipeline][:errors]).to be_empty
      end

      it 'transitions proposal to :passing' do
        builder.build_extension(proposal_id: proposal_id, base_path: '/tmp')
        proposal = Legion::Extensions::MindGrowth::Runners::Proposer.get_proposal_object(proposal_id)
        expect(proposal.status).to eq(:passing)
      end
    end
  end
end
