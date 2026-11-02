# Doğrulama kayıtları (SPEC §11.6)

Her referans karşılaştırmasının sonucu, tarihi ve ortamı burada tutulur.

**Ortam:** R 4.4.3, lavaan 0.7-2, psych 2.6.9, semTools 0.5-10, GPArotation 2026.8-2, mirai 2.7.2, OpenBLAS 0.3.34, Linux (2 çekirdek).

## SPEC §11 referans karşılaştırmaları

| Tarih | Faz | Kontrol | Sonuç | Kanıt |
|---|---|---|---|---|
| 2026-11-03 | 1 | §11.1 `parallel_manual` ↔ `psych::fa.parallel`, aynı tohum: pc/fa/both × simüle/yeniden örnekleme (Pearson) ve polikorik/yeniden örnekleme | **Özdeğer matrisi bit bit aynı** | `test-factor-number.R` |
| 2026-11-03 | 1 | §11.2 HolzingerSwineford1939: önerilen bileşen sayısı ve gözlenen özdeğerler (n.iter = 1000) | psych ile aynı | `test-factor-number.R` |
| 2026-11-03 | 1 | §11.2 bfi: önerilen sayı (pc, fa, both; simüle ve yeniden örnekleme) | psych ile aynı | `test-factor-number.R` |
| 2026-11-03 | 1 | §11.2 bfi: alfa, r.drop, alpha.drop, alt boyut alfaları, betimseller | psych ile birebir aynı | `test-item-analysis.R` |
| 2026-11-03 | 1 | §11.2 KMO, MSA, Bartlett, Mardia (Pearson, HS1939; polikorik, bfi) | psych ile birebir aynı | `test-suitability.R` |
| 2026-11-03 | 1 | PA-1: genel `mc.cores = 2` iken aynı tohum → aynı özdeğerler | Geçti | `test-factor-number.R` |
| 2026-11-03 | 1 | M12: üretilen R betiği ayrı süreçte çalışıp aynı sayıları veriyor (M2, M3, M4) | Geçti | `test-script-export.R` |
| 2026-11-03 | 1 | Tarayıcıda görünen metinler ↔ bağımsız R hesabı (bfi, 9 denetim) | 9/9 aynı | `test-logs/faz1/browser_crosscheck_output.txt` |
| ⏳ | 1 | §11.3 BİDEKÇET: temizleme sayıları, alfa, KMO, paralel analiz | **Koşulmadı: veri bu ortamda yok** | `test-private-bidekcet.R` (atlandı) |
| — | 2–3 | §11.3 DFA ve değişmezlik satırları | henüz yok | — |
| — | 4 | §11.4 referans simülasyon | henüz yok (paket bekleniyor) | — |

### §11.3 testlerini yerelde çalıştırma

1. Veri dosyalarını `engine/tests/private/data/` altına koyun. Bu klasör `.gitignore` ile dışlanmıştır.
2. `engine/tests/private/bidekcet.example.json` dosyasını `bidekcet.json` adıyla kopyalayın ve sütun adlarını dosyanıza göre düzenleyin.
3. `engine/` içinde `LANG=C.UTF-8 Rscript tests/testthat.R` komutunu çalıştırın. Sonucu bu tabloya işleyin.

## Şartname incelemesi doğrulamaları (2 Kasım 2026)

`SPEC_REVIEW.md` bulgularının kanıtları `review/verify/` altındadır.

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
