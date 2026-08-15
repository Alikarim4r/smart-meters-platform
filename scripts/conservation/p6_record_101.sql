insert into supabase_migrations.schema_migrations (version, name, statements)
values ('101', 'automation_rules_trigger_jwt_guard', array[]::text[])
on conflict (version) do nothing;

select version, name from supabase_migrations.schema_migrations
where version::int >= 100
order by version;
