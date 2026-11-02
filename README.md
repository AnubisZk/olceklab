# ÖlçekLab

Ölçek geliştirme ve uyarlama çalışmaları için tekrarlanabilir psikometrik analiz platformu. Bütün istatistiksel hesaplar R motorunda yapılır.

- Teknik şartname: [`SPEC.md`](SPEC.md) (v1.2)
- Şartname incelemesi ve v1.1 önerileri: [`SPEC_REVIEW.md`](SPEC_REVIEW.md)
- Kodlama kuralları: [`AGENTS.md`](AGENTS.md)
- Sürümler: [`docs/VERSIONS.md`](docs/VERSIONS.md)

**Durum:** Faz 1 tamamlandı: veri yükleme ve temizleme (M1), madde analizi (M2), uygunluk (M3), faktör sayısı ve paralel analiz (M4). Diğer analiz uç noktaları ait oldukları faza kadar `501` döndürür.

Doğrulama kayıtları: [`docs/VALIDATION.md`](docs/VALIDATION.md).

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

BİDEKÇET regresyon testleri (SPEC §11.3) yalnızca yerelde çalışır; adımlar `docs/VALIDATION.md` dosyasındadır.

## Klasörler

```
engine/       R analiz motoru (plumber)
web/          ön yüz (Vite + React + TypeScript)
ai-gateway/   yapay zekâ ağ geçidi (Fastify)
review/       şartname incelemesinin doğrulama betikleri
docs/         sürümler, doğrulama kayıtları, kılavuz
```
