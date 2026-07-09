# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Marlens::JiraApi::MarkdownToAdf do
  it "preserves headings, lists, marks, and images when converting markdown to ADF" do
    # Arrange
    captured_images = []
    markdown = <<~MARKDOWN
      # Release Notes

      1. Run `bundle exec ruby -c file.rb`.
      2. Verify **formatted** Jira content.

      <img src="https://github.com/user-attachments/assets/example" alt="HTML screenshot" width="100%" height="300">

      ![Markdown screenshot](https://user-images.githubusercontent.com/example.png)
    MARKDOWN

    # Act
    document = described_class.call(markdown) do |image|
      captured_images << image
      described_class.media_single(
        id: "attachment-#{captured_images.length}",
        alt: image[:alt].to_s.empty? ? "image" : image[:alt],
        width: 640,
        height: 480
      )
    end

    # Assert
    content_types = document.fetch("content").map { |node| node.fetch("type") }
    expect(
      content_types: content_types,
      image_count: captured_images.length,
      html_image_width: captured_images.first.fetch(:width),
      html_image_height: captured_images.first.fetch(:height)
    ).to eq(
      content_types: ["heading", "orderedList", "mediaSingle", "mediaSingle"],
      image_count: 2,
      html_image_width: "100%",
      html_image_height: "300"
    )
  end

  it "routes mixed inline HTML image tags through the resolver without dropping surrounding text" do
    # Arrange
    captured_images = []
    resolved_media = described_class.media_single(
      id: "attachment-dashboard",
      alt: "Dashboard with stacked active banners",
      width: 1900,
      height: 1178
    )
    markdown = <<~MARKDOWN
      Dashboard with stacked active banners
      http://localhost:8080/dashboard
      <img width="1900" height="1178" alt="Dashboard with stacked active banners" src="https://github.com/user-attachments/assets/978779e2-f048-4c52-9da7-80f1e14ae542" />
    MARKDOWN

    # Act
    document = described_class.call(markdown) do |image|
      captured_images << image
      resolved_media
    end

    # Assert
    text_nodes = lambda do |node|
      case node
      when Hash
        (node["type"] == "text" ? [node] : []) + Array(node["content"]).flat_map { |child| text_nodes.call(child) }
      when Array
        node.flat_map { |child| text_nodes.call(child) }
      else
        []
      end
    end
    content_types = document.fetch("content").map { |node| node.fetch("type") }
    paragraph = document.fetch("content").find { |node| node.fetch("type") == "paragraph" }
    media_singles = document.fetch("content").select { |node| node.fetch("type") == "mediaSingle" }
    paragraph_text = text_nodes.call(paragraph).map { |node| node.fetch("text") }.join

    expect(captured_images).to eq(
      [
        {
          url: "https://github.com/user-attachments/assets/978779e2-f048-4c52-9da7-80f1e14ae542",
          alt: "Dashboard with stacked active banners",
          width: "1900",
          height: "1178",
        },
      ]
    )
    expect(content_types).to eq(["paragraph", "mediaSingle"])
    expect(media_singles).to eq([resolved_media])
    expect(paragraph_text).to include("Dashboard with stacked active banners")
    expect(paragraph_text).to include("http://localhost:8080/dashboard")
    expect(text_nodes.call(document)).not_to include(include("text" => include("<img")))
  end
end
