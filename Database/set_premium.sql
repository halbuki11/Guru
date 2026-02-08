-- =====================================================
-- GUROUTE - Premium Kullanıcı Ayarla
-- Supabase Dashboard → SQL Editor'de çalıştır
-- =====================================================

-- Tüm kullanıcıları premium yap (tek kullanıcı olduğun için)
UPDATE profiles
SET is_premium = true,
    premium_expires_at = NULL,
    updated_at = now()
WHERE is_premium = false OR is_premium IS NULL;

-- Sonucu kontrol et
SELECT id, display_name, email, is_premium, premium_expires_at
FROM profiles;
