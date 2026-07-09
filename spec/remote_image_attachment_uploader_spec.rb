# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Marlens::JiraApi::RemoteImageAttachmentUploader do
  FakeClient = Struct.new(:uploaded) do
    def upload_attachment(issue_key:, io:, filename:, content_type:)
      self.uploaded = { issue_key: issue_key, filename: filename, content_type: content_type, bytes: io.read.bytesize }
      { "id" => "attachment-id", "filename" => filename, "content" => "/rest/api/3/attachment/content/attachment-id" }
    end
  end

  FakeResponse = Struct.new(:content_type, :body) do
    def [](key)
      content_type if key == "content-type"
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

  it "records failure metadata when a GitHub user attachment cannot be fetched" do
    # Arrange
    client = FakeClient.new
    failures = []
    url = "https://github.com/user-attachments/assets/missing"
    uploader = described_class.new(
      client: client,
      issue_key: "WRAPX-123",
      allowed_hosts: ["github.com"],
      failures: failures
    )
    allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound.new("1.1", "404", "Not Found"))

    # Act
    result = nil
    capture_stderr do
      result = uploader.media_node_for(url: url, alt: "Screenshot")
    end

    # Assert
    expect(
      result_text: result.fetch("content").fetch(0).fetch("text"),
      uploaded: client.uploaded,
      failures: failures
    ).to eq(
      result_text: "Screenshot: #{url}",
      uploaded: nil,
      failures: [
        {
          url: url,
          alt: "Screenshot",
          error_class: "RuntimeError",
          error_message: "Failed to fetch image: 404 Not Found",
        },
      ]
    )
  end

  it "raises image fetch failures in strict mode" do
    # Arrange
    client = FakeClient.new
    failures = []
    url = "https://github.com/user-attachments/assets/missing"
    uploader = described_class.new(
      client: client,
      issue_key: "WRAPX-123",
      allowed_hosts: ["github.com"],
      strict: true,
      failures: failures
    )
    allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound.new("1.1", "404", "Not Found"))
    expected_failure = {
      url: url,
      alt: "Screenshot",
      error_class: "RuntimeError",
      error_message: "Failed to fetch image: 404 Not Found",
    }

    # Act / Assert
    expect do
      uploader.media_node_for(url: url, alt: "Screenshot")
    end.to raise_error(Marlens::JiraApi::ImageUploadError) { |error|
      expect(error.message).to eq("Failed to upload image #{url}: RuntimeError: Failed to fetch image: 404 Not Found")
      expect(error.failure).to eq(expected_failure)
    }
    expect(client.uploaded).to be_nil
    expect(failures).to eq([expected_failure])
  end

  it "returns Jira-hosted external media after uploading an allowed image" do
    # Arrange
    client = FakeClient.new
    uploader = described_class.new(
      client: client,
      issue_key: "WRAPX-123",
      allowed_hosts: ["raw.githubusercontent.com"]
    )
    allow(uploader).to receive(:fetch_image).and_return(FakeResponse.new("image/png", "pngbytes"))
    allow(uploader).to receive(:image_dimensions).and_return("width" => 288, "height" => 288)

    # Act
    result = uploader.media_node_for(
      url: "https://raw.githubusercontent.com/github/explore/main/topics/ruby/ruby.png",
      alt: "Ruby logo",
      width: nil,
      height: nil
    )

    # Assert
    attrs = result.fetch("content").fetch(0).fetch("attrs")
    expect(
      type: result.fetch("type"),
      media_type: attrs.fetch("type"),
      url: attrs.fetch("url"),
      external_url_present: attrs.to_s.include?("raw.githubusercontent.com"),
      uploaded: client.uploaded
    ).to eq(
      type: "mediaSingle",
      media_type: "external",
      url: "/rest/api/3/attachment/content/attachment-id",
      external_url_present: false,
      uploaded: {
        issue_key: "WRAPX-123",
        filename: "ruby.png",
        content_type: "image/png",
        bytes: 8,
      }
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
