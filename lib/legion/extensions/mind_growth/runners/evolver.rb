# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      module Runners
        module Evolver
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers, false) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex, false)

          extend self

          BOTTOM_PERCENTILE          = 0.05
          SPECIATION_DRIFT_THRESHOLD = 0.5
          INELIGIBLE_STATUSES        = %i[building testing].freeze

          def select_for_improvement(extensions:, count: 3, **)
            exts = Array(extensions)
            return { success: true, candidates: [], count: 0, total_evaluated: 0 } if exts.empty?

            eligible = exts.reject { |e| INELIGIBLE_STATUSES.include?((e[:status] || :active).to_sym) }
            ranked   = Helpers::FitnessEvaluator.rank(eligible)
            bottom_n = ranked.last(count)

            { success: true, candidates: bottom_n, count: bottom_n.size, total_evaluated: eligible.size }
          end

          def propose_improvement(extension:, **)
            name     = extension[:name] || extension[:extension_name]
            fitness  = Helpers::FitnessEvaluator.fitness(extension)

            weaknesses = identify_weaknesses(extension)
            suggestions = generate_suggestions(weaknesses)

            if defined?(Legion::LLM) && Legion::LLM.respond_to?(:started?) && Legion::LLM.started?
              suggestions = llm_suggestions(name, fitness, weaknesses) || suggestions
            end

            { success: true, extension_name: name, fitness: fitness,
              weaknesses: weaknesses, suggestions: suggestions }
          end

          def replace_extension(old_name:, new_proposal_id:, **)
            status_store[old_name] = :pruned
            replacement_map[old_name] = new_proposal_id

            { success: true, replaced: old_name, replacement_proposal_id: new_proposal_id }
          end

          def merge_extensions(extension_a:, extension_b:, merged_name: nil, **)
            name_a = extension_a[:name] || extension_a[:extension_name]
            name_b = extension_b[:name] || extension_b[:extension_name]
            cat_a  = (extension_a[:category] || :cognition).to_sym
            merged = merged_name || "lex-merged-#{name_a.to_s.delete_prefix('lex-')}-#{name_b.to_s.delete_prefix('lex-')}"
            desc   = "Merged extension combining capabilities of #{name_a} and #{name_b}"

            proposal = Runners::Proposer.propose_concept(
              name:        merged,
              category:    cat_a,
              description: desc,
              enrich:      false
            )

            { success: true, merged_proposal: proposal, sources: [name_a, name_b] }
          end

          def evolution_summary(extensions:, **)
            exts = Array(extensions)

            improvement_candidates = select_for_improvement(extensions: exts, count: 5)[:candidates]

            prune_candidates = Helpers::FitnessEvaluator.prune_candidates(exts).map do |e|
              e[:name] || e[:extension_name]
            end

            speciation_candidates = exts.filter_map do |e|
              e[:name] || e[:extension_name] if (e[:drift_score] || 0.0) >= SPECIATION_DRIFT_THRESHOLD
            end

            fitnesses = exts.map { |e| Helpers::FitnessEvaluator.fitness(e) }

            distribution = if fitnesses.empty?
                             { min: 0.0, max: 0.0, mean: 0.0, median: 0.0 }
                           else
                             sorted = fitnesses.sort
                             mid    = sorted.size / 2
                             median = sorted.size.odd? ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2.0).round(3)
                             { min:    sorted.first.round(3),
                               max:    sorted.last.round(3),
                               mean:   (fitnesses.sum / fitnesses.size.to_f).round(3),
                               median: median }
                           end

            { success:                true,
              improvement_candidates: improvement_candidates,
              prune_candidates:       prune_candidates,
              speciation_candidates:  speciation_candidates,
              fitness_distribution:   distribution }
          end

          SUGGESTION_MAP = {
            low_invocations: 'improve wiring or broaden phase coverage',
            high_error_rate: 'add error handling and input validation',
            high_latency:    'optimize hot paths or add caching',
            low_impact:      'enrich output or add downstream connections'
          }.freeze

          private

          def identify_weaknesses(extension)
            weaknesses = []
            count = extension[:invocation_count] || 0
            error = extension[:error_rate]       || 0.0
            lat   = extension[:avg_latency_ms]   || 0
            imp   = extension[:impact_score]     || 0.5

            weaknesses << :low_invocations if count < Helpers::Constants::DECAY_INVOCATION_THRESHOLD
            weaknesses << :high_error_rate if error > 0.2
            weaknesses << :high_latency    if lat > 1000
            weaknesses << :low_impact      if imp < 0.3
            weaknesses
          end

          def generate_suggestions(weaknesses)
            suggestions = weaknesses.filter_map { |w| SUGGESTION_MAP[w] }
            suggestions.empty? ? ['review overall design for incremental improvements'] : suggestions
          end

          def llm_suggestions(name, fitness, weaknesses)
            # rubocop:disable Legion/HelperMigration/DirectLlm
            response = Legion::LLM.chat(
              caller: {
                extension: 'lex-mind-growth',
                operation: 'evolver',
                phase:     'suggest'
              }
            ).ask(improvement_prompt(name, fitness, weaknesses))
            # rubocop:enable Legion/HelperMigration/DirectLlm
            parse_llm_suggestions(response.content)
          rescue StandardError => _e
            nil
          end

          def improvement_prompt(name, fitness, weaknesses)
            <<~PROMPT
              The LegionIO cognitive extension "#{name}" has a fitness score of #{fitness.round(3)}.
              Identified weaknesses: #{weaknesses.join(', ')}.

              Provide 2-4 concrete improvement suggestions as a JSON array of strings.
              Example: ["suggestion one", "suggestion two"]
              Return ONLY the JSON array, no markdown fencing.
            PROMPT
          end

          def parse_llm_suggestions(content)
            cleaned = content.gsub(/```(?:json)?\s*\n?/, '').strip
            data = ::JSON.parse(cleaned)
            return nil unless data.is_a?(Array)

            data.map(&:to_s).reject(&:empty?)
          rescue ::JSON::ParserError => _e
            nil
          end

          def status_store
            @status_store ||= {}
          end

          def replacement_map
            @replacement_map ||= {}
          end
        end
      end
    end
  end
end
