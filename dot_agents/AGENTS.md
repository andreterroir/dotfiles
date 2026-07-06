## Restrictions

Do not interact with Git repository or GitHub (via API or `gh` CLI) unless
asked explicitly.

## Before Making Changes

Create a Git worktree first, unless asked to make changes to the current branch
or the working directory within a worktree already (a child of `.wt/` or in
`git worktree list`). Create worktrees with `git worktree add
.wt/<branch-name>` using a short simple name referencing the change being
made, e.g. `message-length-validation`.

## Before Committing Changes

Start a code review, if it was not yet performed, using the agent's native
review capability if available.

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
- Limit the subject line to ~50 characters.
- Omit trailing punctuation in the subject.
- Separate subject from body with a blank line.
- Wrap the body at 72 characters.
- Use the body to explain what and why, not how.

### Attribution trailers

When committing as an agent, append the following Git trailers to every
commit message, separated from the body by a blank line:

    Model: <provider/model>
    Agent: <agent-name>
    Agent-Session: <session-id>

Examples of the `Model` value: `bedrock/sonnet-4.6`,
`opencode-go/minimax-m3`. Use the current session ID provided by the
agent runtime for `Agent-Session`.
