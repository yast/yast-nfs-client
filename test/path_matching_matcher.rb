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

        # RSpec 3 uses === while RSpec 2 uses ==
        # Thus, implementing just == should work with both
        def ==(other)
          return false unless other.is_a?(Yast::Path)
          other.to_s =~ @expected ? true : false
        end

        def description
          "path_matching(#{@expected})"
        end

        def inspect
          description
        end
      end
    end
  end
end
