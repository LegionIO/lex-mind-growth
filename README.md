# lex-mind-growth

A LegionIO cognitive architecture extension for autonomous cognitive expansion. Analyzes the current extension ecosystem against five reference cognitive models (Global Workspace, Free Energy Principle, Dual Process, Somatic Marker, Working Memory), identifies capability gaps, proposes new extensions to address them, evaluates proposals through a multi-dimensional scoring pipeline, and manages a staged build lifecycle for approved proposals.

## What It Does

Provides a four-phase growth loop for the cognitive architecture:

1. **Analyze** — compare loaded extensions against reference model requirements to find gaps
2. **Propose** — generate concept proposals for missing capabilities, scored on novelty, fit, cognitive value, implementability, and composability
3. **Build** — execute the staged build pipeline (scaffold, implement, test, validate, register)
4. **Validate** — confirm proposal structure and fitness of live extensions

Also evaluates the fitness of existing extensions based on invocation rate, impact, health, error rate, and latency — identifying candidates for pruning or improvement.

## Usage

```ruby
require 'lex-mind-growth'

client = Legion::Extensions::MindGrowth::Client.new

# Analyze gaps against reference cognitive models
client.analyze_gaps(existing_extensions: [:emotion, :memory, :prediction, :identity])
# => { success: true,
#      models: [
#        { model: :global_workspace, coverage: 0.2, missing: [:attention, :broadcasting, ...] },
#        { model: :free_energy, coverage: 0.17, missing: [:free_energy, :predictive_coding, ...] },
#        ...
#      ],
#      recommendations: [:attention, :working_memory, :executive_function, ...] }

# Full cognitive profile
client.cognitive_profile(existing_extensions: [:emotion, :memory])
# => { success: true, total_extensions: 2,
#      model_coverage: [...], overall_coverage: 0.15 }

# Propose a new extension concept
result = client.propose_concept(
  category:    :cognition,
  name:        'lex-attention',
  description: 'Selective attention filtering for sensory input prioritization'
)
# => { success: true, proposal: { id: "uuid...", name: "lex-attention",
#      category: :cognition, status: :proposed, ... } }

proposal_id = result[:proposal][:id]

# Validate the proposal structure
client.validate_proposal(proposal_id: proposal_id)
# => { success: true, valid: true, issues: [], proposal_id: "uuid..." }

# Evaluate with dimension scores (all must be >= 0.6 to approve)
client.evaluate_proposal(
  proposal_id: proposal_id,
  scores: {
    novelty:          0.8,
    fit:              0.9,
    cognitive_value:  0.85,
    implementability: 0.7,
    composability:    0.75
  }
)
# => { success: true, proposal: { status: :approved, ... }, approved: true }

# Build the approved extension (stages are currently stubs)
client.build_extension(proposal_id: proposal_id)
# => { success: true, pipeline: { stage: :complete, errors: [] }, proposal: { status: :passing } }

# List proposals by status
client.list_proposals(status: :approved)
# => { success: true, proposals: [...], count: 0 }

# Evaluate fitness of live extensions
client.validate_fitness(extensions: [
  { invocation_count: 500, impact_score: 0.8, health_score: 1.0, error_rate: 0.02, avg_latency_ms: 120 },
  { invocation_count: 5,   impact_score: 0.3, health_score: 0.6, error_rate: 0.3,  avg_latency_ms: 4000 }
])
# => { success: true, ranked: [...], prune_candidates: 1, improvement_candidates: 0 }
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
