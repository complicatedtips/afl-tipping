-- Lock down database access from the browser (anon / logged-in member keys).
--
-- Before this migration:
--   * 20 tables had Row Level Security OFF, so anyone holding the public anon key
--     (it ships in every page) could read or change them: payment records, the admin
--     audit log, interested-member emails, reminder logs, caches, etc.
--   * memberships_all_own let a logged-in member UPDATE their own membership row,
--     e.g. set role = 'owner' (admin access) or payment_status = 'paid'.
--   * competitions_all_authenticated let any logged-in member edit or delete the
--     competition itself.
--
-- The app's server routes use the service-role key, which bypasses RLS, so none of
-- this changes what the site can do. It only removes what a member could do by
-- talking to the database directly.

begin;

-- 1. Server-only tables: RLS on, no policies => only the service role can touch them.
alter table public.admin_anomaly_dismissals          enable row level security;
alter table public.admin_audit_log                   enable row level security;
alter table public.announcements                     enable row level security;
alter table public.automation_alert_events           enable row level security;
alter table public.automation_job_runs               enable row level security;
alter table public.leaderboard_group_invites         enable row level security;
alter table public.leaderboard_group_members         enable row level security;
alter table public.leaderboard_groups                enable row level security;
alter table public.leaderboard_snapshot_cache        enable row level security;
alter table public.next_season_interest              enable row level security;
alter table public.odds_snapshot_notification_emails enable row level security;
alter table public.payment_records                   enable row level security;
alter table public.payment_reminder_emails           enable row level security;
alter table public.prelock_reminder_emails           enable row level security;
alter table public.round_locked_tips_cache           enable row level security;
alter table public.round_recap_emails                enable row level security;
alter table public.round_recaps                      enable row level security;
alter table public.round_tip_status_cache            enable row level security;
alter table public.scoring_automation_runs           enable row level security;
alter table public.season_champions                  enable row level security;

-- 2. Competitions: logged-in members may read (join-by-code needs it); no writes.
drop policy if exists competitions_all_authenticated on public.competitions;
create policy competitions_select_authenticated on public.competitions
  for select to authenticated
  using (true);

-- 3. Memberships: read your own row; join only as a plain, unpaid member.
--    Role and payment changes happen only through admin server routes.
drop policy if exists memberships_all_own on public.memberships;
create policy memberships_select_own on public.memberships
  for select to authenticated
  using (user_id = auth.uid());
create policy memberships_insert_self_as_member on public.memberships
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and role = 'member'
    and payment_status = 'pending'
    and is_test_account = false
  );

commit;
