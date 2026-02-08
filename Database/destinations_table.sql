-- Guroute Destinations Table
-- Bu SQL'i Supabase Dashboard > SQL Editor'de çalıştır

-- Destinations tablosu
CREATE TABLE IF NOT EXISTS destinations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    country TEXT NOT NULL,
    description TEXT,
    image_url TEXT NOT NULL,
    rating DECIMAL(2,1) DEFAULT 4.5,
    trend_percentage INT DEFAULT 0,
    seasonal_tag TEXT,
    primary_color TEXT DEFAULT '667eea',
    secondary_color TEXT DEFAULT '764ba2',
    category TEXT NOT NULL CHECK (category IN ('story', 'featured', 'trending', 'seasonal', 'popular')),
    season TEXT CHECK (season IN ('winter', 'spring', 'summer', 'fall', 'all')),
    display_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    search_keywords TEXT[], -- Unsplash arama için
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index'ler
CREATE INDEX idx_destinations_category ON destinations(category);
CREATE INDEX idx_destinations_season ON destinations(season);
CREATE INDEX idx_destinations_active ON destinations(is_active);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_destinations_updated_at
    BEFORE UPDATE ON destinations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS (Row Level Security) - Herkes okuyabilir
ALTER TABLE destinations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Destinations are viewable by everyone"
ON destinations FOR SELECT
USING (true);

-- Sadece service role yazabilir (n8n için)
CREATE POLICY "Service role can insert destinations"
ON destinations FOR INSERT
WITH CHECK (true);

CREATE POLICY "Service role can update destinations"
ON destinations FOR UPDATE
USING (true);

CREATE POLICY "Service role can delete destinations"
ON destinations FOR DELETE
USING (true);

