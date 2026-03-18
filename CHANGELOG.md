# Changelog

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
