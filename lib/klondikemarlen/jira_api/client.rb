# frozen_string_literal: true

require "base64"
require "json"
require "multipart/post"
require "net/http"
require "uri"

module Klondikemarlen
  module JiraApi
    class Client
      def initialize(base_url:, email:, api_token:)
        @base_url = base_url.to_s.delete_suffix("/")
        @email = email
        @api_token = api_token
      end

      def list_comments(issue_key:, start_at: nil, max_results: nil)
        uri = api_uri("/issue/#{issue_key}/comment")
        query = {}
        query["startAt"] = start_at unless start_at.nil?
        query["maxResults"] = max_results unless max_results.nil?
        uri.query = URI.encode_www_form(query) unless query.empty?

        json_request(Net::HTTP::Get.new(uri), uri)
      end

      def get_comment(issue_key:, comment_id:)
        uri = api_uri("/issue/#{issue_key}/comment/#{comment_id}")
        json_request(Net::HTTP::Get.new(uri), uri)
      end

      def create_comment(issue_key:, document:)
        uri = api_uri("/issue/#{issue_key}/comment")
        request = Net::HTTP::Post.new(uri)
        request.body = JSON.dump({ "body" => document })

        json_request(request, uri)
      end

      def update_comment(issue_key:, comment_id:, document:)
        uri = api_uri("/issue/#{issue_key}/comment/#{comment_id}")
        request = Net::HTTP::Put.new(uri)
        request.body = JSON.dump({ "body" => document })

        json_request(request, uri)
      end

      def delete_comment(issue_key:, comment_id:)
        uri = api_uri("/issue/#{issue_key}/comment/#{comment_id}")
        response = authenticated_request(Net::HTTP::Delete.new(uri), uri)
        return true if response.code.to_i == 204

        raise "Failed to delete Jira comment #{comment_id} for #{issue_key}: #{response.code} #{response.body}"
      end

      def create_markdown_comment(issue_key:, markdown:, allowed_image_hosts: [])
        document = markdown_document(
          issue_key: issue_key,
          markdown: markdown,
          allowed_image_hosts: allowed_image_hosts
        )
        create_comment(issue_key: issue_key, document: document)
      end

      def update_markdown_comment(issue_key:, comment_id:, markdown:, allowed_image_hosts: [])
        document = markdown_document(
          issue_key: issue_key,
          markdown: markdown,
          allowed_image_hosts: allowed_image_hosts
        )
        update_comment(issue_key: issue_key, comment_id: comment_id, document: document)
      end

      alias post_comment create_comment
      alias post_markdown_comment create_markdown_comment

      def upload_attachment(issue_key:, io:, filename:, content_type:)
        uri = api_uri("/issue/#{issue_key}/attachments")
        request = Net::HTTP::Post::Multipart.new(
          uri.request_uri,
          "file" => UploadIO.new(io, content_type, filename)
        )
        request.basic_auth(@email, @api_token)
        request["X-Atlassian-Token"] = "no-check"

        response = http_request(uri, request)
        unless response.code.to_i.between?(200, 299)
          raise "Failed to upload Jira attachment for #{issue_key}: #{response.code} #{response.body}"
        end

        JSON.parse(response.body).first
      end

      private

      def markdown_document(issue_key:, markdown:, allowed_image_hosts:)
        image_uploader = RemoteImageAttachmentUploader.new(
          client: self,
          issue_key: issue_key,
          allowed_hosts: allowed_image_hosts
        )
        MarkdownToAdf.call(markdown) do |image|
          image_uploader.media_node_for(image)
        end
      end

      def json_request(request, uri)
        response = authenticated_request(request, uri)
        return JSON.parse(response.body) if response.code.to_i.between?(200, 299)

        raise "Jira API request failed: #{request.method} #{uri.request_uri}: #{response.code} #{response.body}"
      end

      def authenticated_request(request, uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Basic #{auth_token}"
        http_request(uri, request)
      end

      def api_uri(path)
        URI("#{@base_url}/rest/api/3#{path}")
      end

      def http_request(uri, request)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.request(request)
      end

      def auth_token
        Base64.strict_encode64("#{@email}:#{@api_token}")
      end
    end
  end
end
