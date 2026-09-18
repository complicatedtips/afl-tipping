# Complicated Tips Site Handoff

This document is a self-contained project briefing for another model or engineer reviewing the site.

## What This Site Is

Complicated Tips is a Next.js/Supabase AFL tipping application for a private competition. Members tip every AFL match in a round, tips lock at round lock time, and scoring awards decimal points equal to the winner's locked odds. The app includes member tipping, post-lock tip visibility, round results, leaderboard, stats, chat, announcements, admin tools, payment/onboarding workflows, automated fixture/results sync, odds snapshots, reminders, recaps, and observability.

Production references in the repo assume:

- Site URL: `https://www.complicatedtips.com`
- Current season default: `2026`
- Timezone for user-facing dates: `Australia/Melbourne`
- Deployment: Vercel, Sydney region (`vercel.json` sets `syd1`)

## Tech Stack

- Framework: Next.js App Router, currently `next ^16.2.2`
- UI: React `19.2.3`, mostly hand-authored CSS in `app/globals.css` and small shared UI components
- Auth/database: Supabase via `@supabase/ssr` and `@supabase/supabase-js`
- Email provider: Resend via direct REST calls
- External data:
  - Squiggle API for AFL fixture/results
  - The Odds API for Sportsbet AFL H2H odds
- Tests: Node test runner with TypeScript stripping

Important commands:

```bash
npm run dev
npm run build
npm run start
npm run lint
npm run test
npm run test:regression
```

The build script runs `scripts/build-with-label.mjs`, which injects `NEXT_PUBLIC_BUILD_LABEL` for the in-app build label.

## Environment Variables

Known env vars from code and local config names:

- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `NEXT_PUBLIC_CURRENT_SEASON`
- `NEXT_PUBLIC_SIGNUPS_OPEN`
- `NEXT_PUBLIC_SITE_URL`
- `CRON_SECRET`
- `ODDS_API_KEY`
- `RESEND_API_KEY`
- `REMINDER_FROM_EMAIL`
- `REMINDER_REPLY_TO`
- `ROUND_RECAP_FROM_EMAIL`
- `ROUND_RECAP_REPLY_TO`
- `ROUND_RECAP_TO_EMAIL`
- `PAYMENT_REMINDER_INSTRUCTIONS`
- `ACTIVE_SCORING_FAILURE_ALERT_EMAIL`
- `ACTIVE_SCORING_FAILURE_ALERT_THRESHOLD`
- `ACTIVE_SCORING_FAILURE_ALERT_COOLDOWN_MINUTES`
- `ACTIVE_SCORING_STALE_WARNING_MINUTES`
- `SQUIGGLE_USER_AGENT`

Do not expose secret values. API routes that use the service role must remain server-only.

## Application Structure

Core directories:

- `app/`: Next.js pages and API routes
- `components/`: client UI and layout components
- `lib/`: shared domain rules, data loading, auth, scoring, caches, admin helpers
- `db/migrations/`: database changes layered on the baseline Supabase schema
- `tests/regression/`: focused rule regression tests
- `.github/workflows/`: scheduled/manual automation workflows
- `docs/`: operational and workflow notes

## Auth And Layout

Supabase Auth is the identity system. Server components use `createClient()` from `lib/supabase-server.ts` to read sessions from cookies. Server jobs and privileged routes use `createServiceClient()` with the service role.

`proxy.ts` attaches `x-pathname` to requests so `app/layout.tsx` can decide whether to render the public shell or the authenticated app chrome.

Public paths:

- `/login`
- `/signup`
- `/forgot-password`
- `/reset-password`
- `/next-season`
- `/howitworks`

Authenticated pages generally redirect to `/login` if there is no session. Admin status is determined from `memberships.role in ('owner', 'admin')`.

Admin/cron API authorization is centralized in `lib/admin-auth.ts`:

- `requireAdminOrCron()` accepts `Authorization: Bearer <CRON_SECRET>`, `?secret=<CRON_SECRET>`, or a valid Supabase bearer token belonging to an owner/admin.
- `getUserIdFromBearer()` validates Supabase access tokens.
- `resolveCompetitionIdForAdminRequest()` picks explicit `competition_id`, then preferred admin competition, then default competition.

## Main User Routes

