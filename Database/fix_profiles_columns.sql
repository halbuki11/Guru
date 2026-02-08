-- =====================================================
-- GUROUTE - Profiles tablosuna eksik sütunları ekle
-- Supabase Dashboard → SQL Editor'de çalıştır
-- =====================================================

-- Mevcut profiles tablosuna eksik sütunları ekle
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS allow_follow_requests BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS countries_visited INTEGER NOT NULL DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS cities_visited INTEGER NOT NULL DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS trips_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS premium_expires_at TIMESTAMPTZ;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

-- =====================================================
-- BİTTİ! Artık profiles tablosunda tüm sütunlar var.
-- =====================================================
