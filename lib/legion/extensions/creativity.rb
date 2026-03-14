# frozen_string_literal: true

require 'legion/extensions/creativity/version'
require 'legion/extensions/creativity/helpers/constants'
require 'legion/extensions/creativity/helpers/idea'
require 'legion/extensions/creativity/helpers/idea_store'
require 'legion/extensions/creativity/helpers/creative_engine'
require 'legion/extensions/creativity/runners/creativity'
require 'legion/extensions/creativity/client'

module Legion
  module Extensions
    module Creativity
      extend Legion::Extensions::Core if Legion::Extensions.const_defined?(:Core)
    end
  end
end
