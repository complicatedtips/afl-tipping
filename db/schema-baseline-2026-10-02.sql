-- Snapshot of the LIVE database structure, rebuilt from the database catalog on 2026-10-02.
-- The files in db/migrations predate many live changes; treat this file as the true starting point.
-- Used to build the test database (complicated-tips-test). No data, structure only.

create sequence if not exists public.chat_message_mentions_id_seq;
create sequence if not exists public.leaderboard_snapshots_id_seq;
create sequence if not exists public.round_recap_emails_id_seq;
create sequence if not exists public.round_recaps_id_seq;
create sequence if not exists public.season_champions_id_seq;
create table public.admin_anomaly_dismissals (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  dismiss_key text not null,
  dismissed_by_user_id uuid,
  dismissed_at_utc timestamp with time zone default now() not null,
  expires_at_utc timestamp with time zone not null,
  created_at timestamp with time zone default now() not null
);
create table public.admin_audit_log (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer,
  action_type text not null,
  result_status text default 'success'::text not null,
  actor_mode text default 'bearer'::text not null,
  actor_user_id text,
  actor_display_name text,
  target_type text,
  target_user_id text,
  target_label text,
  summary text not null,
  request_path text,
  details jsonb,
  created_at timestamp with time zone default now() not null
);
create table public.announcements (
  id uuid default gen_random_uuid() not null,
  competition_id uuid,
  title text not null,
  body text not null,
  image_urls text[] default '{}'::text[] not null,
  is_pinned boolean default false not null,
  is_published boolean default true not null,
  created_by_user_id uuid,
  published_at_utc timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table public.automation_alert_events (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  alert_key text not null,
  alert_channel text not null,
  target text not null,
  context jsonb,
  sent_at_utc timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);
create table public.automation_job_runs (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  job_kind text not null,
  trigger_mode text not null,
  run_status text not null,
  request_path text,
  started_at_utc timestamp with time zone default now() not null,
  finished_at_utc timestamp with time zone default now() not null,
  summary text,
  details jsonb,
  created_at timestamp with time zone default now() not null
);
create table public.chat_message_mentions (
  id bigint default nextval('chat_message_mentions_id_seq'::regclass) not null,
  message_id uuid not null,
  mentioned_user_id uuid not null,
  mentioned_username text not null,
  created_at timestamp with time zone default now() not null
);
create table public.chat_messages (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  body text not null,
  created_at timestamp with time zone default now() not null,
  reply_to_message_id uuid,
  edited_at timestamp with time zone
);
create table public.chat_reactions (
  message_id uuid not null,
  user_id uuid not null,
  emoji text not null,
  created_at timestamp with time zone default now() not null
);
create table public.competitions (
  id uuid default uuid_generate_v4() not null,
  name text not null,
  join_code text not null,
  owner_user_id uuid not null,
  created_at timestamp with time zone default now() not null,
  enforce_unpaid_tip_lock boolean default false not null,
  reigning_champion_override_user_id uuid,
  champion_highlight_user_ids uuid[] default '{}'::uuid[] not null
);
create table public.leaderboard_entries (
  competition_id uuid not null,
  season integer not null,
  user_id uuid not null,
  total_points numeric default 0 not null,
  updated_at_utc timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table public.leaderboard_group_invites (
  id uuid default gen_random_uuid() not null,
  group_id uuid not null,
  competition_id uuid not null,
  season integer not null,
  invited_user_id uuid not null,
  invited_by_user_id uuid not null,
  status text default 'pending'::text not null,
  created_at timestamp with time zone default now() not null,
  handled_at timestamp with time zone,
  updated_at timestamp with time zone default now() not null
);
create table public.leaderboard_group_members (
  group_id uuid not null,
  user_id uuid not null,
  added_by_user_id uuid,
  joined_at timestamp with time zone default now() not null
);
create table public.leaderboard_groups (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  name text not null,
  created_by_user_id uuid not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table public.leaderboard_snapshot_cache (
  competition_id uuid not null,
  season integer not null,
  payload jsonb not null,
  computed_at timestamp with time zone default now() not null
);
create table public.leaderboard_snapshots (
  id bigint default nextval('leaderboard_snapshots_id_seq'::regclass) not null,
  competition_id uuid not null,
  season integer not null,
  round_number integer not null,
  user_id uuid not null,
  rank integer not null,
  total_points numeric not null,
  created_at timestamp with time zone default now() not null
);
create table public.match_odds (
  id uuid default uuid_generate_v4() not null,
  match_id uuid not null,
  competition_id uuid not null,
  bookmaker_key text default 'sportsbet'::text not null,
  market_key text default 'h2h'::text not null,
  home_team text not null,
  away_team text not null,
  home_odds numeric not null,
  away_odds numeric not null,
  snapshot_for_time_utc timestamp with time zone not null,
  captured_at_utc timestamp with time zone default now() not null
);
create table public.matches (
  id uuid default uuid_generate_v4() not null,
  round_id uuid not null,
  squiggle_game_id integer,
  commence_time_utc timestamp with time zone not null,
  home_team text not null,
  away_team text not null,
  odds_home numeric(6,2),
  odds_away numeric(6,2),
  odds_bookmaker text,
  odds_source text,
  odds_snapshot_time_utc timestamp with time zone,
  status text default 'scheduled'::text not null,
  winner_team text,
  updated_at timestamp with time zone default now() not null,
  venue text
);
create table public.memberships (
  competition_id uuid not null,
  user_id uuid not null,
  role text default 'member'::text not null,
  created_at timestamp with time zone default now() not null,
  payment_status text default 'pending'::text not null,
  is_test_account boolean default false not null
);
create table public.next_season_interest (
  id uuid default gen_random_uuid() not null,
  target_season integer not null,
  email text,
  email_normalized text,
  full_name text,
  source text default 'public_form'::text not null,
  status text default 'pending'::text not null,
  notes text,
  submitted_at_utc timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  pipeline_stage text default 'new'::text not null,
  reviewed_at_utc timestamp with time zone,
  contacted_at_utc timestamp with time zone,
  invited_at_utc timestamp with time zone,
  archived_at_utc timestamp with time zone,
  archived_reason text,
  linked_user_id uuid,
  linked_membership_competition_id uuid,
  last_contact_note text
);
create table public.odds_snapshot_notification_emails (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  round_id uuid not null,
  season integer not null,
  round_number integer not null,
  user_id uuid not null,
  email text not null,
  notification_type text default 'odds_snapshot_set_v1'::text not null,
  snapshot_for_time_utc timestamp with time zone not null,
  lock_time_utc timestamp with time zone not null,
  status text not null,
  provider text,
  provider_message_id text,
  error text,
  sent_at_utc timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);
create table public.payment_records (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  amount_cents integer not null,
  payment_method text default 'bank_transfer'::text not null,
  payer_name text,
  payer_email text,
  reference_text text,
  notes text,
  paid_at_utc timestamp with time zone not null,
  recorded_source text default 'manual'::text not null,
  reconciliation_status text default 'unmatched'::text not null,
  matched_user_id uuid,
  matched_onboarding_id uuid,
  matched_at_utc timestamp with time zone,
  recorded_by_user_id uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table public.payment_reminder_emails (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  user_id uuid not null,
  email text not null,
  reminder_type text default 'season_payment_pending_v1'::text not null,
  status text not null,
  provider text,
  provider_message_id text,
  error text,
  sent_at_utc timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);
create table public.prelock_reminder_emails (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  round_id uuid not null,
  season integer not null,
  round_number integer not null,
  user_id uuid not null,
  email text not null,
  reminder_type text not null,
  lock_time_utc timestamp with time zone not null,
  status text not null,
  provider text,
  provider_message_id text,
  error text,
  sent_at_utc timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null
);
create table public.profiles (
  id uuid not null,
  display_name text,
  created_at timestamp with time zone default now(),
  favorite_team text,
  username text
);
create table public.round_locked_tips_cache (
  competition_id uuid not null,
  round_id uuid not null,
  season integer not null,
  round_number integer not null,
  snapshot_for_time_utc timestamp with time zone,
  computed_at timestamp with time zone default now() not null,
  players jsonb default '[]'::jsonb not null
);
create table public.round_recap_emails (
  id bigint default nextval('round_recap_emails_id_seq'::regclass) not null,
  competition_id uuid not null,
  round_id uuid not null,
  season integer not null,
  round_number integer not null,
  recap_type text default 'end_of_round_v1'::text not null,
  recipient_email text not null,
  provider text,
  provider_message_id text,
  payload_json jsonb,
  sent_at timestamp with time zone default now() not null
);
create table public.round_recaps (
  id bigint default nextval('round_recaps_id_seq'::regclass) not null,
  competition_id uuid not null,
  round_id uuid not null,
  season integer not null,
  round_number integer not null,
  recap_type text default 'end_of_round_v1'::text not null,
  subject text not null,
  narrative_text text not null,
  raw_stats_text text not null,
  email_text text not null,
  email_html text not null,
  summary_json jsonb,
  generated_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table public.round_tip_status_cache (
  competition_id uuid not null,
  season integer not null,
  payload jsonb not null,
  computed_at timestamp with time zone default now() not null
);
create table public.rounds (
  id uuid default uuid_generate_v4() not null,
  competition_id uuid not null,
  season integer not null,
  round_number integer not null,
  first_match_time_utc timestamp with time zone,
  odds_snapshot_time_utc timestamp with time zone,
  lock_time_utc timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  odds_snapshot_for_time_utc timestamp with time zone,
  odds_captured_at_utc timestamp with time zone
);
create table public.scoring_automation_runs (
  id uuid default gen_random_uuid() not null,
  competition_id uuid not null,
  season integer not null,
  job_kind text not null,
  scope text not null,
  trigger_mode text not null,
  run_status text not null,
  sync_ok boolean default false not null,
  sync_updated integer default 0 not null,
  leaderboard_recalc_ran boolean default false not null,
  leaderboard_recalc_ok boolean,
  started_at_utc timestamp with time zone default now() not null,
  finished_at_utc timestamp with time zone default now() not null,
  details jsonb,
  created_at timestamp with time zone default now() not null
);
create table public.season_champions (
  id bigint default nextval('season_champions_id_seq'::regclass) not null,
  competition_id uuid not null,
  season integer not null,
  user_id uuid not null,
  source text default 'manual'::text not null,
  note text,
  awarded_at timestamp with time zone default now() not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
create table public.tip_scores (
  competition_id uuid not null,
  season integer not null,
  match_id uuid not null,
  user_id uuid not null,
  points numeric default 0 not null,
  picked_team text,
  winner_team text,
  calculated_at_utc timestamp with time zone default now() not null
);
create table public.tips (
  id uuid default uuid_generate_v4() not null,
  match_id uuid not null,
  competition_id uuid not null,
  user_id uuid not null,
  picked_team text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);
alter table public.admin_anomaly_dismissals add constraint admin_anomaly_dismissals_pkey PRIMARY KEY (id);
alter table public.admin_audit_log add constraint admin_audit_log_action_type_check CHECK ((action_type = ANY (ARRAY['sync_fixture'::text, 'sync_results'::text, 'recalc_leaderboard'::text, 'snapshot_odds_due'::text, 'late_tip_override'::text, 'member_updated'::text, 'member_removed'::text, 'payment_settings_updated'::text, 'champion_settings_updated'::text])));
alter table public.admin_audit_log add constraint admin_audit_log_actor_mode_check CHECK ((actor_mode = ANY (ARRAY['bearer'::text, 'cron'::text])));
alter table public.admin_audit_log add constraint admin_audit_log_pkey PRIMARY KEY (id);
alter table public.admin_audit_log add constraint admin_audit_log_result_status_check CHECK ((result_status = ANY (ARRAY['success'::text, 'skipped'::text, 'failed'::text])));
alter table public.announcements add constraint announcements_body_not_blank CHECK ((char_length(btrim(body)) > 0));
alter table public.announcements add constraint announcements_pkey PRIMARY KEY (id);
alter table public.announcements add constraint announcements_title_not_blank CHECK ((char_length(btrim(title)) > 0));
alter table public.automation_alert_events add constraint automation_alert_events_alert_channel_check CHECK ((alert_channel = 'email'::text));
alter table public.automation_alert_events add constraint automation_alert_events_pkey PRIMARY KEY (id);
alter table public.automation_job_runs add constraint automation_job_runs_job_kind_check CHECK ((job_kind = ANY (ARRAY['snapshot_odds_due'::text, 'prelock_reminders'::text])));
alter table public.automation_job_runs add constraint automation_job_runs_pkey PRIMARY KEY (id);
alter table public.automation_job_runs add constraint automation_job_runs_run_status_check CHECK ((run_status = ANY (ARRAY['success'::text, 'failed'::text, 'skipped'::text])));
alter table public.automation_job_runs add constraint automation_job_runs_trigger_mode_check CHECK ((trigger_mode = ANY (ARRAY['cron'::text, 'bearer'::text])));
alter table public.chat_message_mentions add constraint chat_message_mentions_message_id_mentioned_user_id_key UNIQUE (message_id, mentioned_user_id);
alter table public.chat_message_mentions add constraint chat_message_mentions_pkey PRIMARY KEY (id);
alter table public.chat_messages add constraint chat_messages_pkey PRIMARY KEY (id);
alter table public.chat_reactions add constraint chat_reactions_pkey PRIMARY KEY (message_id, user_id, emoji);
alter table public.competitions add constraint competitions_join_code_key UNIQUE (join_code);
alter table public.competitions add constraint competitions_pkey PRIMARY KEY (id);
alter table public.leaderboard_entries add constraint leaderboard_entries_comp_season_user_unique UNIQUE (competition_id, season, user_id);
alter table public.leaderboard_entries add constraint leaderboard_entries_comp_user_unique UNIQUE (competition_id, user_id);
alter table public.leaderboard_entries add constraint leaderboard_entries_pkey PRIMARY KEY (competition_id, season, user_id);
alter table public.leaderboard_entries add constraint leaderboard_entries_user_id_key UNIQUE (user_id);
alter table public.leaderboard_group_invites add constraint leaderboard_group_invites_pkey PRIMARY KEY (id);
alter table public.leaderboard_group_invites add constraint leaderboard_group_invites_season_reasonable CHECK (((season >= 2000) AND (season <= 2100)));
alter table public.leaderboard_group_invites add constraint leaderboard_group_invites_status_valid CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text, 'declined'::text])));
alter table public.leaderboard_group_invites add constraint leaderboard_group_invites_user_not_self CHECK ((invited_user_id <> invited_by_user_id));
alter table public.leaderboard_group_members add constraint leaderboard_group_members_pkey PRIMARY KEY (group_id, user_id);
alter table public.leaderboard_groups add constraint leaderboard_groups_name_not_blank CHECK ((char_length(btrim(name)) > 0));
alter table public.leaderboard_groups add constraint leaderboard_groups_pkey PRIMARY KEY (id);
alter table public.leaderboard_groups add constraint leaderboard_groups_season_reasonable CHECK (((season >= 2000) AND (season <= 2100)));
alter table public.leaderboard_snapshot_cache add constraint leaderboard_snapshot_cache_pkey PRIMARY KEY (competition_id, season);
alter table public.leaderboard_snapshots add constraint leaderboard_snapshots_pkey PRIMARY KEY (id);
alter table public.match_odds add constraint match_odds_match_id_bookmaker_key_market_key_snapshot_for_t_key UNIQUE (match_id, bookmaker_key, market_key, snapshot_for_time_utc);
alter table public.match_odds add constraint match_odds_pkey PRIMARY KEY (id);
alter table public.matches add constraint matches_pkey PRIMARY KEY (id);
alter table public.matches add constraint matches_squiggle_game_id_key UNIQUE (squiggle_game_id);
alter table public.memberships add constraint memberships_payment_status_check CHECK ((payment_status = ANY (ARRAY['paid'::text, 'pending'::text, 'waived'::text])));
alter table public.memberships add constraint memberships_pkey PRIMARY KEY (competition_id, user_id);
alter table public.next_season_interest add constraint next_season_interest_archived_reason_length_check CHECK (((archived_reason IS NULL) OR (char_length(archived_reason) <= 500)));
alter table public.next_season_interest add constraint next_season_interest_contact_identity_check CHECK ((((email IS NOT NULL) AND (email_normalized IS NOT NULL)) OR ((email IS NULL) AND (email_normalized IS NULL) AND (NULLIF(btrim(full_name), ''::text) IS NOT NULL))));
alter table public.next_season_interest add constraint next_season_interest_email_like_check CHECK ((POSITION(('@'::text) IN (email_normalized)) > 1));
alter table public.next_season_interest add constraint next_season_interest_email_normalized_check CHECK ((email_normalized = lower(btrim(email_normalized))));
alter table public.next_season_interest add constraint next_season_interest_last_contact_note_length_check CHECK (((last_contact_note IS NULL) OR (char_length(last_contact_note) <= 2000)));
alter table public.next_season_interest add constraint next_season_interest_pipeline_stage_check CHECK ((pipeline_stage = ANY (ARRAY['new'::text, 'reviewed'::text, 'contacted'::text, 'invited'::text, 'joined'::text, 'payment_pending'::text, 'active'::text, 'archived'::text])));
alter table public.next_season_interest add constraint next_season_interest_pkey PRIMARY KEY (id);
alter table public.next_season_interest add constraint next_season_interest_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'notified'::text, 'unsubscribed'::text])));
alter table public.next_season_interest add constraint next_season_interest_target_season_check CHECK (((target_season >= 2000) AND (target_season <= 2100)));
alter table public.odds_snapshot_notification_emails add constraint odds_snapshot_notification_em_competition_id_round_id_user__key UNIQUE (competition_id, round_id, user_id, notification_type, snapshot_for_time_utc);
alter table public.odds_snapshot_notification_emails add constraint odds_snapshot_notification_emails_pkey PRIMARY KEY (id);
alter table public.odds_snapshot_notification_emails add constraint odds_snapshot_notification_emails_status_check CHECK ((status = ANY (ARRAY['sent'::text, 'simulated'::text, 'failed'::text])));
alter table public.payment_records add constraint payment_records_amount_cents_check CHECK (((amount_cents > 0) AND (amount_cents <= 1000000)));
alter table public.payment_records add constraint payment_records_notes_length_check CHECK (((notes IS NULL) OR (char_length(notes) <= 2000)));
alter table public.payment_records add constraint payment_records_payer_email_like_check CHECK (((payer_email IS NULL) OR (POSITION(('@'::text) IN (payer_email)) > 1)));
alter table public.payment_records add constraint payment_records_payer_name_length_check CHECK (((payer_name IS NULL) OR (char_length(payer_name) <= 200)));
alter table public.payment_records add constraint payment_records_payment_method_check CHECK ((payment_method = ANY (ARRAY['bank_transfer'::text, 'payid'::text, 'cash'::text, 'other'::text])));
alter table public.payment_records add constraint payment_records_pkey PRIMARY KEY (id);
alter table public.payment_records add constraint payment_records_reconciliation_status_check CHECK ((reconciliation_status = ANY (ARRAY['unmatched'::text, 'matched'::text, 'ignored'::text])));
alter table public.payment_records add constraint payment_records_recorded_source_check CHECK ((recorded_source = ANY (ARRAY['manual'::text, 'import'::text])));
alter table public.payment_records add constraint payment_records_reference_text_length_check CHECK (((reference_text IS NULL) OR (char_length(reference_text) <= 500)));
alter table public.payment_records add constraint payment_records_season_check CHECK (((season >= 2000) AND (season <= 2100)));
alter table public.payment_reminder_emails add constraint payment_reminder_emails_competition_id_season_user_id_remin_key UNIQUE (competition_id, season, user_id, reminder_type);
alter table public.payment_reminder_emails add constraint payment_reminder_emails_pkey PRIMARY KEY (id);
alter table public.payment_reminder_emails add constraint payment_reminder_emails_status_check CHECK ((status = ANY (ARRAY['sent'::text, 'simulated'::text, 'failed'::text])));
alter table public.prelock_reminder_emails add constraint prelock_reminder_emails_competition_id_round_id_user_id_rem_key UNIQUE (competition_id, round_id, user_id, reminder_type);
alter table public.prelock_reminder_emails add constraint prelock_reminder_emails_pkey PRIMARY KEY (id);
alter table public.prelock_reminder_emails add constraint prelock_reminder_emails_status_check CHECK ((status = ANY (ARRAY['sent'::text, 'simulated'::text, 'failed'::text])));
alter table public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table public.profiles add constraint profiles_username_format_check CHECK (((username IS NULL) OR ((username = lower(username)) AND ((char_length(username) >= 3) AND (char_length(username) <= 24)) AND (username ~ '^[a-z0-9_]+$'::text))));
alter table public.round_locked_tips_cache add constraint round_locked_tips_cache_pkey PRIMARY KEY (competition_id, round_id);
alter table public.round_recap_emails add constraint round_recap_emails_pkey PRIMARY KEY (id);
alter table public.round_recaps add constraint round_recaps_pkey PRIMARY KEY (id);
alter table public.round_tip_status_cache add constraint round_tip_status_cache_pkey PRIMARY KEY (competition_id, season);
alter table public.rounds add constraint rounds_competition_id_season_round_number_key UNIQUE (competition_id, season, round_number);
alter table public.rounds add constraint rounds_pkey PRIMARY KEY (id);
alter table public.scoring_automation_runs add constraint scoring_automation_runs_job_kind_check CHECK ((job_kind = ANY (ARRAY['scoring_15m'::text, 'scoring_daily_full'::text, 'manual'::text])));
alter table public.scoring_automation_runs add constraint scoring_automation_runs_pkey PRIMARY KEY (id);
alter table public.scoring_automation_runs add constraint scoring_automation_runs_run_status_check CHECK ((run_status = ANY (ARRAY['success'::text, 'failed'::text])));
alter table public.scoring_automation_runs add constraint scoring_automation_runs_scope_check CHECK ((scope = ANY (ARRAY['active'::text, 'full'::text])));
alter table public.scoring_automation_runs add constraint scoring_automation_runs_trigger_mode_check CHECK ((trigger_mode = ANY (ARRAY['cron'::text, 'bearer'::text])));
alter table public.season_champions add constraint season_champions_pkey PRIMARY KEY (id);
alter table public.tip_scores add constraint tip_scores_pkey PRIMARY KEY (competition_id, season, match_id, user_id);
alter table public.tips add constraint tips_match_id_user_id_key UNIQUE (match_id, user_id);
alter table public.tips add constraint tips_pkey PRIMARY KEY (id);
alter table public.admin_anomaly_dismissals add constraint admin_anomaly_dismissals_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.admin_audit_log add constraint admin_audit_log_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.announcements add constraint announcements_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE SET NULL;
alter table public.automation_alert_events add constraint automation_alert_events_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.automation_job_runs add constraint automation_job_runs_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.chat_message_mentions add constraint chat_message_mentions_mentioned_user_id_fkey FOREIGN KEY (mentioned_user_id) REFERENCES profiles(id) ON DELETE CASCADE;
alter table public.chat_message_mentions add constraint chat_message_mentions_message_id_fkey FOREIGN KEY (message_id) REFERENCES chat_messages(id) ON DELETE CASCADE;
alter table public.chat_messages add constraint chat_messages_reply_to_message_id_fkey FOREIGN KEY (reply_to_message_id) REFERENCES chat_messages(id) ON DELETE SET NULL;
alter table public.chat_messages add constraint chat_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.chat_reactions add constraint chat_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES chat_messages(id) ON DELETE CASCADE;
alter table public.chat_reactions add constraint chat_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.competitions add constraint competitions_reigning_champion_override_user_id_fkey FOREIGN KEY (reigning_champion_override_user_id) REFERENCES profiles(id) ON DELETE SET NULL;
alter table public.leaderboard_entries add constraint leaderboard_entries_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.leaderboard_group_invites add constraint leaderboard_group_invites_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.leaderboard_group_invites add constraint leaderboard_group_invites_group_id_fkey FOREIGN KEY (group_id) REFERENCES leaderboard_groups(id) ON DELETE CASCADE;
alter table public.leaderboard_group_members add constraint leaderboard_group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES leaderboard_groups(id) ON DELETE CASCADE;
alter table public.leaderboard_groups add constraint leaderboard_groups_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.leaderboard_snapshots add constraint leaderboard_snapshots_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.match_odds add constraint match_odds_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.match_odds add constraint match_odds_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;
alter table public.matches add constraint matches_round_id_fkey FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
alter table public.memberships add constraint memberships_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.odds_snapshot_notification_emails add constraint odds_snapshot_notification_emails_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.odds_snapshot_notification_emails add constraint odds_snapshot_notification_emails_round_id_fkey FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
alter table public.payment_records add constraint payment_records_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.payment_records add constraint payment_records_matched_onboarding_id_fkey FOREIGN KEY (matched_onboarding_id) REFERENCES next_season_interest(id) ON DELETE SET NULL;
alter table public.payment_reminder_emails add constraint payment_reminder_emails_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.prelock_reminder_emails add constraint prelock_reminder_emails_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.prelock_reminder_emails add constraint prelock_reminder_emails_round_id_fkey FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
alter table public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table public.round_locked_tips_cache add constraint round_locked_tips_cache_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.round_locked_tips_cache add constraint round_locked_tips_cache_round_id_fkey FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
alter table public.round_recap_emails add constraint round_recap_emails_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.round_recap_emails add constraint round_recap_emails_round_id_fkey FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
alter table public.round_recaps add constraint round_recaps_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.round_recaps add constraint round_recaps_round_id_fkey FOREIGN KEY (round_id) REFERENCES rounds(id) ON DELETE CASCADE;
alter table public.rounds add constraint rounds_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.scoring_automation_runs add constraint scoring_automation_runs_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.season_champions add constraint season_champions_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.tip_scores add constraint tip_scores_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.tip_scores add constraint tip_scores_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;
alter table public.tips add constraint tips_competition_id_fkey FOREIGN KEY (competition_id) REFERENCES competitions(id) ON DELETE CASCADE;
alter table public.tips add constraint tips_match_id_fkey FOREIGN KEY (match_id) REFERENCES matches(id) ON DELETE CASCADE;
CREATE INDEX chat_messages_created_at_idx ON public.chat_messages USING btree (created_at DESC);
CREATE INDEX chat_messages_user_id_idx ON public.chat_messages USING btree (user_id);
CREATE INDEX chat_reactions_message_id_idx ON public.chat_reactions USING btree (message_id);
CREATE INDEX idx_admin_anomaly_dismissals_active ON public.admin_anomaly_dismissals USING btree (competition_id, season, expires_at_utc DESC);
CREATE INDEX idx_admin_audit_log_action_created ON public.admin_audit_log USING btree (action_type, created_at DESC);
CREATE INDEX idx_admin_audit_log_comp_created ON public.admin_audit_log USING btree (competition_id, created_at DESC);
CREATE INDEX idx_announcements_competition_published ON public.announcements USING btree (competition_id, is_published, is_pinned DESC, published_at_utc DESC);
CREATE INDEX idx_automation_alert_events_lookup ON public.automation_alert_events USING btree (competition_id, season, alert_key, sent_at_utc DESC);
CREATE INDEX idx_automation_alert_events_sent ON public.automation_alert_events USING btree (sent_at_utc DESC);
CREATE INDEX idx_automation_job_runs_comp_season_started ON public.automation_job_runs USING btree (competition_id, season, started_at_utc DESC);
CREATE INDEX idx_automation_job_runs_kind_status_started ON public.automation_job_runs USING btree (job_kind, run_status, started_at_utc DESC);
CREATE INDEX idx_chat_message_mentions_message ON public.chat_message_mentions USING btree (message_id);
CREATE INDEX idx_chat_message_mentions_target_created ON public.chat_message_mentions USING btree (mentioned_user_id, created_at DESC);
CREATE INDEX idx_chat_messages_created_at ON public.chat_messages USING btree (created_at DESC);
CREATE INDEX idx_chat_messages_reply_to ON public.chat_messages USING btree (reply_to_message_id);
CREATE INDEX idx_chat_reactions_message ON public.chat_reactions USING btree (message_id);
CREATE INDEX idx_chat_reactions_message_emoji ON public.chat_reactions USING btree (message_id, emoji);
CREATE INDEX idx_chat_reactions_message_user_emoji ON public.chat_reactions USING btree (message_id, user_id, emoji);
CREATE INDEX idx_leaderboard_entries_comp_season_points ON public.leaderboard_entries USING btree (competition_id, season, total_points DESC);
CREATE INDEX idx_leaderboard_group_invites_group ON public.leaderboard_group_invites USING btree (group_id, created_at DESC);
CREATE INDEX idx_leaderboard_group_invites_pending_by_user ON public.leaderboard_group_invites USING btree (invited_user_id, status, created_at DESC);
CREATE INDEX idx_leaderboard_group_members_user ON public.leaderboard_group_members USING btree (user_id, joined_at DESC);
CREATE INDEX idx_leaderboard_groups_competition_season ON public.leaderboard_groups USING btree (competition_id, season, created_at DESC);
CREATE INDEX idx_leaderboard_snapshot_cache_computed ON public.leaderboard_snapshot_cache USING btree (computed_at DESC);
CREATE INDEX idx_match_odds_comp_match_captured ON public.match_odds USING btree (competition_id, match_id, captured_at_utc DESC);
CREATE INDEX idx_match_odds_comp_match_snapshot_captured ON public.match_odds USING btree (competition_id, match_id, snapshot_for_time_utc, captured_at_utc DESC);
CREATE INDEX idx_matches_round_id_commence ON public.matches USING btree (round_id, commence_time_utc);
CREATE INDEX idx_matches_squiggle_game_id ON public.matches USING btree (squiggle_game_id);
CREATE INDEX idx_memberships_comp_created ON public.memberships USING btree (competition_id, created_at);
CREATE INDEX idx_memberships_comp_payment_status ON public.memberships USING btree (competition_id, payment_status);
CREATE INDEX idx_memberships_comp_user ON public.memberships USING btree (competition_id, user_id);
CREATE INDEX idx_memberships_competition_test ON public.memberships USING btree (competition_id, is_test_account);
CREATE INDEX idx_next_season_interest_linked_user_id ON public.next_season_interest USING btree (linked_user_id);
CREATE INDEX idx_next_season_interest_manual_name ON public.next_season_interest USING btree (target_season, lower(btrim(full_name))) WHERE (email_normalized IS NULL);
CREATE INDEX idx_next_season_interest_target_pipeline_stage ON public.next_season_interest USING btree (target_season, pipeline_stage);
CREATE INDEX idx_next_season_interest_target_status ON public.next_season_interest USING btree (target_season, status);
CREATE INDEX idx_odds_snapshot_notification_emails_comp_round ON public.odds_snapshot_notification_emails USING btree (competition_id, round_id);
CREATE INDEX idx_odds_snapshot_notification_emails_comp_user ON public.odds_snapshot_notification_emails USING btree (competition_id, user_id);
CREATE INDEX idx_odds_snapshot_notification_emails_status ON public.odds_snapshot_notification_emails USING btree (status);
CREATE INDEX idx_payment_records_comp_matched_user ON public.payment_records USING btree (competition_id, matched_user_id);
CREATE INDEX idx_payment_records_comp_season_paid ON public.payment_records USING btree (competition_id, season, paid_at_utc DESC);
CREATE INDEX idx_payment_records_comp_season_status ON public.payment_records USING btree (competition_id, season, reconciliation_status, paid_at_utc DESC);
CREATE INDEX idx_payment_records_onboarding ON public.payment_records USING btree (matched_onboarding_id);
CREATE INDEX idx_payment_reminder_emails_comp_season ON public.payment_reminder_emails USING btree (competition_id, season);
CREATE INDEX idx_payment_reminder_emails_comp_user ON public.payment_reminder_emails USING btree (competition_id, user_id);
CREATE INDEX idx_payment_reminder_emails_status ON public.payment_reminder_emails USING btree (status);
CREATE INDEX idx_prelock_reminder_emails_comp_round ON public.prelock_reminder_emails USING btree (competition_id, round_id);
CREATE INDEX idx_prelock_reminder_emails_comp_user ON public.prelock_reminder_emails USING btree (competition_id, user_id);
CREATE INDEX idx_prelock_reminder_emails_status ON public.prelock_reminder_emails USING btree (status);
CREATE INDEX idx_round_locked_tips_cache_comp_round ON public.round_locked_tips_cache USING btree (competition_id, round_id);
CREATE INDEX idx_round_recap_emails_comp_season_round ON public.round_recap_emails USING btree (competition_id, season, round_number);
CREATE INDEX idx_round_recaps_comp_season_round ON public.round_recaps USING btree (competition_id, season, round_number DESC);
CREATE INDEX idx_round_tip_status_cache_computed ON public.round_tip_status_cache USING btree (computed_at DESC);
CREATE INDEX idx_rounds_comp_season_roundnum ON public.rounds USING btree (competition_id, season, round_number);
CREATE INDEX idx_scoring_automation_runs_comp_season_started ON public.scoring_automation_runs USING btree (competition_id, season, started_at_utc DESC);
CREATE INDEX idx_scoring_automation_runs_job_status ON public.scoring_automation_runs USING btree (job_kind, run_status, started_at_utc DESC);
CREATE INDEX idx_season_champions_comp_user ON public.season_champions USING btree (competition_id, user_id);
CREATE INDEX idx_tips_comp_match ON public.tips USING btree (competition_id, match_id);
CREATE INDEX idx_tips_comp_user_match ON public.tips USING btree (competition_id, user_id, match_id);
CREATE INDEX leaderboard_snapshots_lookup ON public.leaderboard_snapshots USING btree (competition_id, season, round_number, rank);
CREATE UNIQUE INDEX leaderboard_snapshots_unique ON public.leaderboard_snapshots USING btree (competition_id, season, round_number, user_id);
CREATE INDEX match_odds_comp_round_idx ON public.match_odds USING btree (competition_id, snapshot_for_time_utc);
CREATE INDEX matches_round_id_idx ON public.matches USING btree (round_id);
CREATE INDEX matches_squiggle_game_id_idx ON public.matches USING btree (squiggle_game_id);
CREATE UNIQUE INDEX matches_squiggle_game_id_ux ON public.matches USING btree (squiggle_game_id);
CREATE INDEX round_locked_tips_cache_season_round_idx ON public.round_locked_tips_cache USING btree (competition_id, season, round_number);
CREATE INDEX rounds_odds_due_idx ON public.rounds USING btree (season, odds_captured_at_utc, lock_time_utc);
CREATE INDEX tips_comp_user_idx ON public.tips USING btree (competition_id, user_id);
CREATE UNIQUE INDEX uq_admin_anomaly_dismissals_comp_season_key ON public.admin_anomaly_dismissals USING btree (competition_id, season, dismiss_key);
CREATE UNIQUE INDEX uq_leaderboard_group_invites_pending ON public.leaderboard_group_invites USING btree (group_id, invited_user_id) WHERE (status = 'pending'::text);
CREATE UNIQUE INDEX ux_next_season_interest_target_email ON public.next_season_interest USING btree (target_season, email_normalized);
CREATE UNIQUE INDEX ux_profiles_username_lower ON public.profiles USING btree (lower(username)) WHERE (username IS NOT NULL);
CREATE UNIQUE INDEX ux_round_recap_emails_unique ON public.round_recap_emails USING btree (competition_id, round_id, recap_type, recipient_email);
CREATE UNIQUE INDEX ux_round_recaps_unique ON public.round_recaps USING btree (competition_id, round_id, recap_type);
CREATE UNIQUE INDEX ux_season_champions_comp_season ON public.season_champions USING btree (competition_id, season);
CREATE OR REPLACE FUNCTION public.cleanup_chat_messages()
 RETURNS void
 LANGUAGE sql
