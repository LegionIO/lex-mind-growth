# Changelog

## [Unreleased]

## [0.1.9] - 2026-03-24

### Added
- Phase 5.2 Evolutionary Pressure: `Runners::Evolver` module with five methods
- `select_for_improvement` — ranks all extensions by fitness and returns the bottom N; skips extensions in `:building` or `:testing` status
- `propose_improvement` — analyzes a low-scoring extension for weaknesses (low_invocations, high_error_rate, high_latency, low_impact) and returns targeted improvement suggestions; enriches via LLM when available
- `replace_extension` — marks an extension as `:pruned` in the status store and records its replacement proposal ID
- `merge_extensions` — proposes a new extension that combines two overlapping ones via `Proposer.propose_concept`
- `evolution_summary` — aggregates improvement candidates, prune candidates, speciation candidates, and fitness distribution (min/max/mean/median) for a set of extensions
- Phase 7.3 Dashboard Data: `Runners::Dashboard` module with seven methods
- `extension_timeline` — stub time series returning current extension count at today's date
- `category_distribution` — counts extensions per cognitive category; initialises all CATEGORIES to zero before counting
- `build_metrics` — reads `ProposalStore` stats and computes build success rate and approval rate
- `top_extensions` — returns the top N highest-fitness extensions with name, invocation_count, and fitness
- `bottom_extensions` — returns the bottom N lowest-fitness extensions (pruning candidates)
- `recent_proposals` — delegates to `Proposer.list_proposals` with configurable limit
- `full_dashboard` — aggregates all six sub-methods plus `Monitor.health_summary` and a UTC timestamp into one response
- Delegation for all twelve new public methods added to `Client`
- 57 new specs covering both runners with happy paths, edge cases, sorting correctness, and empty-input handling

## [0.1.8] - 2026-03-24

### Added
- Phase 5.1 Health Monitoring: `Runners::Monitor` module with six methods
- `health_check` — classifies a single extension's fitness into five health levels (excellent/good/fair/degraded/critical); sets alert flag for degraded or critical
- `usage_stats` — returns per-extension invocation count, error rate, and average latency for a list of extensions
- `impact_score` — extracts the impact component from an extension and computes rank percentile when a comparison list is provided
- `decay_check` — identifies extensions with fewer than `DECAY_INVOCATION_THRESHOLD` invocations or fitness below `PRUNE_THRESHOLD`
- `auto_prune` — delegates to `FitnessEvaluator.prune_candidates`; returns candidates (does not unwire)
- `health_summary` — full dashboard: per-health-level counts, alert list, and prune candidates for a set of extensions
- Phase 4.3 Composition Rules: `Helpers::CompositionMap` module with thread-safe rule storage and `Runners::Composer` module
- `CompositionMap` — stores composition rules keyed by UUID; supports add/remove/query by source/match against output hash; exposes stats
- `add_composition` / `remove_composition` — delegate to `CompositionMap`
- `evaluate_output` — finds matching rules for an extension's output and builds dispatch plans (no actual dispatch)
- `composition_stats` — returns total rules and per-source/per-target breakdowns
- `suggest_compositions` — heuristic category-flow suggestions (perception->cognition, cognition->memory, etc.) with LLM guard
- `list_compositions` — returns all stored rules with count
- Phase 1.3 Dream Ideation: `Runners::DreamIdeation` module with three methods
- `generate_dream_proposals` — runs gap analysis, creates proposals with `origin: :dream`, applies `DREAM_NOVELTY_BONUS`
- `dream_agenda_items` — formats agenda items compatible with Dream::Helpers::Agenda; weight based on category underrepresentation
- `enrich_from_dream_context` — injects dream-cycle associations into an existing proposal's rationale
- New constants in `Helpers::Constants`: `HEALTH_LEVELS`, `DECAY_INVOCATION_THRESHOLD`
- Delegation for all fifteen new public methods added to `Client`
- 88 new specs covering all three features with happy paths, edge cases, and thread safety

## [0.1.7] - 2026-03-24

