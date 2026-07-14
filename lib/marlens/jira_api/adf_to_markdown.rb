# frozen_string_literal: true

module Marlens
  module JiraApi
    class AdfToMarkdown
      BLOCK_TYPES = %w[doc paragraph heading blockquote orderedList bulletList listItem].freeze

      def self.call(document)
        new(document).to_markdown
      end

      def initialize(document)
        @document = document.is_a?(Hash) ? document : {}
      end

      def to_markdown
        render_block(@document).strip
      end

      private

      def render_block(node)
        case node["type"]
        when "doc"
          render_blocks(children(node)).join("\n\n")
        when "paragraph"
          render_inline_nodes(children(node))
        when "heading"
          "#{"#" * heading_level(node)} #{render_inline_nodes(children(node))}".rstrip
        when "blockquote"
          quote(render_blocks(children(node)).join("\n\n"))
        when "orderedList", "bulletList"
          render_list(node)
        when "listItem"
          render_list_item(node, marker: "-", indent: 0)
        when "text", "hardBreak"
          render_inline(node)
        else
          render_unknown(node)
        end
      end

      def render_blocks(nodes)
        nodes.filter_map do |node|
          rendered = render_block(node)
          rendered unless rendered.empty?
        end
      end

      def render_unknown(node)
        content = children(node)
        return "" if content.empty?

        if content.any? { |child| BLOCK_TYPES.include?(child["type"]) }
          render_blocks(content).join("\n\n")
        else
          render_inline_nodes(content)
        end
      end

      def render_list(node, indent: 0)
        start = node.dig("attrs", "order").to_i
        start = 1 if start.zero?

        children(node).each_with_index.map do |item, index|
          marker = node["type"] == "orderedList" ? "#{start + index}." : "-"
          render_list_item(item, marker:, indent:)
        end.join("\n")
      end

      def render_list_item(node, marker:, indent:)
        item_children = children(node)
        first_child = item_children.shift
        indentation = " " * indent
        prefix = "#{marker} "

        if first_child&.fetch("type", nil) == "paragraph"
          lines = ["#{indentation}#{prefix}#{render_inline_nodes(children(first_child))}".rstrip]
        else
          lines = ["#{indentation}#{marker}"]
          item_children.unshift(first_child) unless first_child.nil?
        end

        continuation_indent = indent + prefix.length
        item_children.each do |child|
          rendered = if ["orderedList", "bulletList"].include?(child["type"])
                       render_list(child, indent: continuation_indent)
                     else
                       indent_lines(render_block(child), continuation_indent)
                     end
          lines << rendered unless rendered.empty?
        end

        lines.join("\n")
      end

      def render_inline_nodes(nodes)
        nodes.map { |node| render_inline(node) }.join
      end

      def render_inline(node)
        case node["type"]
        when "text"
          apply_marks(node.fetch("text", ""), node["marks"])
        when "hardBreak"
          "\n"
        else
          render_inline_nodes(children(node))
        end
      end

      def apply_marks(text, marks)
        Array(marks).reduce(text) do |markdown, mark|
          case mark["type"]
          when "strong", "bold"
            "**#{markdown}**"
          when "em", "italic"
            "*#{markdown}*"
          when "code"
            "`#{markdown}`"
          when "link"
            href = mark.dig("attrs", "href")
            href.to_s.empty? ? markdown : "[#{markdown}](#{href})"
          when "strike"
            "~~#{markdown}~~"
          else
            markdown
          end
        end
      end

      def heading_level(node)
        level = node.dig("attrs", "level").to_i
        level.zero? ? 1 : level
      end

      def quote(content)
        content.split("\n", -1).map { |line| line.empty? ? ">" : "> #{line}" }.join("\n")
      end

      def indent_lines(text, indent)
        return "" if text.empty?

        text.lines(chomp: true).map { |line| "#{" " * indent}#{line}" }.join("\n")
      end

      def children(node)
        Array(node["content"]).select { |child| child.is_a?(Hash) }
      end
    end
  end
end
