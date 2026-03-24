# Changelog

## [Unreleased]

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
