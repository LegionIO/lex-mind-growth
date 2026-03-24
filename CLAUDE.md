# lex-mind-growth

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Autonomous cognitive architecture expansion for LegionIO. Analyzes the current extension ecosystem against reference cognitive models, identifies capability gaps, proposes new extensions to fill them, evaluates proposals through a scoring pipeline, and manages a build pipeline for approved proposals. The build pipeline stages (scaffold, implement, test, validate, register) are currently stubbed — they delegate to `lex-codegen`, `legion-llm`, `lex-exec`, and `lex-metacognition` which are not yet implemented.

## Gem Info

- **Gem name**: `lex-mind-growth`
- **Version**: `0.1.9`
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
    phase_allocator.rb     # PhaseAllocator module — phase allocation heuristic for wiring
    composition_map.rb     # CompositionMap module — thread-safe composition rule storage
  runners/
    proposer.rb            # Proposer — gap analysis, proposal creation, evaluation
    analyzer.rb            # Analyzer — cognitive profile, weak link identification
    builder.rb             # Builder — build pipeline execution
    validator.rb           # Validator — proposal and score validation
    wirer.rb               # Wirer — auto-wiring extensions into tick phases
    integration_tester.rb  # IntegrationTester — tick simulation with wired extensions
    retrospective.rb       # Retrospective — session report, trend analysis, learning extraction
    governance.rb          # Governance — submit/vote/tally/approve/reject proposals
    risk_assessor.rb       # RiskAssessor — 4-dimension risk assessment with tiers
    monitor.rb             # Monitor — health check, usage stats, decay check, auto prune
    composer.rb            # Composer — cross-extension composition rules and evaluation
    dream_ideation.rb      # DreamIdeation — dream cycle integration for gap-based proposals
    evolver.rb             # Evolver — evolutionary pressure, improvement selection, merging
    dashboard.rb           # Dashboard — formatted data aggregation for UI
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

**Build pipeline**: `MAX_FIX_ATTEMPTS: 3`, `BUILD_TIMEOUT_MS: 600_000` (10 minutes)

**Reference cognitive models**: `[:global_workspace, :free_energy, :dual_process, :somatic_marker, :working_memory]`

**Governance**: `QUORUM: 3`, `REJECTION_COOLDOWN_HOURS: 24`, `GOVERNANCE_STATUSES: [:pending, :approved, :rejected, :expired]`

**Risk tiers**: `[:low, :medium, :high, :critical]` with `RISK_RECOMMENDATIONS: { low: :auto_approve, medium: :governance, high: :human_required, critical: :blocked }`

**Health levels**: `{ excellent: 0.8, good: 0.6, fair: 0.4, degraded: 0.2, critical: 0.0 }`

**Evolver**: `BOTTOM_PERCENTILE: 0.05`, `SPECIATION_DRIFT_THRESHOLD: 0.5`

## Key Classes

### `Helpers::ConceptProposal`

One proposed cognitive extension with full lifecycle tracking.

- `evaluate!(scores)` — sets `@scores`, `@evaluated_at`, transitions status to `:approved` or `:rejected` based on `passing_evaluation?`
- `passing_evaluation?` — all 5 dimensions must have scores >= `MIN_DIMENSION_SCORE` (0.6)
- `auto_approvable?` — all 5 dimensions >= `AUTO_APPROVE_THRESHOLD` (0.9)
- `transition!(new_status)` — validates against `PROPOSAL_STATUSES`, raises `ArgumentError` for invalid statuses; sets `@built_at` when status becomes `:passing`
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

- `advance!(result)` — no-ops if already `complete?` or `failed?`; if `result[:success]`, stores artifact and moves to next stage; if failure, records error and transitions to `:failed` after `MAX_FIX_ATTEMPTS` errors
- `complete?` / `failed?` — stage checks
- `duration_ms` — elapsed time since start

### `Helpers::PhaseAllocator`

Maps extension categories to tick phases. Used by `Runners::Wirer` to determine the appropriate tick phase for a given extension before wiring it into the cycle.

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
| `propose_concept` | `category: nil`, `description: nil`, `name: nil`, `enrich: true` | `{ success:, proposal: }` or `{ success: false, error: :redundant, similar_to:, score: }` |
| `evaluate_proposal` | `proposal_id:`, `scores: nil` | `{ success:, proposal:, approved:, auto_approved: }` |
| `list_proposals` | `status: nil`, `limit: 20` | `{ success:, proposals:, count: }` |
| `proposal_stats` | — | `{ success:, stats: }` |
| `get_proposal_object` | `id` | raw `ConceptProposal` object (used by Builder/Validator internally) |

When `existing_extensions` is nil, falls back to `Legion::Extensions::Metacognition::Helpers::Constants::SUBSYSTEMS` if defined, else `[]`.

Before creating a proposal, `propose_concept` runs a redundancy check against all existing proposals. Exact name matches are rejected immediately (score 1.0). When `legion-llm` is available, semantic similarity is checked by sending the new name/description and the last 20 existing proposals to the LLM; proposals with similarity score >= `REDUNDANCY_THRESHOLD` (0.8) are rejected with `error: :redundant`. Falls back to allowing the proposal when LLM is unavailable, returns unparseable output, or errors.

