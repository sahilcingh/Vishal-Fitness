-- ==========================================
-- APP AUTO-UPDATE CONFIGURATION
-- ==========================================

-- 1. Create the app_config table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    description TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Enable RLS (Read-Only for Everyone)
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "App config is viewable by everyone" ON public.app_config;
CREATE POLICY "App config is viewable by everyone" ON public.app_config
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "Admins can manage app config" ON public.app_config;
CREATE POLICY "Admins can manage app config" ON public.app_config
    FOR ALL USING (
        public.is_admin()
    );

-- 3. Insert initial configuration (Change these values when releasing an update!)
INSERT INTO public.app_config (key, value, description)
VALUES 
    ('latest_version', '1.0.2', 'The most recent version of the app available'),
    ('min_version', '1.0.0', 'Any version older than this will be FORCED to update'),
    ('update_url', 'https://your-download-link.com/app.apk', 'Direct download link to the new APK or App Store URL')
ON CONFLICT (key) 
DO UPDATE SET 
    value = EXCLUDED.value,
    updated_at = now();
