-- Preserve access to the shared private schema for existing invoker RPCs.
-- Friend implementation functions remain individually non-executable by API roles.
grant usage on schema private to authenticated;
