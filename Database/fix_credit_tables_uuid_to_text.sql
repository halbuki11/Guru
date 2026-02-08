-- =====================================================
-- GUROUTE - KREDİ TABLOLARI UUID → TEXT DÜZELTME
-- Apple Sign In kullanıcı ID'si TEXT formatında
-- (örn: "000304.e1eaef650c6b...")
-- auth.users tablosu kullanılmıyor, profiles(id) TEXT
--
-- Supabase Dashboard → SQL Editor'de çalıştır
-- =====================================================

-- =====================================================
-- ADIM 1: Mevcut tabloları ve constraint'leri temizle
-- =====================================================

-- user_credits tablosunu yeniden oluştur (TEXT user_id ile)
DROP TABLE IF EXISTS credit_transactions CASCADE;
DROP TABLE IF EXISTS referral_history CASCADE;
DROP TABLE IF EXISTS referral_codes CASCADE;
DROP TABLE IF EXISTS user_credits CASCADE;

-- =====================================================
-- ADIM 2: Tabloları TEXT user_id ile oluştur
-- =====================================================

-- USER CREDITS
CREATE TABLE user_credits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    balance INTEGER NOT NULL DEFAULT 2,
    lifetime_earned INTEGER NOT NULL DEFAULT 2,
    lifetime_spent INTEGER NOT NULL DEFAULT 0,
    last_free_credit_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- CREDIT TRANSACTIONS
CREATE TABLE credit_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    balance_after INTEGER NOT NULL,
    type TEXT NOT NULL CHECK (type IN (
        'welcome_bonus',
        'monthly_free',
        'purchase',
        'trip_generation',
        'referral_bonus',
        'referral_welcome',
        'admin_grant',
        'refund'
    )),
    description TEXT,
    reference_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- REFERRAL CODES
CREATE TABLE referral_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,
    total_referrals INTEGER NOT NULL DEFAULT 0,
    total_credits_earned INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- REFERRAL HISTORY
CREATE TABLE referral_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    referred_user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    referral_code TEXT NOT NULL,
    referrer_credited BOOLEAN NOT NULL DEFAULT false,
    referred_credited BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(referred_user_id)
);

-- =====================================================
-- ADIM 3: İndeksler
-- =====================================================
CREATE INDEX idx_user_credits_user_id ON user_credits(user_id);
CREATE INDEX idx_credit_transactions_user_id ON credit_transactions(user_id);
CREATE INDEX idx_credit_transactions_type ON credit_transactions(type);
CREATE INDEX idx_credit_transactions_created_at ON credit_transactions(created_at);
CREATE INDEX idx_referral_codes_code ON referral_codes(code);
CREATE INDEX idx_referral_codes_user_id ON referral_codes(user_id);
CREATE INDEX idx_referral_history_referrer ON referral_history(referrer_user_id);

-- =====================================================
-- ADIM 4: RLS Politikaları
-- Anon key ile erişim için kullanıcı kendi verisini görebilir
-- =====================================================

-- user_credits
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "user_credits_select" ON user_credits FOR SELECT USING (true);
CREATE POLICY "user_credits_insert" ON user_credits FOR INSERT WITH CHECK (true);
CREATE POLICY "user_credits_update" ON user_credits FOR UPDATE USING (true);
CREATE POLICY "user_credits_delete" ON user_credits FOR DELETE USING (true);

-- credit_transactions
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "credit_transactions_select" ON credit_transactions FOR SELECT USING (true);
CREATE POLICY "credit_transactions_insert" ON credit_transactions FOR INSERT WITH CHECK (true);

-- referral_codes
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "referral_codes_select" ON referral_codes FOR SELECT USING (true);
CREATE POLICY "referral_codes_insert" ON referral_codes FOR INSERT WITH CHECK (true);
CREATE POLICY "referral_codes_update" ON referral_codes FOR UPDATE USING (true);

-- referral_history
ALTER TABLE referral_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "referral_history_select" ON referral_history FOR SELECT USING (true);
CREATE POLICY "referral_history_insert" ON referral_history FOR INSERT WITH CHECK (true);

