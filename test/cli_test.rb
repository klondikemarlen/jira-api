# frozen_string_literal: true

require "tempfile"

require_relative "test_helper"

class CliTest < Minitest::Test
  EXECUTABLE = File.expand_path("../exe/jira-comment", __dir__)

  def around
    original_argv = ARGV.dup
    yield
  ensure
    ARGV.replace(original_argv)
  end

  def test_when_command_is_unknown_then_exits_before_requiring_credentials
    # Arrange
    ARGV.replace(["bogus"])

    # Act
    _, stderr = capture_io do
      assert_raises(SystemExit) { load EXECUTABLE }
    end

    # Assert
    assert_includes(stderr, "Unknown command")
  end

  def test_when_required_options_are_missing_then_exits_before_requiring_credentials
    # Arrange
    ARGV.replace(["get", "--issue-key", "WRAPX-123"])

    # Act
    _, stderr = capture_io do
      assert_raises(SystemExit) { load EXECUTABLE }
    end

    # Assert
    assert_includes(stderr, "Missing required option(s): --comment-id")
  end

  def test_when_create_command_is_valid_then_posts_markdown_with_stubbed_client
    # Arrange
    markdown_file = Tempfile.new("jira-comment")
    markdown_file.write("# Heading")
    markdown_file.close
    ARGV.replace([
      "create",
      "--issue-key",
      "WRAPX-123",
      "--markdown-file",
      markdown_file.path,
      "--image-host",
      "github.com",
    ])
    fake_client = Object.new
    def fake_client.create_markdown_comment(issue_key:, markdown:, allowed_image_hosts:)
      {
        "id" => "10001",
        "issue_key" => issue_key,
        "markdown" => markdown,
        "allowed_image_hosts" => allowed_image_hosts,
      }
    end
    Klondikemarlen::JiraApi::Client.stub(:new, fake_client) do
      # Act
      stdout, = capture_io { load EXECUTABLE }

      # Assert
      assert_equal(
        {
          "id" => "10001",
          "issue_key" => "WRAPX-123",
          "markdown" => "# Heading",
          "allowed_image_hosts" => ["github.com"],
        },
        JSON.parse(stdout)
      )
    end
  ensure
    markdown_file&.unlink
  end
end
