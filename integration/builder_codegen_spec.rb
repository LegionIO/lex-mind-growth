# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

# Integration spec: tests the full wired pipeline with real lex-codegen.
# Requires lex-codegen to be loadable. Skips gracefully if not available.

begin
  require 'legion/extensions/codegen'
  CODEGEN_LOADED = true
rescue LoadError
  CODEGEN_LOADED = false
end

RSpec.describe 'Builder + Codegen Integration', :integration, skip: (CODEGEN_LOADED ? false : 'lex-codegen not available') do
  let(:builder) { Legion::Extensions::MindGrowth::Runners::Builder }
  let(:proposer) { Legion::Extensions::MindGrowth::Runners::Proposer }
  let(:tmpdir) { Dir.mktmpdir('mind-growth-integration') }

  before { proposer.instance_variable_set(:@proposal_store, nil) }
  after { FileUtils.rm_rf(tmpdir) }

  let(:proposal_id) do
    result = proposer.propose_concept(
      name:        'lex-test-cognition',
      category:    :cognition,
      description: 'Integration test extension for cognitive processing'
    )
    result[:proposal][:id]
  end

  it 'scaffolds a real extension via codegen' do
    result = builder.build_extension(proposal_id: proposal_id, base_path: tmpdir)

    expect(result[:success]).to be true
    expect(result[:pipeline][:stage]).to eq(:complete)

    ext_dir = File.join(tmpdir, 'lex-test-cognition')
    expect(Dir.exist?(ext_dir)).to be true
    expect(File.exist?(File.join(ext_dir, 'lex-test-cognition.gemspec'))).to be true
    expect(File.exist?(File.join(ext_dir, 'Gemfile'))).to be true
    expect(File.exist?(File.join(ext_dir, '.rubocop.yml'))).to be true
    expect(File.exist?(File.join(ext_dir, 'spec', 'spec_helper.rb'))).to be true
  end

  it 'scaffolds with helpers and runner_methods from proposal' do
    # Create a proposal with structured helpers and runners
    proposal_result = proposer.propose_concept(
      name:        'lex-test-structured',
      category:    :perception,
      description: 'Structured integration test'
    )
    pid = proposal_result[:proposal][:id]

    # Get the raw proposal and set helpers/runner_methods
    proposal = proposer.get_proposal_object(pid)
    proposal.instance_variable_set(:@helpers, [{ name: 'signal_filter', methods: [] }])
    proposal.instance_variable_set(:@runner_methods, [{ name: 'filter_signals', params: %w[signals:], returns: 'Hash' }])

    result = builder.build_extension(proposal_id: pid, base_path: tmpdir)
    expect(result[:success]).to be true

    ext_dir = File.join(tmpdir, 'lex-test-structured')
    expect(File.exist?(File.join(ext_dir, 'lib', 'legion', 'extensions', 'test_structured', 'helpers', 'signal_filter.rb'))).to be true
    expect(File.exist?(File.join(ext_dir, 'lib', 'legion', 'extensions', 'test_structured', 'runners', 'filter_signals.rb'))).to be true
  end

  it 'validate stage passes on codegen-scaffolded extension' do
    result = builder.build_extension(proposal_id: proposal_id, base_path: tmpdir)
    # Validate stage should pass since codegen generates valid structure
    validate_step = result[:pipeline][:stage]
    expect(validate_step).to eq(:complete)
    expect(result[:pipeline][:errors]).to be_empty
  end
end
