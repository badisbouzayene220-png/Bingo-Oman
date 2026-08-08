-- BINGO Oman: storage setup for listing photos
-- Run this once in Supabase SQL Editor.

insert into storage.buckets (id, name, public)
values ('listing-images', 'listing-images', true)
on conflict (id) do update set public = true;

-- Users may upload only inside a folder named with their own auth user id.
drop policy if exists "listing_images_upload_own_folder" on storage.objects;
create policy "listing_images_upload_own_folder"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "listing_images_delete_own_folder" on storage.objects;
create policy "listing_images_delete_own_folder"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'listing-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Public URLs are used by the marketplace cards/detail page because the bucket is public.
