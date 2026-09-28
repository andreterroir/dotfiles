## Local Configuration

If present, inspect `~/.agents/AGENTS.local.md` and respect the instructions
found there, which take precedence over the content of this file in case of
conflicts.

## Restrictions

To avoid reading large binary files unintentionally, inspect files without
extension first using `file` command line tool.

When Git repository has staged changes, keep your modifications unstaged in the
working directory, until asked to commit.

## Before Making Changes

Keep `main` branch always checked out in the main worktree (repository root).

Create a Git worktree first, unless asked to make changes to a branch with an
existing worktree, or the working directory is within a linked worktree. Never create a
nested worktree inside another worktree.

Make sure the base branch is up to date by fetching it from the remote. If a
fast-forward is not possible, stop and ask the user — never create a merge
commit on `main`.

Create worktrees with `git worktree add .wt/<branch-name>` using a short
simple name referencing the change being made, e.g.
`message-length-validation`.

## Making Changes

Keep comments brief. A good comment should speed up reading the code, not slow
it down. Extended context belongs in commit messages, not in comments.

## After Making Changes

Start a code review using the review tool/subagent, not within the context of
the main conversation.

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

Break down changes into small logical commits. Ask what to do with unrelated
changes. Make sure that all verifications (compilation, linter, test etc.) pass
as of each commit.

### Commit Messages

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

When committing as an agent, append the following Git commit trailer to every
commit message, separated from the body by a blank line:

	Assisted-by: <agent>:<model>

Replace `<agent>` with the agent actually in use, e.g. `Amp` or `OpenCode`.
Replace `<model>` with the model actually in use, with no provider prefix,
e.g. `gpt-6-astra`, `kimi-k3`, `minimax-m3`, or `sonnet-4.6`.

## Publishing Changes

After pushing a branch, if it has an associated pull request, make sure that
that its title and description reflect the most recent changes.

When asked to create a new pull request make sure it has the correct base
branch, if differs from the main branch.
