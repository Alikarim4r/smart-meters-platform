-- Review 0: all conservation + platform review flags OFF for org
-- org 11111111-1111-4111-8111-111111111111
update public.conservation_feature_flags
set enabled = false, updated_at = now()
where organization_id = '11111111-1111-4111-8111-111111111111'
  and site_id is null;

update public.platform_feature_flags
set enabled = false, updated_at = now()
where organization_id = '11111111-1111-4111-8111-111111111111'
  and site_id is null;

select 'conservation' as kind, flag_key, enabled
from conservation_feature_flags
where organization_id = '11111111-1111-4111-8111-111111111111' and site_id is null
union all
select 'platform', flag_key, enabled
from platform_feature_flags
where organization_id = '11111111-1111-4111-8111-111111111111' and site_id is null
order by 1, 2;
