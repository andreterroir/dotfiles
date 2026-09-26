## Local Configuration

If present, inspect `~/.agents/AGENTS.local.md` and respect the instructions
found there, which take precedence over the content of this file in case of
conflicts.

## Restrictions

To avoid reading large binary files unintentionally, inspect files without
extension first using `file` command line tool.

Do not push or pull changes from Git remotes and do not interact with GitHub
(via `gh` CLI or an API) unless asked. Exception: you may fetch `origin/main`
to check whether the remote main branch has new commits (see "Before Making
Changes").

## Before Making Changes

The `main` branch is always checked out in the main worktree. Two operations
may fetch `origin/main` as an exception to the "Do not push or pull"
restriction above:

- To create a new branch or worktree from a fresh `main`, run
  `git fetch origin && git rebase origin/main` (in the main worktree)
  before cutting the new branch.
- When working on `main` directly, fast-forward the local `main` reference
  with `git fetch origin && git merge --ff-only origin/main`. If a
  fast-forward is not possible, stop and ask the user — never create a
  merge commit on `main`.

For any other branch, use the existing worktree if the current working
directory is already inside a linked one, or if you were asked to work on a
specific branch that already has one. Otherwise create a new worktree with
`git worktree add .wt/<branch-name>`. Use a short simple name referencing the
change being made as the branch name, e.g. `message-length-validation`.

Never create a nested worktree inside another worktree.

## Making Changes

Keep comments brief. A good comment should speed up reading the code, not slow
it down. Extended context belongs in commit messages, not in comments.

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

Use the provider/model and agent name actually in use, e.g. Model values such
as opencode-go/muse-spark-1.3, opencode-go/minimax-m3, amp/gpt-6-astra
or bedrock/sonnet-4.6, and Agent values such as amp or opencode.

## Publishing Changes

After pushing a branch, if it has an associated pull request, make sure that
that its title and description reflect the most recent changes.

When asked to create a new pull request make sure it has the correct base
branch, if differs from the main branch.
