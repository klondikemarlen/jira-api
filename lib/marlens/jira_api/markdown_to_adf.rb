# frozen_string_literal: true

require "commonmarker"

module Marlens
  module JiraApi
    class MarkdownToAdf
      IMAGE_TAG_PATTERN = /<img\b(?<attributes>[^>]+)>/i

      def self.call(markdown, &image_resolver)
        new(markdown, image_resolver: image_resolver).to_document
      end

      def self.media_single(id:, alt:, width:, height:)
        {
          "type" => "mediaSingle",
          "attrs" => { "layout" => "center" },
          "content" => [
            {
              "type" => "media",
              "attrs" => {
                "id" => id,
                "type" => "file",
                "collection" => "jira-issue-attachments",
                "alt" => alt,
                "width" => width,
                "height" => height,
              },
            },
          ],
        }
      end

      def self.paragraph(text)
        new("").send(:paragraph_from_text, text)
      end

      def initialize(markdown, image_resolver: nil)
        @markdown = markdown.to_s
        @image_resolver = image_resolver
      end

      def to_document
        {
          "type" => "doc",
          "version" => 1,
          "content" => document_content,
        }
      end

      private

      def document_content
        blocks = render_blocks(markdown_document)
        blocks.empty? ? [paragraph_from_text("(No PR description provided.)")] : blocks
      end

      def markdown_document
        Commonmarker.parse(
          @markdown,
          options: {
            parse: { smart: true },
            extension: {
              autolink: true,
              strikethrough: true,
              table: true,
              tagfilter: false,
            },
          }
        )
      end

      def render_blocks(parent)
        children(parent).flat_map { |node| render_block(node) }.compact
      end

      def render_block(node)
        case node.type
        when :heading
          heading(node)
        when :paragraph
          paragraph(node)
        when :code_block
          code_block(node)
        when :list
          list(node)
        when :item
          list_item(node)
        when :block_quote
          blockquote(node)
        when :thematic_break
          { "type" => "rule" }
        when :html_block
          html_image_block(node) || paragraph_from_text(node.to_commonmark.strip)
        else
          render_blocks(node)
        end
      end

      def heading(node)
        {
          "type" => "heading",
          "attrs" => { "level" => node.header_level },
          "content" => inline_content(node),
        }
      end

      def paragraph(node)
        return image_block_for(children(node).first) if single_image_node?(node)

        {
          "type" => "paragraph",
          "content" => inline_content(node),
        }
      end

      def paragraph_from_text(text)
        {
          "type" => "paragraph",
          "content" => [text_node(text)],
        }
      end

      def code_block(node)
        block = {
          "type" => "codeBlock",
          "content" => [{ "type" => "text", "text" => node.string_content.chomp }],
        }
        block["attrs"] = { "language" => node.fence_info } unless node.fence_info.to_s.empty?
        block
      end

      def list(node)
        content = children(node).map { |child| list_item(child) }

        if node.list_type == :ordered
          {
            "type" => "orderedList",
            "attrs" => { "order" => node.list_start },
            "content" => content,
          }
        else
          {
            "type" => "bulletList",
            "content" => content,
          }
        end
      end

      def list_item(node)
        content = render_blocks(node)
        content = [paragraph_from_text("")] if content.empty?

        {
          "type" => "listItem",
          "content" => content,
        }
      end

      def blockquote(node)
        {
          "type" => "blockquote",
          "content" => render_blocks(node),
        }
      end

      def inline_content(parent, marks = [])
        children(parent).flat_map { |node| render_inline(node, marks) }.compact
      end

      def render_inline(node, marks)
        case node.type
        when :text
          text_node(node.string_content, marks)
        when :softbreak, :linebreak
          text_node("\n", marks)
        when :code
          text_node(node.string_content, marks + [{ "type" => "code" }])
        when :strong
          inline_content(node, marks + [{ "type" => "strong" }])
        when :emph
          inline_content(node, marks + [{ "type" => "em" }])
        when :strikethrough
          inline_content(node, marks + [{ "type" => "strike" }])
        when :link
          inline_content(node, marks + [link_mark(node.url)])
        when :image
          text_node(image_alt(node), marks + [link_mark(node.url)])
        when :html_inline
          text_node(node.to_commonmark, marks)
        else
          inline_content(node, marks)
        end
      end

      def image_block_for(node)
        resolved_image_block(url: node.url, alt: image_alt(node))
      end

      def html_image_block(node)
        match = node.to_commonmark.strip.match(IMAGE_TAG_PATTERN)
        return nil if match.nil?

        attributes = parse_html_attributes(match[:attributes])
        resolved_image_block(
          url: attributes["src"],
          alt: attributes["alt"],
          width: attributes["width"],
          height: attributes["height"]
        )
      end

      def resolved_image_block(url:, alt: nil, width: nil, height: nil)
        return nil if url.nil? || url.strip.empty?
        return fallback_image_paragraph(url, alt) if @image_resolver.nil?

        @image_resolver.call(url: url, alt: alt, width: width, height: height)
      end

      def fallback_image_paragraph(url, alt)
        paragraph_from_text("#{alt.to_s.empty? ? "Image" : alt}: #{url}")
      end

      def single_image_node?(node)
        meaningful_children = children(node).reject do |child|
          child.type == :text && child.string_content.strip.empty?
        end

        meaningful_children.length == 1 && meaningful_children.first.type == :image
      end

      def image_alt(node)
        children(node)
          .filter_map { |child| child.string_content if child.type == :text }
          .join
      end

      def text_node(text, marks = [])
        return nil if text.nil? || text.empty?

        node = { "type" => "text", "text" => text }
        node["marks"] = marks unless marks.empty?
        node
      end

      def link_mark(url)
        {
          "type" => "link",
          "attrs" => { "href" => url },
        }
      end

      def parse_html_attributes(attributes)
        attributes.scan(/([a-zA-Z:-]+)=["']([^"']+)["']/).to_h
      end

      def children(node)
        node.each.to_a
      end
    end
  end
end
