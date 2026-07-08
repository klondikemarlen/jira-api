# frozen_string_literal: true

require "fastimage"
require "net/http"
require "tempfile"
require "uri"

module Klondikemarlen
  module JiraApi
    class RemoteImageAttachmentUploader
      MAX_REDIRECTS = 5

      def initialize(client:, issue_key:, allowed_hosts:)
        @allowed_hosts = allowed_hosts
        @client = client
        @issue_key = issue_key
      end

      def media_node_for(image)
        attachment = upload_image_attachment(image.fetch(:url))
        dimensions = attachment.fetch("dimensions")

        MarkdownToAdf.media_single(
          id: attachment.fetch("id"),
          alt: image[:alt].to_s.strip.empty? ? attachment.fetch("filename") : image[:alt],
          width: image_dimension_value(image[:width], dimensions.fetch("width")),
          height: image_dimension_value(image[:height], dimensions.fetch("height"))
        )
      rescue StandardError => error
        warn "Failed to upload image #{image[:url]}: #{error.class}: #{error.message}"
        MarkdownToAdf.paragraph("#{image[:alt] || "Image"}: #{image[:url]}")
      end

      private

      def upload_image_attachment(url)
        uri = allowed_image_uri(url)

        Tempfile.create(["jira-comment-image", File.extname(uri.path)]) do |file|
          response = fetch_image(uri)
          content_type = response_content_type(response) || content_type_for(file.path)
          raise "Expected image content type, got #{content_type}" unless content_type.start_with?("image/")

          file.binmode
          file.write(response.body)
          file.rewind

          filename = filename_for(uri, content_type)
          dimensions = image_dimensions(file.path)
          attachment = @client.upload_attachment(
            issue_key: @issue_key,
            io: file,
            filename: filename,
            content_type: content_type
          )

          return {
            "id" => attachment.fetch("id").to_s,
            "filename" => attachment.fetch("filename", filename),
            "dimensions" => dimensions,
          }
        end
      end

      def allowed_image_uri(url)
        uri = URI(url)
        return uri if @allowed_hosts.include?(uri.host)

        raise "Refusing to upload image URL from disallowed host #{uri.host.inspect}"
      end

      def fetch_image(uri, redirects_remaining: MAX_REDIRECTS)
        response = Net::HTTP.get_response(uri)

        if response.is_a?(Net::HTTPRedirection)
          raise "Too many image redirects" if redirects_remaining.zero?

          redirected_uri = allowed_image_uri(URI.join(uri, response["location"]).to_s)
          return fetch_image(redirected_uri, redirects_remaining: redirects_remaining - 1)
        end

        return response if response.is_a?(Net::HTTPSuccess)

        raise "Failed to fetch image: #{response.code} #{response.message}"
      end

      def response_content_type(response)
        content_type = response["content-type"].to_s.split(";").first.to_s.strip
        return nil if content_type.empty?

        content_type
      end

      def image_dimension_value(value, fallback)
        parsed_value = value.to_s.match?(/\A\d+\z/) ? value.to_i : nil
        return parsed_value if parsed_value&.positive?

        fallback
      end

      def filename_for(uri, content_type)
        filename = File.basename(uri.path)
        filename = "jira-comment-image" if filename.empty?

        extension = File.extname(filename)
        return filename unless extension.empty?

        "#{filename}#{extension_for(content_type)}"
      end

      def extension_for(content_type)
        case content_type
        when "image/jpeg" then ".jpg"
        when "image/png" then ".png"
        when "image/gif" then ".gif"
        when "image/webp" then ".webp"
        else ".img"
        end
      end

      def content_type_for(path)
        case File.extname(path).downcase
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".png" then "image/png"
        when ".gif" then "image/gif"
        when ".webp" then "image/webp"
        else "application/octet-stream"
        end
      end

      def image_dimensions(path)
        width, height = FastImage.size(path)
        return { "width" => width, "height" => height } if width && height

        { "width" => 1200, "height" => 800 }
      end
    end
  end
end