AS $function$
  delete from public.chat_messages
  where created_at < now() - interval '30 days';
$function$
;
CREATE OR REPLACE FUNCTION public.enforce_chat_slowmode()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  last_ts timestamptz;
begin
  select max(created_at) into last_ts
  from public.chat_messages
  where user_id = new.user_id;

  if last_ts is not null and (new.created_at - last_ts) < interval '3 seconds' then
    raise exception 'Slow mode: wait a moment before sending again.';
  end if;

  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.handle_new_user_signup()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  -- Create profile row (id = auth user id)
  insert into public.profiles (id, created_at)
  values (new.id, now())
  on conflict (id) do nothing;

  -- Auto-join default competition as "member"
  insert into public.memberships (competition_id, user_id, role, created_at)
  values ('71289cb2-ef35-403f-a484-74e9e41d4cf0'::uuid, new.id, 'member', now())
  on conflict (competition_id, user_id) do nothing;

  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.round_locked_tips(comp_id uuid, season_in integer, round_in integer)
 RETURNS TABLE(user_id uuid, display_name text, potential numeric, picks jsonb)
 LANGUAGE sql
 STABLE
AS $function$
with r as (
  select id, odds_snapshot_for_time_utc
  from public.rounds
  where competition_id = comp_id
    and season = season_in
    and round_number = round_in
  limit 1
),
ms as (
  select m.id as match_id, m.home_team, m.away_team
  from public.matches m
  join r on m.round_id = r.id
),
latest_odds as (
  select distinct on (o.match_id)
    o.match_id,
    o.home_odds,
    o.away_odds
  from public.match_odds o
  join r on true
  where o.competition_id = comp_id
    and o.match_id in (select match_id from ms)
    and (
      r.odds_snapshot_for_time_utc is null
      or o.snapshot_for_time_utc = r.odds_snapshot_for_time_utc
    )
  order by o.match_id, o.captured_at_utc desc
),
t as (
  select
    t.user_id,
    t.match_id,
    t.picked_team,
    case
      when t.picked_team = ms.home_team then coalesce(lo.home_odds, 0)
      when t.picked_team = ms.away_team then coalesce(lo.away_odds, 0)
      else 0
    end as picked_odds
  from public.tips t
  join ms on ms.match_id = t.match_id
  left join latest_odds lo on lo.match_id = t.match_id
  where t.competition_id = comp_id
)
select
  t.user_id,
  p.display_name,
  sum(t.picked_odds) as potential,
  jsonb_object_agg(
    t.match_id::text,
    jsonb_build_object('team', t.picked_team, 'odds', t.picked_odds)
  ) as picks
