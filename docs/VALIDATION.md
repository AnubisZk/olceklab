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
| 2026-11-03 | 3 | §11.3 düzeneği (değişmezlik) ↔ referans betiğin `cf`, `me`, `sc`, `mk`, `sk` modelleri ve `anova` sonuçları, sentetik BİDEKÇET verisi (birleşik dosya platformun yükleme yolundan geçer) | χ², sd, iki SRMR, kısmi metrik ve kısmi skaler Δχ² aynı (1e-10) | `test-bidekcet-harness.R` |
| ⏳ | 3 | §11.3 değişmezlik ve kısmi değişmezlik gerçek verisi (18 ölçüt) | **Belge sahibinin makinesinde koşulacak** | `test-private-bidekcet.R` (burada atlandı) |
| 2026-11-03 | 3 | M8 sürekli: her adım ve ardışık lavTestLRT (ML, MLR SB2001), group.partial, ΔSRMR (Bentler ortalamasız) | `lavaan::cfa` ile birebir | `test-invariance.R` |
| 2026-11-03 | 3 | M8 kategorik: measEq.syntax (theta, Wu–Estabrook) adımları, Satorra (2000); üç kategoride eşik adımının atlanması; ikili maddelerin reddi | Birebir | `test-invariance.R` |
| 2026-11-03 | 3 | Gizil ortalamalar: κ skaler modelle aynı; d (Hancock birleşik SS) elle hesapla aynı; gizil ortalama modeli skalerle eşdeğer (χ² farkı ≤ 1e-6 denetimi motorda) | Geçti | `test-invariance.R` |
| 2026-11-03 | 3 | Skor testleri: lavTestScore ile aynı χ²; parTable ile okunur parametre adları | Birebir | `test-invariance.R` |
| 2026-11-03 | 3 | Tarayıcı (HS1939, okul): tam ve kısmi zincir, gizil ortalamalar, skor testi ↔ bağımsız R | 38/38 aynı | `test-logs/faz3/browser_crosscheck_output.txt` |
| 2026-11-03 | 4 | M9 kabul (SPEC §7 M9, MC-8): kontrol senaryosu, sürekli-normal veri, ML, N = 600, 1000 tekrar (2 mirai işçisi): Δχ² I. tip hata metrik ,051 (MCSE ,0070), skaler ,040 (MCSE ,0062) | ,03–,07 aralığında | `test-simulation-acceptance.R` (`test-logs/faz4/engine-testthat.txt`) |
| 2026-11-03 | 4 | Aynı tohum ve sürümle iki çalıştırma; kesilip sürdürülen iş ↔ kesintisiz iş; paralel parça ↔ sıralı parça | Tekrar kayıtları birebir aynı (`identical`) | `test-simulation.R`, `test-simulation-acceptance.R` |
| 2026-11-03 | 4 | Ortak rastgele sayılar: aynı tekrar bütün kestiricilerde aynı veriyle | Geçti | `test-simulation.R` |
| 2026-11-03 | 4 | Gerçek değerler: sürekli veride üretim parametresi; sıralı veride kesin popülasyon momentleri (pbivnorm) ↔ mvtnorm ve büyük örneklem | Geçti | `test-simulation.R` |
| 2026-11-03 | 4 | Bağımsız R paketi ayrı süreçte (Rscript) aynı tekrarları ve aynı özeti üretir | Birebir aynı | `test-simulation.R` |
| 2026-11-03 | 4 | HTTP iş sistemi (2 işçi): başlat → iptal → sürdür → sonuçlar (yerel eşzamanlı çalıştırmayla aynı) → paket (zip) | Geçti | `test-api-simulation.R` |
| 2026-11-03 | 4 | Tarayıcı (Firefox): popülasyon JSON'u → süre tahmini → iş → iptal → sürdür → sonuçlar ↔ belgelenen algoritmanın **bağımsız yeniden yazımı** (MASS + lavaan, motor kodu kullanılmadan; tohum kuralı, uygun çözüm oranı, yük ortalaması/yanlılık/kapsama, Δχ² reddetme oranı, ölçü türü, α/ω gerçek ve ortalama) | 127/127 aynı | `test-logs/faz4/browser_crosscheck_output.txt` |
| — | 4 | §11.4 referans simülasyon | henüz yok (REP-4: paket bekleniyor) | — |
| 2026-11-03 | 5 | M10 Word raporu: officer ile yeniden okunur; **her tablo hücresi kayıttaki R-biçimli metnin aynısıdır** (başlıklar dâhil); tablo numaraları ardışık; TR/EN | Geçti | `test-report.R` |
| 2026-11-03 | 5 | M10 "Word raporu açılır": LibreOffice ile PDF'e dönüştürülür | Geçti | `test-report.R` |
| 2026-11-03 | 5 | M10 şablon metinler: Yöntem/Bulgular cümlelerindeki her sayı analiz kaydında var (uydurma sayı yok); yapay zekâ kullanılmaz | Geçti | `test-report.R` |
| 2026-11-03 | 5 | M10 CSV: biçimli (TR `;`, BOM) = ekrandaki metin; ham (17 anlamlı basamak) kayıpsız | Geçti | `test-report.R`, `test-project.R` |
| 2026-11-03 | 5 | M12 proje dosyası (2 işçi, HTTP): dışa aktarma → içe aktarma → yeniden üretim; M1–M8'in yedi modülü 17 basamakta **aynı**; veri yalnızca açık onayla eklenir (baytlar özgün dosyanın aynısı); farklı dosya `hash_mismatch`; sürüm farkı uyarılır; 1e−12'lik yapay değişiklik yakalanır | Geçti | `test-project.R` |
| 2026-11-03 | 5 | M12 betikler: dışa aktarılan R betikleri ayrı süreçte aynı sayıları verir (M2–M8) | Geçti | `test-script-export.R` |
| 2026-11-03 | 5 | Tarayıcı (Firefox): HS1939 → DFA/güvenirlik/değişmezlik → rapor önizlemesi → indirilen .docx (python-docx) → CSV → proje dışa/içe aktarma → yeniden üretim; yüklenen CSV ile onaylı veri ekleme ↔ bağımsız R (lavaan, psych, semTools doğrudan) | 39/39 aynı | `test-logs/faz5/browser_crosscheck_output.txt` |
| 2026-11-03 | 1–5 | Playwright uçtan uca testleri (Chromium): Faz 1–5 akışları gerçek motor ve Vite sunucusuyla | 5/5 geçti | `test-logs/faz5/e2e-playwright.txt` |

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