When `enrich: true` (default) and `legion-llm` is loaded and started, `propose_concept` uses the LLM to generate `helpers`, `runner_methods`, `metaphor`, and `rationale` from the description. This produces richer proposals that scaffold into meaningful extensions. Falls back silently to empty helpers/runner_methods when LLM is unavailable or returns unparseable output.

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
| `run_growth_cycle` | `existing_extensions: nil`, `base_path: nil`, `max_proposals: 3`, `force: false` | `{ success:, trace: }` |
| `growth_status` | — | `{ success:, proposals:, coverage:, model_coverage: }` |

`run_growth_cycle` chains the full autonomous growth loop: analyze gaps -> propose concepts -> evaluate proposals -> build approved extensions. Returns a detailed `trace` hash with step-by-step results. Each step records what happened so the agent can learn from its own build attempts.

**Auto-approve governance gate**: By default, only proposals with all dimension scores >= `AUTO_APPROVE_THRESHOLD` (0.9) are built automatically. Proposals that pass evaluation (>= 0.6) but don't meet the auto-approve threshold are held for governance review — the cycle succeeds but reports them as `held_for_review` in the evaluate step and `held` in the build step. Pass `force: true` to build all approved proposals regardless of auto-approve status. The evaluate step trace includes `auto_approved`, `approved` (held), and `rejected` counts.

### `Runners::Wirer`

| Method | Key Args | Returns |
|---|---|---|
| `analyze_fit` | `extension:` | fit analysis result |
| `wire_extension` | `extension:`, `phase:` | wiring result |
| `unwire_extension` | `extension:` | unwire result |
| `list_wired` | — | list of currently wired extensions |

### `Runners::IntegrationTester`

| Method | Key Args | Returns |
|---|---|---|
| `test_tick_with_extension` | `extension:`, `mode:` | tick simulation result |
| `test_cross_extension` | `extension_a:`, `extension_b:` | cross-extension test result |
| `benchmark_tick` | `with_extension:` | benchmark result |

### `Runners::Retrospective`

| Method | Key Args | Returns |
|---|---|---|
| `session_report` | — | full session summary |
| `trend_analysis` | — | trend data across sessions |
| `learning_extraction` | — | extracted learnings from session history |

### `Runners::Governance` (v0.1.7)

| Method | Key Args | Returns |
|---|---|---|
| `submit_proposal` | `proposal:` | `{ success:, proposal_id: }` |
| `vote_on_proposal` | `proposal_id:, voter_id:, vote:, rationale:` | `{ success:, vote: }` |
| `tally_votes` | `proposal_id:` | `{ success:, tally:, result: }` |
| `approve_proposal` | `proposal_id:` | `{ success:, proposal: }` |
| `reject_proposal` | `proposal_id:, reason:` | `{ success:, proposal: }` |
| `governance_stats` | — | `{ success:, stats: }` |

Thread-safe voting with Mutex. Quorum = 3. Tie votes resolve to :rejected.

### `Runners::RiskAssessor` (v0.1.7)

| Method | Key Args | Returns |
|---|---|---|
| `assess_risk` | `proposal:` | `{ success:, tier:, dimensions:, recommendation: }` |
| `risk_summary` | `proposals:` | `{ success:, summary: }` |

4 dimensions: complexity, blast_radius, reversibility, performance_impact. 4 tiers: low/medium/high/critical.

### `Runners::Monitor` (v0.1.8)

| Method | Key Args | Returns |
|---|---|---|
| `health_check` | `extension:` | `{ success:, fitness:, health_level:, alert: }` |
| `usage_stats` | `extensions:` | `{ success:, stats:, count: }` |
| `impact_score` | `extension:, extensions:` | `{ success:, impact:, rank_percentile: }` |
| `decay_check` | `extensions:` | `{ success:, decayed:, count: }` |
| `auto_prune` | `extensions:` | `{ success:, pruned:, count: }` |
| `health_summary` | `extensions:` | `{ success:, by_health_level:, alerts:, prune_candidates: }` |

Health levels: excellent (>=0.8), good (>=0.6), fair (>=0.4), degraded (>=0.2), critical (<0.2).

### `Runners::Composer` (v0.1.8)

| Method | Key Args | Returns |
|---|---|---|
| `add_composition` | `source_extension:, output_key:, target_extension:, target_method:` | `{ success:, rule_id: }` |
| `remove_composition` | `rule_id:` | `{ success: }` |
| `evaluate_output` | `source_extension:, output:` | `{ success:, dispatches:, count: }` |
| `composition_stats` | — | `{ success:, total_rules:, by_source:, by_target: }` |
| `suggest_compositions` | `extensions:` | `{ success:, suggestions:, count: }` |
| `list_compositions` | — | `{ success:, rules:, count: }` |

Uses Helpers::CompositionMap for thread-safe rule storage. Category-based suggestions with optional LLM enrichment.

### `Runners::DreamIdeation` (v0.1.8)

