# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe Marlens::JiraApi::AdfToMarkdown do
  it "converts common blocks and nested lists" do
    # Arrange
    document = {
      "type" => "doc",
      "content" => [
        { "type" => "heading", "attrs" => { "level" => 2 }, "content" => [{ "type" => "text", "text" => "Release notes" }] },
        { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Read this first." }] },
        { "type" => "blockquote", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Quoted" }] }] },
        {
          "type" => "orderedList",
          "attrs" => { "order" => 3 },
          "content" => [
            { "type" => "listItem", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Third" }] }] },
            { "type" => "listItem", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Fourth" }] }] },
          ],
        },
        {
          "type" => "bulletList",
          "content" => [
            {
              "type" => "listItem",
              "content" => [
                { "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Parent" }] },
                {
                  "type" => "bulletList",
                  "content" => [
                    { "type" => "listItem", "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Nested" }] }] },
                  ],
                },
              ],
            },
          ],
        },
      ],
    }

    # Act
    markdown = described_class.call(document)

    # Assert
    expect(markdown).to eq(<<~MARKDOWN.strip)
      ## Release notes

      Read this first.

      > Quoted

      3. Third
      4. Fourth

      - Parent
        - Nested
    MARKDOWN
  end

  it "converts ADF text marks" do
    # Arrange
    document = {
      "type" => "doc",
      "content" => [
        {
          "type" => "paragraph",
          "content" => [
            { "type" => "text", "text" => "bold", "marks" => [{ "type" => "strong" }] },
            { "type" => "text", "text" => " " },
            { "type" => "text", "text" => "italic", "marks" => [{ "type" => "em" }] },
            { "type" => "text", "text" => " " },
            { "type" => "text", "text" => "code", "marks" => [{ "type" => "code" }] },
            { "type" => "text", "text" => " " },
            { "type" => "text", "text" => "link", "marks" => [{ "type" => "link", "attrs" => { "href" => "https://example.com" } }] },
            { "type" => "text", "text" => " " },
            { "type" => "text", "text" => "struck", "marks" => [{ "type" => "strike" }] },
          ],
        },
      ],
    }

    # Act
    markdown = described_class.call(document)

    # Assert
    expect(markdown).to eq("**bold** *italic* `code` [link](https://example.com) ~~struck~~")
  end

  it "preserves traversable content from unsupported nodes" do
    # Arrange
    document = {
      "type" => "doc",
      "content" => [
        {
          "type" => "unsupportedWrapper",
          "content" => [{ "type" => "paragraph", "content" => [{ "type" => "text", "text" => "Kept" }] }],
        },
        {
          "type" => "unsupportedInlineWrapper",
          "content" => [{ "type" => "text", "text" => "Also kept" }],
        },
      ],
    }

    # Act
    markdown = described_class.call(document)

    # Assert
    expect(markdown).to eq("Kept\n\nAlso kept")
  end
end
