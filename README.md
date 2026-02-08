# Guroute - Swift/SwiftUI

AI destekli seyahat planlama uygulaması - iOS native Swift versiyonu.

## 🚀 Xcode'da Çalıştırma

### 1. Projeyi Aç

```bash
# Terminal'de GurouteSwift klasörüne git
cd GurouteSwift

# Package.swift ile Xcode'u aç
open Package.swift
```

**Alternatif:** Finder'da `Package.swift` dosyasına çift tıkla.

### 2. API Key'leri Ayarla

`Guroute/Config.xcconfig` dosyasını `Config.local.xcconfig` olarak kopyala ve API key'lerini doldur:

```bash
cp Guroute/Config.xcconfig Guroute/Config.local.xcconfig
```

`Config.local.xcconfig` içeriği:
```
SUPABASE_URL = https://your-project.supabase.co
SUPABASE_ANON_KEY = your-supabase-anon-key
CLAUDE_API_KEY = your-claude-api-key
GROQ_API_KEY = your-groq-api-key
```

### 3. Dependencies'i Yükle

Xcode, `Package.swift` açıldığında otomatik olarak bağımlılıkları yükleyecek. İlk açılışta biraz beklemen gerekebilir.

### 4. Run!

1. Sol üstten **iPhone 15 Pro** veya istediğin simülatörü seç
2. **⌘ + R** (Command + R) veya ▶️ butonuna tıkla
3. Simulator'da uygulama açılacak

---

## 📱 Özellikler

- **AI Seyahat Planı**: Claude/Groq API ile akıllı seyahat planları
- **Dünya Haritası**: Ziyaret edilen ve gitmek istenen ülkeleri takip
- **Dijital Pasaport**: Ülke damgaları ve başarılar
- **Premium Abonelik**: Reklamsız deneyim ve sınırsız plan

## 📱 Gereksinimler

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- iOS 17.0+ (Simulator veya cihaz)
- Swift 5.9+

## 📁 Proje Yapısı

```
GurouteSwift/
├── Package.swift           # SPM manifest
├── Guroute/
│   ├── App/                # Ana uygulama (GurouteApp.swift, ContentView.swift)
│   ├── Core/
│   │   ├── Config/         # Konfigürasyon (AppConfig.swift)
│   │   ├── Models/         # Veri modelleri (Trip, User, Passport, Weather)
│   │   ├── Services/       # Servisler (Auth, API, Supabase, Weather, AI)
│   │   ├── Theme/          # Tema (AppColors, ThemeManager)
│   │   └── Utils/          # Yardımcı fonksiyonlar
│   ├── Features/
│   │   ├── Auth/           # Giriş/Kayıt ekranları
│   │   ├── Home/           # Ana sayfa, Geziler listesi
│   │   ├── Plan/           # Gezi oluşturma ve detay
│   │   ├── Map/            # Dünya haritası
│   │   ├── Passport/       # Dijital pasaport
│   │   ├── Generating/     # AI plan oluşturma animasyonu
│   │   ├── Onboarding/     # İlk açılış ekranları
│   │   ├── Profile/        # Profil düzenleme
│   │   └── Settings/       # Ayarlar
│   ├── Resources/
│   │   └── Localization/   # TR/EN dil dosyaları
│   ├── Assets.xcassets/    # App icon, renkler
│   ├── Info.plist
│   ├── Config.xcconfig     # API key şablonu
│   └── Guroute.entitlements
└── README.md
```

## 🎨 Mimari

- **SwiftUI**: Declarative UI framework
- **MVVM**: Model-View-ViewModel pattern
- **Async/Await**: Modern Swift concurrency
- **Supabase**: Backend as a Service
- **Combine**: Reactive programming (state management)

## 📦 Bağımlılıklar

| Paket | Kullanım |
|-------|----------|
| Supabase Swift | Auth, Database, Storage |
| Alamofire | HTTP networking |
| Nuke | Image loading & caching |
| KeychainAccess | Secure storage |
| Lottie | Animasyonlar |

## 🔑 Supabase Kurulumu

1. [supabase.com](https://supabase.com) hesabı oluştur
2. Yeni proje oluştur
3. Settings > API'den URL ve anon key'i al
4. `Config.local.xcconfig`'e ekle

## 🔐 Apple Sign In Kurulumu

1. [Apple Developer](https://developer.apple.com) hesabına git
2. Certificates, Identifiers & Profiles > Identifiers
3. App ID'yi seç ve "Sign in with Apple" capability'yi aktifleştir
4. Xcode'da Signing & Capabilities'den "Sign in with Apple" ekle

## 📝 TODO

- [ ] Apple Sign In tam implementasyon
- [ ] Google Sign In
- [ ] Push Notifications
- [ ] In-App Purchase entegrasyonu
- [ ] Widget extension
- [ ] Apple Watch companion app
- [ ] Unit tests
- [ ] UI tests

## 🐛 Sorun Giderme

### "No such module 'Supabase'" hatası
Xcode'u kapat, `Package.resolved` ve `.build` klasörlerini sil, tekrar aç.

### Simulator'da konum çalışmıyor
Simulator > Features > Location > Custom Location ile test konumu ayarla.

### API key'ler çalışmıyor
`Config.local.xcconfig` dosyasının doğru yerde olduğundan emin ol.

---

## 📄 Lisans

Proprietary - Tüm hakları saklıdır.

---

Geliştirici: Haluk
Dönüştürüldü: Flutter → Swift/SwiftUI
Son güncelleme: Şubat 2026
