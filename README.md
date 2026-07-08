# Klondikemarlen Jira API

Small Ruby helper for Jira Cloud comments. It provides basic Jira comment CRUD, converts Markdown to Atlassian Document Format, and can upload allowed remote images as Jira issue attachments.

## Install

```ruby
gem "klondikemarlen-jira-api"
```

## Ruby API

```ruby
client = Klondikemarlen::JiraApi::Client.new(
  base_url: ENV.fetch("JIRA_BASE_URL"),
  email: ENV.fetch("JIRA_EMAIL"),
  api_token: ENV.fetch("JIRA_API_TOKEN")
)

comments = client.list_comments(issue_key: "WRAPX-123")
comment = client.get_comment(issue_key: "WRAPX-123", comment_id: "10001")

created = client.create_markdown_comment(
  issue_key: "WRAPX-123",
  markdown: "# Release notes\n\n1. Verify `code` and **bold** text.",
  allowed_image_hosts: ["github.com", "user-images.githubusercontent.com"]
)

client.update_markdown_comment(
  issue_key: "WRAPX-123",
  comment_id: created.fetch("id"),
  markdown: "Updated comment body."
)

client.delete_comment(issue_key: "WRAPX-123", comment_id: created.fetch("id"))
```

## CLI

Credentials are read from `JIRA_BASE_URL`, `JIRA_EMAIL`, and `JIRA_API_TOKEN`.

```bash
jira-comment list --issue-key WRAPX-123
jira-comment get --issue-key WRAPX-123 --comment-id 10001
jira-comment create --issue-key WRAPX-123 --markdown-file pr-body.md --image-host github.com
jira-comment update --issue-key WRAPX-123 --comment-id 10001 --markdown-file edited.md
jira-comment delete --issue-key WRAPX-123 --comment-id 10001
```
