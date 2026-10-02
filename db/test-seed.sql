-- Fake data for the TEST database (complicated-tips-test). Never run on production.
--
-- Creates the default competition, 10 test logins, 8 rounds of fixtures relative
-- to "now" (5 finished, 1 open for tipping with odds already locked, 2 upcoming),
-- odds snapshots, tips, leaderboard totals, a little chat and an announcement.
--
-- Every test login uses the password:  TestTips2026!
--   test-admin@complicatedtips.test   (owner / admin, paid)
--   test01..test09@complicatedtips.test (members, mix of paid / pending)
--
-- Safe to re-run: it wipes the test competition's data first.

do $$
declare
  comp constant uuid := '71289cb2-ef35-403f-a484-74e9e41d4cf0'; -- same id the signup trigger uses
  season_val constant int := 2026;
  teams text[] := array['Adelaide','Brisbane Lions','Carlton','Collingwood','Essendon','Fremantle',
    'Geelong','Gold Coast','Greater Western Sydney','Hawthorn','Melbourne','North Melbourne',
    'Port Adelaide','Richmond','St Kilda','Sydney','West Coast','Western Bulldogs'];
  venues text[] := array['M.C.G.','Marvel Stadium','Adelaide Oval','Optus Stadium','Gabba','S.C.G.','GMHBA Stadium','People First Stadium','ENGIE Stadium'];
  names text[] := array['Test Admin','Alex Ablett','Bec Buckley','Chris Carey','Dani Dangerfield','Eddie Eade','Fran Fyfe','Gus Goodes','Hana Hird','Izzy Inglis'];
  users uuid[] := '{}';
  uid uuid;
  owner_id uuid;
  r int; g int; i int;
  round_id uuid; match_id uuid;
  lock_ts timestamptz; snap_ts timestamptz;
  shuffled text[];
  h text; a text; ho numeric; ao numeric; winner text;
  pick text;
begin
  perform setseed(0.42);

  -- Clean slate (cascades remove rounds, matches, odds, tips, memberships, etc.)
  delete from public.competitions where id = comp;
  delete from auth.users where email like '%@complicatedtips.test';

  -- Competition must exist before users, because the signup trigger auto-joins it.
  owner_id := gen_random_uuid();
  insert into public.competitions (id, name, join_code, owner_user_id)
  values (comp, 'Complicated Tips – TEST', 'TEST2026', owner_id);

  -- Test logins
  for i in 1..10 loop
    uid := case when i = 1 then owner_id else gen_random_uuid() end;
    users := users || uid;
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated',
      case when i = 1 then 'test-admin@complicatedtips.test' else format('test%s@complicatedtips.test', lpad((i-1)::text, 2, '0')) end,
      extensions.crypt('TestTips2026!', extensions.gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    select gen_random_uuid(), u.id, u.id::text, jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
      'email', now(), now(), now()
    from auth.users u where u.id = uid;

    -- Trigger created the profile + membership; fill in the details.
    update public.profiles set display_name = names[i],
      username = lower(replace(names[i], ' ', '_')),
      favorite_team = teams[1 + ((i * 5) % 18)]
    where id = uid;
    update public.memberships set
      role = case when i = 1 then 'owner' else 'member' end,
      payment_status = case when i = 1 or i % 3 <> 0 then 'paid' else 'pending' end
    where competition_id = comp and user_id = uid;
  end loop;

  -- Rounds: 1-5 finished, 6 open (odds locked, tips close in ~30h), 7-8 upcoming.
  for r in 1..8 loop
    lock_ts := date_trunc('hour', now()) + make_interval(hours => 30) + make_interval(days => 7 * (r - 6));
    snap_ts := lock_ts - interval '36 hours';
    round_id := gen_random_uuid();
    insert into public.rounds (id, competition_id, season, round_number, first_match_time_utc, lock_time_utc,
      odds_snapshot_for_time_utc, odds_captured_at_utc)
    values (round_id, comp, season_val, r, lock_ts, lock_ts,
      case when r <= 6 then snap_ts end,
      case when r <= 6 then snap_ts + interval '20 minutes' end);

    select array_agg(t order by random()) into shuffled from unnest(teams) t;

    for g in 1..9 loop
      h := shuffled[2 * g - 1];
      a := shuffled[2 * g];
      ho := round((1.25 + random() * 2.4)::numeric, 2);
      ao := round((1 / greatest(0.08, 1.06 - 1 / ho))::numeric, 2);
      winner := case when r <= 5 then (case when random() < (1 / ho) / (1 / ho + 1 / ao) then h else a end) end;
      match_id := gen_random_uuid();

      insert into public.matches (id, round_id, commence_time_utc, home_team, away_team, status, winner_team, venue)
      values (match_id, round_id, lock_ts + make_interval(hours => (g - 1) * 3 + (g / 4) * 14),
        h, a, case when r <= 5 then 'final' else 'scheduled' end, winner, venues[1 + (g % 9)]);

      if r <= 6 then
        insert into public.match_odds (match_id, competition_id, home_team, away_team, home_odds, away_odds,
          snapshot_for_time_utc, captured_at_utc)
        values (match_id, comp, h, a, ho, ao, snap_ts, snap_ts + interval '20 minutes');
      end if;

      -- Tips: everyone tipped finished rounds (a few skipped games); about half have tipped the open round.
      if r <= 6 then
        for i in 1..10 loop
          continue when r <= 5 and random() < 0.06;
          continue when r = 6 and i % 2 = 0;
          pick := case when random() < (1 / ho) / (1 / ho + 1 / ao) + 0.05 * ((i % 3) - 1) then h else a end;
          insert into public.tips (match_id, competition_id, user_id, picked_team,
            created_at, updated_at)
          values (match_id, comp, users[i], pick, snap_ts + interval '2 hours', snap_ts + interval '2 hours');
        end loop;
      end if;
    end loop;
  end loop;

  -- Leaderboard totals: correct tip earns the winner's locked odds, otherwise 0.
  insert into public.leaderboard_entries (competition_id, season, user_id, total_points)
  select comp, season_val, u.uid,
    coalesce((select sum(case when t.picked_team = m.winner_team
                              then case when m.winner_team = o.home_team then o.home_odds else o.away_odds end
                              else 0 end)
              from public.tips t
              join public.matches m on m.id = t.match_id and m.status = 'final'
              join public.match_odds o on o.match_id = m.id
              where t.user_id = u.uid and t.competition_id = comp), 0)
  from unnest(users) as u(uid);

  insert into public.announcements (competition_id, title, body, is_pinned, created_by_user_id)
  values (comp, 'Welcome to the TEST site', 'This is fake data for trying out changes. Nothing here is real.', true, owner_id);

  insert into public.chat_messages (user_id, body, created_at) values
    (users[2], 'Who is everyone tipping for the big one this week?', now() - interval '3 hours'),
    (users[3], 'Taking the outsiders, odds are too good to pass up', now() - interval '2 hours'),
    (users[1], 'Reminder: tips lock at the first bounce of the round.', now() - interval '1 hour');
end $$;
