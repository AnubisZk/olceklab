# Faz 1 sorularına yanıtlar (Zafer → Codex)

Ekteki `bidekcet_referans.R` betiği, §11.3'teki bütün referans değerleri ham Excel dosyalarından baştan üretir. Betiğin tam çıktısı `cikti.txt` dosyasındadır. Bu betik 3 Kasım 2026'da çalıştırılmış ve aşağıdaki değerlerin hepsini vermiştir. Ham veri KVKK nedeniyle paylaşılmıyor; `tests/private/` testlerini ben kendi makinemde çalıştıracağım (madde 4).

## 1. WLSMV CFI: `cfi.scaled`

.908 (ortaokul) ve .931 (lise) değerleri `fitMeasures(fit, "cfi.scaled")` çıktısıdır. Aynı modeller için diğer değerler:

| Kademe | cfi.scaled | cfi.robust | rmsea.scaled | rmsea.robust |
|---|---|---|---|---|
| Ortaokul | 0.908 | 0.829 | 0.096 | 0.113 |
| Lise | 0.931 | 0.875 | 0.094 | 0.106 |

Model ayarı: `cfa(m4, x, ordered = <12 madde>, estimator = "WLSMV", std.lv = TRUE)`; her kademe ayrı. Testte `cfi.scaled` kullan. Arayüzde ise `.scaled` ve `.robust` değerlerinin ikisini de göster ve hangisinin hangisi olduğunu açıkça etiketle.

## 2. HTMT: Pearson, `absolute = TRUE`, `htmt2 = FALSE`

- Çağrı: `semTools::htmt(m4, data = <kademe verisi, 12 madde>, htmt2 = FALSE)`. `ordered` verilmez, bu yüzden Pearson korelasyonları kullanılır. `absolute` varsayılanı `TRUE`'dur. semTools 0.5-9'daki argümanlar şunlardır: `model, data, sample.cov, missing, ordered, absolute, htmt2`.
- .773 (ortaokul, BK–FM) değeri `absolute = TRUE` ve `FALSE` ile aynı çıkar, çünkü bu çiftte negatif korelasyon yoktur. Ayarı ayırt eden test çifti ortaokul BK–CT'dir: `absolute = TRUE` → **0.451**, `absolute = FALSE` → 0.412. Makalede `absolute = TRUE` raporlanıyor. Lütfen §11.3'e bu satırı da ekle.
- Platformda varsayılan `absolute = TRUE`, `htmt2 = FALSE` olsun; ikisi de arayüzde seçilebilir kalsın.

## 3. Temizleme sırası ve oturum bilgisi

Kurallar bu sırayla uygulanır. Her adımdan sonraki satır sayıları:

| Adım | Kural | Ortaokul | Lise |
|---|---|---|---|
| 0 | Ham dosya satır sayısı | 255 | 279 |
| 1 | Grup/sınıf filtresi: ortaokulda `sınıf` boş olan satırlar (2 satır tamamen boş), lisede `Sinif` ∉ {9, 10, 11, 12} (2 satır: 4 ve 7 girilmiş) | 253 | 277 |
| 2 | 12 maddeden (M7 hariç) en az biri eksik | 253 | 272 |
| 3 | Aralık dışı değer (1–5 dışı) | 253 | 272 |
| 4 | Düz yanıt: 12 maddenin hepsi aynı değer (M7 bu denetime dâhil değil) | **250** | **256** |

Notlar:
- Ortaokul dosyasında sütunlar `cinsiyet, sınıf, M1–M13`; lise dosyasında `Cinsiyet, Sinif, Madde1–Madde13` (adlarda boşluk olabilir, `trimws` uygulanmalı).
- Türkçe karakterli sütun adı (`sınıf`) bazı yerel ayarlarda sorun çıkarabildiği için betikte `names(o)[grepl("^s.n.f$", names(o))] <- "sinif"` kullanıldı.
- Kademe birleştirme ve grup etiketi: `grup ∈ {"Ortaokul", "Lise"}`, faktör düzeyi bu sırayla (referans grup: Ortaokul).

