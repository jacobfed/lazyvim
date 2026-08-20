# Work dashboard enhancements

## Current state

Four-tab floating window (`<leader>aj`) pulling from ADO REST API and local git.

- **Work** — my work items, PRs to review, my open PRs, available for pickup, available for code review
- **Repos** — local git repos under `~/Documents/code` with branch and dirty-file count
- **Pipelines** — latest build result per repo/branch
- **Projects** — active PRs with linked work items and build status, one row per PR

Auto-refreshes every 10 minutes. `y` yanks the URL or path on the current line. Numbers 1-8 jump to sections across tabs.

---

## Queued enhancements

### Low effort

**PR age.** Add a column showing how long a PR has been open (`3d`, `12h`) using `creationDate` from the builds API response. Stale PRs need a visual signal.

**Sprint days remaining.** Show days left in the sprint next to the sprint label in the My Work Items header. One extra field from the already-fetched iteration data.

**Reviewer summary on My Open PRs.** The Projects tab shows `2/3 appr` per PR. The same aggregate should appear on tab 1's My Open PRs section. The reviewer data is already in the API response.

**Repo ahead/behind remote.** Add `git rev-list --count HEAD..@{u}` and `@{u}..HEAD` to the repos scanner. Shows `+2 -1` for unpushed/unpulled commits without running a fetch.

### Medium effort

**Description preview.** Press `K` on a work item row to open a small floating window with `System.Description`. Useful for items you don't recognize by title alone. Requires one extra API call per item, on demand.

**State transition.** Press `m` on a work item to pick a new state from a small menu, then PATCH via the work items API. Saves a browser round-trip for routine state moves like In Development to Code Review.

**Filter.** Press `/` to narrow the current section by text match. `<Esc>` clears. No API call needed, just filters the already-loaded rows.

### Larger

**Standup summary.** Press `S` to generate a formatted standup from My Work Items and open PRs, then yank it to the clipboard. Useful if your standup format is consistent.

**New work item.** Press `n` to enter a title, then POST a new Task or Bug into the current sprint's area path. Avoids switching to a browser to create quick tasks.

**Status line integration.** A lightweight component that polls in the background and shows an indicator (e.g. a red dot) in the status line when something needs attention. Right now the dashboard is pull-only, so a failing build goes unnoticed until you open it.

---

## Design observations

The tabs group by kind (work items, repos, pipelines, projects). A more useful grouping is by what needs action now.

Priority order that reflects actual urgency:
1. Broken builds on your branches
2. PRs where you're blocking someone (reviews not done)
3. PRs with comments waiting on you
4. Your active work items
5. Available for pickup

The Projects tab is the most complete view since it shows story, PR, and build together. The case for making it tab 1 gets stronger as it matures. Tab 1's My Open PRs and tab 3's Pipelines are partial views of the same information Projects shows in full.

A single summary line at the top of every tab (`2 failing  1 PR to review  3 passing`) would let you assess health without reading individual rows.

Capping sections at 5-7 rows with a `(+N more)` indicator would reduce scroll time. Twenty available items is noise.

---

## Deferred

**MCP server.** Expose the ADO queries as MCP tools so Claude has live access to sprint items, PRs, and build status during coding sessions. Tabled for now but high leverage once the dashboard data stabilizes.
