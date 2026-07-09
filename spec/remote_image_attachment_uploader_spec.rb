# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Marlens::JiraApi::RemoteImageAttachmentUploader do
  FakeClient = Struct.new(:uploaded) do
    def upload_attachment(issue_key:, io:, filename:, content_type:)
      self.uploaded = { issue_key: issue_key, filename: filename, content_type: content_type, bytes: io.read.bytesize }
      { "id" => "attachment-id", "filename" => filename }
    end
  end

  it "returns a fallback paragraph when the image host is disallowed" do
    # Arrange
    client = FakeClient.new
    uploader = described_class.new(
      client: client,
      issue_key: "WRAPX-123",
      allowed_hosts: ["github.com"]
    )

    # Act
    result = nil
    stderr = capture_stderr do
      result = uploader.media_node_for(
        url: "https://evil.example/image.png",
        alt: "Screenshot"
      )
    end

    # Assert
    expect(
      result_type: result.fetch("type"),
      result_text: result.fetch("content").fetch(0).fetch("text"),
      uploaded: client.uploaded,
      warned: stderr.include?("disallowed host")
    ).to eq(
      result_type: "paragraph",
      result_text: "Screenshot: https://evil.example/image.png",
      uploaded: nil,
      warned: true
    )
  end

  it "uses fallback image dimensions when attributes are not numeric" do
    # Arrange
    uploader = described_class.new(
      client: FakeClient.new,
      issue_key: "WRAPX-123",
      allowed_hosts: []
    )

    # Act
    width = uploader.send(:image_dimension_value, "100%", 640)
    height = uploader.send(:image_dimension_value, "300", 480)

    # Assert
    expect(width: width, height: height).to eq(width: 640, height: 300)
  end

  def capture_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end
end
