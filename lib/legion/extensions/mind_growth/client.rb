# frozen_string_literal: true

module Legion
  module Extensions
    module MindGrowth
      class Client
        def initialize; end

        # Proposer delegation
        def analyze_gaps(**)       = Runners::Proposer.analyze_gaps(**)
        def propose_concept(**)    = Runners::Proposer.propose_concept(**)
        def evaluate_proposal(**)  = Runners::Proposer.evaluate_proposal(**)
        def list_proposals(**)     = Runners::Proposer.list_proposals(**)
        def proposal_stats(**)     = Runners::Proposer.proposal_stats(**)

        # Analyzer delegation
        def cognitive_profile(**)    = Runners::Analyzer.cognitive_profile(**)
        def identify_weak_links(**)  = Runners::Analyzer.identify_weak_links(**)
        def recommend_priorities(**) = Runners::Analyzer.recommend_priorities(**)

        # Builder delegation
        def build_extension(**) = Runners::Builder.build_extension(**)
        def build_status(**)    = Runners::Builder.build_status(**)

        # Validator delegation
        def validate_proposal(**) = Runners::Validator.validate_proposal(**)
        def validate_scores(**)   = Runners::Validator.validate_scores(**)
        def validate_fitness(**)  = Runners::Validator.validate_fitness(**)

        # Orchestrator delegation
        def run_growth_cycle(**) = Runners::Orchestrator.run_growth_cycle(**)
        def growth_status(**)    = Runners::Orchestrator.growth_status(**)

        # Retrospective delegation
        def session_report(**)      = Runners::Retrospective.session_report(**)
        def trend_analysis(**)      = Runners::Retrospective.trend_analysis(**)
        def learning_extraction(**) = Runners::Retrospective.learning_extraction(**)
      end
    end
  end
end
