# External dependencies
require 'pdf-reader'

# Project files
require_relative './lib/importers/pdf_ecad'

RSpec.configure do |config|
  # Silence warnings about the syntax being deprecated.
  config.expect_with(:rspec) { |c| c.syntax = :should }
end
