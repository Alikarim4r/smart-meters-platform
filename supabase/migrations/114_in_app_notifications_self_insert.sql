-- Allow users to insert their own in-app notifications (shade delivery + widgets).
-- Keeps org-admin insert path; adds self-insert when user has site/org access.
-- Note: public.profiles has no organization_id column — use site access instead.

drop policy if exists "in_app_notifications_insert" on public.in_app_notifications;

create policy "in_app_notifications_insert"
  on public.in_app_notifications for insert to authenticated
  with check (
    public.is_super_admin()
    or public.is_platform_owner()
    or public.user_can_manage_organization(organization_id)
    or (
      user_id = auth.uid()
      and (
        (site_id is not null and public.has_site_access(site_id))
        or public.user_can_manage_organization(organization_id)
        or exists (
          select 1
          from public.user_site_access usa
          join public.sites s on s.id = usa.site_id
          where usa.user_id = auth.uid()
            and s.organization_id = in_app_notifications.organization_id
        )
      )
    )
  );
