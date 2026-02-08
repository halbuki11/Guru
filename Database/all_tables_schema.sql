-- =====================================================
-- GUROUTE - TÜM TABLO ŞEMALARI
-- Supabase Dashboard → SQL Editor'de çalıştır
-- =====================================================
-- NOT: destinations, travel_quotes, user_credits,
-- credit_transactions, referral_codes, referral_history
-- tabloları zaten mevcut SQL dosyalarında tanımlı.
-- Bu dosya EKSİK olan tabloları oluşturur.
-- =====================================================

-- =====================================================
-- 1. PROFILES (Kullanıcı profilleri)
-- =====================================================
CREATE TABLE IF NOT EXISTS profiles (
    id TEXT PRIMARY KEY,  -- Apple Sign In user ID
    email TEXT,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    is_public BOOLEAN NOT NULL DEFAULT true,
    allow_follow_requests BOOLEAN NOT NULL DEFAULT true,
    countries_visited INTEGER NOT NULL DEFAULT 0,
    cities_visited INTEGER NOT NULL DEFAULT 0,
    trips_count INTEGER NOT NULL DEFAULT 0,
    is_premium BOOLEAN NOT NULL DEFAULT false,
    premium_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- =====================================================
-- 2. TRIPS (Seyahat planları)
-- =====================================================
CREATE TABLE IF NOT EXISTS trips (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    destination_cities TEXT[] NOT NULL DEFAULT '{}',
    duration_nights INTEGER NOT NULL DEFAULT 3,
    start_date DATE,
    arrival_time TEXT,
    departure_time TEXT,
    companion TEXT NOT NULL DEFAULT 'solo',
    arrival_point TEXT,
    stay_area TEXT NOT NULL DEFAULT 'city_center',
    transport_mode TEXT NOT NULL DEFAULT 'walking',
    iconic_preference TEXT NOT NULL DEFAULT 'mix',
    budget TEXT NOT NULL DEFAULT 'mid_range',
    pace TEXT NOT NULL DEFAULT 'moderate',
    must_visit_places TEXT[] DEFAULT '{}',
    title TEXT,
    status TEXT NOT NULL DEFAULT 'draft',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trips_user_id ON trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON trips(status);
CREATE INDEX IF NOT EXISTS idx_trips_created_at ON trips(created_at);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_trips_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_trips_timestamp ON trips;
CREATE TRIGGER trigger_update_trips_timestamp
    BEFORE UPDATE ON trips
    FOR EACH ROW
    EXECUTE FUNCTION update_trips_timestamp();

-- =====================================================
-- 3. TRIP DAYS (Seyahat günleri)
-- =====================================================
CREATE TABLE IF NOT EXISTS trip_days (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    date TIMESTAMPTZ,
    title TEXT,
    summary TEXT,
    weather JSONB,  -- {condition, condition_text, temperature_max, temperature_min, precipitation_chance, humidity, wind_speed}
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_trip_days_trip_id ON trip_days(trip_id);

-- =====================================================
-- 4. TRIP ACTIVITIES (Gün aktiviteleri)
-- =====================================================
CREATE TABLE IF NOT EXISTS trip_activities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    day_id UUID NOT NULL REFERENCES trip_days(id) ON DELETE CASCADE,
    slot TEXT NOT NULL DEFAULT 'morning',  -- morning, afternoon, evening, night
    name TEXT NOT NULL,
    description TEXT,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    duration INTEGER,  -- dakika cinsinden
    start_time TEXT,   -- "09:00" formatında
    end_time TEXT,     -- "11:00" formatında
    cost TEXT,
    tips TEXT,
    photo_url TEXT,
    is_completed BOOLEAN NOT NULL DEFAULT false,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_trip_activities_day_id ON trip_activities(day_id);

-- =====================================================
-- 5. VISITED REGIONS (Ziyaret edilen ülkeler/bölgeler)
-- =====================================================
CREATE TABLE IF NOT EXISTS visited_regions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    country_code TEXT NOT NULL,
    region_code TEXT,
    city_id TEXT,
    visited_at TIMESTAMPTZ,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'visited',  -- visited, wishlist
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visited_regions_user_id ON visited_regions(user_id);
CREATE INDEX IF NOT EXISTS idx_visited_regions_country_code ON visited_regions(country_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_visited_regions_user_country
    ON visited_regions(user_id, country_code);

-- =====================================================
-- 6. CITIES (Şehir veritabanı)
-- =====================================================
CREATE TABLE IF NOT EXISTS cities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    name_en TEXT,
    country_code TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL DEFAULT 0,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 0,
    population INTEGER,
    is_capital BOOLEAN NOT NULL DEFAULT false,
    admin_region TEXT
);

CREATE INDEX IF NOT EXISTS idx_cities_country_code ON cities(country_code);
CREATE INDEX IF NOT EXISTS idx_cities_name ON cities(name);

-- =====================================================
-- 7. USER VISITED CITIES (Kullanıcının ziyaret ettiği şehirler)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_visited_cities (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    city_id UUID NOT NULL REFERENCES cities(id) ON DELETE CASCADE,
    visited_at TIMESTAMPTZ,
    notes TEXT,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    status TEXT NOT NULL DEFAULT 'visited',  -- visited, wishlist
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_visited_cities_user_id ON user_visited_cities(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_visited_cities_user_city
    ON user_visited_cities(user_id, city_id);

-- =====================================================
-- 8. COUNTRY STAMPS (Ülke damga şablonları)
-- =====================================================
CREATE TABLE IF NOT EXISTS country_stamps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_code TEXT NOT NULL UNIQUE,
    country_name TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_country_stamps_country_code ON country_stamps(country_code);

-- =====================================================
-- 9. STAMP VARIANTS (Damga varyantları)
-- =====================================================
CREATE TABLE IF NOT EXISTS stamp_variants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    country_stamp_id UUID NOT NULL REFERENCES country_stamps(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    image_url TEXT NOT NULL,
    is_premium BOOLEAN NOT NULL DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_stamp_variants_country_stamp_id ON stamp_variants(country_stamp_id);

-- =====================================================
-- 10. USER STAMPS (Kullanıcının kazandığı damgalar)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_stamps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    country_code TEXT NOT NULL,
    stamp_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    trip_id UUID REFERENCES trips(id) ON DELETE SET NULL,
    stamp_variant_id UUID REFERENCES stamp_variants(id) ON DELETE SET NULL,
    display_variant_id UUID REFERENCES stamp_variants(id) ON DELETE SET NULL,
    used_variant_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_stamps_user_id ON user_stamps(user_id);
CREATE INDEX IF NOT EXISTS idx_user_stamps_country_code ON user_stamps(country_code);

-- =====================================================
-- 11. ACHIEVEMENT STAMPS (Başarı damgaları tanımları)
-- =====================================================
CREATE TABLE IF NOT EXISTS achievement_stamps (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    name_tr TEXT,
    description TEXT,
    description_tr TEXT,
    image_url TEXT NOT NULL,
    requirement TEXT NOT NULL,  -- countries_visited, cities_visited, trips_completed, continents_visited, world_explorer
    threshold INTEGER NOT NULL DEFAULT 1,
    is_premium BOOLEAN NOT NULL DEFAULT false,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- 12. USER ACHIEVEMENTS (Kullanıcının açtığı başarılar)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL,
    achievement_id UUID NOT NULL REFERENCES achievement_stamps(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_user_achievements_user_achievement
    ON user_achievements(user_id, achievement_id);

-- =====================================================
-- 13. EVENTS (Etkinlikler - Müzik, Spor, Festival)
-- =====================================================
CREATE TABLE IF NOT EXISTS events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    name_tr TEXT,
    description TEXT,
    description_tr TEXT,
    city TEXT,
    country TEXT,
    country_tr TEXT,
    venue TEXT,
    event_date DATE,
    end_date DATE,
    category TEXT,  -- music, sports, festival
    image_url TEXT,
    ticket_url TEXT,
    ticketmaster_id TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);
CREATE INDEX IF NOT EXISTS idx_events_event_date ON events(event_date);
CREATE INDEX IF NOT EXISTS idx_events_is_active ON events(is_active);

-- =====================================================
-- RLS POLİCİLER - Basit (Development)
-- Apple Sign In kullandığımız için anon key ile erişim
-- =====================================================

-- PROFILES
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON profiles;
CREATE POLICY "Full access" ON profiles FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON profiles TO anon;

-- TRIPS
ALTER TABLE trips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON trips;
CREATE POLICY "Full access" ON trips FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON trips TO anon;

-- TRIP DAYS
ALTER TABLE trip_days ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON trip_days;
CREATE POLICY "Full access" ON trip_days FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON trip_days TO anon;

-- TRIP ACTIVITIES
ALTER TABLE trip_activities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON trip_activities;
CREATE POLICY "Full access" ON trip_activities FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON trip_activities TO anon;

-- VISITED REGIONS
ALTER TABLE visited_regions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON visited_regions;
CREATE POLICY "Full access" ON visited_regions FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON visited_regions TO anon;

-- CITIES
ALTER TABLE cities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON cities;
CREATE POLICY "Full access" ON cities FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON cities TO anon;

-- USER VISITED CITIES
ALTER TABLE user_visited_cities ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON user_visited_cities;
CREATE POLICY "Full access" ON user_visited_cities FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_visited_cities TO anon;

-- COUNTRY STAMPS
ALTER TABLE country_stamps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON country_stamps;
CREATE POLICY "Full access" ON country_stamps FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON country_stamps TO anon;

-- STAMP VARIANTS
ALTER TABLE stamp_variants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON stamp_variants;
CREATE POLICY "Full access" ON stamp_variants FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON stamp_variants TO anon;

-- USER STAMPS
ALTER TABLE user_stamps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON user_stamps;
CREATE POLICY "Full access" ON user_stamps FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_stamps TO anon;

-- ACHIEVEMENT STAMPS
ALTER TABLE achievement_stamps ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON achievement_stamps;
CREATE POLICY "Full access" ON achievement_stamps FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON achievement_stamps TO anon;

-- USER ACHIEVEMENTS
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON user_achievements;
CREATE POLICY "Full access" ON user_achievements FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON user_achievements TO anon;

-- EVENTS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Full access" ON events;
CREATE POLICY "Full access" ON events FOR ALL USING (true) WITH CHECK (true);
GRANT ALL ON events TO anon;

-- =====================================================
-- BAŞLANGIÇ VERİLERİ - Başarı Damgaları
-- =====================================================
INSERT INTO achievement_stamps (name, name_tr, description, description_tr, image_url, requirement, threshold, is_premium, is_active) VALUES
    ('First Steps', 'İlk Adımlar', 'Visit your first country', 'İlk ülkeni ziyaret et', 'achievement_first_steps', 'countries_visited', 1, false, true),
    ('Explorer', 'Kaşif', 'Visit 5 countries', '5 ülke ziyaret et', 'achievement_explorer', 'countries_visited', 5, false, true),
    ('Globe Trotter', 'Dünya Gezgini', 'Visit 10 countries', '10 ülke ziyaret et', 'achievement_globe_trotter', 'countries_visited', 10, false, true),
    ('World Traveler', 'Dünya Seyyahı', 'Visit 25 countries', '25 ülke ziyaret et', 'achievement_world_traveler', 'countries_visited', 25, true, true),
    ('World Master', 'Dünya Ustası', 'Visit 50 countries', '50 ülke ziyaret et', 'achievement_world_master', 'countries_visited', 50, true, true),
    ('City Hopper', 'Şehir Gezgini', 'Visit 5 cities', '5 şehir ziyaret et', 'achievement_city_hopper', 'cities_visited', 5, false, true),
    ('Urban Explorer', 'Şehir Kaşifi', 'Visit 20 cities', '20 şehir ziyaret et', 'achievement_urban_explorer', 'cities_visited', 20, false, true),
    ('Metropolis Master', 'Metropol Ustası', 'Visit 50 cities', '50 şehir ziyaret et', 'achievement_metropolis', 'cities_visited', 50, true, true),
    ('Trip Starter', 'Yolculuk Başlatıcı', 'Complete your first trip', 'İlk seyahatini tamamla', 'achievement_trip_starter', 'trips_completed', 1, false, true),
    ('Adventurer', 'Maceracı', 'Complete 5 trips', '5 seyahat tamamla', 'achievement_adventurer', 'trips_completed', 5, false, true),
    ('Seasoned Traveler', 'Deneyimli Gezgin', 'Complete 20 trips', '20 seyahat tamamla', 'achievement_seasoned', 'trips_completed', 20, true, true),
    ('Continental', 'Kıtasal', 'Visit 2 continents', '2 kıta ziyaret et', 'achievement_continental', 'continents_visited', 2, false, true),
    ('Intercontinental', 'Kıtalararası', 'Visit 4 continents', '4 kıta ziyaret et', 'achievement_intercontinental', 'continents_visited', 4, false, true),
    ('All Continents', 'Tüm Kıtalar', 'Visit all 6 continents', '6 kıtayı da ziyaret et', 'achievement_all_continents', 'continents_visited', 6, true, true),
    ('World Explorer', 'Dünya Kaşifi', 'Visit 10% of the world', 'Dünyanın %10''unu ziyaret et', 'achievement_world_explorer', 'world_explorer', 10, true, true)
ON CONFLICT DO NOTHING;

-- =====================================================
-- BAŞLANGIÇ VERİLERİ - Bazı Örnek Ülke Damgaları
-- =====================================================
INSERT INTO country_stamps (country_code, country_name, is_active) VALUES
    ('TR', 'Türkiye', true),
    ('FR', 'France', true),
    ('IT', 'Italy', true),
    ('ES', 'Spain', true),
    ('DE', 'Germany', true),
    ('GB', 'United Kingdom', true),
    ('US', 'United States', true),
    ('JP', 'Japan', true),
    ('GR', 'Greece', true),
    ('NL', 'Netherlands', true),
    ('PT', 'Portugal', true),
    ('TH', 'Thailand', true),
    ('AE', 'United Arab Emirates', true),
    ('EG', 'Egypt', true),
    ('AU', 'Australia', true),
    ('BR', 'Brazil', true),
    ('MX', 'Mexico', true),
    ('ID', 'Indonesia', true),
    ('IN', 'India', true),
    ('KR', 'South Korea', true)
ON CONFLICT (country_code) DO NOTHING;

-- =====================================================
-- BİTTİ!
-- Bu dosyayı Supabase SQL Editor'de çalıştırın.
-- Zaten var olan tablolar IF NOT EXISTS ile korunur.
-- =====================================================
