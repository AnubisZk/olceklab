# Doğrulama kayıtları (SPEC §11.6)

Her referans karşılaştırmasının sonucu, tarihi ve ortamı burada tutulur.

## SPEC §11 referans karşılaştırmaları

| Tarih | Faz | Kontrol | Sonuç | Ortam |
|---|---|---|---|---|
| — | 1 | §11.2 HolzingerSwineford1939, bfi | henüz yok | — |
| — | 1–3 | §11.3 BİDEKÇET (yalnızca yerelde) | henüz yok | — |
| — | 4 | §11.4 referans simülasyon | henüz yok (paket bekleniyor) | — |

## Şartname incelemesi doğrulamaları (2 Kasım 2026)

`SPEC_REVIEW.md` bulgularının kanıtları `review/verify/` altındadır.

Ortam: R 4.4.3, lavaan 0.7-2, psych 2.6.9, semTools 0.5-10, GPArotation 2026.8-2, mirai 2.7.2.

| Betik | Özet sonuç |
|---|---|
| V01 | HS1939 χ² = 85.306 (sd 24). Bollen–Stine p, `lavInspect(fit, "test")` içinde. WLSMV ve eksik veride Bollen–Stine hata veriyor. |
| V02 | bfi: cfi.scaled = .923, cfi.robust = .867. WLSMV'de AIC/BIC = NA. Varsayılan fark testleri: satorra.2000 (WLSMV), satorra.bentler.2001 (MLR). |
| V03 | 6 kategoride eşik modeli sd 68 → 98 (test edilebilir). 3 kategoride configural ile birebir aynı. |
| V04 | `fa.parallel` aynı tohumla farklı özdeğerler veriyor (mc.cores > 1). mc.cores = 1 ile aynı. |
| V05 | WLSMV theta ham yükü ile ölçek uyuşmazlığı +%46,5. R > 10.000'de tohum çakışması. |
| V06 | §11.3 tablosu iç tutarlılık denetimi geçti. |
| V07 | Şartname vurguları beyaz zeminde 1,54:1 ve 1,79:1. |
| V08 | Tekrar başına tohum, mirai işçi sayısından bağımsız. |
| V09 | psych `fa()` döndürmesi tohuma bağlı (n.rotations = 20). |
