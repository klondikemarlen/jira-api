# Marlens Jira API

Small Ruby helper for Jira Cloud comments. It provides basic Jira comment CRUD, converts Markdown to Atlassian Document Format, and can upload allowed remote images as Jira issue attachments.

[RubyGems: `marlens-jira-api`](https://rubygems.org/gems/marlens-jira-api)

## Install

```ruby
gem "marlens-jira-api", "~> 0.5"
```

## Ruby API

```ruby
client = Marlens::JiraApi::Client.new(
  base_url: ENV.fetch("JIRA_BASE_URL"),
  email: ENV.fetch("JIRA_EMAIL"),
  api_token: ENV.fetch("JIRA_API_TOKEN")
)

comments = client.list_comments(issue_key: "WRAPX-123")
comment = client.get_comment(issue_key: "WRAPX-123", comment_id: "10001")

created = client.create_markdown_comment(
  issue_key: "WRAPX-123",
  markdown: "# Release notes\n\n1. Verify `code` and **bold** text."
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
jira-comment create --issue-key WRAPX-123 --markdown-file pr-body.md
jira-comment update --issue-key WRAPX-123 --comment-id 10001 --markdown-file edited.md
jira-comment delete --issue-key WRAPX-123 --comment-id 10001
```

Remote Markdown image URLs are advanced opt-in behavior. Pass `allowed_image_hosts:` in Ruby or repeat `--image-host` in the CLI only when you intentionally want the gem to fetch images from trusted hosts, upload them to Jira, and convert them into Jira media attachments.

Ruby callers that need to detect degraded images can pass an array via `image_upload_failures:`. Add `strict_images: true` in Ruby or `--strict-images` in the CLI to raise `Marlens::JiraApi::ImageUploadError` instead of falling back to `Alt text: URL` when an image cannot be fetched or uploaded.

## Feature and Issue Workflow

Preferred flow for issue and feature work:

1. Create or identify the GitHub issue with the user story and acceptance criteria.
2. Branch from current `main` using the issue number and a short slug before editing when possible. If scoped work already exists locally, create the issue-named branch before committing.
3. Make the smallest change that resolves the request, including tests and README updates that must stay in sync.
4. For releasable changes, bump `Marlens::JiraApi::VERSION` before opening the release PR.
5. Open a draft PR, link the issue, include the checks run, and mark it ready only after verification.
6. Merge the PR to `main` so GitHub records the review path.
7. After merge, build and publish the gem version to RubyGems with `gem build marlens-jira-api.gemspec` and `gem push marlens-jira-api-<version>.gem`.
8. Verify RubyGems lists the released version with `gem list --remote marlens-jira-api --exact --all`; if that output is stale, verify the specific version API at `https://rubygems.org/api/v2/rubygems/marlens-jira-api/versions/<version>.json`.
9. Run an install or CLI smoke check against the published gem in an isolated temporary gem home; the project uses `gemspec` through Bundler and does not need its own gem installed locally.
10. Keep one-off smoke cleanup helpers in `tmp/`, delete them before committing, and do not turn cleanup-only scripts into product API.
