# review/ — Şartname incelemesinin kanıtları

`SPEC_REVIEW.md` içindeki her bulgu, buradaki betiklerden birine dayanır. Betikler herkese açık verilerle çalışır (`lavaan::HolzingerSwineford1939`, `psych::bfi`) ve bağımsızdır.

| Betik | Konu | Bulgular |
|---|---|---|
| `verify/V01_bollen_stine.R` | Bollen–Stine: p değerinin konumu, tohum, WLSMV/eksik veri/MLR | BS-1, BS-2, BS-3, W-5 |
| `verify/V02_wlsmv_fit_lrt.R` | `.scaled` / `.robust`, AIC/BIC, ölçeklenmiş fark testleri | W-1…W-5 |
| `verify/V03_invariance_wu_estabrook.R` | Wu–Estabrook sırası, 3 kategori eşdeğerliği, skor testi, gizil d | I-1…I-5 |
| `verify/V04_parallel_analysis.R` | `fa.parallel` tekrarlanabilirliği ve algoritması | PA-1…PA-5 |
| `verify/V05_monte_carlo_bias.R` | Ölçek, sözde-gerçek değer, sıfıra yakın yanlılık, tohum şeması, MCSE | MC-1…MC-8 |
| `verify/V06_reliability_htmt_and_table113.R` | HTMT/omega seçenekleri, §11.3 iç tutarlılık | REL-1, §1.1 |
| `verify/V07_theme_contrast.R` | ARES-1 WCAG kontrastı | ARCH-4 |
| `verify/V08_mirai_seed_independence.R` | mirai işçi sayısı ve tohum | MC-5 |
| `verify/V09_efa_random_starts.R` | AFA döndürmesinde rastgele başlangıç | EFA-2 |

Çalıştırma (depo kökünden):

```
Rscript review/verify/V01_bollen_stine.R
```

`verify/out/` altındaki çıktılar 2 Kasım 2026'da şu ortamda üretildi: R 4.4.3, lavaan 0.7-2, psych 2.6.9, semTools 0.5-10, GPArotation 2026.8-2, mirai 2.7.2, nanonext 1.10.4 (Linux, 2 çekirdek).