- `/`: dashboard for signed-in user; unauthenticated users see login.
- `/round/[season]`: list of tipping rounds with user status.
- `/round/[season]/[round]`: tipping page.
- `/results/[season]`: post-lock round result index.
- `/results/[season]/[round]`: round details, picks, score, potential, differences.
- `/leaderboard/[season]`: overall and private group leaderboard UI.
- `/leaderboard/[season]/trend`: leaderboard trend view.
- `/stats`: personal stats and team breakdown.
- `/chat`: member chat.
- `/announcements`: published announcements.
- `/profile`: display name/team/password link.
- `/next-season`: public interest form while signups are closed.
- `/howitworks` and `/info`: public/info pages.

## Core Data Model

The app assumes a baseline Supabase schema with at least:

- `competitions`
- `memberships`
- `profiles`
- `rounds`
- `matches`
- `tips`
- `match_odds`
- `leaderboard_entries`
- `round_locked_tips_cache`
- `chat_messages`
- `chat_reactions`

Migrations add or extend:

- `memberships.payment_status`: `pending`, `paid`, `waived`
- `memberships.is_test_account`: excluded from leaderboards/status/results
- `competitions.enforce_unpaid_tip_lock`
- `profiles.favorite_team`
- `profiles.username` with lowercase unique index and format check
- `competitions.reigning_champion_override_user_id`
- `competitions.champion_highlight_user_ids`
- `season_champions`
- `prelock_reminder_emails`
- `payment_reminder_emails`
- `round_recap_emails`
- `round_recaps`
- `round_tip_status_cache`
- `leaderboard_snapshot_cache`
- `announcements`
- `next_season_interest`
- `leaderboard_groups`, `leaderboard_group_members`, `leaderboard_group_invites`
- `scoring_automation_runs`
- `automation_job_runs`
- `admin_audit_log`
- `payment_records`
- `admin_anomaly_dismissals`
- `automation_alert_events`
- `odds_snapshot_notification_emails`
- `chat_message_mentions`

Many APIs deliberately tolerate missing newer columns/tables and return migration hints, because the project evolved through incremental production migrations.

## Tipping Rules

The core tipping rules are in:

- `lib/scoring-lock-rules.ts`
- `lib/round-page-rules.ts`
- `lib/round-page-data.ts`
- `app/api/tips/save/route.ts`
- `app/api/tips/clear-round/route.ts`

Rules:

- A round is locked when `Date.now() >= rounds.lock_time_utc`.
- If `lock_time_utc` is missing or invalid, the round is treated as locked.
- Tips can be saved only before lock.
- Tip save validates the user is a member of the resolved competition.
- `picked_team` must exactly match the match home or away team.
- Tips upsert on conflict `match_id,user_id`.
- Clearing a round deletes all of that user’s tips for the round, only before lock.
- After tip save/clear, `round_tip_status_cache` is invalidated.
- If `competitions.enforce_unpaid_tip_lock = true`, pending members cannot save/clear tips.
- Owners/admins bypass the unpaid lock.

Competition resolution:

- If `competition_id` is supplied, use it.
- Otherwise resolve by user membership and season/round.
- If multiple candidates exist, choose the competition with the most matching rounds or memberships, with deterministic ID tiebreaks.

## Odds And Scoring

Scoring uses locked odds snapshots, not live/latest odds.

Important files:

- `lib/odds-snapshot-scheduler.ts`
- `app/api/admin/snapshot-odds-all-due/route.ts`
- `app/api/admin/snapshot-odds/route.ts`
- `lib/leaderboard-snapshot.ts`
- `lib/round-results-rules.ts`

Rules:

- Odds are captured 36 hours before round lock.
- `rounds.odds_snapshot_for_time_utc` records the snapshot instant used for scoring.
- `match_odds.snapshot_for_time_utc` must match the round snapshot for scoring.
- Non-force odds snapshot inserts missing odds only; it does not overwrite existing rows.
- Force snapshot can upsert/overwrite, but completed rounds are still protected.
- Once any match in a round is completed, odds are read-only for that round.
- Scoring awards points only for correct tips.
- Points for a correct tip are the winning team’s decimal odds from the locked snapshot.
- Incorrect, missing, drawn, or unscorable tips earn 0.
- Matches without locked odds are skipped for leaderboard scoring.
- A match is considered completed if it has a `winner_team` or a final-like status (`final`, `finished`, `complete`, `completed`, `fulltime`, `full-time`, `ft`).

## Leaderboard Rules

Important files:

- `lib/leaderboard-snapshot.ts`
- `lib/leaderboard-sort.ts`
- `lib/leaderboard-activity.ts`
- `app/api/leaderboard/route.ts`

