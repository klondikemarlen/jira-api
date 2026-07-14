# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Marlens::JiraApi::Client do
  Response = Struct.new(:code, :body)

  let(:client_class) do
    Class.new(described_class) do
      attr_reader :requests

      def initialize(response:)
        super(base_url: "https://example.atlassian.net", email: "user@example.com", api_token: "token")
        @requests = []
        @response = response
      end

      private

      def http_request(uri, request)
        @requests << { uri: uri, request: request }
        @response
      end
    end
  end

  it "posts an ADF document to the issue comment endpoint when creating a comment" do
    # Arrange
    client = client_class.new(response: Response.new("201", '{"id":"10001"}'))
    document = { "type" => "doc", "version" => 1, "content" => [] }

    # Act
    result = client.create_comment(issue_key: "WRAPX-123", document: document)

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      body: JSON.parse(request.body),
      result: result
    ).to eq(
      method: "POST",
      path: "/rest/api/3/issue/WRAPX-123/comment",
      body: { "body" => document },
      result: { "id" => "10001" }
    )
  end

  it "gets the issue comment collection when listing comments" do
    # Arrange
    client = client_class.new(response: Response.new("200", '{"comments":[]}'))

    # Act
    result = client.list_comments(issue_key: "WRAPX-123", max_results: 50)

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      result: result
    ).to eq(
      method: "GET",
      path: "/rest/api/3/issue/WRAPX-123/comment?maxResults=50",
      result: { "comments" => [] }
    )
  end

  it "gets a specific comment endpoint when fetching one comment" do
    # Arrange
    client = client_class.new(response: Response.new("200", '{"id":"10001"}'))

    # Act
    result = client.get_comment(issue_key: "WRAPX-123", comment_id: "10001")

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      result: result
    ).to eq(
      method: "GET",
      path: "/rest/api/3/issue/WRAPX-123/comment/10001",
      result: { "id" => "10001" }
    )
  end

  it "gets a Jira issue" do
    # Arrange
    client = client_class.new(response: Response.new("200", '{"key":"WRAPX-123"}'))

    # Act
    result = client.get_issue(issue_key: "WRAPX-123")

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      result: result
    ).to eq(
      method: "GET",
      path: "/rest/api/3/issue/WRAPX-123",
      result: { "key" => "WRAPX-123" }
    )
  end

  it "gets a Jira issue remote-link collection" do
    # Arrange
    client = client_class.new(response: Response.new("200", '[{"id":10001}]'))

    # Act
    result = client.list_remote_links(issue_key: "WRAPX-123")

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      result: result
    ).to eq(
      method: "GET",
      path: "/rest/api/3/issue/WRAPX-123/remotelink",
      result: [{ "id" => 10001 }]
    )
  end

  it "raises response details for an unsuccessful Jira issue read" do
    # Arrange
    client = client_class.new(response: Response.new("404", '{"errorMessages":["Issue Does Not Exist"]}'))

    # Act / Assert
    expect { client.get_issue(issue_key: "WRAPX-123") }.to raise_error(
      RuntimeError,
      'Jira API request failed: GET /rest/api/3/issue/WRAPX-123: 404 {"errorMessages":["Issue Does Not Exist"]}'
    )
  end

  it "raises JSON::ParserError for a malformed successful remote-link response" do
    # Arrange
    client = client_class.new(response: Response.new("200", "{"))

    # Act / Assert
    expect { client.list_remote_links(issue_key: "WRAPX-123") }.to raise_error(JSON::ParserError)
  end

  it "puts an ADF document to the specific comment endpoint when updating a comment" do
    # Arrange
    client = client_class.new(response: Response.new("200", '{"id":"10001"}'))
    document = { "type" => "doc", "version" => 1, "content" => [] }

    # Act
    result = client.update_comment(issue_key: "WRAPX-123", comment_id: "10001", document: document)

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      body: JSON.parse(request.body),
      result: result
    ).to eq(
      method: "PUT",
      path: "/rest/api/3/issue/WRAPX-123/comment/10001",
      body: { "body" => document },
      result: { "id" => "10001" }
    )
  end

  it "returns Jira attachment content URL when uploading an attachment" do
    # Arrange
    response_body = <<~JSON
      [
        {
          "id": "26605",
          "filename": "ruby.png",
          "content": "https://example.atlassian.net/rest/api/3/attachment/content/26605"
        }
      ]
    JSON
    client = client_class.new(response: Response.new("200", response_body))

    # Act
    result = client.upload_attachment(
      issue_key: "WRAPX-123",
      io: StringIO.new("pngbytes"),
      filename: "ruby.png",
      content_type: "image/png"
    )

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      token: request["X-Atlassian-Token"],
      result: result
    ).to eq(
      method: "POST",
      path: "/rest/api/3/issue/WRAPX-123/attachments",
      token: "no-check",
      result: {
        "id" => "26605",
        "filename" => "ruby.png",
        "content" => "https://example.atlassian.net/rest/api/3/attachment/content/26605",
      }
    )
  end


  it "records markdown image upload failures when creating a comment" do
    # Arrange
    client = client_class.new(response: Response.new("201", '{"id":"10001"}'))
    failures = []
    url = "https://github.com/user-attachments/assets/missing"
    allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound.new("1.1", "404", "Not Found"))

    # Act
    result = nil
    silence_stderr do
      result = client.create_markdown_comment(
        issue_key: "WRAPX-123",
        markdown: "![Screenshot](#{url})",
        allowed_image_hosts: ["github.com"],
        image_upload_failures: failures
      )
    end

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    body = JSON.parse(request.body).fetch("body")
    expect(
      result: result,
      posted_text: body.fetch("content").fetch(0).fetch("content").fetch(0).fetch("text"),
      failures: failures
    ).to eq(
      result: { "id" => "10001" },
      posted_text: "Screenshot: #{url}",
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

  it "raises markdown image upload failures when updating in strict mode" do
    # Arrange
    client = client_class.new(response: Response.new("200", '{"id":"10001"}'))
    failures = []
    url = "https://github.com/user-attachments/assets/missing"
    allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound.new("1.1", "404", "Not Found"))
    expected_failure = {
      url: url,
      alt: "Screenshot",
      error_class: "RuntimeError",
      error_message: "Failed to fetch image: 404 Not Found",
    }

    # Act / Assert
    expect do
      client.update_markdown_comment(
        issue_key: "WRAPX-123",
        comment_id: "10001",
        markdown: "![Screenshot](#{url})",
        allowed_image_hosts: ["github.com"],
        strict_images: true,
        image_upload_failures: failures
      )
    end.to raise_error(Marlens::JiraApi::ImageUploadError) { |error|
      expect(error.message).to eq("Failed to upload image #{url}: RuntimeError: Failed to fetch image: 404 Not Found")
      expect(error.failure).to eq(expected_failure)
    }
    expect(client.requests).to eq([])
    expect(failures).to eq([expected_failure])
  end

  it "deletes the specific comment endpoint when deleting a comment" do
    # Arrange
    client = client_class.new(response: Response.new("204", ""))

    # Act
    result = client.delete_comment(issue_key: "WRAPX-123", comment_id: "10001")

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    expect(
      method: request.method,
      path: client.requests.fetch(0).fetch(:uri).request_uri,
      result: result
    ).to eq(
      method: "DELETE",
      path: "/rest/api/3/issue/WRAPX-123/comment/10001",
      result: true
    )
  end
  def silence_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
  ensure
    $stderr = original_stderr
  end
end
