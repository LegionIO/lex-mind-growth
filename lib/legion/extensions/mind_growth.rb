# frozen_string_literal: true

require 'securerandom'

require 'legion/extensions/mind_growth/version'
require 'legion/extensions/mind_growth/helpers/constants'
require 'legion/extensions/mind_growth/helpers/concept_proposal'
require 'legion/extensions/mind_growth/helpers/proposal_store'
require 'legion/extensions/mind_growth/helpers/cognitive_models'
require 'legion/extensions/mind_growth/helpers/build_pipeline'
require 'legion/extensions/mind_growth/helpers/fitness_evaluator'
require 'legion/extensions/mind_growth/runners/proposer'
require 'legion/extensions/mind_growth/runners/analyzer'
require 'legion/extensions/mind_growth/runners/builder'
require 'legion/extensions/mind_growth/runners/validator'
require 'legion/extensions/mind_growth/runners/orchestrator'
require 'legion/extensions/mind_growth/client'

module Legion
  module Extensions
    module MindGrowth
      extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core)
    end
  end
end