Leaderboard snapshot behavior:

- Reads season rounds, completed matches, locked snapshot odds, tips, memberships, and profiles.
- Excludes `memberships.is_test_account = true`.
- Participants include all non-test members, plus valid tip users.
- Computes total points, correct tips, tips submitted, tips possible, missed tips, accuracy, latest round score, rank movement, behind leader, current streak, average winning odds, consecutive missed rounds, inactive flag, and trends.
- Writes `leaderboard_entries` best-effort and `leaderboard_snapshot_cache`.
- Cache max age is 2 minutes; stale/missing cache recomputes.
- `preferCached` returns cached data when valid.

Ranking comparator:

1. Higher `total_points`
2. Higher `accuracy_pct`
3. Higher `correct_tips`
4. Display name ascending, case-insensitive

Activity rule:

- Consecutive missed rounds are counted up to the current Melbourne Monday checkpoint.
- `inactive_due_to_missed_rounds` becomes true at 5 consecutive missed rounds.

## Round Status And Post-Lock Visibility

Important files:

- `lib/post-lock-visibility.ts`
- `lib/round-tip-status-data.ts`
- `lib/round-tip-status-rules.ts`
- `app/api/round-tip-status/route.ts`
- `app/api/round-locked-tips/route.ts`
- `app/api/round-tip-breakdown/route.ts`

Rules:

- Post-lock public-for-members data is visible only after `lock_time_utc`.
- `round-tip-status` returns per-round counts and, for admins, missing/tipped player lists.
- A player is “tipped” for a round only if they have at least one valid tip for every match in that round.
- Missing/tipped player lists include `latest_submitted_at_utc` and `last_reminded_at_utc` where available.
- `round_locked_tips_cache` stores everyone’s post-lock picks and potential score.
- Tip breakdown counts team picks per match and is also lock-gated.

## Round Results

Important files:

- `lib/round-results-data.ts`
- `lib/round-results-rules.ts`
- `app/api/round-results/route.ts`

Rules:

- Results are available only after round lock.
- Results include match odds, winners/statuses, total tips, home/away pick counts and percentages.
- Player rows include round score, potential score, difference, correct tips, total tips, accuracy, average correct odds, and picks.
- Eligible players are non-test competition members.
- Player sort: round score desc, correct tips desc, potential score desc, display name asc.
- Accuracy uses completed games in the round as the base.

## Stats

Important files:

- `lib/stats-data.ts`
- `lib/stats-rules.ts`
- `lib/stats-types.ts`
- `app/stats/page.tsx`
- `app/api/my-stats-insights/route.ts`
- `app/api/profile-team-stats/route.ts`

Stats derive from the same leaderboard/scored-match base:

- Snapshot: rank, total points, accuracy, behind leader, movement, streak, correct/submitted/missed tips, round score, avg winning odds.
- Insights: current/longest streak, underdog record, favourite record, risk profile, contrarian edge, best/worst round, points vs competition average, missed-tip impact.
- Team stats normalize AFL team names and show tipped/correct/incorrect/points/averages per team.
- Stats base is cached with `unstable_cache`, revalidate 60 seconds, tag `stats-season-base-v1`.
- Result sync invalidates the stats cache tag.

## AFL Team Display Rules

Important files:

- `lib/afl-teams.ts`
- `lib/team-display.ts`

Canonical selectable teams include all AFL teams plus `no AFL team`. During Sir Doug Nicholls windows in season 2026, selected team display names can render as renamed names:

- Adelaide -> Kuwarna
- Fremantle -> Walyalup
- Melbourne -> Narrm
- Port Adelaide -> Yartapuulti
- St Kilda -> Euro-Yroke
- West Coast -> Waalitj Marawar

This is display-only; scoring and stored team matching still use canonical match team names.

## Chat

Main file: `app/chat/page.tsx`

Features:

- Member-only chat resolved to the active/current competition.
- Recent message list, realtime refresh on `chat_messages`, `chat_reactions`, `chat_message_mentions`.
- Message max length: 3000 characters.
- Slow-mode UI copy says 1 message per 3 seconds.
- Auto-delete policy is described in UI as 30 days, but actual cleanup is not visible in this repo.
- Reactions: thumbs up, laughing, crying, heart, fire, surprised.
- Replies via `reply_to_message_id`.
- Edits via `edited_at`.
- Owners can edit/delete their own messages for 5 minutes.
- Admins can delete messages outside that window.
- Mentions parse `@alias`, resolve against usernames/display names, and write `chat_message_mentions`.
- Ambiguous mention aliases are removed; fallback aliases get suffixes.
- Mentions of the current user are highlighted and counted if unread.

