# frozen_string_literal: true

require "open3"
require "rbconfig"
require "tempfile"

require_relative "spec_helper"
Marlens
RSpec.describe Marlens::JiraApi::CLI do
  def run_cli(arguments, environment: {}, client: Object.new, client_factory: ->(env:) { client })
    described_class.run(
      arguments,
      env: environment,
      out: output,
      err: errors,
      client_factory: client_factory
    )
  end

  let(:output) { StringIO.new }
  let(:errors) { StringIO.new }

  it "exits before requiring credentials when the command is unknown" do
    # Arrange
    arguments = ["bogus"]
    client_factory = ->(env:) { raise "client should not be built for an unknown command" }

    # Act
    exit_code = run_cli(arguments, client_factory: client_factory)

    # Assert
    expect(exit_code).to eq(1)
    expect(errors.string).to eq("Unknown command \"bogus\". Expected one of: list, get, create, update, delete\n")
    expect(output.string).to eq("")
  end

  it "exits before requiring credentials when required options are missing" do
    # Arrange
    arguments = ["get", "--issue-key", "WRAPX-123"]
    client_factory = ->(env:) { raise "client should not be built when required options are missing" }

    # Act
    exit_code = run_cli(arguments, client_factory: client_factory)

    # Assert
    expect(exit_code).to eq(1)
    expect(errors.string).to eq("Missing required option(s): --comment-id\n")
    expect(output.string).to eq("")
  end

  it "posts markdown through the injected client when create options are valid" do
    # Arrange
    markdown_file = Tempfile.new("jira-comment")
    markdown_file.write("# Heading")
    markdown_file.close
    client = Class.new do
      def create_markdown_comment(issue_key:, markdown:, allowed_image_hosts:)
        created_comment = {
          "issue_key" => issue_key,
          "markdown" => markdown,
          "allowed_image_hosts" => allowed_image_hosts,
        }
        { "id" => "10001", **created_comment }
      end
    end.new
    arguments = [
      "create",
      "--issue-key", "WRAPX-123",
      "--markdown-file", markdown_file.path,
      "--image-host", "github.com",
    ]

    # Act
    exit_code = run_cli(
      arguments,
      environment: {
        "JIRA_BASE_URL" => "https://example.atlassian.net",
        "JIRA_EMAIL" => "user@example.com",
        "JIRA_API_TOKEN" => "token",
      },
      client: client
    )

    # Assert
    expect(exit_code).to eq(0)
    expect(JSON.parse(output.string)).to eq(
      "id" => "10001",
      "issue_key" => "WRAPX-123",
      "markdown" => "# Heading",
      "allowed_image_hosts" => ["github.com"]
    )
    expect(errors.string).to eq("")
  ensure
    markdown_file&.unlink
  end

  it "returns a failing process status from the bin wrapper on invalid input" do
    # Arrange
    root = File.expand_path("..", __dir__)

    # Act
    standard_output, standard_error, status = Open3.capture3(RbConfig.ruby, "-Ilib", "bin/jira-comment", "bogus", chdir: root)

    # Assert
    expect(status.exitstatus).to eq(1)
    expect(standard_output).to eq("")
    expect(standard_error).to include("Unknown command")
  end
end
