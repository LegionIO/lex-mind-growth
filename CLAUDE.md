# lex-mind-growth

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Autonomous cognitive architecture expansion for LegionIO. Analyzes the current extension ecosystem against reference cognitive models, identifies capability gaps, proposes new extensions to fill them, evaluates proposals through a scoring pipeline, and manages a build pipeline for approved proposals. The build pipeline stages (scaffold, implement, test, validate, register) are currently stubbed — they delegate to `lex-codegen`, `legion-llm`, `lex-exec`, and `lex-metacognition` which are not yet implemented.

## Gem Info

- **Gem name**: `lex-mind-growth`
- **Version**: `0.1.0`
- **Module**: `Legion::Extensions::MindGrowth`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/mind_growth/
  version.rb
  helpers/
    constants.rb           # Proposal statuses, categories, evaluation dimensions, fitness weights
    concept_proposal.rb    # ConceptProposal class — one proposed cognitive extension
    proposal_store.rb      # ProposalStore — thread-safe proposal registry
    cognitive_models.rb    # CognitiveModels module — 5 reference models and gap analysis
    build_pipeline.rb      # BuildPipeline class — staged build with error tracking
    fitness_evaluator.rb   # FitnessEvaluator module — fitness scoring for live extensions
  runners/
    proposer.rb            # Proposer — gap analysis, proposal creation, evaluation
    analyzer.rb            # Analyzer — cognitive profile, weak link identification
    builder.rb             # Builder — build pipeline execution
    validator.rb           # Validator — proposal and score validation
  client.rb
