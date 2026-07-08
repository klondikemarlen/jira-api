# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Klondikemarlen::JiraApi::MarkdownToAdf do
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
end