from t
left join public.profiles p on p.id = t.user_id
group by t.user_id, p.display_name;
$function$
;
CREATE OR REPLACE FUNCTION public.set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$
;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user_signup();
CREATE TRIGGER set_matches_updated_at BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_chat_slowmode BEFORE INSERT ON public.chat_messages FOR EACH ROW EXECUTE FUNCTION enforce_chat_slowmode();
CREATE TRIGGER trg_leaderboard_entries_updated_at BEFORE UPDATE ON public.leaderboard_entries FOR EACH ROW EXECUTE FUNCTION set_updated_at();
alter table public.chat_message_mentions enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_reactions enable row level security;
alter table public.competitions enable row level security;
alter table public.leaderboard_entries enable row level security;
alter table public.leaderboard_snapshots enable row level security;
alter table public.match_odds enable row level security;
alter table public.matches enable row level security;
alter table public.memberships enable row level security;
alter table public.profiles enable row level security;
alter table public.rounds enable row level security;
alter table public.tip_scores enable row level security;
alter table public.tips enable row level security;
create policy chat_message_mentions_delete on public.chat_message_mentions as PERMISSIVE for DELETE to authenticated using ((EXISTS ( SELECT 1
   FROM chat_messages m
  WHERE ((m.id = chat_message_mentions.message_id) AND (m.user_id = auth.uid())))));
