# frozen_string_literal: true

require "json"
require "optparse"

module Klondikemarlen
  module JiraApi
    class CLI
      COMMANDS = {
        "list" => { required: %i[issue_key], action: :list_comments },
        "get" => { required: %i[issue_key comment_id], action: :get_comment },
        "create" => { required: %i[issue_key markdown_file], action: :create_comment },
        "update" => { required: %i[issue_key comment_id markdown_file], action: :update_comment },
        "delete" => { required: %i[issue_key comment_id], action: :delete_comment },
      }.freeze

      def self.run(argv = ARGV, env: ENV, out: $stdout, err: $stderr, client_factory: nil)
        new(argv, env:, out:, err:, client_factory:).run
      end

      def initialize(argv, env:, out:, err:, client_factory: nil)
        @argv = argv.dup
        @env = env
        @out = out
        @err = err
        @client_factory = client_factory || method(:build_client)
      end

      def run
        command = @argv.shift
        config = COMMANDS[command]
        return fail_with("Unknown command #{command.inspect}. Expected one of: #{COMMANDS.keys.join(", ")}") unless config

        options = parse_options
        missing = config.fetch(:required).select { |key| options[key].to_s.empty? }
        return fail_with("Missing required option(s): #{option_names(missing)}") unless missing.empty?

        @out.puts JSON.pretty_generate(send(config.fetch(:action), options))
        0
      rescue OptionParser::ParseError, KeyError => error
        fail_with(error.message)
      end

      private

      def parse_options
        options = { allowed_image_hosts: [] }
        parser = OptionParser.new do |parser|
          parser.banner = "Usage: jira-comment [#{COMMANDS.keys.join("|")}] [options]"
          parser.on("--issue-key ISSUE", "Jira issue key") { |value| options[:issue_key] = value }
          parser.on("--comment-id ID", "Jira comment ID") { |value| options[:comment_id] = value }
          parser.on("--markdown-file FILE", "Markdown file for create/update") { |value| options[:markdown_file] = value }
          parser.on("--image-host HOST", "Allowed remote image host; repeatable") do |value|
            options[:allowed_image_hosts] << value
          end
        end
        parser.parse!(@argv)
        options
      end

      def list_comments(options)
        client.list_comments(issue_key: options.fetch(:issue_key))
      end

      def get_comment(options)
        client.get_comment(issue_key: options.fetch(:issue_key), comment_id: options.fetch(:comment_id))
      end

      def create_comment(options)
        client.create_markdown_comment(
          issue_key: options.fetch(:issue_key),
          markdown: File.read(options.fetch(:markdown_file)),
          allowed_image_hosts: options.fetch(:allowed_image_hosts)
        )
      end

      def update_comment(options)
        client.update_markdown_comment(
          issue_key: options.fetch(:issue_key),
          comment_id: options.fetch(:comment_id),
          markdown: File.read(options.fetch(:markdown_file)),
          allowed_image_hosts: options.fetch(:allowed_image_hosts)
        )
      end

      def delete_comment(options)
        client.delete_comment(issue_key: options.fetch(:issue_key), comment_id: options.fetch(:comment_id))
        { deleted: true }
      end

      def client
        @client ||= @client_factory.call(env: @env)
      end

      def build_client(env:)
        Client.new(
          base_url: env.fetch("JIRA_BASE_URL"),
          email: env.fetch("JIRA_EMAIL"),
          api_token: env.fetch("JIRA_API_TOKEN")
        )
      end

      def fail_with(message)
        @err.puts(message)
        1
      end

      def option_names(keys)
        keys.map { |key| "--#{key.to_s.tr("_", "-")}" }.join(", ")
      end
    end
  end
end