```

## Key Constants

**Proposal lifecycle statuses**: `[:proposed, :evaluating, :approved, :rejected, :building, :testing, :passing, :wired, :active, :degraded, :pruned, :build_failed]`

**Cognitive categories**: `[:cognition, :perception, :introspection, :safety, :communication, :memory, :motivation, :coordination]`

**Target distribution** (desired category proportions):
- `cognition: 0.30`, `perception: 0.15`, `introspection: 0.12`, `safety: 0.12`
- `communication: 0.10`, `memory: 0.10`, `motivation: 0.06`, `coordination: 0.05`

**Evaluation dimensions**: `[:novelty, :fit, :cognitive_value, :implementability, :composability]`
- `MIN_DIMENSION_SCORE`: `0.6` — all dimensions must reach this for approval
- `AUTO_APPROVE_THRESHOLD`: `0.9` — all dimensions at this level = auto-approvable
- `REDUNDANCY_THRESHOLD`: `0.8`

**Fitness weights** for live extension scoring:
- `invocation_rate: 0.25`, `impact_score: 0.30`, `health: 0.25`
- `error_penalty: -0.15`, `latency_penalty: -0.05`
- `PRUNE_THRESHOLD`: `0.2`, `IMPROVEMENT_THRESHOLD`: `0.4`

**Build pipeline**: `MAX_FIX_ATTEMPTS: 3`, `BUILD_TIMEOUT_MS: 600_000` (10 minutes, defined but not enforced)

**Reference cognitive models**: `[:global_workspace, :free_energy, :dual_process, :somatic_marker, :working_memory]`

## Key Classes

### `Helpers::ConceptProposal`

One proposed cognitive extension with full lifecycle tracking.

- `evaluate!(scores)` — sets `@scores`, `@evaluated_at`, transitions status to `:approved` or `:rejected` based on `passing_evaluation?`
- `passing_evaluation?` — all 5 dimensions must have scores >= `MIN_DIMENSION_SCORE` (0.6)
- `auto_approvable?` — all 5 dimensions >= `AUTO_APPROVE_THRESHOLD` (0.9)
- `transition!(new_status)` — sets `@status`; sets `@built_at` when status becomes `:passing`
- Fields: `id` (UUID), `name`, `module_name`, `category`, `description`, `metaphor`, `helpers` (array of `{name:, methods:}`), `runner_methods` (array of `{name:, params:, returns:}`), `rationale`, `scores`, `status`, `origin`, `created_at`, `evaluated_at`, `built_at`

### `Helpers::ProposalStore`

Thread-safe proposal registry (Mutex-synchronized).

- `store(proposal)` / `get(id)` — basic CRUD
- `by_status(status)` / `by_category(category)` — filtered queries
- `approved` — proposals with `:approved` status
- `build_queue` — approved proposals sorted by mean score descending
- `recent(limit:)` — most recent proposals by `created_at`
- `stats` — `{ total:, by_status: }` hash

### `Helpers::CognitiveModels`

Reference cognitive model definitions and gap analysis.

Five models with required extension names:
- `global_workspace` (Baars): attention, global_workspace, broadcasting, working_memory, consciousness
- `free_energy` (Friston): prediction, free_energy, predictive_coding, belief_revision, active_inference, error_monitoring
- `dual_process` (Kahneman): intuition, dual_process, inhibition, executive_function, cognitive_control
- `somatic_marker` (Damasio): emotion, somatic_marker, interoception, appraisal, embodied_simulation
- `working_memory` (Baddeley): working_memory, episodic_buffer, attention, executive_function, cognitive_load

- `gap_analysis(existing_extensions)` — returns array of `{ model:, name:, coverage:, missing:, total_required: }`
- `recommend_from_gaps(gap_results)` — tallies missing requirements across models, returns sorted by frequency

### `Helpers::BuildPipeline`

Staged build with error accumulation.

Stages: `[:scaffold, :implement, :test, :validate, :register, :complete, :failed]`

- `advance!(result)` — if `result[:success]`, stores artifact and moves to next stage; if failure, records error and transitions to `:failed` after `MAX_FIX_ATTEMPTS` errors
- `complete?` / `failed?` — stage checks
- `duration_ms` — elapsed time since start

### `Helpers::FitnessEvaluator`

Scores live extensions by weighted formula.

- `fitness(extension)` — weighted sum using `FITNESS_WEIGHTS`; invocation uses log10 scale (0 = 0.0, 1000+ = 1.0); latency uses linear scale (5000ms = 1.0 penalty)
- `rank(extensions)` — adds `:fitness` key and sorts descending
- `prune_candidates(extensions)` — fitness < `PRUNE_THRESHOLD` (0.2)
- `improvement_candidates(extensions)` — fitness >= 0.2 and < `IMPROVEMENT_THRESHOLD` (0.4)

## Runners

### `Runners::Proposer`

| Method | Key Args | Returns |
|---|---|---|
| `analyze_gaps` | `existing_extensions: nil` | `{ success:, models:, recommendations: }` |
| `propose_concept` | `category: nil`, `description: nil`, `name: nil` | `{ success:, proposal: }` |
| `evaluate_proposal` | `proposal_id:`, `scores: nil` | `{ success:, proposal:, approved: }` |
| `list_proposals` | `status: nil`, `limit: 20` | `{ success:, proposals:, count: }` |
| `proposal_stats` | — | `{ success:, stats: }` |
| `get_proposal_object` | `id` | raw `ConceptProposal` object (used by Builder/Validator internally) |

When `existing_extensions` is nil, falls back to `Legion::Extensions::Metacognition::Helpers::Constants::SUBSYSTEMS` if defined, else `[]`.

### `Runners::Analyzer`

| Method | Key Args | Returns |
|---|---|---|
| `cognitive_profile` | `existing_extensions: nil` | `{ success:, total_extensions:, model_coverage:, overall_coverage: }` |
| `identify_weak_links` | `extensions: []` | `{ success:, weak_links:, count: }` |
| `recommend_priorities` | `existing_extensions: nil` | `{ success:, priorities:, rationale: }` |

### `Runners::Builder`

| Method | Key Args | Returns |
|---|---|---|
| `build_extension` | `proposal_id:`, `base_path: nil` | `{ success:, pipeline:, proposal: }` |
| `build_status` | `proposal_id:` | `{ success:, name:, status: }` |

Build stages delegate to real implementations when their dependencies are loaded:
- **scaffold**: delegates to `Legion::Extensions::Codegen::Runners::Generate.scaffold_extension` — generates the full extension file tree from the proposal's helpers and runner_methods
- **implement**: delegates to `Legion::LLM.chat` — reads each scaffolded runner/helper stub, sends it to the LLM with proposal context (description, category, metaphor), writes back the generated implementation. Skips `version.rb` and `client.rb`. Uses `with_instructions` for coding rules and `ask` for per-file prompts. Extracts code from markdown fences if the LLM wraps its response.
- **test**: delegates to `Legion::Extensions::Exec::Runners::Bundler` — runs `bundle install`, `bundle exec rspec`, and `bundle exec rubocop`
- **validate**: delegates to `Legion::Extensions::Codegen::Runners::Validate` — checks structure and gemspec
- **register**: delegates to `Legion::Extensions::Metacognition::Runners::Registry.register_extension`

When a dependency is not loaded, each stage falls back to a stub that returns `{ success: true }` with a message indicating what's needed. This enables incremental wiring — the pipeline works end-to-end as stubs and activates real behavior as dependencies become available.

### `Runners::Validator`

| Method | Key Args | Returns |
|---|---|---|
| `validate_proposal` | `proposal_id:` | `{ success:, valid:, issues:, proposal_id: }` |
| `validate_scores` | `scores:` | `{ success:, valid:, issues: }` |
| `validate_fitness` | `extensions:` | `{ success:, ranked:, prune_candidates:, improvement_candidates: }` |

### `Runners::Orchestrator`

| Method | Key Args | Returns |
|---|---|---|
| `run_growth_cycle` | `existing_extensions: nil`, `base_path: nil`, `max_proposals: 3` | `{ success:, trace: }` |
| `growth_status` | — | `{ success:, proposals:, coverage:, model_coverage: }` |

`run_growth_cycle` chains the full autonomous growth loop: analyze gaps -> propose concepts -> evaluate proposals -> build approved extensions. Returns a detailed `trace` hash with step-by-step results. Each step records what happened so the agent can learn from its own build attempts.

## Actors

### `Actor::GrowthCycle`

`Every 3600s` (1 hour). Calls `Runners::Orchestrator.run_growth_cycle`. Only `enabled?` when `lex-codegen` or `lex-exec` is loaded. `run_now?` is false — waits for first interval.

## Integration Points

- `analyze_gaps` should be run after the extension ecosystem changes to identify what to build next
- `propose_concept` followed by `evaluate_proposal` and `build_extension` is the full autonomous growth cycle
- `cognitive_profile` provides coverage metrics across all five reference cognitive models
- `identify_weak_links` and `prune_candidates` enable ecosystem health maintenance
- Builder depends on `Runners::Proposer.get_proposal_object` — Builder and Validator access proposals from Proposer's private store

## Development Notes

- All five runners use `extend self` — they are module singletons, not class instances
- `Client` delegates to all five runner modules via method forwarding (`def method(**) = Runners::Module.method(**)`)
- Build stages use graceful degradation: each checks `defined?()` for its dependency module and falls back to a stub if unavailable. All five stages are now wired — `implement` checks `Legion::LLM.started?` and falls back to a stub when legion-llm is not loaded or not started.
- `BUILD_TIMEOUT_MS = 600_000` is defined but not enforced — there is no actual timeout in `BuildPipeline`
- `propose_concept` when given no `name:` generates a random hex name (`lex-xxxxxxxx`) and a capitalized `module_name`
- `evaluate_proposal` with no `scores:` defaults all 5 dimensions to `0.7` — guarantees approval
- `ProposalStore` max is 500 (defined as class constant, not in Constants module) — no eviction, just a cap reference; the store does not actually enforce this limit in the current implementation
