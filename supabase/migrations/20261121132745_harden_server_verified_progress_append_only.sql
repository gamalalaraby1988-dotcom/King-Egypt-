drop policy if exists player_verified_activity_progress_service_role_all
    on private.player_verified_activity_progress;

drop policy if exists player_verified_activity_progress_service_role_select
    on private.player_verified_activity_progress;
create policy player_verified_activity_progress_service_role_select
    on private.player_verified_activity_progress for select to service_role
    using (true);

drop policy if exists player_verified_activity_progress_service_role_insert
    on private.player_verified_activity_progress;
create policy player_verified_activity_progress_service_role_insert
    on private.player_verified_activity_progress for insert to service_role
    with check (true);

revoke update, delete on table private.player_verified_activity_progress
    from public, anon, authenticated, service_role;
grant select, insert on table private.player_verified_activity_progress to service_role;

comment on table private.player_verified_activity_progress is
'Append-only server-verified activity completion ledger. Only the trusted HMAC-verified backend can insert rows; no client or service API role can update or delete existing completion evidence.';