create policy chat_message_mentions_insert on public.chat_message_mentions as PERMISSIVE for INSERT to authenticated with check ((EXISTS ( SELECT 1
   FROM chat_messages m
  WHERE ((m.id = chat_message_mentions.message_id) AND (m.user_id = auth.uid())))));
create policy chat_message_mentions_select on public.chat_message_mentions as PERMISSIVE for SELECT to authenticated using (((mentioned_user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM chat_messages m
  WHERE ((m.id = chat_message_mentions.message_id) AND (m.user_id = auth.uid()))))));
create policy chat_messages_delete_admin on public.chat_messages as PERMISSIVE for DELETE to authenticated using ((lower(COALESCE((auth.jwt() ->> 'email'::text), ''::text)) = lower('beau.j.williams@gmail.com'::text)));
create policy chat_messages_delete_own on public.chat_messages as PERMISSIVE for DELETE to authenticated using ((user_id = auth.uid()));
create policy chat_messages_insert on public.chat_messages as PERMISSIVE for INSERT to authenticated with check ((auth.uid() = user_id));
create policy chat_messages_insert_own on public.chat_messages as PERMISSIVE for INSERT to authenticated with check ((user_id = auth.uid()));
create policy chat_messages_read on public.chat_messages as PERMISSIVE for SELECT to authenticated using (true);
create policy chat_messages_select on public.chat_messages as PERMISSIVE for SELECT to authenticated using (true);
create policy chat_messages_update_own on public.chat_messages as PERMISSIVE for UPDATE to authenticated using ((user_id = auth.uid())) with check ((user_id = auth.uid()));
create policy chat_reactions_delete_own on public.chat_reactions as PERMISSIVE for DELETE to authenticated using ((user_id = auth.uid()));
create policy chat_reactions_insert on public.chat_reactions as PERMISSIVE for INSERT to authenticated with check ((auth.uid() = user_id));
create policy chat_reactions_insert_own on public.chat_reactions as PERMISSIVE for INSERT to authenticated with check ((user_id = auth.uid()));
create policy chat_reactions_read on public.chat_reactions as PERMISSIVE for SELECT to authenticated using (true);
create policy chat_reactions_select on public.chat_reactions as PERMISSIVE for SELECT to authenticated using (true);
create policy competitions_all_authenticated on public.competitions as PERMISSIVE for ALL to public using ((auth.uid() IS NOT NULL)) with check ((auth.uid() IS NOT NULL));
create policy leaderboard_select_authenticated on public.leaderboard_entries as PERMISSIVE for SELECT to public using ((auth.uid() IS NOT NULL));
create policy snapshots_select_members on public.leaderboard_snapshots as PERMISSIVE for SELECT to authenticated using ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.competition_id = leaderboard_snapshots.competition_id) AND (m.user_id = auth.uid())))));
create policy match_odds_select_authenticated on public.match_odds as PERMISSIVE for SELECT to public using ((auth.uid() IS NOT NULL));
create policy matches_select_member on public.matches as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM (rounds r
     JOIN memberships m ON ((m.competition_id = r.competition_id)))
  WHERE ((r.id = matches.round_id) AND (m.user_id = auth.uid())))));
