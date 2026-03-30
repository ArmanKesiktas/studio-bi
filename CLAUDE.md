# Studio BI — Proje Planı

Mobil-first AI analytics uygulaması. Kullanıcı CSV/XLSX yükler, Gemini 2.5 Flash analiz eder, otomatik dashboard ve AI sohbet üretir.

---

## Mimari

```
studioBI/
├── backend/     FastAPI (Python) — Render'da canlı
└── ios/         SwiftUI (iOS 17+) — Xcode projesi
```

---

## Backend

**URL:** `https://studio-bi-backend.onrender.com`
**Render Service ID:** `srv-d75cogtm5p6s73dvnaqg`
**GitHub:** `https://github.com/ArmanKesiktas/studio-bi`
**Platform:** Render Free Tier (Python 3.12)

### Stack
- FastAPI + uvicorn
- pandas (veri işleme), openpyxl (XLSX)
- google-genai SDK → Gemini 2.5 Flash
- Dosya cache: pickle (pyarrow Python 3.14'te build olmadığı için)
- Storage: local disk (`./storage/uploads/`, `./storage/parquet/`)

### Env Variables (Render'da tanımlı)
```
GEMINI_API_KEY=AIzaSyBqBfcThs_vSWaetV82geQVrdsvw4BVPxU
GEMINI_MODEL=gemini-2.5-flash
MAX_UPLOAD_SIZE_MB=50
STORAGE_PATH=./storage
```

### API Endpoints

| Method | Path | Açıklama |
|--------|------|----------|
| GET | /health | Servis sağlık kontrolü |
| POST | /upload | CSV/XLSX yükle → parse → profil → AI özet |
| GET | /datasets/{id} | Dataset metadata + kolon profilleri |
| GET | /datasets/{id}/table?page=1&page_size=50 | Sayfalı tablo verisi |
| GET | /datasets/{id}/dashboard | Kural tabanlı auto-dashboard (KPI + chart'lar) |
| POST | /datasets/{id}/chat | NL soru → pandas sorgu → Gemini narration |
| GET | /datasets/{id}/export/csv | Temizlenmiş CSV indir |

### Dosya Yapısı

```
backend/
├── main.py                  FastAPI app, CORS, router kayıtları
├── config.py                .env okuma (pydantic-settings)
├── requirements.txt
├── .env                     (gitignore'da, Render'da env var olarak tanımlı)
├── .env.example
├── .python-version          3.12.0 (Render için)
├── Dockerfile               (mevcut ama kullanılmıyor, Python runtime tercih edildi)
├── render.yaml              Render blueprint config
├── models/
│   ├── dataset.py           UploadResponse, DatasetResponse, TablePageResponse
│   ├── dashboard.py         DashboardResponse, KPICard, ChartConfig
│   └── chat.py              ChatRequest, ChatResponse
├── routers/
│   ├── upload.py            POST /upload
│   ├── datasets.py          GET /datasets/{id}, /table, /export/csv
│   ├── dashboard.py         GET /datasets/{id}/dashboard
│   └── chat.py              POST /datasets/{id}/chat
└── services/
    ├── file_parser.py       CSV/XLSX → DataFrame → pickle cache
    ├── profiler.py          Deterministik kolon tipi tespiti (DATE/METRIC/DIMENSION/IDENTIFIER/FREE_TEXT)
    ├── dashboard_gen.py     Kural tabanlı chart seçimi (line/bar/pie + KPI cards)
    └── gemini.py            Gemini API wrapper (summarize, explain_chart, parse_chat_intent, narrate_result)
```

### Kritik Tasarım Kararları

- **Ham veri Gemini'ye gönderilmez.** Sadece istatistiksel profil (özet) gönderilir.
- **Chat güvenli pipeline:** NL → Gemini (intent parse) → pandas (deterministik hesap) → Gemini (narration).
- **Dashboard tamamen deterministik:** Kural tabanlı (DATE+METRIC→line, DIMENSION+METRIC→bar, vb.)
- **Gemini sadece:** özet, açıklama, NL→intent parse, sonuç anlatımı için kullanılır.
- `pyarrow` Python 3.14'te build olmuyor → `pickle` kullanılıyor.

---

## iOS

**Proje:** `/Users/arman/Desktop/studioıBI/ios/StudioBI.xcodeproj`
**Xcode:** xcodegen ile generate edildi (`project.yml`)
**Target:** iOS 17.0+, SwiftUI

### Stack
- SwiftUI + Swift Charts (native chart rendering)
- URLSession (network)
- `@MainActor` + `ObservableObject` (state management)
- xcodegen (proje yönetimi)

### Dosya Yapısı

```
ios/StudioBI/
├── StudioBIApp.swift            @main entry
├── ContentView.swift            Tab bar + upload→dataset geçiş mantığı
├── Models/
│   ├── Dataset.swift            UploadResponse, DatasetResponse, ColumnProfileResponse, TablePageResponse, AnyCodable
│   ├── Dashboard.swift          DashboardResponse, KPICard, ChartConfig, ChartDataPoint
│   └── Chat.swift               ChatRequest, ChatResponse, ChatMessage
├── Network/
│   └── APIClient.swift          Tüm backend çağrıları (upload multipart, get, post, export)
├── ViewModels/
│   ├── UploadViewModel.swift
│   ├── DatasetViewModel.swift   Sayfalı tablo yönetimi
│   ├── DashboardViewModel.swift
│   └── ChatViewModel.swift      Mesaj geçmişi + önerilen sorular
└── Views/
    ├── Upload/
    │   ├── UploadView.swift      Dosya seçici, drop zone UI
    │   └── ExportView.swift      CSV export + iOS share sheet
    ├── Dataset/
    │   ├── DatasetSummaryView.swift  AI özet + kolon kartları (expand/collapse)
    │   └── TableView.swift           Yatay/dikey scroll tablo, sayfalama
    ├── Dashboard/
    │   ├── DashboardView.swift       KPI + chart listesi, pull-to-refresh
    │   ├── KPICardView.swift
    │   └── ChartCardView.swift       line/bar/pie — Swift Charts, expand toggle
    ├── Chat/
    │   └── ChatView.swift            Bubble UI, önerilen sorular, thinking indicator
    └── Components/
        └── LoadingView.swift         LoadingView, ErrorView, StatBadge
```

### Uygulama Akışı

```
ContentView
├── activeDatasetId == nil  → UploadView (dosya seç → API'ye yükle)
└── activeDatasetId != nil  → TabView (5 sekme)
    ├── Özet      → DatasetDetailView → DatasetSummaryView
    ├── Tablo     → TableView
    ├── Dashboard → DashboardView
    ├── Sohbet    → ChatView
    └── Aktar     → ExportView
```

### Backend URL
`APIClient.swift` içinde hardcoded:
```swift
private let baseURL = "https://studio-bi-backend.onrender.com"
```

---

## Deploy

### Render CLI Komutları

```bash
# Login
render login

# Workspace set
render workspace set tea-d56pduemcj7s738286b0

# Deploy tetikle
render deploys create srv-d75cogtm5p6s73dvnaqg --confirm

# Deploy durumu
render deploys list srv-d75cogtm5p6s73dvnaqg --output json

# Loglar
render logs --resources srv-d75cogtm5p6s73dvnaqg --output text --limit 50

# Env var güncelle (Render API ile — CLI update env desteklemiyor)
curl -X PUT "https://api.render.com/v1/services/srv-d75cogtm5p6s73dvnaqg/env-vars" \
  -H "Authorization: Bearer rnd_ggp73emWQ6PRBoAoRfYBZkevZioh" \
  -H "Content-Type: application/json" \
  -d '[{"key": "KEY", "value": "VALUE"}, ...]'
```

### Git → GitHub → Render (CI/CD)

```bash
cd /Users/arman/Desktop/studioıBI
git add -A
git commit -m "commit mesajı"
git push  # → GitHub → Render otomatik deploy başlar
```

---

## Bilinen Sorunlar & Çözümler

| Sorun | Çözüm |
|-------|-------|
| pyarrow Python 3.14'te build olmaz | pickle kullanılıyor |
| pandas 2.2.2 strict pin build yavaşlatıyor | `pandas>=2.2.0` ile bırakıldı |
| `infer_datetime_format` pandas 2.x'te kaldırıldı | `format="mixed"` kullanılıyor |
| google-generativeai deprecated | google-genai SDK'ya geçildi |
| gemini-2.0-flash yeni kullanıcılara kapalı | gemini-2.5-flash kullanılıyor |
| Render env var CLI update ile değiştirilemiyor | Render REST API ile değiştiriliyor |

---

## Sonraki Adımlar (MVP Sonrası)

- [ ] Kullanıcı kimlik doğrulama (auth) — şu an yok
- [ ] Dataset kalıcı depolama (Supabase/PostgreSQL) — şu an local disk, restart'ta silinir
- [ ] UptimeRobot ile Render'ı uyanık tut (5dk ping → /health)
- [ ] iOS gerçek cihaz testi
- [ ] Veri temizleme UI (null doldur, duplicate sil, kolon yeniden adlandır)
- [ ] Dashboard PDF export
- [ ] JSON dosya desteği
- [ ] AI insight özet (3 madde "dikkat et" kartı)
