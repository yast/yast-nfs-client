# Copyright (c) 2015 SUSE Linux.
#  All Rights Reserved.

#  This program is free software; you can redistribute it and/or
#  modify it under the terms of version 2 or 3 of the GNU General
#  Public License as published by the Free Software Foundation.

#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.   See the
#  GNU General Public License for more details.

#  You should have received a copy of the GNU General Public License
#  along with this program; if not, contact SUSE LLC.

#  To contact Novell about this file by physical or electronic mail,
#  you may find current contact information at www.suse.com

# Set the paths
SRC_PATH = File.expand_path("../src", __dir__)
DATA_PATH = File.join(__dir__, "data")
ENV["Y2DIR"] = SRC_PATH

# make sure we run the tests in English locale
# (some tests check the output which is marked for translation)
ENV["LC_ALL"] = "en_US.UTF-8"

require "yast"
require "yast/rspec"

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    # If you misremember a method name both in code and in tests,
    # will save you.
    # https://relishapp.com/rspec/rspec-mocks/v/3-0/docs/verifying-doubles/partial-doubles
    #
    # With graceful degradation for RSpec 2
    mocks.verify_partial_doubles = true if mocks.respond_to?(:verify_partial_doubles=)
  end
end

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/test/"
  end

  src_location = File.expand_path("../src", __dir__)
  # track all ruby files under src
  SimpleCov.track_files("#{src_location}/**/*.rb")

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["CI"] || ENV["COVERAGE_LCOV"]
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end
