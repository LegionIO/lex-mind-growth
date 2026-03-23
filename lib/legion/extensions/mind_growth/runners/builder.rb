# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Builder
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          extend self

          def build_extension(proposal_id:, base_path: nil, **)
            proposal = find_proposal(proposal_id)
            return { success: false, error: :not_found } unless proposal

            pipeline = Helpers::BuildPipeline.new(proposal)
            proposal.transition!(:building)
            base_path ||= ::Dir.pwd

            run_stage(pipeline, :scaffold,  -> { scaffold_stage(proposal, base_path) })
            run_stage(pipeline, :implement, -> { implement_stage(proposal, base_path) }) unless pipeline.failed?
            run_stage(pipeline, :test,      -> { test_stage(proposal, base_path) }) unless pipeline.failed?
            run_stage(pipeline, :validate,  -> { validate_stage(proposal, base_path) }) unless pipeline.failed?
            run_stage(pipeline, :register,  -> { register_stage(proposal) }) unless pipeline.failed?

            proposal.transition!(pipeline.complete? ? :passing : :build_failed)
            log.info "[mind_growth:builder] #{proposal.name}: #{pipeline.stage}"
            { success: pipeline.complete?, pipeline: pipeline.to_h, proposal: proposal.to_h }
          rescue ArgumentError => e
            { success: false, error: e.message }
          end

          def build_status(proposal_id:, **)
            proposal = find_proposal(proposal_id)
            return { success: false, error: :not_found } unless proposal

            { success: true, name: proposal.name, status: proposal.status }
          end

          private

          def find_proposal(proposal_id)
            return nil unless defined?(Runners::Proposer) && Runners::Proposer.respond_to?(:get_proposal_object)

            Runners::Proposer.get_proposal_object(proposal_id)
          end

          def run_stage(pipeline, stage, callable)
            return if pipeline.stage != stage

            result = callable.call
            pipeline.advance!(result)
          end

          def ext_path(proposal, base_path)
            name = strip_lex_prefix(proposal.name)
            ::File.join(base_path, "lex-#{name}")
          end

          def strip_lex_prefix(name)
            name.to_s.sub(/\Alex-/, '')
          end

          # --- Scaffold Stage ---
          # Delegates to lex-codegen when loaded; stubs otherwise
          def scaffold_stage(proposal, base_path)
            return { success: true, stage: :scaffold, files: 0, message: 'scaffold requires lex-codegen' } unless codegen_available?

            name = strip_lex_prefix(proposal.name)
            result = Legion::Extensions::Codegen::Runners::Generate.scaffold_extension(
              name:           name,
              module_name:    proposal.module_name,
              description:    proposal.description || "#{proposal.name} cognitive extension",
              category:       proposal.category,
              helpers:        proposal.helpers || [],
              runner_methods: proposal.runner_methods || [],
              base_path:      base_path
            )

            { success: result[:success], stage: :scaffold, files: result[:files_created] || 0,
              path: result[:path], error: result[:error] }
          end

          # --- Implement Stage ---
          # Delegates to legion-llm when loaded and started; stubs otherwise
          def implement_stage(proposal, base_path)
            return { success: true, stage: :implement, message: 'implementation requires legion-llm' } unless llm_available?

            path = ext_path(proposal, base_path)
            target_files = implementation_targets(path)

            if target_files.empty?
              return { success: true, stage: :implement, files_implemented: 0,
                       message: 'no implementation targets found' }
            end

            files_implemented = 0
            errors = []

            target_files.each do |file_path|
              result = implement_file(file_path, proposal)
              if result[:success]
                files_implemented += 1
              else
                errors << "#{::File.basename(file_path)}: #{result[:error]}"
              end
            end

            success = errors.empty?
            { success: success, stage: :implement, files_implemented: files_implemented,
              total_files: target_files.size, error: success ? nil : errors.join('; ') }
          end

          # --- Test Stage ---
          # Delegates to lex-exec bundler runners when loaded; stubs otherwise
          def test_stage(proposal, base_path)
            return { success: true, stage: :test, message: 'testing requires lex-exec' } unless exec_available?

            path = ext_path(proposal, base_path)

            install = Legion::Extensions::Exec::Runners::Bundler.install(path: path)
            unless install[:success]
              return { success: false, stage: :test, step: :install,
                       error: install[:stderr] || install[:error] }
            end

            rspec   = Legion::Extensions::Exec::Runners::Bundler.exec_rspec(path: path)
            rubocop = Legion::Extensions::Exec::Runners::Bundler.exec_rubocop(path: path)

            rspec_ok   = rspec[:success] && (rspec.dig(:parsed, :failures) || 0).zero?
            rubocop_ok = rubocop[:success]

            errors = [
              (rspec_ok ? nil : "rspec: #{rspec[:parsed] || rspec[:stderr]}"),
              (rubocop_ok ? nil : "rubocop: #{rubocop[:parsed] || rubocop[:stderr]}")
            ].compact.join('; ')

            { success: rspec_ok && rubocop_ok, stage: :test,
              rspec: rspec[:parsed] || { raw: rspec[:stdout] },
              rubocop: rubocop[:parsed] || { raw: rubocop[:stdout] },
              error: errors.empty? ? nil : errors }
          end

          # --- Validate Stage ---
          # Delegates to lex-codegen validators when loaded; stubs otherwise
          def validate_stage(proposal, base_path)
            return { success: true, stage: :validate, message: 'validation requires lex-codegen' } unless codegen_available?

            path      = ext_path(proposal, base_path)
            structure = Legion::Extensions::Codegen::Runners::Validate.validate_structure(path: path)
            gemspec   = Legion::Extensions::Codegen::Runners::Validate.validate_gemspec(path: path)

            valid = structure[:valid] && gemspec[:valid]
            { success: valid, stage: :validate, structure: structure, gemspec: gemspec,
              error: valid ? nil : "structure: #{structure[:missing]}, gemspec: #{gemspec[:issues]}" }
          end

          # --- Register Stage ---
          # Delegates to lex-metacognition registry when loaded; stubs otherwise
          def register_stage(proposal)
            return { success: true, stage: :register, message: 'registration requires lex-metacognition registry' } unless registry_available?

            result = Legion::Extensions::Metacognition::Runners::Registry.register_extension(
              name:        proposal.name,
              module_name: proposal.module_name,
              category:    proposal.category.to_s,
              description: proposal.description
            )

            { success: result[:success], stage: :register, error: result[:error] }
          end

          # --- LLM implementation helpers ---
          def implementation_targets(path)
            runners = ::Dir.glob(::File.join(path, 'lib/**/runners/*.rb'))
            helpers = ::Dir.glob(::File.join(path, 'lib/**/helpers/*.rb'))
            (runners + helpers).reject { |f| f.end_with?('version.rb', 'client.rb') }
          end

          def implement_file(file_path, proposal)
            stub_content = ::File.read(file_path)

            chat = Legion::LLM.chat
            chat.with_instructions(implementation_instructions)
            response = chat.ask(file_implementation_prompt(stub_content, proposal))
            code = extract_ruby_code(response.content)

            ::File.write(file_path, code)
            { success: true, path: file_path }
          rescue StandardError => e
            { success: false, error: e.message }
          end

          def implementation_instructions
            <<~INSTRUCTIONS
              You are a Ruby code generator for LegionIO cognitive extensions.
              You receive a stub Ruby file and a description of the extension's purpose.
              Replace stub method bodies with real implementations.

              Rules:
              - Return ONLY the complete Ruby file content, no markdown fencing, no explanation
              - Keep the exact module/class/method structure and signatures
              - Keep `# frozen_string_literal: true` on line 1
              - Runner methods must return `{ success: true/false, ... }` hashes
              - Use in-memory state only (instance variables, no database, no external APIs)
              - Helper classes may use initialize for state setup
              - Follow Ruby style: 2-space indent, snake_case methods
              - Do not add require statements
              - Do not add comments unless the logic is non-obvious
            INSTRUCTIONS
          end

          def file_implementation_prompt(stub_content, proposal)
            parts = ['Implement this LegionIO extension file.']
            parts << "Extension: #{proposal.name}"
            parts << "Category: #{proposal.category}"
            parts << "Description: #{proposal.description}"
            parts << "Metaphor: #{proposal.metaphor}" if proposal.metaphor
            parts << ''
            parts << 'Current stub:'
            parts << stub_content
            parts.join("\n")
          end

          def extract_ruby_code(content)
            code = if content.match?(/```ruby\s*\n/)
                     content.match(/```ruby\s*\n(.*?)```/m)&.captures&.first || content
                   elsif content.match?(/```\s*\n/)
                     content.match(/```\s*\n(.*?)```/m)&.captures&.first || content
                   else
                     content
                   end
            "#{code.strip}\n"
          end

          # --- Dependency availability checks ---
          def codegen_available?
            defined?(Legion::Extensions::Codegen::Runners::Generate)
          end

          def exec_available?
            defined?(Legion::Extensions::Exec::Runners::Bundler)
          end

          def registry_available?
            defined?(Legion::Extensions::Metacognition::Runners::Registry)
          end

          def llm_available?
            defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
          end
        end
      end
    end
  end
end
