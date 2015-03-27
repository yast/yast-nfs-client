require "rspec"
require "yast"

module RSpec
  module Mocks
    module ArgumentMatchers
      # ArgumentMatcher for Yast::Path allowing the use of regular expressions
      class PathMatchingMatcher
        def initialize(expected)
          @expected = Regexp.new(expected)
        end

        def ===(other)
          return false unless other.is_a?(Yast::Path)
          other.to_s =~ @expected ? true : false
        end

        def description
          "path_matching(#{@expected})"
        end
      end
    end
  end
end
