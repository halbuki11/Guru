-- ============================================
-- GUROUTE PREMIUM & CREDITS SYSTEM
-- Hybrid Model: Free + Credits + Subscription
-- ============================================

-- 1. USER CREDITS TABLE
-- Her kullanıcının kredi bakiyesini tutar
CREATE TABLE IF NOT EXISTS user_credits (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    balance INTEGER NOT NULL DEFAULT 2,  -- Kayıt olunca 2 hoşgeldin kredisi
    lifetime_earned INTEGER NOT NULL DEFAULT 2,
    lifetime_spent INTEGER NOT NULL DEFAULT 0,
    last_free_credit_at TIMESTAMPTZ,  -- Son ücretsiz aylık kredi zamanı
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- 2. CREDIT TRANSACTIONS TABLE
-- Her kredi hareketinin logu
CREATE TABLE IF NOT EXISTS credit_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,  -- Pozitif = kazanç, negatif = harcama
    balance_after INTEGER NOT NULL,
    type TEXT NOT NULL CHECK (type IN (
        'welcome_bonus',      -- Kayıt bonusu (+2)
        'monthly_free',       -- Aylık ücretsiz kredi (+1)
        'purchase',           -- Satın alma (+3, +5, +10)
        'trip_generation',    -- Rota oluşturma (-1)
        'referral_bonus',     -- Referans bonusu (+1)
        'referral_welcome',   -- Referansla gelen kullanıcı bonusu (+1)
        'admin_grant',        -- Admin tarafından verilen
        'refund'              -- İade
    )),
    description TEXT,
    reference_id TEXT,  -- İlişkili trip_id, purchase_id, referral_code vb.
    created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. REFERRAL CODES TABLE
-- Her kullanıcının benzersiz referans kodu
CREATE TABLE IF NOT EXISTS referral_codes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,  -- 8 karakter benzersiz kod (örn: GR-A7X2K9)
    total_referrals INTEGER NOT NULL DEFAULT 0,
    total_credits_earned INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- 4. REFERRAL HISTORY TABLE
-- Hangi kullanıcı kimi davet etti
CREATE TABLE IF NOT EXISTS referral_history (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    referred_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    referral_code TEXT NOT NULL,
    referrer_credited BOOLEAN NOT NULL DEFAULT false,
    referred_credited BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(referred_user_id)  -- Bir kullanıcı sadece bir kez referansla gelebilir
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_user_credits_user_id ON user_credits(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_user_id ON credit_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_type ON credit_transactions(type);
CREATE INDEX IF NOT EXISTS idx_credit_transactions_created_at ON credit_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON referral_codes(code);
CREATE INDEX IF NOT EXISTS idx_referral_codes_user_id ON referral_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_referral_history_referrer ON referral_history(referrer_user_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- user_credits
ALTER TABLE user_credits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own credits"
    ON user_credits FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage credits"
    ON user_credits FOR ALL
    USING (auth.role() = 'service_role');

-- credit_transactions
ALTER TABLE credit_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own transactions"
    ON credit_transactions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can manage transactions"
    ON credit_transactions FOR ALL
    USING (auth.role() = 'service_role');

-- referral_codes
ALTER TABLE referral_codes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own referral code"
    ON referral_codes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Anyone can look up a referral code"
    ON referral_codes FOR SELECT
    USING (is_active = true);

CREATE POLICY "Service role can manage referral codes"
    ON referral_codes FOR ALL
    USING (auth.role() = 'service_role');

-- referral_history
ALTER TABLE referral_history ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own referral history"
    ON referral_history FOR SELECT
    USING (auth.uid() = referrer_user_id OR auth.uid() = referred_user_id);

CREATE POLICY "Service role can manage referral history"
    ON referral_history FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_user_credits_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_credits_timestamp
    BEFORE UPDATE ON user_credits
    FOR EACH ROW
    EXECUTE FUNCTION update_user_credits_timestamp();

-- ============================================
-- FUNCTION: Initialize credits for new user
-- Called after user registration
-- ============================================
CREATE OR REPLACE FUNCTION initialize_user_credits(p_user_id UUID, p_referral_code TEXT DEFAULT NULL)
RETURNS JSONB AS $$
DECLARE
    v_referrer_id UUID;
    v_welcome_credits INTEGER := 2;
    v_referral_bonus INTEGER := 1;
    v_result JSONB;
BEGIN
    -- Create user credits with welcome bonus
    INSERT INTO user_credits (user_id, balance, lifetime_earned)
    VALUES (p_user_id, v_welcome_credits, v_welcome_credits)
    ON CONFLICT (user_id) DO NOTHING;

    -- Log welcome bonus transaction
    INSERT INTO credit_transactions (user_id, amount, balance_after, type, description)
    VALUES (p_user_id, v_welcome_credits, v_welcome_credits, 'welcome_bonus', 'Hoşgeldin kredisi');

    -- Generate referral code for new user
    INSERT INTO referral_codes (user_id, code)
    VALUES (p_user_id, 'GR-' || upper(substr(md5(random()::text), 1, 6)))
    ON CONFLICT (user_id) DO NOTHING;

    -- Process referral if provided
    IF p_referral_code IS NOT NULL THEN
        SELECT user_id INTO v_referrer_id
        FROM referral_codes
        WHERE code = upper(p_referral_code) AND is_active = true;

        IF v_referrer_id IS NOT NULL AND v_referrer_id != p_user_id THEN
            -- Record referral
            INSERT INTO referral_history (referrer_user_id, referred_user_id, referral_code, referrer_credited, referred_credited)
            VALUES (v_referrer_id, p_user_id, upper(p_referral_code), true, true)
            ON CONFLICT (referred_user_id) DO NOTHING;

            -- Credit the referrer (+1)
            UPDATE user_credits
            SET balance = balance + v_referral_bonus,
                lifetime_earned = lifetime_earned + v_referral_bonus
            WHERE user_id = v_referrer_id;

            INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
            VALUES (
                v_referrer_id,
                v_referral_bonus,
                (SELECT balance FROM user_credits WHERE user_id = v_referrer_id),
                'referral_bonus',
                'Arkadaş davet bonusu',
                p_referral_code
            );

            -- Update referral code stats
            UPDATE referral_codes
            SET total_referrals = total_referrals + 1,
                total_credits_earned = total_credits_earned + v_referral_bonus
            WHERE user_id = v_referrer_id;

            -- Credit the referred user (+1 extra)
            UPDATE user_credits
            SET balance = balance + v_referral_bonus,
                lifetime_earned = lifetime_earned + v_referral_bonus
            WHERE user_id = p_user_id;

            INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
            VALUES (
                p_user_id,
                v_referral_bonus,
                (SELECT balance FROM user_credits WHERE user_id = p_user_id),
                'referral_welcome',
                'Referans kodu ile kayıt bonusu',
                p_referral_code
            );
        END IF;
    END IF;

    SELECT jsonb_build_object(
        'balance', (SELECT balance FROM user_credits WHERE user_id = p_user_id),
        'referral_applied', v_referrer_id IS NOT NULL
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Spend credit for trip generation
-- ============================================
CREATE OR REPLACE FUNCTION spend_credit(p_user_id UUID, p_trip_id TEXT)
RETURNS JSONB AS $$
DECLARE
    v_current_balance INTEGER;
    v_is_premium BOOLEAN;
BEGIN
    -- Check premium status first
    SELECT is_premium INTO v_is_premium FROM profiles WHERE id = p_user_id::text;
    IF v_is_premium = true THEN
        RETURN jsonb_build_object('success', true, 'reason', 'premium', 'balance', -1);
    END IF;

    -- Check credit balance
    SELECT balance INTO v_current_balance FROM user_credits WHERE user_id = p_user_id;

    IF v_current_balance IS NULL OR v_current_balance < 1 THEN
        RETURN jsonb_build_object('success', false, 'reason', 'insufficient_credits', 'balance', COALESCE(v_current_balance, 0));
    END IF;

    -- Deduct credit
    UPDATE user_credits
    SET balance = balance - 1,
        lifetime_spent = lifetime_spent + 1
    WHERE user_id = p_user_id;

    -- Log transaction
    INSERT INTO credit_transactions (user_id, amount, balance_after, type, description, reference_id)
    VALUES (
        p_user_id,
        -1,
        v_current_balance - 1,
        'trip_generation',
        'Rota oluşturma',
        p_trip_id
    );

    RETURN jsonb_build_object('success', true, 'reason', 'credit_spent', 'balance', v_current_balance - 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Add credits after purchase
-- ============================================
CREATE OR REPLACE FUNCTION add_purchased_credits(p_user_id UUID, p_amount INTEGER, p_product_id TEXT)
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
    VALUES (
        p_user_id,
        p_amount,
        v_new_balance,
        'purchase',
        p_amount || ' kredi satın alındı',
        p_product_id
    );

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- FUNCTION: Grant monthly free credit
-- ============================================
CREATE OR REPLACE FUNCTION grant_monthly_credit(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_last_free TIMESTAMPTZ;
    v_new_balance INTEGER;
BEGIN
    SELECT last_free_credit_at INTO v_last_free FROM user_credits WHERE user_id = p_user_id;

    -- Check if 30 days have passed
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