Chat-related migrations add reply/edit fields and mention records with RLS policies.

## Announcements

Files:

- `app/announcements/page.tsx`
- `app/api/announcements/route.ts`
- `app/api/admin/announcements/route.ts`
- `db/migrations/20260325_announcements.sql`

Rules:

- Members read published global announcements (`competition_id is null`) and competition-specific announcements.
- Results are sorted pinned first, then newest published/created.
- Admin API requires bearer user with owner/admin membership.
- Admins can create, update, delete.
- Title max normalized to 140 chars, body to 12000 chars.
- Image URLs must be valid HTTP(S), deduped, max 12.

## Private Leaderboard Groups

Files:

- `lib/leaderboard-groups.ts`
- `lib/leaderboard-group-insights.ts`
- `app/api/leaderboard-groups/*`
- `app/api/leaderboard-group-invites/*`
- `db/migrations/20260327_leaderboard_groups.sql`

Features:

- Members can create named private leaderboard groups for a season.
- Creator is added as a member.
- Members can invite other competition members.
- Invites can be pending/accepted/declined.
- Pending invite uniqueness is enforced per `group_id + invited_user_id`.
- Group summary computes leader, current user position, biggest mover, and round leader from scoped leaderboard rows.
- Missing table errors return migration hints.

## Payments And Onboarding

Important files:

- `lib/payment-ledger.ts`
- `lib/onboarding-workflow.ts`
- `lib/onboarding-reminders.ts`
- `app/admin/payments/page.tsx`
- `app/admin/onboarding/page.tsx`
- `app/admin/interested-members/page.tsx`
- `app/api/admin/payments/*`
- `app/api/admin/onboarding/*`
- `app/api/next-season-interest/route.ts`
- `docs/BL-033-payment-and-onboarding-workflow.md`
- `docs/BL-033-simplified-next-season-invite-flow.md`

Payment rules:

- Season buy-in defaults to 3000 cents for 2026 and 2027.
- Membership payment statuses: `pending`, `paid`, `waived`.
- Payment records can be unmatched/matched/ignored.
- Matching suggestions score exact email, email in payer details, display name tokens, expected amount, and pending status.
- Matched payment records can link to users and onboarding rows.
- Payment truth remains on `memberships.payment_status`; onboarding derives `payment_pending`/`active` from linked membership status.

Onboarding status model in code:

- `new`
- `reviewed`
- `contacted`
- `invited`
- `joined`
- `payment_pending`
- `active`
- `archived`

The latest doc recommends simplifying future workflow to:

- `queued`
- `invited`
- `joined`
- `payment_pending`
- `active`
- `archived`

Current public flow:

- If `NEXT_PUBLIC_SIGNUPS_OPEN=false`, signup page is paused and people are routed toward `/next-season`.
- Public next-season submissions upsert into `next_season_interest`.
- Admin pages can review, edit, delete, invite, link members, manage payment state, and send season-open emails.

## Profile And Signup

Files:

- `app/login/page.tsx`
- `app/signup/page.tsx`
- `app/auth/callback/route.ts`
- `app/profile/page.tsx`
- `app/api/profile/route.ts`
- `lib/username.ts`

Rules:

- Signup is gated by `SIGNUPS_OPEN`, derived from `NEXT_PUBLIC_SIGNUPS_OPEN`; default is closed.
- Signup requires email, password >= 6 chars, and favorite team.
- Signup metadata can bootstrap display name, favorite team, and username on callback.
- Password reset routes support Supabase recovery links and hash/session variants.
- Profile lets users update display name and favorite team; email is read-only.
- Username validation, where used: 3-24 chars, lowercase letters/numbers/underscores.

## Champion Highlighting

Files:

- `lib/reigning-champion.ts`
- `lib/season-champions.ts`
- `lib/champion-metadata.ts`
- `components/ChampionCrown.tsx`
- `components/ChampionSeasonLabels.tsx`

Data sources:

- `season_champions` records.
- `competitions.reigning_champion_override_user_id`.
- `competitions.champion_highlight_user_ids`.

Leaderboard, results, chat, and related views include champion metadata and highlight user IDs.

## Automation And Operations

GitHub workflows:

