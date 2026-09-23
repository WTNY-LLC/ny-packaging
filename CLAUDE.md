# NY Packaging app

Read this before changing anything. It is loaded by every Claude session opened in this folder.

This repo is the Wizard Trees NY Packaging app and nothing else. Gianni and Kelsey (NY packaging
lead) both change it, each by asking their own Claude. Every change goes straight to `main`, with
no branches and no pull requests. The person asking for a change should never have to touch git.

- **Live:** https://wtny-llc.github.io/ny-packaging/
- **Who uses it:** the NY packaging crew, all day. A broken push breaks their board.
- **Database:** Supabase project `uxpjbxmfluwfxwkefqkk` ("ny-packaging"), which holds only this
  app's data.

## Every change, every time

1. **Pull first.** Run `git pull --rebase --autostash origin main` before reading or editing
   anything. The other person may have pushed since your last change. Never discard unsaved edits
   to make a pull succeed.
2. **Make only the requested change.**
3. **Check it.** Run `node tests/ny-check.mjs`. Never push if it fails; fix it first.
4. **Commit by file name** (`git add <file>`), with one plain sentence about what changed.
5. **Push.** `git push origin main`. If it is rejected because the other person pushed first, pull
   again, rerun the check, and push. Never force-push. Never rewrite or revert the other person's
   commits unless the person you are working for asks.
6. **Confirm it is live.** GitHub Pages takes about a minute. Fetch the live page and look for text
   from your change before saying it is done.
7. **Report in plain English.** What changed, where to see it, and anything the person must do.

If a pull conflicts on lines the other person just changed, keep both changes where they fit
together. If they truly contradict each other, stop and ask; do not pick a winner silently.

## Adding a page

A page is two pieces:

- a tab button in the nav: `<button class="tab" data-tab="mypage" data-beta>My page</button>`
- a container in `<main>`: `<div id="view-mypage" hidden> ... </div>`

**A new page keeps `data-beta` until its owner says it is ready.** The crew does not see it.
People marked `beta = true` in `ny_members` (Gianni and Kelsey) see it automatically after signing
in; anyone else sees it only if the address ends in `?beta`. Removing `data-beta` is the launch.

Kelsey's own page is the `kelsey` tab (`view-kelsey`); build her requests there unless she asks
for something else.

## Data

- Every table here is live data the crew sees. Test with rows you create and delete them after.
- Never delete or bulk-update rows you did not create. Never run an UPDATE or DELETE without a
  WHERE that names exactly the rows meant.
- **Who can sign in** is the `ny_members` table (one email per row, plus a `beta` flag for who sees
  in-progress pages). Signing in with any other Google account is refused. Adding someone is one
  INSERT into `ny_members`; keep member emails out of committed files (this repo is public).
- **Structure changes** (new tables, columns, access rules) are run against the database with the
  connection string in `.env.local` (never committed; ask Gianni for it). Save every change you run
  as a numbered file in `supabase/migrations/` (for example `002-add-waste-log.sql`) and commit it,
  so the repo always describes the real database. New tables need row level security with
  `public.is_staff()`, like the existing ones.
- **Timesheet rows marked Gusto** are written every hour by a sync on Gianni's computer, which also
  owns the roster's Gusto link. Hand edits to those rows are overwritten; fix hours in Gusto. Do not
  rename or remove `ny_shifts`, `ny_roster` or their columns without asking Gianni, because the sync
  writes to them.
- The photo reader (`supabase/functions/read-timesheet`) uses an Anthropic key stored in the
  project's secrets. Deploying functions needs Gianni's Supabase access.

## Decisions already made (add new ones here, so both Claudes know them)

- **Overtime is not a raise.** NY overtime is weekly, over 40 hours, and WTNY's Gusto week runs
  Saturday to Friday. A day with overtime shows a blended rate so hours times rate equals the day's
  gross pay, and carries a blue OT pill.
- **Uploaded (non-Gusto) workers are $25/hr.** Gusto workers use their roster rate.
- **Task costs absorb the day's actual payroll.** Each day's worked pay is spread over that day's
  task hours, so task totals always add up to real payroll.
- **5-pack units are single 0.7g sticks**, five per box.
- **Vape carts carry no weight.** They are costed per unit and stay out of every dollars-per-pound
  figure.
- **Sick pay** rows come from Gusto with no clock times and show a Sick Pay pill.
