alter policy test_city_presence_read on realtime.messages
using (
  realtime.topic() = 'game:city:presence'
  and realtime.messages.extension = 'presence'
  and (select auth.uid()) is not null
  and (select game_private.my_test_account_id()) is not null
);

alter policy test_city_presence_track on realtime.messages
with check (
  realtime.topic() = 'game:city:presence'
  and realtime.messages.extension = 'presence'
  and (select auth.uid()) is not null
  and (select game_private.my_test_account_id()) is not null
);