- `.github/workflows/regression-tests.yml`
- `.github/workflows/snapshot-odds.yml`
- `.github/workflows/fixture-sync-finals-2026.yml`
- `.github/workflows/prelock-reminders.yml`
- `.github/workflows/scoring-sync-15m.yml`
- `.github/workflows/scoring-sync-daily-full.yml`
- `.github/workflows/round-recap.yml`

README notes Vercel Hobby only supports daily cron jobs, so high-frequency automations should be triggered externally or from GitHub Actions.

Recommended external scheduler endpoints:

- Every 5 minutes: `/api/cron/scoring-active?season=2026`
- Every 5 minutes: `/api/cron/prelock-reminders?season=2026`
- Daily UTC: `/api/cron/scoring-daily-full?season=2026`

All require:

```http
Authorization: Bearer <CRON_SECRET>
```

### Fixture Sync

File: `app/api/admin/sync-fixture/route.ts`

- Fetches Squiggle games and teams for a season.
- Upserts `rounds` by `competition_id,season,round_number`.
- Uses first match time as `first_match_time_utc` and `lock_time_utc`.
- Upserts `matches` by `squiggle_game_id`.
- Parses Squiggle times carefully, preferring `unixtime` and then timezone-aware/local Melbourne conversions.
- Invalidates round tip status cache when rounds/matches change.

### Result Sync

File: `app/api/admin/sync-results/route.ts`

- `scope=active`: only locked unfinished rounds with matches at least 3 hours after commence.
- `scope=full`: all season rounds.
- Active sync throttles Squiggle fetches for the same round for 10 minutes.
- Fetches Squiggle completed games (`complete=100`).
- Updates `matches.winner_team` and `matches.status = 'final'`.
- Handles draws by setting final status with null winner.
- Invalidates round tip status, leaderboard snapshot, and stats cache when updates occur.
- Writes admin audit log.

### Scoring Automation

File: `app/api/admin/run-scoring-automation/route.ts`

Sequence:

1. Calls `/api/admin/sync-results`.
2. If result updates occurred, calls `/api/admin/recalc-leaderboard`.
3. If sync updated or daily full run, calls `/api/admin/send-round-recap?save_only=1&hours_after_first=0&skip_if_exists=1`.
4. Logs to `scoring_automation_runs`.
5. On daily full jobs, deletes old scoring automation runs after 72 hours.
6. Sends active scoring failure email alerts after consecutive `scoring_15m` failures.

Skip behavior:

- If active sync has no live round or is throttled, it records a success/skipped-style response and does not recalc.

### Odds Snapshot

Files:

- `lib/odds-snapshot-scheduler.ts`
- `app/api/admin/snapshot-odds-all-due/route.ts`
- `app/api/admin/snapshot-odds/route.ts`

Rules:

- Snapshot due time is `lock_time_utc - 36 hours`.
- Scheduler picks one target round per request.
- Normal mode picks first due, uncaptured, not-completed round.
- Force mode can backfill first due pending or next upcoming pending round.
- Round-specific request acts on that round.
- Completed rounds with missing snapshots are reported as read-only.
- After successful non-force capture, the app triggers odds-added emails.
- Snapshot automation logs to `automation_job_runs` and `admin_audit_log`.

### Pre-Lock Reminders

Files:

- `app/api/admin/send-prelock-reminders/route.ts`
- `app/api/cron/prelock-reminders/route.ts`
- `db/migrations/20260307_prelock_reminder_emails.sql`

Default scheduler call targets users missing tips in the 15-minute window before 4 hours to lock:

```text
hours_before_lock=4
window_minutes=15
window_direction=before
```

Emails dedupe by `competition_id, round_id, user_id, reminder_type`. There is a force-resend override window near lock.

### Other Email Jobs

- `send-payment-reminders`: payment pending notices, deduped in `payment_reminder_emails`.
- `send-round-recap`: end-of-round recap emails and saved recaps.
- `send-odds-added-emails`: notifies users when locked odds are captured, deduped in `odds_snapshot_notification_emails`.
- `next-season-interest/send-season-open`: season-open invite emails.

Resend calls retry on 429/5xx with `Retry-After`/rate-limit header support and minimum send spacing where implemented.

## Admin Area

Admin pages under `/admin` include:

- dashboard
- members/roster/people settings
- payment settings and payment ledger
- onboarding and interested members
- recaps
- scoring sync
- automation health
- audit log
- announcements
- late tip overrides

