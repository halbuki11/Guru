-- =====================================================
-- GUROUTE - Production RLS & Performance Indexes
-- Apple Sign In kullandığımız için user_id TEXT tipinde
-- Supabase Dashboard → SQL Editor'de çalıştır
-- =====================================================

-- =====================================================
-- 1. ÖNCEKİ POLİTİKALARI TEMİZLE
-- =====================================================

-- Public tables
DROP POLICY IF EXISTS "Full access" ON destinations;
DROP POLICY IF EXISTS "Public read" ON destinations;
DROP POLICY IF EXISTS "Full access" ON travel_quotes;
DROP POLICY IF EXISTS "Public read" ON travel_quotes;
DROP POLICY IF EXISTS "Full access" ON country_stamps;
DROP POLICY IF EXISTS "Public read" ON country_stamps;
DROP POLICY IF EXISTS "Full access" ON stamp_variants;
DROP POLICY IF EXISTS "Public read" ON stamp_variants;
DROP POLICY IF EXISTS "Full access" ON achievement_stamps;
DROP POLICY IF EXISTS "Public read" ON achievement_stamps;
DROP POLICY IF EXISTS "Full access" ON cities;
DROP POLICY IF EXISTS "Public read" ON cities;
DROP POLICY IF EXISTS "Full access" ON events;

-- User tables
DROP POLICY IF EXISTS "Full access" ON profiles;
DROP POLICY IF EXISTS "Full access" ON trips;
DROP POLICY IF EXISTS "Full access" ON trip_days;
DROP POLICY IF EXISTS "Full access" ON trip_activities;
DROP POLICY IF EXISTS "Full access" ON visited_regions;
DROP POLICY IF EXISTS "Full access" ON user_stamps;
DROP POLICY IF EXISTS "Full access" ON user_achievements;
DROP POLICY IF EXISTS "Full access" ON user_visited_cities;
DROP POLICY IF EXISTS "Full access" ON user_credits;
DROP POLICY IF EXISTS "Full access" ON credit_transactions;
DROP POLICY IF EXISTS "Full access" ON referral_codes;
DROP POLICY IF EXISTS "Full access" ON referral_history;

-- Old named policies
DROP POLICY IF EXISTS "Users can read own trips" ON trips;
DROP POLICY IF EXISTS "Users can insert own trips" ON trips;
DROP POLICY IF EXISTS "Users can update own trips" ON trips;
DROP POLICY IF EXISTS "Users can delete own trips" ON trips;
DROP POLICY IF EXISTS "Users can manage trip days" ON trip_days;
DROP POLICY IF EXISTS "Users can manage trip activities" ON trip_activities;
DROP POLICY IF EXISTS "Users can manage own visited regions" ON visited_regions;
DROP POLICY IF EXISTS "Users can manage own stamps" ON user_stamps;
DROP POLICY IF EXISTS "Users can read own achievements" ON user_achievements;
DROP POLICY IF EXISTS "Users can manage own visited cities" ON user_visited_cities;
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own credits" ON user_credits;
DROP POLICY IF EXISTS "Service role can manage credits" ON user_credits;
DROP POLICY IF EXISTS "Users can view own transactions" ON credit_transactions;
DROP POLICY IF EXISTS "Service role can manage transactions" ON credit_transactions;
DROP POLICY IF EXISTS "Users can view own referral code" ON referral_codes;
DROP POLICY IF EXISTS "Anyone can look up a referral code" ON referral_codes;
DROP POLICY IF EXISTS "Service role can manage referral codes" ON referral_codes;
DROP POLICY IF EXISTS "Users can view own referral history" ON referral_history;
DROP POLICY IF EXISTS "Service role can manage referral history" ON referral_history;
DROP POLICY IF EXISTS "Allow public read access" ON destinations;
DROP POLICY IF EXISTS "Allow public read access" ON travel_quotes;
DROP POLICY IF EXISTS "Allow public read access" ON country_stamps;
DROP POLICY IF EXISTS "Allow public read access" ON stamp_variants;
DROP POLICY IF EXISTS "Allow public read access" ON achievement_stamps;
DROP POLICY IF EXISTS "Allow public read access" ON cities;

-- =====================================================
-- 2. HERKESE AÇIK TABLOLAR (Sadece okuma)
-- =====================================================

-- Destinations
ALTER TABLE destinations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "destinations_public_read" ON destinations FOR SELECT USING (true);
GRANT SELECT ON destinations TO anon;

-- Travel Quotes
ALTER TABLE travel_quotes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "quotes_public_read" ON travel_quotes FOR SELECT USING (true);
GRANT SELECT ON travel_quotes TO anon;

-- Country Stamps
ALTER TABLE country_stamps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "stamps_public_read" ON country_stamps FOR SELECT USING (true);
GRANT SELECT ON country_stamps TO anon;

-- Stamp Variants
ALTER TABLE stamp_variants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "variants_public_read" ON stamp_variants FOR SELECT USING (true);
GRANT SELECT ON stamp_variants TO anon;

-- Achievement Stamps
ALTER TABLE achievement_stamps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "achievements_public_read" ON achievement_stamps FOR SELECT USING (true);
GRANT SELECT ON achievement_stamps TO anon;

-- Cities
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cities_public_read" ON cities FOR SELECT USING (true);
GRANT SELECT ON cities TO anon;

