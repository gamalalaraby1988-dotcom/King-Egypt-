-- Allow authenticated test players to exchange ephemeral city Presence only.
-- No player profile, account id, display name, or player code is stored in Presence.
drop policy if exists test_city_presence_read on realtime.messages;
create policy test_city_presence_read on realtime.messages
for select to authenticated
using (
  realtime.topic() = 'game:city:presence'
  and realtime.messages.extension = 'presence'
  and auth.uid() is not null
  and game_private.my_test_account_id() is not null
);

drop policy if exists test_city_presence_track on realtime.messages;
create policy test_city_presence_track on realtime.messages
for insert to authenticated
with check (
  realtime.topic() = 'game:city:presence'
  and realtime.messages.extension = 'presence'
  and auth.uid() is not null
  and game_private.my_test_account_id() is not null
);
