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
| 2026-11-03 | 1–2 | §11.3 düzeneği ↔ belge sahibinin referans betiği, **sentetik** BİDEKÇET düzenindeki iki Excel dosyasında: temizleme adımları, veri, alfa, KMO, paralel analiz, DFA χ², Δχ², HTMT (absolute = TRUE/FALSE), WLSMV indeksleri | **Birebir aynı** | `test-bidekcet-harness.R` |
| ⏳ | 1–2 | §11.3 BİDEKÇET gerçek verisi (40 ölçüt: temizleme, alfa, KMO, PA, DFA, Δχ², HTMT, WLSMV) | **Belge sahibinin makinesinde koşulacak** (`BIDEKCET_DATA_DIR=… Rscript tests/private/run_bidekcet.R`) | `test-private-bidekcet.R` (burada atlandı) |
| 2026-11-03 | 2 | §11.2 HS1939 üç faktör (ML): lavaan belgesindeki χ² 85.306 (24), CFI .931, TLI .896, RMSEA .092 [.071, .114], SRMR .065 | Raporlanan basamakta aynı; bütün ölçütler `lavaan::cfa` ile birebir | `test-cfa.R` |
| 2026-11-03 | 2 | M5: psych::fa (minres/ml/pa/uls × oblimin/promax/geominQ/varimax/none; Pearson ve polikorik), aynı tohum | Yükler, h², Phi, açıklanan varyans ve uyum birebir | `test-efa.R` |
| 2026-11-03 | 2 | M6: Wishart (χ² oranı N/(N − 1)), MLR ve WLSMV ölçeklenmiş/dayanıklı indeksler, Bollen–Stine (p, B_etkin, b; aynı iseed), MI | `lavaan` ile birebir | `test-cfa.R` |
| 2026-11-03 | 2 | M6 karşılaştırma: lavTestLRT (standard, satorra.bentler.2001, satorra.2000), semTools::net iç içelik matrisi | Birebir. SB2001 < 0 → SB2010 dalı sahte bir ilk sonuçla sınandı (gerçek veride örnek bulunamadı) | `test-cfa-compare.R` |
| 2026-11-03 | 2 | M7: α, compRelSEM (obs.var TRUE/FALSE, ord.scale), AVE, HTMT (htmt2 × absolute; polikorik) | semTools ile birebir; ω ve AVE ayrıca formülle elle yeniden hesaplandı (1e-12) | `test-reliability.R` |
| 2026-11-03 | 2 | M12: M5–M7 betikleri ayrı süreçte aynı sayıları verir (Bollen–Stine p dâhil) | Geçti | `test-script-export.R` |
| 2026-11-03 | 2 | Tarayıcıda görünen metinler ↔ bağımsız R hesabı (HS1939; AFA, DFA, Bollen–Stine, karşılaştırma, güvenirlik) | 38/38 aynı | `test-logs/faz2/browser_crosscheck_output.txt` |
| 2026-11-03 | 2 | V10: semTools 0.5-9 ↔ 0.5-10 (htmt, compRelSEM, AVE, measEq.syntax) | 21/21 birebir aynı | `review/verify/out/V10_semtools_059_vs_0510.txt` |
| — | 3 | §11.3 değişmezlik satırları | henüz yok | — |
| — | 4 | §11.4 referans simülasyon | henüz yok (paket bekleniyor) | — |

### §11.3 testlerini yerelde çalıştırma

```
cd engine
BIDEKCET_DATA_DIR=/iki/excel/dosyasinin/klasoru LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R
```

Dosyalar başlıklarına bakılarak bulunur (ortaokul: `sınıf`, `M1–M13`; lise: `Sinif`, `Madde1–Madde13`); dosya adları depoda yazılı değildir. Çıktı tablosu `tests/private/bidekcet_sonuc.csv` dosyasına da yazılır (yalnızca toplu değerler). Sonucu bu tabloya işleyin.

Belge sahibinin 3 Kasım 2026 tarihli referans çıktısı: `docs/validation/bidekcet_referans_cikti_2026-11-03.txt` (R 4.5.3, lavaan 0.7-2, psych 2.6.9, semTools 0.5-9).

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
| V10 | semTools 0.5-9 ile 0.5-10 arasında htmt, compRelSEM, AVE ve measEq.syntax çıktıları birebir aynı (21/21). |