**Özgün analiz ortamları:**
- Makaledeki ilk analizler Python ile yapıldı: Python 3.13.17, numpy 2.5.3, scipy 1.18.1, pandas 3.0.5, factor_analyzer 0.5.1, semopy 2.3.11, openpyxl 3.1.5.
- Simülasyon ve R doğrulamaları önce R 4.4.3 ile yapıldı (lavaan 0.7-2, semTools 0.5-9, psych 2.6.9, MASS 7.3-66, GPArotation 2026.8-2).
- Ekteki referans betiği 3 Kasım'da **R 4.5.3** ile yeniden çalıştırıldı ve aynı değerleri verdi (lavaan 0.7-2, semTools 0.5-9, psych 2.6.9, readxl 1.6.0). Yani §11.3 değerleri R 4.4.3 ve 4.5.3'te aynı.
- Tam `sessionInfo()` çıktısı `cikti.txt` dosyasının sonundadır.

## 4. §11.3 testleri

Ham veriyle referans betiğini çalıştırdım. Sonuçlar §11.3 tablosuyla birebir aynı:

| Analiz | Beklenen | Elde edilen |
|---|---|---|
| Temizleme | 250 / 256 | 250 / 256 |
| Alfa | .794 / .836 | 0.794 / 0.836 |
| KMO | .805 / .821 | 0.805 / 0.821 |
| Paralel analiz (pc, 1000) | 2 / 2 | 2 / 2 |
| Model 4 χ² (wishart) | 147.844 / 133.325 | 147.844 / 133.325 |
| Model 1 χ² | 179.058 / 178.149 | 179.058 / 178.149 |
| Δχ² M1–M4 | 31.21 / 44.82 | 31.21 / 44.82 |
| Değişmezlik χ² | 281.168 / 299.621 / 319.77 | 281.1685 / 299.6211 / 319.7724 |
| Kısmi metrik | Δχ²(7) = 3.64, p = .821 | 3.64, 7, 0.821 |
| Kısmi skaler | Δχ²(7) = 11.80, p = .107 | 11.8, 7, 0.107 |
| HTMT BK–FM | .773 | 0.773 |
| WLSMV CFI | .908 / .931 | 0.908 / 0.931 |

§11.3'e eklenmesini istediğim iki satır:
- **Çok gruplu SRMR** (makalede raporlanan): `srmr_bentler_nomean` → biçimsel 0.0626, metrik 0.0710, skaler 0.0713. lavaan varsayılanı `srmr` ise 0.0583 / 0.0661 / 0.0683 verir. Platform çok gruplu modellerde ikisini de göstermeli; varsayılan rapor değeri `srmr_bentler_nomean` olsun.
- **HTMT BK–CT (ortaokul):** `absolute = TRUE` → 0.451.

Senin depondaki `tests/private/` testlerini ayrıca kendi makinemde çalıştırıp sonucu ileteceğim. Testlerin, veri dosyasının yolunu bir ortam değişkeninden (ör. `BIDEKCET_DATA_DIR`) okuyacak biçimde yazıldığından emin ol.

## Faz 2 onayı

Bu yanıtlarla Faz 2'ye (AFA, DFA, güvenirlik) geçebilirsin. Faz 2'de dikkat:
- DFA'da `likelihood = "wishart"` seçeneği arayüzde açıkça sunulsun (makale değerleri bununla birebir).
- Güvenirlikte omega için `compRelSEM(..., obs.var = FALSE)` ve `TRUE` farkı belgelensin.
- HTMT ayarları yukarıdaki gibi olsun.
- Docker, CI ve Playwright bu ortamda çalışmadıysa Faz 2 sonunda bunların gerçek bir ortamda (GitHub Actions) çalıştığını göster.
