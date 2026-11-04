# ÖlçekLab

Ölçek geliştirme ve uyarlama çalışmaları için tekrarlanabilir psikometrik analiz platformu. Bütün istatistiksel hesaplar R motorunda yapılır.

- Teknik şartname: [`SPEC.md`](SPEC.md) (v1.2)
- Şartname incelemesi ve v1.1 önerileri: [`SPEC_REVIEW.md`](SPEC_REVIEW.md)
- Kodlama kuralları: [`AGENTS.md`](AGENTS.md)
- Sürümler: [`docs/VERSIONS.md`](docs/VERSIONS.md)

**Durum:** Faz 1–5 ve Faz 7a canlı yayını tamamlandı. Veri yükleme ve temizleme (M1), madde analizi (M2), uygunluk (M3), faktör sayısı ve paralel analiz (M4), açımlayıcı faktör analizi (M5), doğrulayıcı faktör analizi ve model karşılaştırma (M6), güvenirlik ve geçerlik (M7), ölçme değişmezliği, kısmi değişmezlik sihirbazı ve gizil ortalamalar (M8), Monte Carlo simülasyonu (M9), APA 7 Word raporu, CSV ve grafik (SVG/PNG) dışa aktarma (M10), proje dosyası dışa/içe aktarma ve 17 basamaklı yeniden üretim (M12) kullanılabilir. M11 yorum asistanı canlı sitede EVREN ile çalışır.

Simülasyon iş dosyaları `JOBS_DIR` altında tutulur (yalnızca sentetik veriden türetilmiş parçalar ve özetler). Çevrim içi kurulumda `ONLINE_LIMITS=true` ile tekrar × koşul, işçi ve süre sınırları açılır (`.env.example`).

[Canlı ÖlçekLab](https://olceklab.netlify.app) · [Yapay zekâ yorum asistanı ve doğrulaması](docs/PHASE6_TR.md)

Kullanım kılavuzu: [`docs/USER_GUIDE_TR.md`](docs/USER_GUIDE_TR.md). Doğrulama kayıtları: [`docs/VALIDATION.md`](docs/VALIDATION.md). Yöntem notları: [`docs/METHODS_TR.md`](docs/METHODS_TR.md). Devir notu: [`docs/HANDOFF_CODEX.md`](docs/HANDOFF_CODEX.md).

## Yerel (çevrimdışı) çalıştırma

```
cp .env.example .env
docker compose up --build
```

| Servis | Adres |
|---|---|
| Web arayüzü | http://localhost:5173 |
| R motoru | http://localhost:8000/health · /versions |
| Yapay zekâ ağ geçidi | http://localhost:8787/health |

## Testler

```
# R motoru (UTF-8 yerel ayarı zorunlu)
cd engine && LANG=C.UTF-8 Rscript tests/testthat.R

# Ön yüz
cd web && npm ci && npm run typecheck && npm test

# Yapay zekâ ağ geçidi
cd ai-gateway && npm ci && npm run typecheck && npm test

# Uçtan uca (servisler çalışırken)
cd web && npx playwright install chromium && npx playwright test
```

BİDEKÇET regresyon testleri (SPEC §11.3) yalnızca belge sahibinin makinesinde çalışır: `cd engine && BIDEKCET_DATA_DIR=/veri LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R`. Ayrıntı: `docs/VALIDATION.md`.

## Klasörler

```
engine/       R analiz motoru (plumber)
web/          ön yüz (Vite + React + TypeScript)
ai-gateway/   yapay zekâ ağ geçidi (Fastify)
review/       şartname incelemesinin doğrulama betikleri
docs/         sürümler, doğrulama kayıtları, kılavuz
```
