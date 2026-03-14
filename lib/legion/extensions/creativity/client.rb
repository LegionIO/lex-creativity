# frozen_string_literal: true

require 'legion/extensions/creativity/helpers/constants'
require 'legion/extensions/creativity/helpers/idea'
require 'legion/extensions/creativity/helpers/idea_store'
require 'legion/extensions/creativity/helpers/creative_engine'
require 'legion/extensions/creativity/runners/creativity'

module Legion
  module Extensions
    module Creativity
      class Client
        include Runners::Creativity

        attr_reader :creative_engine

        def initialize(creative_engine: nil, **)
          @creative_engine = creative_engine || Helpers::CreativeEngine.new
        end
      end
    end
  end
end
