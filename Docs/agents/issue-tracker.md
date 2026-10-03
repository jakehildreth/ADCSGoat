# Issue tracker: GitHub

Issues and specs for this repo live in GitHub Issues for `jakehildreth/ADCSGoat`. Use the `gh` CLI from this clone. It selects the repository from the Git remote.

## Conventions

- Create: `gh issue create --title "..." --body-file <file>`.
- Read: `gh issue view <number> --json number,title,body,labels,comments`.
- List: `gh issue list --state open --json number,title,body,labels,comments`, with appropriate `--label` and `--state` filters.
- Comment: `gh issue comment <number> --body-file <file>`.
- Apply or remove labels: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`. Use the mappings in `triage-labels.md`.
- Close: `gh issue close <number> --comment "..."`.

## Pull requests as a triage surface

**PRs as a request surface: no.**

When set to `yes`, use the `gh pr` equivalents:

- Read: `gh pr view <number> --comments` and `gh pr diff <number>`.
- List: `gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`. Keep only `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE` author associations.
- Comment, label, or close: `gh pr comment`, `gh pr edit --add-label` or `--remove-label`, and `gh pr close`.

GitHub shares issue and PR numbers. Resolve an unknown reference with `gh pr view <number>` and fall back to `gh issue view <number>`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --json number,title,body,labels,comments`.

Existing `.scratch/` files remain local records. Read an explicitly referenced local path directly. Publish new issues and specs to GitHub; do not migrate existing files automatically.

## Wayfinding operations

Used by `/wayfinder`. The map is a single issue with child issues as tickets.

- Map: an issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- Child ticket: link it to the map through GitHub sub-issues. If unavailable, add it to a task list in the map and put `Part of #<map>` at the top of the child body. Use `wayfinder:<type>` labels: `research`, `prototype`, `grilling`, or `task`.
- Blocking: use native issue dependencies. Add an edge with `gh api --method POST repos/jakehildreth/ADCSGoat/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`. Get the database ID with `gh api repos/jakehildreth/ADCSGoat/issues/<blocker> --jq .id`; it is not the issue number or node ID. If dependencies are unavailable, use a `Blocked by: #<n>, #<n>` line. A ticket is unblocked when every blocker is closed.
- Frontier: list the map's open children. Exclude tickets with an assignee or open blockers. For native dependencies, check `issue_dependencies_summary.blocked_by`; for text dependencies, check each referenced issue. First in map order wins.
- Claim: `gh issue edit <number> --add-assignee @me` before work.
- Resolve: comment with the answer, close the child issue, then append a context pointer (gist + link) to Decisions-so-far in the map.
