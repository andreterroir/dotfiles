## Local Configuration

If present, inspect `~/.agents/AGENTS.local.md` and respect the instructions
found there, which take precedence over the content of this file in case of
conflicts.

## Restrictions

To avoid reading large binary files unintentionally, inspect files without
extension first using `file` command line tool.

Do not push or pull changes from Git remotes and do not interact with GitHub
(via `gh` CLI or an API) unless asked. Exception: you may fetch the default
branch before creating new worktrees (see "Before Making Changes").

## Before Making Changes

When inside a Git repository, always make changes within a non-main Git
worktree, unless asked explicitly to work on the default branch.

Before cutting a new branch or worktree, ensure the local default branch is up
to date: `git fetch origin` and rebase onto `origin/main`. Only update the
local main reference when working on the default branch directly, since it is
always checked out in the main worktree. This is a permitted exception to the
"Do not push or pull" restriction above.

Use the existing worktree, if asked to work on a specific branch that has a
linked worktree or the current working directory is already inside a worktree.
Otherwise create a new worktree with `git worktree add .wt/<branch-name>`. Use
a short simple name referencing the change being made as the branch name, e.g.
`message-length-validation`.

Never create a nested worktree inside another worktree.

## After Making Changes

Start a code review, if it was not yet performed, with the agent's native
review capability (agent/tool), if available. Use the review tool before
committing to catch issues that a manual pass misses.

## Code Review

- flag any unrelated changes
- make sure the documentation is up to date and reflects state after the
  changes
  - code comments close to the changed code
  - code comments for the parent scope of the changed code
  - project documentation (`README.md`, `docs/`, `AGENTS.md` etc.)
- make sure that any temporary changes (e.g. debug print statements) were
  undone

## Committing Changes

- break down into small logical changes
- ask what to do with unrelated changes

## Commit Messages

Follow https://commit.style unless the repository has its own commit
instructions (e.g., repo-level `AGENTS.md` or `CONTRIBUTING.md`):

- Capitalize the subject line.
- Use the imperative mood ("Fix bug", not "Fixed bug").
- Limit the subject line to 50 characters.
- Omit trailing punctuation in the subject.
- Separate subject from body with a blank line.
- Wrap the body at 72 characters.
- Use the body to explain what and why, not how.

### Attribution Trailers

When committing as an agent, append the following Git trailers to every commit
message, separated from the body by a blank line:

	Model: <provider/model>
	Agent: <agent-name>

Examples of the `Model` value: `bedrock/claude-sonnet-4.6`,
`opencode-go/minimax-m3`.

## Publishing Changes

After pushing a branch, if it has an associated pull request, make sure that
that its title and description reflect the most recent changes.

When asked to create a new pull request make sure it has the correct base
branch, if differs from the main branch.
