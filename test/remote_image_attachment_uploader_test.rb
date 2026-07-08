# frozen_string_literal: true

require_relative "test_helper"

class RemoteImageAttachmentUploaderTest < Minitest::Test
  FakeClient = Struct.new(:uploaded) do
    def upload_attachment(issue_key:, io:, filename:, content_type:)
      self.uploaded = { issue_key: issue_key, filename: filename, content_type: content_type, bytes: io.read.bytesize }
      { "id" => "attachment-id", "filename" => filename }
    end
  end

  def test_when_image_host_is_disallowed_then_returns_fallback_paragraph
    # Arrange
    client = FakeClient.new
    uploader = Klondikemarlen::JiraApi::RemoteImageAttachmentUploader.new(
      client: client,
      issue_key: "WRAPX-123",
      allowed_hosts: ["github.com"]
    )

    # Act
    _, stderr = capture_io do
      @result = uploader.media_node_for(
        url: "https://evil.example/image.png",
        alt: "Screenshot"
      )
    end

    # Assert
    assert_equal(
      {
        result_type: "paragraph",
        result_text: "Screenshot: https://evil.example/image.png",
        uploaded: nil,
        warned: true,
      },
      {
        result_type: @result.fetch("type"),
        result_text: @result.fetch("content").fetch(0).fetch("text"),
        uploaded: client.uploaded,
        warned: stderr.include?("disallowed host"),
      }
    )
  end

  def test_when_dimension_attribute_is_not_numeric_then_fallback_dimension_is_used
    # Arrange
    uploader = Klondikemarlen::JiraApi::RemoteImageAttachmentUploader.new(
      client: FakeClient.new,
      issue_key: "WRAPX-123",
      allowed_hosts: []
    )

    # Act
    width = uploader.send(:image_dimension_value, "100%", 640)
    height = uploader.send(:image_dimension_value, "300", 480)

    # Assert
    assert_equal(
      { width: 640, height: 300 },
      { width: width, height: height }
    )
  end
end