| Method | Key Args | Returns |
|---|---|---|
| `generate_dream_proposals` | `existing_extensions: nil, max_proposals: 2` | `{ success:, proposals:, count: }` |
| `dream_agenda_items` | `existing_extensions: nil` | `{ success:, items:, count: }` |
| `enrich_from_dream_context` | `proposal_id:, dream_context: {}` | `{ success:, enriched: }` |

Dream-originated proposals get tagged `origin: :dream` with DREAM_NOVELTY_BONUS (0.15) applied.

### `Runners::Evolver` (v0.1.9)

| Method | Key Args | Returns |
|---|---|---|
| `select_for_improvement` | `extensions:, count: 3` | `{ success:, candidates:, total_evaluated: }` |
| `propose_improvement` | `extension:` | `{ success:, weaknesses:, suggestions: }` |
| `replace_extension` | `old_name:, new_proposal_id:` | `{ success:, replaced: }` |
| `merge_extensions` | `extension_a:, extension_b:, merged_name: nil` | `{ success:, merged_proposal: }` |
| `evolution_summary` | `extensions:` | `{ success:, improvement_candidates:, fitness_distribution: }` |

Bottom 5% (BOTTOM_PERCENTILE) are candidates. Uses SUGGESTION_MAP for weakness-to-suggestion mapping. LLM-enhanced when available.

### `Runners::Dashboard` (v0.1.9)

| Method | Key Args | Returns |
|---|---|---|
| `extension_timeline` | `extensions:, days: 30` | `{ success:, series: }` |
| `category_distribution` | `extensions:` | `{ success:, distribution:, total: }` |
| `build_metrics` | — | `{ success:, total_proposals:, success_rate:, approval_rate: }` |
| `top_extensions` | `extensions:, limit: 10` | `{ success:, top: }` |
| `bottom_extensions` | `extensions:, limit: 10` | `{ success:, bottom: }` |
| `recent_proposals` | `limit: 10` | `{ success:, proposals:, count: }` |
| `full_dashboard` | `extensions:` | `{ success:, category_distribution:, build_metrics:, ... }` |

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

- All runners use `extend self` — they are module singletons, not class instances
- `Client` delegates to all fourteen runner modules (Proposer, Analyzer, Builder, Validator, Orchestrator, Wirer, IntegrationTester, Retrospective, Governance, RiskAssessor, Monitor, Composer, DreamIdeation, Evolver, Dashboard) via method forwarding (`def method(**) = Runners::Module.method(**)`)
- Build stages use graceful degradation: each checks `defined?()` for its dependency module and falls back to a stub if unavailable. All five stages are now wired — `implement` checks `Legion::LLM.started?` and falls back to a stub when legion-llm is not loaded or not started.
- `BUILD_TIMEOUT_MS = 600_000` is enforced: `advance!` checks `timed_out?` before processing and transitions to `:failed` when elapsed time exceeds the budget
- `propose_concept` when given no `name:` generates a random hex name (`lex-xxxxxxxx`); `derive_module_name` strips the `lex-` prefix and capitalizes segments (e.g., `lex-working-memory` -> `WorkingMemory`)
- `suggest_category` compares actual proposal category distribution against `TARGET_DISTRIBUTION` and picks the category with the largest gap; with no proposals, defaults to `:cognition` (highest target at 0.30)
- `enrich_proposal` uses `Legion::LLM` to generate helpers, runner_methods, metaphor, and rationale from the proposal description; parses the JSON response with graceful fallback to empty on parse errors or LLM unavailability
- `evaluate_proposal` uses a three-tier fallback: explicit `scores:` → LLM scoring via `score_with_llm` → default 0.7 scores. LLM scoring sends proposal context (name, category, description, metaphor, rationale, helpers, runner_methods) to `Legion::LLM.chat.ask` and parses the JSON response into dimension scores clamped to 0.0–1.0. Falls back to defaults on LLM unavailability, errors, malformed JSON, or incomplete scores (missing dimensions).
- `ProposalStore` max is 500 (`MAX_PROPOSALS` class constant) — enforced via LRU eviction of the oldest proposal by `created_at` when at capacity
- `BuildPipeline` exposes `artifacts` hash via `attr_reader` and `to_h` — each successful stage stores its result hash keyed by stage name
- `Orchestrator.propose_from_priorities` maps gap-analysis requirement names to cognitive categories via `REQUIREMENT_CATEGORIES` constant (23 mappings from the 5 reference cognitive models); unmapped requirements fall through to `suggest_category` auto-selection
- Governance uses thread-safe Mutex-protected vote storage with quorum=3 and tie-to-reject policy
- Monitor wraps FitnessEvaluator with health level classification (5 levels) and alert/auto-prune logic
- CompositionMap provides thread-safe rule storage with Mutex; Composer builds dispatch plans without executing them
- DreamIdeation integrates with lex-agentic-imagination dream cycle via defined?() guard (v0.1.7 hook)
- Evolver uses SUGGESTION_MAP hash for weakness-to-suggestion mapping; optional LLM enrichment via defined?() guard
- Dashboard aggregates data from Monitor, Proposer, Analyzer, and FitnessEvaluator into UI-ready formats
