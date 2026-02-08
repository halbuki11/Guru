# Guroute Database & Automation Setup

## 1. Supabase Tablosu Oluşturma

### Adım 1: SQL Çalıştır
1. [Supabase Dashboard](https://supabase.com/dashboard) → Projen → SQL Editor
2. `destinations_table.sql` dosyasındaki SQL'i yapıştır ve çalıştır
3. Başarılı olduğunu doğrula

### Adım 2: RLS Politikalarını Kontrol Et
- `destinations` tablosu → Policies → "Enable RLS" aktif olmalı
- Read policy herkes için açık olmalı

---

## 2. n8n Workflow Kurulumu

### Gerekli API Anahtarları

| Servis | Nereden Alınır | Ücretsiz |
|--------|----------------|----------|
| Anthropic (Claude) | https://console.anthropic.com | Ücretli |
| OpenAI (DALL-E 3) | https://platform.openai.com/api-keys | ~$0.08/görsel |
| Supabase | Dashboard → Settings → API | ✅ |

### n8n Kurulumu

#### Docker ile (Önerilen)
```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  n8nio/n8n
```

#### Alternatif: Cloud
https://n8n.cloud (ücretsiz plan mevcut)

### Workflow Import

1. n8n Dashboard → Workflows → Import
2. `n8n_workflow.json` dosyasını yükle
3. Credentials ayarla:

#### Anthropic API Credential
- Type: Header Auth
- Name: `x-api-key`
- Value: `sk-ant-...` (API anahtarın)

#### OpenAI API Credential (DALL-E 3 görsel üretim)
- Type: Header Auth
- Name: `Authorization`
- Value: `Bearer YOUR_OPENAI_API_KEY`

#### Supabase Credential
- Host: `https://xxxxx.supabase.co`
- Service Role Key: (Dashboard → Settings → API → service_role key)

### Test Etme
1. Workflow'u aç
2. "Execute Workflow" tıkla
3. Her node'un başarılı olduğunu kontrol et
4. Supabase'de verileri kontrol et

---

## 3. Workflow Açıklaması

```
[Schedule: Pazartesi 09:00]
        ↓
[Claude API] → 10 destinasyon öner (JSON)
        ↓
[Parse] → Her destinasyonu ayrı işle
        ↓
[DALL-E 3] → kategori bazlı görsel üret + Supabase Storage'a yükle
        ↓
[Prepare] → Supabase formatına dönüştür
        ↓
[Supabase Upsert] → Kaydet/Güncelle
        ↓
[Summary] → Özet log
```

---

## 4. Görsel Tutarlılık Stratejisi

DALL-E 3 ile her destinasyon için kategori bazlı sinematik görsel üretilir.
Görseller Supabase Storage "destination-images" bucket'ında saklanır.
Var olan görseller tekrar üretilmez (maliyet tasarrufu).

**Örnek:**
```
Destinasyon: "Japan" (category: "cultural")
→ DALL-E prompt: Cinematic travel photograph of Japan. Ancient temples, rich cultural heritage...
→ Storage: destination-images/destinations/japan.png
→ Public URL: https://xxx.supabase.co/storage/v1/object/public/destination-images/destinations/japan.png
```

---

## 5. Manuel Güncelleme (Opsiyonel)

Supabase Dashboard'dan manuel olarak da güncelleyebilirsin:
1. Table Editor → destinations
2. Row ekle/düzenle
3. Değişiklikler anında uygulamaya yansır

---

## 6. Troubleshooting

### Resimler yüklenmiyor
- DALL-E API key'inin geçerli olduğunu kontrol et
- Supabase Storage "destination-images" bucket'ının public olduğunu kontrol et
- `image_url` alanının doğru format olduğunu kontrol et

### Veriler gelmiyor
- Supabase RLS politikalarını kontrol et
- iOS app'te SupabaseService.swift'i kontrol et

### n8n workflow çalışmıyor
- Credentials'ların doğru olduğunu kontrol et
- Her node'u tek tek test et