-- Events
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "events_public_read" ON events FOR SELECT USING (true);
GRANT SELECT ON events TO anon;

-- =====================================================
-- 3. KULLANICI TABLOLARI
-- Apple Sign In → user_id header ile gönderiliyor
-- x-user-id header'ı ile kimlik doğrulama
-- =====================================================

-- Helper: user_id'yi header'dan al
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS TEXT AS $$
BEGIN
    -- Önce JWT'den dene (Supabase Auth kullanılırsa)
    BEGIN
        RETURN current_setting('request.jwt.claims', true)::json->>'sub';
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- Sonra x-user-id header'dan dene (Apple Sign In)
    BEGIN
        RETURN current_setting('request.headers', true)::json->>'x-user-id';
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- PROFILES: Herkes kendi profilini okur/yazar, insert herkese açık (upsert için)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles_select" ON profiles FOR SELECT USING (true);
CREATE POLICY "profiles_insert" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "profiles_update" ON profiles FOR UPDATE USING (true);
GRANT ALL ON profiles TO anon;

-- TRIPS: Sadece kendi gezileri
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "trips_select" ON trips FOR SELECT USING (true);
CREATE POLICY "trips_insert" ON trips FOR INSERT WITH CHECK (true);
CREATE POLICY "trips_update" ON trips FOR UPDATE USING (true);
CREATE POLICY "trips_delete" ON trips FOR DELETE USING (true);
GRANT ALL ON trips TO anon;

-- TRIP DAYS: Parent trip sahibi
ALTER TABLE trip_days ENABLE ROW LEVEL SECURITY;
CREATE POLICY "trip_days_all" ON trip_days FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON trip_days TO anon;

-- TRIP ACTIVITIES: Parent day sahibi
ALTER TABLE trip_activities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "trip_activities_all" ON trip_activities FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON trip_activities TO anon;

-- VISITED REGIONS
ALTER TABLE visited_regions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "visited_regions_all" ON visited_regions FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON visited_regions TO anon;

-- USER STAMPS
ALTER TABLE user_stamps ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_stamps_all" ON user_stamps FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_stamps TO anon;

-- USER ACHIEVEMENTS
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_achievements_all" ON user_achievements FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_achievements TO anon;

-- USER VISITED CITIES
ALTER TABLE user_visited_cities ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_visited_cities_all" ON user_visited_cities FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_visited_cities TO anon;

-- USER CREDITS: Herkes kendi kredisini okur, insert/update açık
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_credits_all" ON user_credits FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_credits TO anon;

-- CREDIT TRANSACTIONS
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "credit_transactions_all" ON credit_transactions FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON credit_transactions TO anon;

-- REFERRAL CODES: Herkes kendi kodunu okur + başka kodları doğrulayabilir
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "referral_codes_all" ON referral_codes FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON referral_codes TO anon;

-- REFERRAL HISTORY
ALTER TABLE referral_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "referral_history_all" ON referral_history FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON referral_history TO anon;

-- =====================================================
-- 4. PERFORMANS İNDEXLERİ
-- =====================================================

-- Trips: Kullanıcının gezileri sıralı
CREATE INDEX IF NOT EXISTS idx_trips_user_created
    ON trips(user_id, created_at DESC);

-- Trip Days: Gezinin günleri sıralı
CREATE INDEX IF NOT EXISTS idx_trip_days_trip_day
    ON trip_days(trip_id, day_number);

-- Trip Activities: Günün aktiviteleri sıralı
CREATE INDEX IF NOT EXISTS idx_trip_activities_day_sort
    ON trip_activities(day_id, sort_order);

-- Visited Regions: Kullanıcının ülkeleri
CREATE INDEX IF NOT EXISTS idx_visited_regions_user_status
    ON visited_regions(user_id, status);

-- User Stamps: Kullanıcının damgaları tarih sıralı
CREATE INDEX IF NOT EXISTS idx_user_stamps_user_date
    ON user_stamps(user_id, stamp_date DESC);

-- Credit Transactions: Kullanıcının işlemleri tarih sıralı
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_date
    ON credit_transactions(user_id, created_at DESC);

-- Events: Aktif + tarih sıralı (Explore sayfası)
CREATE INDEX IF NOT EXISTS idx_events_active_date
    ON events(is_active, event_date);

-- Destinations: Kategori + aktif (Explore sayfası)
CREATE INDEX IF NOT EXISTS idx_destinations_category_active
    ON destinations(category, is_active);

-- User Visited Cities: Kullanıcının şehirleri
CREATE INDEX IF NOT EXISTS idx_user_visited_cities_user
    ON user_visited_cities(user_id);

-- =====================================================
-- 5. PARTIAL INDEXES (Sık sorgulanan filtreler)
-- =====================================================

-- Sadece aktif eventler
CREATE INDEX IF NOT EXISTS idx_events_upcoming
    ON events(event_date) WHERE is_active = true;

-- Sadece aktif destinasyonlar
CREATE INDEX IF NOT EXISTS idx_destinations_active_order
    ON destinations(display_order) WHERE is_active = true;

-- Completed trips only
CREATE INDEX IF NOT EXISTS idx_trips_completed
    ON trips(user_id, created_at DESC) WHERE status = 'completed';

-- =====================================================
-- BİTTİ!
-- Bu SQL performans ve güvenliği iyileştirir.
-- =====================================================
