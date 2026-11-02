# Yöntem notları (Faz 2: M5–M7)

Bu notlar platformun hangi R çağrısını hangi ayarla yaptığını ve tablolarda neyin raporlandığını açıklar.
Bütün sayılar R motorunda hesaplanır ve biçimlenir; ön yüz yalnızca gösterir.

## AFA (M5)

- Çağrı: `psych::fa(x, nfactors, fm, rotate, cor = "cor" | "poly", correct = 0.5, n.rotations, scores = "none")`.
- psych 2.6.9'da `fa()` döndürmeyi varsayılan olarak 20 rastgele başlangıçla yapar (`n.rotations = 20`). Bu yüzden her
  çağrıdan önce `RNGkind("Mersenne-Twister", "Inversion", "Rejection")`, `set.seed(tohum)` ve `options(mc.cores = 1)`
  ayarlanır; tohum kayda ve R betiğine yazılır (SPEC_REVIEW EFA-2).
- Polikorik korelasyonla `fm = "ml"` önerilmez; uyarı verilir (EFA-1).
- Heywood uyarısı: ortak varyans ≥ ,995 (kalan varyans ≤ ,005; psych'in ML alt sınırı).
- Faktörleri yeniden adlandırma ve sıralama yalnızca görünümdür; R betiği ve rapor psych'in adlarını kullanır.

## DFA (M6)

- Çağrı: `lavaan::cfa(model, data, estimator, likelihood (yalnızca ML), std.lv, ordered (yalnızca WLSMV), ...)`.
- **Wishart olabilirliği** (`likelihood = "wishart"`) yalnızca ML ile seçilebilir; χ² N − 1 ile hesaplanır
  (AMOS/LISREL uyumlu). Normal olabilirlikle oran tam olarak N/(N − 1)'dir. §11.3'teki makale değerleri Wishart'tır.
- **Ölçeklenmiş ve dayanıklı indeksler.** MLR ve WLSMV'de iki ayrı sütun vardır:
  - ölçeklenmiş (`cfi.scaled`, `rmsea.scaled`…): ölçeklenmiş(-kaydırılmış) χ²'den; WLSMV'de Mplus'ın raporladığı değerler;
  - dayanıklı (`cfi.robust`…): MLR'de Brosseau-Liard ve Savalei, WLSMV'de Savalei (2021) düzeltmesi.
  İkisi aynı şeyi ölçmez; raporda hangisinin kullanıldığı yazılmalıdır. §11.3 karşılaştırması `cfi.scaled` iledir.
- **Bollen–Stine** yalnızca ML, sürekli kabul edilen ve eksiksiz veride kullanılabilir. `test = "bollen.stine"`,
  `bootstrap = B`, `iseed = tohum`, `parallel = "no"`. Raporlanan p, lavaan'ın `b / B_etkin` değeridir; b = 0 ise
  "p < 1/B_etkin" yazılır. Tutucu p = (b + 1)/(B_etkin + 1) (Davison ve Hinkley, 1997).
- **Model karşılaştırma.** İç içe çiftler `semTools::net` ile belirlenir (Bentler ve Satorra, 2010; kategorik veride
  Asparouhov ve Muthén, 2019). Fark testi `lavaan::lavTestLRT` ile: ML'de standart χ² farkı, MLR'de Satorra–Bentler
  (2001), WLSMV'de Satorra (2000). SB2001 negatif çıkarsa SB2010 ile yeniden hesaplanır. Ölçeklenmiş χ² değerleri
  hiçbir zaman elle çıkarılmaz. ΔCFI ve ΔRMSEA kısıtlı − daha az kısıtlı modeldir; MLR/WLSMV'de ölçeklenmiş indekslerle.
- Hu ve Bentler (1999) eşikleri ML ve sürekli veri için önerilmiştir; tablolarda iyi/kötü sınıflaması yapılmaz.

## Güvenirlik ve geçerlik (M7)

### ω: `compRelSEM(obs.var = TRUE)` ile `obs.var = FALSE` farkı

semTools ω'yı şöyle hesaplar:

  ω = w′ΛΦΛ′w / w′Σ̂w

Pay (gerçek puan varyansı) iki seçenekte de aynıdır ve modelden gelir. Fark paydadadır:

| Seçenek | Payda (Σ̂) | Anlamı |
|---|---|---|
| `obs.var = TRUE` (semTools ve platform varsayılanı) | gözlenen (doymuş model) kovaryans matrisi: 1′S1 | gözlenen toplam puan varyansının modelin açıkladığı payı; model uyumsuzluğu ω'ya yansır |
| `obs.var = FALSE` | modelin örtük kovaryans matrisi: 1′Σ(θ̂)1 | modele göre güvenirlik; hata kovaryansı yoksa McDonald'ın (1999) ω = (Σλ)²ψ / ((Σλ)²ψ + Σθ) formülüne, yani yapı güvenirliğine (CR) eşittir |

- Model veriye tam uyduğunda (S = Σ(θ̂)) ikisi aynıdır.
- Hata kovaryansı varsa `obs.var = FALSE` paydası 2θᵢⱼ terimlerini de içerir; skaler McDonald formülü bunu içermez.
- Örnek (HolzingerSwineford1939, üç faktör, ML): `visual` için ω (TRUE) = ,612; iki formül de testlerde lavaan
  kestirimlerinden elle yeniden hesaplanarak 1e-12 duyarlıkla doğrulanır (`engine/tests/testthat/test-reliability.R`).
- WLSMV'de `ord.scale = TRUE` kullanılır: ω, gözlenen sıralı toplam puanın güvenirliğidir (Green ve Yang, 2009).

### AVE ve HTMT

- AVE = Σλ²ψ / Σ diag(Σ̂) (`semTools::AVE`, aynı `obs.var` seçeneği); sıralı veride gizil yanıt (y*) ölçeğindedir.
- HTMT: `semTools::htmt(model, data, htmt2 = FALSE, absolute = TRUE, ordered = NULL)` platform varsayılanıdır
  (Henseler vd., 2015; aritmetik ortalama, Pearson). semTools'un kendi varsayılanı `htmt2 = TRUE` olduğu için ayar
  her çağrıda açıkça verilir. Ters maddeler temizlemede yeniden kodlanmamışsa `absolute = FALSE` ile sonuç tanımsız
  (NaN) olabilir; uyarı verilir.
- Eşikler (ayarlanabilir): ω ≥ ,70, AVE ≥ ,50 (Fornell ve Larcker, 1981); HTMT < ,85 (Henseler vd., 2015; Roemer vd., 2021).