create policy memberships_all_own on public.memberships as PERMISSIVE for ALL to public using ((user_id = auth.uid())) with check ((user_id = auth.uid()));
create policy "users can insert own profile" on public.profiles as PERMISSIVE for INSERT to authenticated with check ((auth.uid() = id));
create policy "users can read profiles" on public.profiles as PERMISSIVE for SELECT to authenticated using (true);
create policy "users can update own profile" on public.profiles as PERMISSIVE for UPDATE to authenticated using ((auth.uid() = id));
create policy rounds_select_member on public.rounds as PERMISSIVE for SELECT to public using ((EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.competition_id = rounds.competition_id) AND (m.user_id = auth.uid())))));
create policy tip_scores_select_authenticated on public.tip_scores as PERMISSIVE for SELECT to public using ((auth.uid() IS NOT NULL));
create policy tips_insert_own_before_lock on public.tips as PERMISSIVE for INSERT to authenticated with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.competition_id = tips.competition_id) AND (m.user_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM (matches ma
     JOIN rounds r ON ((r.id = ma.round_id)))
  WHERE ((ma.id = tips.match_id) AND (now() < r.lock_time_utc))))));
create policy tips_select_own on public.tips as PERMISSIVE for SELECT to authenticated using (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.competition_id = tips.competition_id) AND (m.user_id = auth.uid()))))));
create policy tips_update_own_before_lock on public.tips as PERMISSIVE for UPDATE to authenticated using (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.competition_id = tips.competition_id) AND (m.user_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM (matches ma
     JOIN rounds r ON ((r.id = ma.round_id)))
  WHERE ((ma.id = tips.match_id) AND (now() < r.lock_time_utc)))))) with check (((user_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM memberships m
  WHERE ((m.competition_id = tips.competition_id) AND (m.user_id = auth.uid())))) AND (EXISTS ( SELECT 1
   FROM (matches ma
     JOIN rounds r ON ((r.id = ma.round_id)))
  WHERE ((ma.id = tips.match_id) AND (now() < r.lock_time_utc))))));
alter sequence public.chat_message_mentions_id_seq owned by public.chat_message_mentions.id;
alter sequence public.leaderboard_snapshots_id_seq owned by public.leaderboard_snapshots.id;
alter sequence public.round_recap_emails_id_seq owned by public.round_recap_emails.id;
alter sequence public.round_recaps_id_seq owned by public.round_recaps.id;
alter sequence public.season_champions_id_seq owned by public.season_champions.id;
