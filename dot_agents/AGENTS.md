Do not interact with Git repository or GitHub (via API or gh CLI) unless
prompted explicitly.

## Commit Messages

Follow https://commit.style unless the repository has its own commit
instructions (e.g., repo-level AGENTS.md or CONTRIBUTING.md):

- Capitalize the subject line.
- Use the imperative mood ("Fix bug", not "Fixed bug").
- Limit the subject line to ~50 characters.
- Omit trailing punctuation in the subject.
- Separate subject from body with a blank line.
- Wrap the body at 72 characters.
- Use the body to explain what and why, not how.

## Documentation maintenance

When making structural changes to a repository — such as renaming
files, reorganising directories, or changing configuration variable
names — update the repo's agent instruction file (`AGENTS.md` or
equivalent) to keep layout descriptions and references accurate.