-- =====================================================
-- ADIM 5: updated_at Trigger
-- =====================================================
CREATE OR REPLACE FUNCTION update_user_credits_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_credits_timestamp ON user_credits;
CREATE TRIGGER trigger_update_user_credits_timestamp
    BEFORE UPDATE ON user_credits
    FOR EACH ROW
    EXECUTE FUNCTION update_user_credits_timestamp();

-- =====================================================
-- ADIM 6: RPC Fonksiyonları (TEXT user_id ile)
-- =====================================================

-- initialize_user_credits: Yeni kullanıcı için kredi başlat
CREATE OR REPLACE FUNCTION initialize_user_credits(p_user_id TEXT, p_referral_code TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_referrer_id TEXT;
    v_welcome_credits INTEGER := 2;
    v_referral_bonus INTEGER := 1;
    v_result JSONB;
BEGIN
    -- Mevcut kredi var mı?
    IF EXISTS (SELECT 1 FROM user_credits WHERE user_id = p_user_id) THEN
        SELECT jsonb_build_object(
            'balance', (SELECT balance FROM user_credits WHERE user_id = p_user_id),
            'referral_applied', false,
            'already_exists', true
        ) INTO v_result;
        RETURN v_result;
    END IF;

    -- Hoşgeldin kredisi
    INSERT INTO user_credits (user_id, balance, lifetime_earned)
    VALUES (p_user_id, v_welcome_credits, v_welcome_credits);

    INSERT INTO credit_transactions (user_id, amount, balance_after, type, description)
    VALUES (p_user_id, v_welcome_credits, v_welcome_credits, 'welcome_bonus', 'Hoşgeldin kredisi');

    -- Referans kodu oluştur
    INSERT INTO referral_codes (user_id, code)
    VALUES (p_user_id, 'GR-' || upper(substr(md5(random()::text), 1, 6)))
    ON CONFLICT (user_id) DO NOTHING;

    -- Referans kodu işle
    IF p_referral_code IS NOT NULL THEN
        SELECT user_id INTO v_referrer_id
        FROM referral_codes
        WHERE code = upper(p_referral_code) AND is_active = true;

        IF v_referrer_id IS NOT NULL AND v_referrer_id != p_user_id THEN
            -- Referans kaydı
            INSERT INTO referral_history (referrer_user_id, referred_user_id, referral_code, referrer_credited, referred_credited)
            VALUES (v_referrer_id, p_user_id, upper(p_referral_code), true, true)
            ON CONFLICT (referred_user_id) DO NOTHING;

            -- Davet eden: +1 kredi
            UPDATE user_credits
            SET balance = balance + v_referral_bonus,
                lifetime_earned = lifetime_earned + v_referral_bonus
            WHERE user_id = v_referrer_id;

            INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
            VALUES (
                v_referrer_id, v_referral_bonus,
                (SELECT balance FROM user_credits WHERE user_id = v_referrer_id),
                'referral_bonus', 'Arkadaş davet bonusu', p_referral_code
            );

            -- Referans istatistiklerini güncelle
            UPDATE referral_codes
            SET total_referrals = total_referrals + 1,
                total_credits_earned = total_credits_earned + v_referral_bonus
            WHERE user_id = v_referrer_id;

            -- Davet edilen: +1 ekstra kredi
            UPDATE user_credits
            SET balance = balance + v_referral_bonus,
                lifetime_earned = lifetime_earned + v_referral_bonus
            WHERE user_id = p_user_id;

            INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
            VALUES (
                p_user_id, v_referral_bonus,
                (SELECT balance FROM user_credits WHERE user_id = p_user_id),
                'referral_welcome', 'Referans kodu ile kayıt bonusu', p_referral_code
            );
        END IF;
    END IF;

    SELECT jsonb_build_object(
        'balance', (SELECT balance FROM user_credits WHERE user_id = p_user_id),
        'referral_applied', v_referrer_id IS NOT NULL,
        'already_exists', false
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- spend_credit: Rota oluşturma için kredi harca
CREATE OR REPLACE FUNCTION spend_credit(p_user_id TEXT, p_trip_id TEXT)
RETURNS JSONB AS $$
DECLARE
    v_current_balance INTEGER;
    v_is_premium BOOLEAN;
BEGIN
    -- Premium kontrolü
    SELECT is_premium INTO v_is_premium FROM profiles WHERE id = p_user_id;
    IF v_is_premium = true THEN
        RETURN jsonb_build_object('success', true, 'reason', 'premium', 'balance', -1);
    END IF;

    -- Bakiye kontrolü
    SELECT balance INTO v_current_balance FROM user_credits WHERE user_id = p_user_id;

    IF v_current_balance IS NULL OR v_current_balance < 1 THEN
        RETURN jsonb_build_object('success', false, 'reason', 'insufficient_credits', 'balance', COALESCE(v_current_balance, 0));
    END IF;

    -- Kredi düş
    UPDATE user_credits
    SET balance = balance - 1,
        lifetime_spent = lifetime_spent + 1
    WHERE user_id = p_user_id;

    -- İşlem logu
    INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
    VALUES (p_user_id, -1, v_current_balance - 1, 'trip_generation', 'Rota oluşturma', p_trip_id);

    RETURN jsonb_build_object('success', true, 'reason', 'credit_spent', 'balance', v_current_balance - 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- add_purchased_credits: Satın alma sonrası kredi ekle
CREATE OR REPLACE FUNCTION add_purchased_credits(p_user_id TEXT, p_amount INTEGER, p_product_id TEXT)
RETURNS INTEGER AS $$
DECLARE
    v_new_balance INTEGER;
BEGIN
    UPDATE user_credits
    SET balance = balance + p_amount,
        lifetime_earned = lifetime_earned + p_amount
    WHERE user_id = p_user_id;

    SELECT balance INTO v_new_balance FROM user_credits WHERE user_id = p_user_id;

    INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
    VALUES (p_user_id, p_amount, v_new_balance, 'purchase', p_amount || ' kredi satın alındı', p_product_id);

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- grant_monthly_credit: Aylık ücretsiz kredi
CREATE OR REPLACE FUNCTION grant_monthly_credit(p_user_id TEXT)
RETURNS JSONB AS $$
DECLARE
    v_last_free TIMESTAMPTZ;
    v_new_balance INTEGER;
BEGIN
    SELECT last_free_credit_at INTO v_last_free FROM user_credits WHERE user_id = p_user_id;

    IF v_last_free IS NOT NULL AND v_last_free > now() - INTERVAL '30 days' THEN
        RETURN jsonb_build_object('granted', false, 'reason', 'too_soon');
    END IF;

    UPDATE user_credits
    SET balance = balance + 1,
        lifetime_earned = lifetime_earned + 1,
        last_free_credit_at = now()
    WHERE user_id = p_user_id;

    SELECT balance INTO v_new_balance FROM user_credits WHERE user_id = p_user_id;

    INSERT INTO credit_transactions (user_id, amount, balance_after, type, description)
    VALUES (p_user_id, 1, v_new_balance, 'monthly_free', 'Aylık ücretsiz kredi');

    RETURN jsonb_build_object('granted', true, 'new_balance', v_new_balance);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- ADIM 7: Mevcut kullanıcıyı yeniden başlat
-- (profiles tablosundaki kullanıcılar için)
-- =====================================================
INSERT INTO user_credits (user_id, balance, lifetime_earned)
SELECT id, 2, 2 FROM profiles
WHERE id NOT IN (SELECT user_id FROM user_credits)
ON CONFLICT (user_id) DO NOTHING;

-- Hoşgeldin kredisi logu
INSERT INTO credit_transactions (user_id, amount, balance_after, type, description)
SELECT id, 2, 2, 'welcome_bonus', 'Hoşgeldin kredisi' FROM profiles
WHERE id NOT IN (SELECT DISTINCT user_id FROM credit_transactions WHERE type = 'welcome_bonus');

-- Referans kodu oluştur
INSERT INTO referral_codes (user_id, code)
SELECT id, 'GR-' || upper(substr(md5(id || random()::text), 1, 6)) FROM profiles
WHERE id NOT IN (SELECT user_id FROM referral_codes)
ON CONFLICT (user_id) DO NOTHING;

-- =====================================================
-- KONTROL: Sonuçları görüntüle
-- =====================================================
SELECT 'user_credits' as tablo, count(*) as kayit FROM user_credits
UNION ALL
SELECT 'credit_transactions', count(*) FROM credit_transactions
UNION ALL
SELECT 'referral_codes', count(*) FROM referral_codes;
