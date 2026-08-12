-- BINGO Oman banner public-read setup
-- Run once in Supabase SQL Editor.

-- 1) Allow visitors to read published banners only.
DO $$
BEGIN
  IF to_regclass('public.site_banners') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.site_banners ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "Public can read published banners" ON public.site_banners';
    EXECUTE 'CREATE POLICY "Public can read published banners" ON public.site_banners FOR SELECT TO anon, authenticated USING (status = ''published'' AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at >= now()))';
  END IF;
END $$;

-- 2) Make the banner storage bucket public (safe to run repeatedly).
INSERT INTO storage.buckets (id, name, public)
VALUES ('bingo-banners', 'bingo-banners', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- 3) Public read access to files in the banner bucket.
DROP POLICY IF EXISTS "Public can view bingo banners" ON storage.objects;
CREATE POLICY "Public can view bingo banners"
ON storage.objects FOR SELECT TO anon, authenticated
USING (bucket_id = 'bingo-banners');
