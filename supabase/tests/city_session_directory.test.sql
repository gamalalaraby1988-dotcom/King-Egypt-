begin; select extensions.plan(29);
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at) values
('00000000-0000-4000-8000-000000000071','authenticated','authenticated','city-test71@example.invalid','',now()),
('00000000-0000-4000-8000-000000000072','authenticated','authenticated','city-test72@example.invalid','',now()),
('00000000-0000-4000-8000-000000000073','authenticated','authenticated','city-test73@example.invalid','',now()),
('00000000-0000-4000-8000-000000000074','authenticated','authenticated','city-test74@example.invalid','',now()) on conflict(id) do nothing;
select extensions.ok(not has_table_privilege('authenticated','private.city_session_servers','SELECT'),'authenticated cannot read server registry');
select extensions.ok(not has_table_privilege('anon','private.city_session_reservations','SELECT'),'anon cannot read reservations');
select extensions.ok(not has_function_privilege('authenticated','public.city_register_server(text,text,text,integer,integer,uuid,integer)','EXECUTE'),'authenticated cannot register servers');
select extensions.ok(not has_function_privilege('authenticated','public.city_reserve_session(uuid,text)','EXECUTE'),'client cannot bypass matchmaking gateway');
select extensions.ok(has_function_privilege('service_role','public.city_reserve_session(uuid,text)','EXECUTE'),'service role can reserve');
select extensions.ok(not (select prosecdef from pg_proc where oid='public.city_reserve_session(uuid,text)'::regprocedure),'reservation RPC is security invoker');
set local role service_role;
select extensions.is(city_register_server('city-a','eu-central-1','wss://a.invalid:2456',4,0,'70000000-0000-4000-8000-000000000001')->>'status','registered','server A registers');
select extensions.is(city_register_server('city-b','eu-central-1','wss://b.invalid:2456',4,0,'70000000-0000-4000-8000-000000000002')->>'status','registered','server B registers');
select extensions.throws_ok($$select city_register_server('city-a','eu-central-1','wss://a.invalid',4,0,'70000000-0000-4000-8000-000000000001')$$,'23505','city_server_nonce_replayed','registration nonce replay rejected');
select extensions.throws_ok($$select city_register_server('city-bad','eu-central-1','http://bad.invalid',4,0,'70000000-0000-4000-8000-000000000003')$$,'22023','city_server_registration_invalid','non-WSS endpoint rejected');
select extensions.throws_ok($$select city_register_server('city-bad','eu-central-1','wss://bad.invalid',65,0,'70000000-0000-4000-8000-000000000004')$$,'22023','city_server_registration_invalid','capacity above 64 rejected');
create temp table r1 on commit drop as select city_reserve_session('00000000-0000-4000-8000-000000000071','eu-central-1') v;
select extensions.is((select v->>'server_id' from r1),'city-a','stable tie break selects server A');
create temp table r1b on commit drop as select city_reserve_session('00000000-0000-4000-8000-000000000071','eu-central-1') v;
select extensions.is((select v->>'reused' from r1b),'true','retry reuses active reservation');
select extensions.is((select v->>'reservation_id' from r1b),(select v->>'reservation_id' from r1),'retry does not duplicate reservation');
create temp table r2 on commit drop as select city_reserve_session('00000000-0000-4000-8000-000000000072','eu-central-1') v;
select extensions.is((select v->>'server_id' from r2),'city-b','less occupied server selected');
create temp table r3 on commit drop as select city_reserve_session('00000000-0000-4000-8000-000000000073','eu-central-1') v;
select extensions.is((select v->>'server_id' from r3),'city-a','equal occupancy tie break is deterministic');
select extensions.is((select count(*)::int from private.city_session_reservations where status='reserved'),3,'three reservations stored');
select extensions.is(city_heartbeat_server('city-b',0,'draining','70000000-0000-4000-8000-000000000005')->>'status','heartbeat_accepted','draining heartbeat accepted');
create temp table r4 on commit drop as select city_reserve_session('00000000-0000-4000-8000-000000000074','eu-central-1') v;
select extensions.is((select v->>'server_id' from r4),'city-a','draining server gets no new reservations');
select extensions.throws_ok($$select city_heartbeat_server('city-a',5,'ready','70000000-0000-4000-8000-000000000006')$$,'P0002','city_server_not_registered_or_capacity_invalid','heartbeat rejects over capacity');
select extensions.is(city_confirm_session_connection('city-a','00000000-0000-4000-8000-000000000071',(select (v->>'reservation_id')::uuid from r1),'70000000-0000-4000-8000-000000000007')->>'status','connected','server confirms reservation');
select extensions.is(city_release_player_reservation('00000000-0000-4000-8000-000000000071',(select (v->>'reservation_id')::uuid from r1))->>'status','not_found','player cannot release a reservation after connecting');
select extensions.is(city_release_server_session('city-a','00000000-0000-4000-8000-000000000071',(select (v->>'reservation_id')::uuid from r1),'70000000-0000-4000-8000-000000000008')->>'status','released','server releases reservation');
select extensions.is(city_release_player_reservation('00000000-0000-4000-8000-000000000072',(select (v->>'reservation_id')::uuid from r2))->>'status','released','trusted gateway releases player reservation');
select extensions.is(city_heartbeat_server('city-a',4,'ready','70000000-0000-4000-8000-000000000009')->>'status','heartbeat_accepted','heartbeat updates connected count');
create temp table rn on commit drop as select city_reserve_session('00000000-0000-4000-8000-000000000072','eu-central-1') v;
select extensions.is((select v->>'status' from rn),'no_capacity','full and draining servers do not receive assignments');
select extensions.throws_ok($$select city_heartbeat_server('city-a',0,'ready','70000000-0000-4000-8000-000000000009')$$,'23505','city_server_nonce_replayed','heartbeat nonce replay rejected');
reset role; set local role authenticated;
select extensions.throws_ok($$select city_reserve_session('00000000-0000-4000-8000-000000000071','eu-central-1')$$,'42501',null,'authenticated cannot invoke internal reservation RPC');
select extensions.throws_ok($$select * from private.city_session_servers$$,'42501',null,'authenticated cannot inspect registry');
reset role; select * from extensions.finish(); rollback;