-- Başlangıç verileri
INSERT INTO destinations (name, country, description, image_url, rating, trend_percentage, seasonal_tag, primary_color, secondary_color, category, season, display_order, search_keywords) VALUES
-- Story Destinations
('Paris', 'Fransa', 'Işıklar şehri', 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=400&q=80', 4.8, 24, 'Romantik', '667eea', '764ba2', 'story', 'all', 1, ARRAY['eiffel tower', 'paris skyline', 'seine river']),
('Tokyo', 'Japonya', 'Geleceğin şehri', 'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=400&q=80', 4.9, 32, 'Kültür', 'f093fb', 'f5576c', 'story', 'all', 2, ARRAY['tokyo tower', 'shibuya crossing', 'tokyo night']),
('Roma', 'İtalya', 'Ebedi şehir', 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400&q=80', 4.7, 18, 'Tarih', '4facfe', '00f2fe', 'story', 'all', 3, ARRAY['colosseum', 'roman forum', 'trevi fountain']),
('Barcelona', 'İspanya', 'Gaudi''nin şehri', 'https://images.unsplash.com/photo-1583422409516-2895a77efded?w=400&q=80', 4.6, 21, 'Sanat', '43e97b', '38f9d7', 'story', 'all', 4, ARRAY['sagrada familia', 'park guell', 'barcelona beach']),
('Dubai', 'BAE', 'Lüksün başkenti', 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?w=400&q=80', 4.5, 45, 'Modern', 'fa709a', 'fee140', 'story', 'all', 5, ARRAY['burj khalifa', 'dubai marina', 'palm jumeirah']),
('İstanbul', 'Türkiye', 'İki kıtanın buluşması', 'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?w=400&q=80', 4.8, 28, 'Tarih & Kültür', 'a8edea', 'fed6e3', 'story', 'all', 6, ARRAY['hagia sophia', 'blue mosque', 'bosphorus']),

-- Featured (Öne Çıkan - her hafta 1 tane)
('Paris', 'Fransa', 'Işıklar şehri, aşkın başkenti', 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=800&q=80', 4.8, 24, 'İlkbahar favorisi', '667eea', '764ba2', 'featured', 'all', 1, ARRAY['eiffel tower', 'paris romantic']),

-- Trending
('Bali', 'Endonezya', 'Cennet adası', 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?w=400&q=80', 4.9, 52, 'Plaj', '11998e', '38ef7d', 'trending', 'all', 1, ARRAY['bali temple', 'bali rice terrace', 'bali beach']),
('Santorini', 'Yunanistan', 'Mavi cennet', 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?w=400&q=80', 4.8, 38, 'Romantik', '4facfe', '00f2fe', 'trending', 'all', 2, ARRAY['santorini blue dome', 'oia sunset', 'santorini caldera']),
('Kyoto', 'Japonya', 'Geleneksel Japonya', 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?w=400&q=80', 4.9, 29, 'Kültür', 'f5af19', 'f12711', 'trending', 'all', 3, ARRAY['fushimi inari', 'kyoto temple', 'bamboo forest']),
('Marakeş', 'Fas', 'Renkli şehir', 'https://images.unsplash.com/photo-1597211833712-5e41faa202ea?w=400&q=80', 4.6, 35, 'Egzotik', 'eb3349', 'f45c43', 'trending', 'all', 4, ARRAY['marrakech medina', 'jemaa el fna', 'morocco market']),

-- Seasonal - Winter
('Alpler', 'İsviçre', 'Kayak cenneti', 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=400&q=80', 4.8, 40, 'Kayak sezonu', '4facfe', '00f2fe', 'seasonal', 'winter', 1, ARRAY['swiss alps', 'ski resort', 'matterhorn']),
('Lapland', 'Finlandiya', 'Kuzey ışıkları', 'https://images.unsplash.com/photo-1531366936337-7c912a4589a7?w=400&q=80', 4.9, 55, 'Aurora borealis', '667eea', '764ba2', 'seasonal', 'winter', 2, ARRAY['northern lights', 'aurora borealis', 'lapland snow']),

-- Seasonal - Summer
('Maldivler', 'Maldivler', 'Tropikal cennet', 'https://images.unsplash.com/photo-1514282401047-d79a71a590e8?w=400&q=80', 4.9, 48, 'Plaj sezonu', '11998e', '38ef7d', 'seasonal', 'summer', 1, ARRAY['maldives beach', 'overwater bungalow', 'maldives aerial']),
('Ibiza', 'İspanya', 'Parti adası', 'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=400&q=80', 4.5, 42, 'Festival sezonu', 'f093fb', 'f5576c', 'seasonal', 'summer', 2, ARRAY['ibiza beach', 'ibiza sunset', 'ibiza party']),

-- Seasonal - Spring/Fall
('Prag', 'Çekya', 'Masallar şehri', 'https://images.unsplash.com/photo-1519677100203-a0e668c92439?w=400&q=80', 4.7, 25, 'Sonbahar güzelliği', 'f5af19', 'f12711', 'seasonal', 'fall', 1, ARRAY['prague castle', 'charles bridge', 'old town square']),
('Amsterdam', 'Hollanda', 'Kanallar şehri', 'https://images.unsplash.com/photo-1534351590666-13e3e96b5017?w=400&q=80', 4.6, 22, 'Lale sezonu', 'fa709a', 'fee140', 'seasonal', 'spring', 1, ARRAY['amsterdam canals', 'tulip fields', 'dutch windmill']),

-- Popular
('New York', 'ABD', 'Asla uyumayan şehir', 'https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400&q=80', 4.7, 20, 'Şehir', '232526', '414345', 'popular', 'all', 1, ARRAY['times square', 'statue of liberty', 'manhattan skyline']),
('Londra', 'İngiltere', 'Kraliçenin şehri', 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?w=400&q=80', 4.6, 18, 'Kültür', '0f2027', '2c5364', 'popular', 'all', 2, ARRAY['big ben', 'tower bridge', 'london eye']),
('Sydney', 'Avustralya', 'Opera evi', 'https://images.unsplash.com/photo-1506973035872-a4ec16b8e8d9?w=400&q=80', 4.7, 15, 'Doğa', '11998e', '38ef7d', 'popular', 'all', 3, ARRAY['sydney opera house', 'harbour bridge', 'bondi beach']),
('Singapur', 'Singapur', 'Bahçe şehir', 'https://images.unsplash.com/photo-1525625293386-3f8f99389edd?w=400&q=80', 4.8, 30, 'Modern', 'fc4a1a', 'f7b733', 'popular', 'all', 4, ARRAY['marina bay sands', 'gardens by the bay', 'singapore skyline']);

-- Quotes tablosu (opsiyonel)
CREATE TABLE IF NOT EXISTS travel_quotes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    quote TEXT NOT NULL,
    author TEXT DEFAULT 'Bilinmeyen Gezgin',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE travel_quotes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Quotes are viewable by everyone"
ON travel_quotes FOR SELECT
USING (true);

INSERT INTO travel_quotes (quote, author) VALUES
('Seyahat, önyargıların, bağnazlığın ve dar görüşlülüğün düşmanıdır.', 'Mark Twain'),
('Dünya bir kitaptır ve seyahat etmeyenler sadece bir sayfasını okur.', 'Saint Augustine'),
('Yolculuk, varış noktası değil, yolun kendisidir.', 'Ralph Waldo Emerson'),
('En güzel yolculuklar, kaybolduğumuzda başlar.', 'Bilinmeyen'),
('Konfor alanından çık, macera orada başlıyor.', 'Bilinmeyen');
