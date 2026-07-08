# frozen_string_literal: true

require_relative "lib/klondikemarlen/jira_api/version"

Gem::Specification.new do |spec|
  spec.name = "klondikemarlen-jira-api"
  spec.version = Klondikemarlen::JiraApi::VERSION
  spec.authors = ["Marlen Brunner"]
  spec.email = ["klondikemarlen@gmail.com"]

  spec.summary = "Small Jira Cloud API helper for comment CRUD and rich Markdown comments."
  spec.description = "Provides Jira Cloud comment CRUD, converts Markdown to Atlassian Document Format, and optionally uploads allowed remote images as Jira issue attachments."
  spec.homepage = "https://github.com/klondikemarlen/jira-api"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*.rb", "exe/*", "README.md", "LICENSE.txt"]
  end
  spec.bindir = "exe"
  spec.executables = ["jira-comment"]
  spec.require_paths = ["lib"]

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "commonmarker", "~> 2.8"
  spec.add_dependency "fastimage", "~> 2.4"
  spec.add_dependency "multipart-post", "~> 2.4"

  spec.add_development_dependency "minitest", "~> 5.25"
end
