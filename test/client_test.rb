# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  Response = Struct.new(:code, :body)

  class FakeClient < Klondikemarlen::JiraApi::Client
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

  def test_when_creating_comment_then_posts_adf_document_to_issue_comment_endpoint
    # Arrange
    client = FakeClient.new(response: Response.new("201", '{"id":"10001"}'))
    document = { "type" => "doc", "version" => 1, "content" => [] }

    # Act
    result = client.create_comment(issue_key: "WRAPX-123", document: document)

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    assert_equal(
      {
        method: "POST",
        path: "/rest/api/3/issue/WRAPX-123/comment",
        body: { "body" => document },
        result: { "id" => "10001" },
      },
      {
        method: request.method,
        path: client.requests.fetch(0).fetch(:uri).request_uri,
        body: JSON.parse(request.body),
        result: result,
      }
    )
  end

  def test_when_listing_comments_then_gets_issue_comment_collection
    # Arrange
    client = FakeClient.new(response: Response.new("200", '{"comments":[]}'))

    # Act
    result = client.list_comments(issue_key: "WRAPX-123", max_results: 50)

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    assert_equal(
      {
        method: "GET",
        path: "/rest/api/3/issue/WRAPX-123/comment?maxResults=50",
        result: { "comments" => [] },
      },
      {
        method: request.method,
        path: client.requests.fetch(0).fetch(:uri).request_uri,
        result: result,
      }
    )
  end

  def test_when_getting_comment_then_gets_specific_comment_endpoint
    # Arrange
    client = FakeClient.new(response: Response.new("200", '{"id":"10001"}'))

    # Act
    result = client.get_comment(issue_key: "WRAPX-123", comment_id: "10001")

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    assert_equal(
      {
        method: "GET",
        path: "/rest/api/3/issue/WRAPX-123/comment/10001",
        result: { "id" => "10001" },
      },
      {
        method: request.method,
        path: client.requests.fetch(0).fetch(:uri).request_uri,
        result: result,
      }
    )
  end

  def test_when_updating_comment_then_puts_adf_document_to_specific_comment_endpoint
    # Arrange
    client = FakeClient.new(response: Response.new("200", '{"id":"10001"}'))
    document = { "type" => "doc", "version" => 1, "content" => [] }

    # Act
    result = client.update_comment(issue_key: "WRAPX-123", comment_id: "10001", document: document)

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    assert_equal(
      {
        method: "PUT",
        path: "/rest/api/3/issue/WRAPX-123/comment/10001",
        body: { "body" => document },
        result: { "id" => "10001" },
      },
      {
        method: request.method,
        path: client.requests.fetch(0).fetch(:uri).request_uri,
        body: JSON.parse(request.body),
        result: result,
      }
    )
  end

  def test_when_deleting_comment_then_deletes_specific_comment_endpoint
    # Arrange
    client = FakeClient.new(response: Response.new("204", ""))

    # Act
    result = client.delete_comment(issue_key: "WRAPX-123", comment_id: "10001")

    # Assert
    request = client.requests.fetch(0).fetch(:request)
    assert_equal(
      {
        method: "DELETE",
        path: "/rest/api/3/issue/WRAPX-123/comment/10001",
        result: true,
      },
      {
        method: request.method,
        path: client.requests.fetch(0).fetch(:uri).request_uri,
        result: result,
      }
    )
  end
end