### Added
- Phase 2.1 Proposal Governance: `Runners::Governance` module with six methods
- `submit_proposal` — validates proposal is in `:proposed` or `:evaluating` status, transitions to `:evaluating`
- `vote_on_proposal` — thread-safe voting (`:approve` / `:reject`) with Mutex-protected vote store
- `tally_votes` — counts approve/reject votes; returns `:pending` (below QUORUM=3), `:approved`, or `:rejected` verdict
- `approve_proposal` — transitions proposal to `:approved`
- `reject_proposal` — transitions proposal to `:rejected`, stores optional reason
- `governance_stats` — summarises total votes, per-proposal vote breakdown, and governance status counts
- Phase 2.2 Risk Assessment: `Runners::RiskAssessor` module with two methods
- `assess_risk` — evaluates four risk dimensions (complexity, blast_radius, reversibility, performance_impact) and returns a risk tier (`:low`/`:medium`/`:high`/`:critical`) with recommendation
- `risk_summary` — batch-assesses proposals (from store or explicit list), returns results grouped by tier
- New constants in `Helpers::Constants`: `QUORUM`, `REJECTION_COOLDOWN_HOURS`, `GOVERNANCE_STATUSES`, `RISK_TIERS`, `RISK_RECOMMENDATIONS`
- Delegation for all eight new runner methods added to `Client`
- 113 new specs covering both runners with happy paths, error cases, thread safety, quorum logic, risk tier matrix, and edge cases

## [0.1.6] - 2026-03-24

### Added
- Phase 5.3 Retrospective Analysis: `Runners::Retrospective` module with three methods
- `session_report` — generates a summary of growth activity (proposals by status, recent builds, failures, in-progress)
- `trend_analysis` — returns snapshot metrics (extension count, coverage, avg fitness, healthy/prune/improvement counts) suitable for time-series storage
- `learning_extraction` — identifies patterns from build failures (category stats, failure patterns, recommendations to avoid/focus/investigate categories)
- Delegation for all three methods added to `Client`
- 64 new specs covering all three runner methods with empty-store, live-data, and stub scenarios

## [0.1.5] - 2026-03-24

### Added
- Phase 4 auto-wiring for GAIA tick integration
- `Helpers::PhaseAllocator` — maps 23 cognitive categories to GAIA active tick phases and 8 dream cycle phases; method-name inference as fallback for unknown categories
- `Runners::Wirer` — wires/unwires/enables/disables built extensions into the GAIA tick cycle via a local registry and GAIA rediscovery; full analyze_fit before commit
- `Runners::IntegrationTester` — validates a wired extension is method-callable, returns a valid response, and completes within the 5000ms tick budget; benchmarks tick timing across N iterations
- Comprehensive specs for all three new files (155 new examples across phase_allocator, wirer, and integration_tester specs)

### Changed
- Add `caller:` identity parameters to all four LLM call sites in `runners/proposer.rb` and `runners/builder.rb` for cost attribution and routing: proposer uses phases `capability`, `score`, and `validate`; builder uses operation `build` with `intent: { capability: :reasoning }`

## [0.1.3] - 2026-03-22

### Changed
- Add legion-cache, legion-crypt, legion-data, legion-json, legion-logging, legion-settings, legion-transport as runtime dependencies
- Replace direct Legion::Logging calls with injected log helper in runners/builder, runners/orchestrator, runners/proposer
- Update spec_helper with real sub-gem helper stubs

## [0.1.2] - 2026-03-22

### Changed
- Tightened `legion-gaia` dev dependency to `>= 0.9.9`

## [0.1.1] - 2026-03-18

### Fixed
- Enforce `BUILD_TIMEOUT_MS` (600s) in `BuildPipeline#advance!` — pipeline now transitions to `:failed` with a timeout error when elapsed time exceeds the budget
- Added `timed_out?` predicate to `BuildPipeline`

## [0.1.0] - 2026-03-13

### Added
- Initial release: gap analysis, proposal creation, evaluation pipeline, build pipeline, fitness scoring
- Five reference cognitive models (global_workspace, free_energy, dual_process, somatic_marker, working_memory)
- LLM-enhanced proposal enrichment and evaluation scoring
- GrowthCycle periodic actor (hourly)
- Standalone Client