Admin APIs generally require bearer admin or cron depending on the operation.

Audit logging:

- `lib/admin-audit.ts`
- `app/api/admin/audit-log/route.ts`
- `app/api/audit/export/route.ts`
- `app/api/audit/options/route.ts`

Audit events cover fixture sync, results sync, leaderboard recalc, odds snapshot, member updates/removals, payment settings, champion settings, and late tip overrides.

## Admin Anomalies And Health

Files:

- `lib/admin-anomalies.ts`
- `app/api/admin/anomalies/route.ts`
- `app/api/admin/anomalies/dismiss/route.ts`
- `app/api/admin/automation-health/route.ts`
- `components/admin/AdminShell.tsx`

Anomaly rules include:

- Odds snapshots due/missing around the 36-hour snapshot window.
- Stale result rounds after configured hours.
- Recaps due 48 hours after first match.
- Pending payment attention after 72 hours.
- Next-season interest attention after a configured month.
- Automation failures and stale active scoring warnings.

Dismissals are stored in `admin_anomaly_dismissals`.

## Caching And Invalidation

Database caches:

- `round_tip_status_cache`
- `leaderboard_snapshot_cache`
- `round_locked_tips_cache`

Next cache:

- stats base cache, tag `stats-season-base-v1`

Invalidate after:

- Tip save/clear -> round tip status cache.
- Fixture sync -> round tip status cache.
- Result sync updates -> round tip status cache, leaderboard snapshot cache, stats cache.
- Leaderboard recalc/refresh -> writes leaderboard cache and entries.

## Testing

Regression tests live in `tests/regression/*.test.mts`.

Current test coverage focuses on rule modules, including:

- scoring lock time
- round page rules
- round results rules
- leaderboard sort and tip groups
- leaderboard trend
- post-lock visibility
- match status
- stats rules
- payment ledger
- onboarding workflow
- admin audit/anomalies
- automation observability
- join code
- username/auth callback routing
- snapshot time
- venue/team/round label display

Run:

```bash
npm run test:regression
```

CI runs regression tests on PRs, pushes to `main`, schedule every 12 hours, and manual workflow dispatch. Failures on main/scheduled runs open or update a GitHub issue titled `[CI] Regression tests failing`; successes close it.

## Known Backlog And Docs

Planning has moved to a single strategic-pillars doc, which is now the backlog and plan for the site: [Complicated Tips — Unified Backlog & Strategic Pillars](https://claude.ai/code/artifact/05e95e01-3b73-45cd-8c5a-b0c09927b2b4). The legacy `BACKLOG.md`, `BACKLOG_BUGS.md`, `BACKLOG_FEATURES.md` and `BACKLOG_UI_UX.md` files were removed from the repo (commit `793f4c6`).

`docs/end-of-season-checklist.md` still has local modifications in the worktree.

Other docs:

- `docs/end-of-season-feedback-form-draft.md`
- `docs/BL-033-payment-and-onboarding-workflow.md`
- `docs/BL-033-simplified-next-season-invite-flow.md`

The BL-033 simplified invite flow is the preferred future direction for onboarding simplification (feeds `MEMB-002` in the pillar doc).

## Design/Implementation Conventions

- Keep business rules in `lib/*` modules and cover them with regression tests.
- Prefer server-side Supabase service client only inside server routes/components.
- Client components use `supabaseBrowser` and bearer tokens where API routes require explicit auth.
- Keep caches invalidated whenever underlying tips, fixture, match results, or scoring data change.
- Treat newer DB features as optional where code already has fallbacks and migration hints.
- Do not change lock/scoring/odds behavior while working on admin/onboarding UI unless explicitly requested.
- For time display, use `Australia/Melbourne`.
- For season defaults, many files still hard-code `2026`; `lib/season-config.ts` is the newer central config for signup/current-season labels.

## Review Hotspots For Another Model

When reviewing this site, pay close attention to:

- Any change that could alter scoring from locked snapshot odds.
- Any route that exposes service-role data or accepts bearer/cron auth.
- Cache invalidation after tips/results/fixture changes.
- Differences between hard-coded `2026` constants and `NEXT_PUBLIC_CURRENT_SEASON`.
- Missing migrations in a target environment.
- Admin/cron routes that call other internal routes and need the right secret/bearer forwarding.
- Client-side chat permissions versus database RLS.
- Payment/onboarding derived state so payment truth does not diverge from `memberships.payment_status`.
- Odds snapshot read-only protection once results exist.

