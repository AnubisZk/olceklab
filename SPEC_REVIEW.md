# ÖlçekLab — Şartname İncelemesi (SPEC v1.0 → v1.1 önerisi)

- **İncelenen belge:** `SPEC.md` v1.0 (2 Kasım 2026)
- **İnceleme tarihi:** 2 Kasım 2026
- **Durum:** Onay bekliyor. Onaylanan maddeler `SPEC.md` v1.1'e işlenecek; onaylanmayanlar v1.0'daki hâliyle kalacak.

## 0. Bu inceleme nasıl yapıldı

Her iddia mümkün olduğunda **çalıştırılarak** sınandı. Doğrulama ortamı, şartnamenin §11.3'teki doğrulama ortamıyla aynıdır:

| Bileşen | Sürüm | Not |
|---|---|---|
| R | 4.4.3 | conda-forge |
| lavaan | 0.7-2 | CRAN yayını 2026-07-16 (en yeni: 0.7-3, 2026-10-08) |
| psych | 2.6.9 | CRAN yayını 2026-09-30 |
| semTools | 0.5-10 | lavaan ≥ 0.7-2 gerektirir |
| GPArotation | 2026.8-2 | |
| mirai / nanonext | 2.7.2 / 1.10.4 | |

lavaan, psych, semTools ve GPArotation kaynakları CRAN'ın GitHub aynasından tam sürüm etiketiyle alındı. Kullanılan veriler herkese açıktır: `lavaan::HolzingerSwineford1939` ve `psych::bfi`. BİDEKÇET verisi bende yoktur; o tabloyu yalnızca belgedeki sayılarla iç tutarlılık açısından sınadım.

Her bulgunun yanında kanıt betiği gösterilir (`review/verify/V0x_*.R`). Çıktılar `review/verify/out/` altındadır. Bütün betikler tek komutla yeniden çalıştırılabilir:

```
Rscript review/verify/V01_bollen_stine.R
```

**Önem düzeyleri:**
- **Kritik:** düzeltilmezse yanlış ya da tekrarlanamayan sayı üretir.
- **Yüksek:** yanlış yoruma ya da kabul ölçütünün geçmemesine yol açar.
- **Orta:** belirsizliktir; iki geliştirici farklı şey yapar.
- **Düşük:** iyileştirmedir.

---

## 1. Özet

### 1.1 Şartnamede doğru olduğu doğrulanan noktalar (değişiklik gerekmez)

- lavaan 0.7-2 ve psych 2.6.9 gerçek CRAN sürümleridir. HolzingerSwineford1939 üç faktörlü modelinde χ² = 85.306, sd = 24, CFI = .931, RMSEA = .092, SRMR = .065 elde edilir (V01 a).
- Bollen–Stine p değeri `lavInspect(fit, "test")$bollen.stine$pvalue` yolundadır. `fitMeasures()` içinde yoktur (V01 b).
- `lavTestLRT`, WLSMV ve MLR'de ölçeklenmiş fark testini kendiliğinden seçer (V02 d–e).
- `measEq.syntax(..., ID.cat = "Wu.Estabrook.2016", parameterization = "theta")` ve `lavTestScore` WLSMV modellerinde çalışır (V03).
- §11.3 tablosu kendi içinde tutarlıdır (V06 d):
  - Δχ² değerleri ve serbestlik dereceleri doğru hesaplanmıştır.
  - Biçimsel χ², iki kademenin Model 4 χ² toplamına eşittir (281.169 ↔ 281.168, yuvarlama farkı).
  - Kısmi değişmezlik p değerleri `pchisq` ile örtüşür.
- Tekrar başına tohum ayarlamak, mirai işçi sayısından bağımsız olarak aynı sonucu verir (V08).

### 1.2 Bulgular

| ID | Önem | Konu | Önerilen karar (kısa) |
|---|---|---|---|
| PA-1 | **Kritik** | `fa.parallel` aynı tohumla farklı özdeğerler üretiyor | Motor `mc.cores = 1` ile çağırır; RNG türü kayda girer |
| MC-1 | **Kritik** | WLSMV yanlılığı yanlış ölçekte hesaplanabilir (+%46,5 sahte yanlılık) | Her parametre için kestirilen nicelik ve ölçek tanımlanır |
| I-1 | **Kritik** | Kategorik değişmezlikte "eşik + yük birlikte" iki hipotezi birleştiriyor | Wu–Estabrook sırası: eşik → eşik+yük → +kesişim → +artık |
| BS-1 | Yüksek | Bollen–Stine WLSMV, eksik veri ve MLR ile uyumsuz | Yalnızca ML, tam veri; arayüzde kilit |
| W-1 | Yüksek | WLSMV'de `.scaled` ile `.robust` karışıklığı; §11.3 CFI belirsiz | İkisi de etiketle gösterilir; §11.3'te hangisi olduğu yazılır |
| W-2 | Yüksek | WLSMV'de AIC/BIC yok | İç içe olmayan karşılaştırma WLSMV'de kapalı |
| I-2 | Yüksek | ΔCFI/ΔRMSEA eşikleri ML'den; WLSMV'de geçerli değil; ΔSRMR eksik | Etiket, ΔSRMR, işaret kuralı, birleşik kural |
| PA-2 | Yüksek | "resampled = sütun permütasyonu" yanlış; psych yerine koyarak örnekliyor | Ad düzeltilir; permütasyon yalnızca el uygulamasında |
| PA-3 | Yüksek | psych `mean` ölçütünü desteklemiyor; döndürülen `pc.sim` ortalama | İkisi de R'de `$values`'tan hesaplanır |
| PA-4 | Yüksek | Polikorik + simüle referans, Pearson ile kıyaslanıyor | Polikorikte yalnızca yeniden örneklenmiş referans |
| MC-2 | Yüksek | "N = 200.000 örneklemden gerçek değer" gereksiz ve gürültülü | Kesin popülasyon momentleri; büyük N yalnızca yedek |
| MC-3 | Yüksek | Muthén–Muthén ölçütlerinden SH yanlılığı ve kapsama eksik | Eklenir |
| MC-4 | Yüksek | Sıfıra yakın parametrede göreli yanlılık anlamsız | Ham ve standardize yanlılık + MCSE |
| MC-5 | Yüksek | Tohum şemasında R > 10.000'de çakışma; ızgara sırasına bağlılık | R ≤ 10.000 sınırı, kanonik koşul sırası, RNG türü sabit |
| MC-6 | Yüksek | Kestirici ızgara faktörü olunca yöntemler farklı verilerle kıyaslanıyor | Ortak rastgele sayılar: aynı veri, tüm kestiriciler |
| CL-1 | Yüksek | Düz yanıt ters kodlamadan önce mi sonra mı? Kural sırası yok | Sabit sıra; düz yanıt ham veride |
| ARCH-1 | Yüksek | plumber tek iş parçacıklı; uzun analiz `/health` ve `/jobs`'u kilitler | Bütün analizler mirai işçisinde |
| AI-1 | Yüksek | Sayı denetleyici yanlış yere bağlanmış sayıyı ve yazıyla sayıyı yakalayamaz | Yapay zekâ yer tutucu yazar, sayıyı ağ geçidi R'den yerleştirir |
| REP-1 | Yüksek | §11.3 için psych/semTools sürümleri kayıtlı değil | Sürüm sabitleme + Zafer'in `sessionInfo()` çıktısı |
| BS-2 | Orta | Bollen–Stine tohumu ve paralel modu | `iseed` açıkça verilir; paralel kapalı |
| BS-3 | Orta | Bollen–Stine p = 0 olabiliyor; başarısız tekrarlar düşülüyor | B, B_etkin, başarısız ve uygunsuz sayıları raporlanır |
| W-3 | Orta | Ölçeklenmiş χ² farkı elle alınmamalı; SB2001 negatif olabilir | Yöntem kayda girer; negatifse SB2010 |
| W-4 | Orta | χ²/sd, ölçeklenmiş istatistikte anlamsız | Yalnızca ML'de, "bilgi" etiketiyle |
| W-5 | Orta | `likelihood = "wishart"` MLR ile sessizce kabul ediliyor | Yalnızca ML'de seçilebilir |
| I-3 | Orta | Skor testinde X2 ile X2.scaled farklı sıralama veriyor | WLSMV/MLR'de X2.scaled ile sıralanır |
| I-4 | Orta | Kısmi değişmezlik kuralları eksik | Faktör başına ≥ 2 değişmez gösterge; kesişim kuralı açık |
| I-5 | Orta | Gizil ortalama d'si için payda belirsiz | Varsayılan birleşik SS (Hancock, 2001); lavaan `:=` ile |
| PA-5 | Orta | psych FA özdeğeri ve `n.iter` varsayılanı | El uygulaması psych'in algoritmasını birebir izler |
| MC-7 | Orta | Veri üretimi eksik tanımlı (Θ, yük DIF'i, eşik kaynağı) | Tanımlar eklenir |
| MC-8 | Orta | I. tip hata kabul ölçütü koşulsuz yazılmış | Kuramsal güvence olan koşulda sınanır |
| MC-9 | Orta | Başarısız tekrar ve boş kategori paydası tanımsız | Payda kuralı ve hata türleri |
| MC-10 | Orta | AFA "doğru yapı" ölçütü eksik tanımlı | k, atama kuralı, eşleme, Tucker φ |
| MC-11 | Orta | Örneklem önerisi MC gürültüsüyle tutarsız olabilir | "O N ve sonrasındaki bütün N'ler" kuralı |
| EFA-1 | Orta | `fm = "ml"` + polikorik | Uyarı; minres/uls önerisi |
| EFA-2 | Orta | AFA döndürmesi rastgele başlangıç kullanıyor | Tohum ve `n.rotations` kayda girer |
| REL-1 | Orta | HTMT/omega seçenekleri sonucu büyük ölçüde değiştiriyor | Bütün seçenekler kayıtta; §11.3 HTMT satırı tamamlanır |
| REP-2 | Orta | "Birebir" eşitlik tanımsız | Raporlanan basamakta tolerans |
| REP-3 | Orta | Yuvarlamanın JS'te yapılması sayıyı değiştirebilir | Biçimli metni R üretir; APA baştaki sıfır kuralı |
| REP-4 | Orta | Referans simülasyon paketi ve BİDEKÇET verisi yok | Kabulün bir kısmı yerelde Zafer tarafından koşulur |
| ARCH-2 | Orta | Node 20'nin desteği 30 Nisan 2026'da bitti | Node 24 LTS |
| ARCH-3 | Orta | Çevrimdışı modda yazı tipleri ve varlıklar CDN'den gelmemeli | Yerel paketleme |
| ARCH-4 | Orta | ARES-1 vurguları açık temada 4.5:1'i sağlamıyor | Açık tema için koyulaştırılmış vurgular |
| REP-6 | Yüksek | JSON serileştirme sayıları sessizce yuvarlıyor (Faz 0'da bulundu) | 17 anlamlı basamak; testle güvence |
| ARCH-8 | Orta | UTF-8 dışı yerel ayarda R kaynak dosyalarını yarıda kesiyor (Faz 0'da bulundu) | UTF-8 zorunlu; açık hata |
| CL-2 | Orta | Düz yanıt silmek uç geçerli yanıtları da siler | Duyarlılık çıktısı |
| W-6, PA-6, MC-12, MC-13, CL-3, REL-2, ITEM-1, ARCH-5…7, AI-2, PRIV-1, REP-5 | Düşük | Ayrıntılar §9'da | |

---

## 2. Bollen–Stine bootstrap (M6)

### BS-1 — Bollen–Stine yalnızca sürekli ve tam veride ML ile tanımlıdır (Yüksek)

**Sorun.** Şartname Bollen–Stine'i M6'nın genel seçenekleri arasında sunuyor. Kestirici ML, MLR ya da WLSMV olabilir.

**Kanıt (V01 d–f).** lavaan 0.7-2'de:
- `ordered` + WLSMV ile çalıştırınca: *"bollen.stine/yuan bootstrap not available for categorical/ordinal data"* hatası.
- `missing = "ml"` ile çalıştırınca: *"not available for missing data"* hatası.
- MLR ile çalıştırınca bootstrap'lenen istatistik ölçeklenmiş (Yuan–Bentler) değil, **standart ML χ²'sidir**. Değerler: `bollen.stine$stat = 85.306 = standard$stat` ve `yuan.bentler.mplus$stat = 81.956`.

Kaynak kodda da aynı kontroller vardır (`lav_bootstrap.R`, satır 249–260).

**Düzeltme (v1.1, M6).**
- Bollen–Stine yalnızca şu koşullarda etkinleşir: `estimator = "ML"`, maddeler sürekli kabul edilmiş ve `missing = "listwise"`.
- Koşullar sağlanmazsa seçenek kilitli görünür ve nedeni yazar.
- MLR'de Bollen–Stine sunulmaz. MLR'nin kendi ölçeklenmiş testi zaten ham olmayan dağılım için bir düzeltmedir. İkisini birlikte göstermek, okuyucuya hangi testin raporlandığı konusunda belirsizlik yaratır.

**Gerekçe.** Bollen ve Stine (1992) dönüşümü, gözlenen kovaryans matrisini model kovaryansına eşleyen sürekli veri dönüşümüdür. Sıralı veri için tanımlı değildir.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### BS-2 — Tohum ve paralel mod (Orta)

**Kanıt (V01 c; `lav_bootstrap.R` 596–655).**
- `iseed` verilmezse lavaan tohumu genel RNG'den çeker. Bu durumda `set.seed` önceden çağrılırsa tekrarlanabilirlik sağlanır.
- `iseed` verilirse, arada genel RNG ilerletilse bile aynı `boot.T` elde edilir.
- Paralel modda (`parallel = "multicore"`) lavaan RNG türünü L'Ecuyer-CMRG'ye çevirir. Bu yüzden aynı `iseed` seri ve paralel çalıştırmada **farklı** sonuç verir.

**Düzeltme.**
- Motor her Bollen–Stine çağrısında `iseed = seed` verir.
- `parallel = "no"` kullanır. Paralellik mirai iş düzeyinde sağlanır.
- `iseed`, `RNGkind()` ve paralel modu analiz kaydına (§6.2) yazılır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### BS-3 — p değerinin hesabı ve raporlanması (Orta)

**Kanıt (V01 b; `lav_test.R` 692–732).**
- lavaan p'yi `sum(boot.T > T_gözlenen) / B_etkin` olarak hesaplar.
- Başarısız ya da yakınsamayan tekrarlar paydadan düşülür. Uygunsuz (nonadmissible) çözümler ise içeride kalır.
- HolzingerSwineford1939'da B = 200 ile p = 0 çıktı.

**Düzeltme.** Tabloda şunlar gösterilir:
- istenen B,
- `boot.length` (B_etkin),
- başarısız tekrar sayısı,
- uygunsuz çözüm sayısı,
- lavaan'ın p değeri.

`boot.larger = 0` ise p, "p < 1/B_etkin" biçiminde yazılır, "p = ,000" yazılmaz. İsteğe bağlı olarak R'de (b + 1)/(B + 1) değeri de "tutucu p" etiketiyle verilir (Davison & Hinkley, 1997). Varsayılan B = 1000'dir (lavaan'ın kendi varsayılanı da budur).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 3. WLSMV ve model karşılaştırma (M6)

### W-1 — `.scaled` ve `.robust` uyum indeksleri farklı şeylerdir (Yüksek)

**Kanıt (V02 b, `psych::bfi`, N = 2617).**

| İndeks | `.scaled` | `.robust` |
|---|---|---|
| CFI | .923 | .867 |
| TLI | .898 | .823 |
| RMSEA | .124 | .120 |

`.scaled` değerleri ölçeklenmiş-kaydırılmış χ²'den hesaplanır ve Mplus'ın raporladığı değerlerdir. `.robust` değerleri Savalei (2021) düzeltmesidir. Ayrıca çok gruplu ve kısıtlı Wu–Estabrook modellerinde `cfi.robust` ve `rmsea.robust` **NA** döner (V03 a). Bu yüzden değişmezlikte Δ değerleri yalnızca `.scaled` ile hesaplanabilir.

§11.3'teki "WLSMV Model 4: CFI .908 / .931" satırı hangisi olduğunu söylemiyor. Bu iki değer arasındaki fark, kabul ölçütünü geçip geçmeme farkı kadar büyük olabilir.

**Düzeltme.**
- WLSMV tablosu iki sütun taşır: "CFI (ölçeklenmiş, Mplus uyumlu)" ve "CFI (dayanıklı, Savalei 2021)". RMSEA ve TLI için de aynısı geçerlidir.
- Değişmezlik ve karşılaştırma Δ'ları `.scaled` ile yapılır ve bu, tablo notunda yazar.
- §11.3 satırı "cfi.scaled" ya da "cfi.robust" diye netleştirilir. **Bunu Zafer'in bilmesi gerekiyor** (bkz. §10).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### W-2 — WLSMV'de AIC/BIC yoktur (Yüksek)

**Kanıt (V02 c).** `fitMeasures(fit, c("aic", "bic"))` → `NA NA`.

Ayrıca aynı model ve veride `likelihood = "normal"` ile `"wishart"` arasında AIC değeri 10 birim farklı çıkıyor (V02 f). Bu yüzden farklı olabilirlik ayarlarıyla kestirilmiş modellerin AIC'leri kıyaslanamaz.

**Düzeltme (M6 model karşılaştırma).**
- İç içe olmayan modeller için AIC/BIC yalnızca ML/MLR'de, aynı N, aynı kestirici ve aynı `likelihood` ile kestirilmiş modellerde gösterilir.
- WLSMV'de iç içe olmayan modeller için test sunulmaz. Uyum indeksleri yalnızca betimsel olarak yan yana konur ve tablo notunda bu yazar.
- Karşılaştırma tablosu, kestirici ayarları farklı modellerin aynı tabloya girmesini reddeder.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### W-3 — Ölçeklenmiş fark testi: yöntem açık yazılmalı (Orta)

**Kanıt (V02 d–e).**
- WLSMV'de iki modelin `chisq.scaled` değerlerinin farkı 4056,0'dır. Doğru Satorra (2000) farkı ise 1100,3'tür. Bu yüzden ölçeklenmiş χ²'ler asla elle çıkarılmamalıdır.
- MLR'de varsayılan yöntem SB2001'dir: Δχ² = 830,3. SB2010 ile aynı fark 532,5'tir.
- SB2001 negatif çıkabilir (Satorra & Bentler, 2010).

**Düzeltme.**
- Her fark testinin kaydında `method` alanı yer alır: `satorra.2000`, `satorra.bentler.2001` ya da `satorra.bentler.2010`.
- SB2001 negatif çıkarsa motor SB2010 ile yeniden hesaplar ve bir uyarı ekler.
- Ön yüz hiçbir χ² farkını kendisi hesaplamaz.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### W-4 — χ²/sd oranı (Orta)

Ölçeklenmiş-kaydırılmış istatistikte sd model sd'sidir, ama istatistik kaydırılmıştır. Bu yüzden oran ML'dekiyle aynı anlamı taşımaz.

**Düzeltme.** χ²/sd yalnızca ML'de gösterilir, eşik verilmez ve "bilgi" etiketi taşır. WLSMV ve MLR'de gösterilmez.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### W-5 — `likelihood = "wishart"` (Orta)

**Kanıt (V01 g).** `estimator = "MLR", likelihood = "wishart"` hata ya da uyarı vermeden kabul ediliyor.

**Düzeltme.**
- Varsayılan `likelihood = "normal"`dır (lavaan'ın varsayılanı).
- `"wishart"` yalnızca ML'de "AMOS/LISREL uyumlu (N − 1)" etiketiyle seçilebilir.
- §11.3'teki ML satırları "wishart" kullandığı için testler bunu açıkça belirtir. Bunu doğruladım: oran normal/wishart = N/(N − 1).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 4. Ölçme değişmezliği (M8)

### I-1 — Kategorik sıra: eşik ve yük ayrı adımlardır (Kritik)

**Sorun.** Şartnamede şu yazıyor: "Metrik adımda eşik ve yük birlikte kısıtlanır." Bu, iki ayrı hipotezi tek testte birleştirir. Test reddedilirse eşiklerin mi yüklerin mi değişmez olmadığı anlaşılamaz.

**Kanıt (V03, `bfi`, cinsiyet; WLSMV, theta, Wu–Estabrook tanımlaması).**

| Adım | χ² (ölçeklenmiş) | sd | Önceki adımla Δχ² (Satorra 2000) |
|---|---|---|---|
| Biçimsel | 1517,79 | 68 | — |
| Eşik | 1727,06 | 98 | Δχ²(30) = 41,94, p = ,072 |
| Eşik + yük | 1594,64 | 106 | Δχ²(8) = 6,06, p = ,640 |
| + kesişim | 1738,05 | 114 | Δχ²(8) = 164,46, p < ,001 |
| + artık varyans | 1731,46 | 124 | Δχ²(10) = 31,20, p < ,001 |

Biçimselden doğrudan "eşik + yük" adımına geçildiğinde (şartnamenin önerisi): Δχ²(38) = 42,19, p = ,295.

**Üç kategorili maddeler özel durumdur.** Aynı veri üç kategoriye indirildiğinde eşik modeli biçimsel modelle **birebir aynıdır**: χ² = 785,955654, sd = 68 (V03 b2). Bu sonuç, Wu ve Estabrook'un (2016) üç kategorili maddeler için verdiği eşdeğerlik sonucuyla tutarlıdır. Altı kategoride ise eşik değişmezliği ayrıca sınanabilir bir hipotezdir.

Bir de şunu gösterir: daha çok kısıt eklendiğinde ölçeklenmiş χ² **azalabiliyor** (1727 → 1594). Ölçeklenmiş istatistikler kendi aralarında tekdüze değildir. Bu, W-3'ü destekler.

**Düzeltme (v1.1, M8 kategorik).**
1. Sıra şudur: biçimsel → eşik → eşik + yük → eşik + yük + kesişim → + artık varyans.
2. Bütün maddeler üç kategoriliyse eşik adımı "biçimselle eşdeğer (sd farkı 0)" notuyla atlanır.
3. İkili maddeler için Wu–Estabrook'un önerileri farklıdır. Bu durumu bu incelemede **doğrulamadım**. v1.1'de ikili madde içeren ölçeklerde kategorik değişmezlik ayrı bir doğrulama betiği yazılana kadar kapalı kalır.
4. Tablo, "metrik/skaler" adlarını yalnızca parantez içinde takma ad olarak kullanır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### I-2 — Δ ölçütleri: kaynak, kapsam ve eksikler (Yüksek)

**Sorunlar.**
1. ΔCFI ≥ −,01 (Cheung & Rensvold, 2002) ve ΔRMSEA ≤ ,015 (Chen, 2007) sürekli veride ML ile yapılmış simülasyonlardan türetilmiştir. WLSMV'de bu indekslerin davranışı farklıdır (Sass, Schmitt & Marsh, 2014). V03'te kısıt eklendiğinde ΔRMSEA.scaled'in −,024 çıkması bunun bir örneğidir.
2. Chen (2007) ΔSRMR'yi de önerir ve ölçütleri N'ye göre ayırır. Şartnamede ΔSRMR yok.
3. Δ'nın işareti tanımlı değil.
4. §11.4'te "ΔCFI/ΔRMSEA gücü" diye birleşik bir karar kullanılıyor. Bunun VE mi VEYA mı olduğu yazmıyor.

**Düzeltme.**
- Δ tanımı: Δ = kısıtlı model − daha az kısıtlı model.
- ΔSRMR seçeneği eklenir. Chen'in (2007) değerleri varsayılandır: yük için ,030; kesişim ve artık için ,010.
- Her ölçüt ayrı sütunda gösterilir (şartnamede zaten var). Ek olarak kullanıcı tanımlı bir birleşik kural seçilir (VE/VEYA) ve tablo notunda yazar.
- WLSMV tablosuna şu not eklenir: "Δ eşikleri sürekli ML simülasyonlarından türetilmiştir; WLSMV için doğrulanmamıştır. Birincil ölçüt Satorra (2000) fark testidir."
- M9 bu eşikleri kullanıcının kendi yapısında kalibre etmek için önerilir.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### I-3 — Skor testi sıralaması (Orta)

**Kanıt (V03 d).** WLSMV modelinde `lavTestScore` hem X2 hem X2.scaled verir ve sıralamalar farklıdır:
- X2'de ikinci sıradaki kısıt `.p4. == .p99.` (X2 = 4,33).
- X2.scaled'de ikinci sırada `.p57. == .p152.` var (X2.scaled = 5,38).

Parametre etiketleri `parTable` ile okunur hâle getirilebiliyor. Örneğin ilk sıradaki kısıt `N4|t1 [g1] ↔ N4|t1 [g2]` olarak okunuyor.

**Düzeltme.**
- WLSMV ve MLR'de sıralama X2.scaled'e göre yapılır. ML'de X2 kullanılır. İki sütun da gösterilir.
- İkiden çok grupta bir parametre birden çok kısıt taşır. Sihirbaz, serbest bırakmanın "bütün gruplarda" mı yoksa "tek grup çiftinde" mi yapılacağını sorar.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### I-4 — Kısmi değişmezlik kuralları (Orta)

**Düzeltme.**
1. Gizil ortalama karşılaştırması için her faktörde en az iki göstergenin yükü ve kesişimi (kategorikte eşikleri) değişmez kalmalıdır (Steenkamp & Baumgartner, 1998; Byrne vd., 1989). Bu sağlanmazsa sihirbaz gizil ortalama adımını kilitler.
2. Yükü serbest bırakılan maddenin kesişiminin de serbest bırakılıp bırakılmayacağı açık bir seçenektir. §11.3'teki kısmi skaler model M10'un kesişimini kısıtlı tutuyor (yalnızca `M4~1` eklenmiş). v1.1 varsayılanı da bu olur ve tablo notunda yazar.
3. İki göstergeli faktörler için (BİDEKÇET'te KD: M9, M11) genel bir uyarı eklenir: deneysel tanımlanamama riski ve kararsız güvenirlik kestirimi (Bollen, 1989).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### I-5 — Gizil ortalama etki büyüklüğü (Orta)

**Sorun.** Şartnamedeki tanım şu: "d = fark / ilgili grubun gizil SS". Hangi grubun kastedildiği belirsiz.

**Kanıt (V03 e).** Nevrotiklik için üç tanım üç farklı değer veriyor:
- referans SS ile: ,2891
- odak grup SS ile: ,2845
- birleşik SS ile (Hancock, 2001): ,2860

Bu veride gizil varyanslar 1'e yakın olduğu için fark küçük. Varyanslar ayrıştığında fark büyür.

**Düzeltme.**
- Varsayılan, birleşik SS'dir (Hancock, 2001). Referans grup SS'si seçenek olarak sunulur.
- d, lavaan sözdiziminde `:=` ile tanımlanır. Böylece SH ve güven aralığı lavaan'dan (delta yöntemi) gelir. Ön yüz hesap yapmaz.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 5. Paralel analiz (M4)

### PA-1 — Aynı tohum, farklı özdeğerler (Kritik)

**Kanıt (V04 a–c; iki çekirdekli makine).** `psych::fa.parallel` içeride `mclapply` kullanıyor.
- Varsayılan RNG ve `mc.cores` > 1 ile `set.seed(20261030)` iki kez çağrıldığında özdeğerler **farklı** çıkıyor. En büyük fark 0,201.
- `options(mc.cores = 1)` ile özdeğerler birebir aynı.
- L'Ecuyer-CMRG ile de birebir aynı. Ancak bu durumda sonuç `mc.cores` değerine bağlı: 2 çekirdek ile 1 çekirdek farklı sonuç veriyor.

Şartnamenin M4 kabul ölçütü ("aynı tohumla aynı özdeğerler"), düz bir sarmalamayla çekirdek sayısı birden büyük her makinede **geçmez**.

**Düzeltme.**
- Motor `fa.parallel`'i her zaman `mc.cores = 1` ile ve sabit RNG türüyle çağırır: `RNGkind("Mersenne-Twister", "Inversion", "Rejection")`.
- Paralellik mirai iş düzeyinde sağlanır.
- `RNGkind()` ve `mc.cores` analiz kaydına yazılır.
- Kabul testi aynı tohumla iki çalıştırmayı karşılaştırır. Bunun mümkün olması için CI makinesi birden çok çekirdekli olmalıdır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### PA-2 — "resampled" permütasyon değil (Yüksek)

**Kanıt (V04 e; kaynak).** psych 2.6.9'daki satır: `sample(y, nsub, replace = TRUE)`. Bu, sütun içinde **yerine koyarak örneklemedir** (bootstrap), permütasyon değildir.

Kaynak koddan bir ayrıntı daha: `sim = TRUE` ise karar, yeniden örneklenmiş referans da hesaplanmış olsa bile simüle normal referansa göre verilir (`fa.parallel.R` 206–223). Yeniden örneklenmiş referansla karar almak için `sim = FALSE` gerekir.

**Düzeltme.**
- `reference` değerleri şunlar olur:
  - `simulated_normal` → `sim = TRUE`,
  - `resampled_bootstrap` → `sim = FALSE`; psych ile birebir karşılaştırılır,
  - `permutation` → yalnızca `parallel_manual`; psych ile karşılaştırılmaz.
- Arayüz metninde "sütun permütasyonu" ifadesi kaldırılır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### PA-3 — `mean` ölçütü ve döndürülen referans (Yüksek)

**Kanıt (V04 d; `fa.parallel.R` satır 133).**
- Kaynak koddaki yorum: "always apply quant". Yani `mean` ölçütü psych'te seçilemiyor.
- Döndürülen `pc.sim`, simülasyon **ortalamasıdır** (`colMeans`). Karar ise %95 yüzdeliğe göre veriliyor.
- HolzingerSwineford1939'da örnek: 1. bileşen için referans ortalama 1,268, %95 yüzdelik 1,347.

Tabloya psych'in `pc.sim`'i konursa, kararın dayandığı sayı tabloda görünmez.

**Düzeltme.**
- Motor, ortalama ve yüzdelik referansı psych'in döndürdüğü `$values` matrisinden R'de hesaplar.
- Tabloda hangi referansın karar için kullanıldığı işaretlenir.
- `mean` ölçütü R'de `$values`'tan uygulanır. psych ile birebir karşılaştırma yalnızca `quantile` ölçütü için yapılır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### PA-4 — Polikorik korelasyonla simüle referans (Yüksek)

**Kanıt (V04 f; kaynak).** `sim.cor <- cor(simdata)` satırı, `cor = "poly"` seçilse bile simüle referansın normal veriden **Pearson** ile hesaplandığını gösteriyor. Gözlenen polikorik özdeğerler, örnekleme dağılımı farklı olan bir referansla karşılaştırılıyor.

**Düzeltme.**
- `correlation = "polychoric"` seçilince referans zorunlu olarak `resampled_bootstrap` ya da `permutation` olur.
- Ölçüt önerisi olarak Garrido, Abad ve Ponsoda (2013) gösterilir.
- Hesap süresi uyarısı verilir: her yinelemede polikorik matris kestirilir.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### PA-5 — El uygulamasının psych ile örtüşmesi için gerekenler (Orta)

**Kanıt (V04 d, g; kaynak).**
- psych'te FA özdeğerleri, indirgenmiş korelasyon matrisinden değil, **tek faktörlü** `fa(rx, nfactors = 1, fm = fm)$values` çözümünden alınır. `SMC = TRUE` verilirse farklıdır.
- psych'in `n.iter` varsayılanı 20'dir, şartnameninki 1000.
- Sayım kuralı ardışıktır: ilk kez referansın altına düşmeden önceki özdeğer sayısı.
- psych'in MAP'i Velicer'in (1976) karesel kısmi korelasyon sürümüdür ve sayıma 1'den başlar, yani 0 faktör öneremez. Dördüncü kuvvetli sürüm (Velicer, Eaton & Fava, 2000) yoktur.

**Düzeltme.**
- `parallel_manual` bu kuralları birebir izler.
- `n.iter` her zaman açıkça verilir.
- MAP'in hangi sürüm olduğu tablo notunda yazar.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 6. Monte Carlo simülasyonu (M9)

### MC-1 — Yanlılık, kestirilen niceliğin ölçeğinde hesaplanmalı (Kritik)

**Kanıt (V05 a).** Üretimdeki standardize yük λ = ,70. WLSMV theta parametrelemesinde ham yük ortalaması 1,026 çıkıyor; kuramsal değer ,70/√,51 = ,980. std.all ,715; delta ham ,715.

Theta ham değeri ,70 ile kıyaslanırsa "göreli yanlılık" **+%46,5** olarak raporlanır. Bu kestiricinin yanlılığı değil, ölçek uyuşmazlığıdır.

**Düzeltme (9.5'e "kestirilen nicelik tablosu" eklenir).**
- Her parametre türü için karşılaştırma ölçeği tanımlanır: yükler ve faktör korelasyonları std.all ölçeğinde; eşikler y* ölçeğinde; gizil ortalama farkı referans grubun gizil SS'si cinsinden.
- Gerçek değer, kestirimle aynı ölçekte hesaplanır.
- Bu tablo `params.json`'a yazılır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-2 — "Gerçek değer" için büyük örneklem yerine kesin popülasyon değerleri (Yüksek)

**Kanıt (V05 b–c).**
- 5 kategorili veriye ML uygulandığında yükün olasılık limiti (sözde-gerçek değer) ,670'tir, üretim değeri ise ,70'tir. Fark −,030.
- Bu sözde-gerçek değer, kesikli puanların **kesin** popülasyon kovaryansından (iki değişkenli normal olasılıklarıyla) 0,07 saniyede, örnekleme hatası olmadan hesaplandı.
- N = 200.000 örneklem aynı değeri 1,23 saniyede, yük başına en çok 0,004 hatayla verdi.
- WLSMV'de N = 200.000 her senaryo için 30,1 saniye sürdü.

Bu iki soru birbirinden farklıdır:
- (a) Kestirici üretim parametresini ne kadar iyi yakalıyor? (Kesiklileştirme ve model yanlışlığı dâhil.)
- (b) Kestiricinin sonlu örneklem yanlılığı ne kadar?

Şartname hangisini raporladığını söylemiyor.

**Düzeltme (9.6).** Gerçek değerin kaynağı sırasıyla şudur:
1. Model doğru ve ölçek uyumluysa üretim parametresi.
2. Kesin popülasyon momentlerine uydurulan modelin değeri (sözde-gerçek). ML/MLR ile sıralı veri, yanlış tanımlanmış modeller, popülasyon alfa ve omega değerleri bu yolla hesaplanır.
3. Kapalı biçim yoksa büyük örneklem; bu durumda kendi MC hatası raporlanır.

Raporda iki satır yer alır: "üretim değerinden sapma" ve "sözde-gerçek değere göre yanlılık". Ordinal veride alfa/omega için kestirilen nicelik açıkça yazılır: gözlenen toplam puanın güvenirliği (Green & Yang, 2009) ya da y* güvenirliği.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-3 — Muthén ve Muthén (2002) ölçütlerinin eksik kısmı (Yüksek)

**Sorun.** Muthén ve Muthén (2002) şu ölçütleri kullanır:
- bütün parametrelerde parametre **ve SH** yanlılığı ≤ %10,
- gücü incelenen parametrede SH yanlılığı ≤ %5,
- %95 güven aralığı **kapsaması** ,91–,98,
- güç ≥ ,80.

Şartnamede SH yanlılığı ve kapsama yok. "Uygun çözüm ≥ ,95" ise Muthén ve Muthén'den gelmiyor, kullanıcı tanımlıdır.

**Düzeltme.**
- 9.5'e SH göreli yanlılığı eklenir: (ort(SH) − SS(θ̂)) / SS(θ̂).
- %95 kapsama oranı eklenir.
- Varsayılan ölçüt listesi Muthén–Muthén ölçütleri ve kullanıcı tanımlı ölçütler olarak iki ayrı başlıkta verilir.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-4 — Sıfıra yakın parametrede göreli yanlılık (Yüksek)

**Kanıt (V05 d).** Gerçek φ = ,02, R = 200, n = 300 ile:
- ham yanlılık −,0031,
- göreli yanlılık **−%15,7** (%10 ölçütünü "geçemiyor"),
- standardize yanlılık −%4,7,
- ortalamanın MCSE'si ,0047 (yani yanlılık MC hatasından küçük).

θ = 0 olduğunda (DIF kontrol senaryosu, sıfır çapraz yük, sıfır ortalama farkı) göreli yanlılık hiç tanımlı değildir.

**Düzeltme.**
- |θ| < ,10 olduğunda (bu eşik ayarlanabilir) ölçüt olarak ham yanlılık ve standardize yanlılık (yanlılık/SS) kullanılır. Collins, Schafer ve Kam'a (2001) göre |%40| üzeri sorunludur.
- Bütün yanlılıklar MCSE ile birlikte verilir (Morris, White & Crowther, 2019).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-5 — Tohum şeması (Yüksek)

**Kanıt (V05 e).**
- `seed + 10000*koşul + tekrar` şeması R ≤ 10.000'de çakışmasız çalışıyor.
- R = 12.000 ve 16 koşulda **30.000 çakışan tohum** oluşuyor.
- Aynı hücrenin (N = 600, 70/30) koşul indeksi ızgaranın kuruluş sırasına göre 6 ya da 4 oluyor. Yani ızgaraya bir koşul eklemek ya da sırayı değiştirmek bütün tohumları kaydırıyor.

**Düzeltme.** Şema korunur, çünkü §11.4'teki referans değerleri buna bağlıdır. Şunlar eklenir:
1. R ≤ 10.000 sınırı motor ve arayüz tarafından denetlenir.
2. Koşul sırası kanoniktir: faktörler sabit sırada, düzeyler kullanıcı girdisi sırasında. Her koşulun indeksi ve tohumu `params.json`'a yazılır.
3. RNG türü açıkça ayarlanır ve kayda girer: `RNGkind("Mersenne-Twister", "Inversion", "Rejection")`.
4. Tohum yalnızca **veri üretim** faktörlerine bağlıdır (N, grup oranı, DIF). Kestirici ve analiz seçenekleri tohumu değiştirmez (bkz. MC-6).
5. Popülasyon ve gerçek değer üretimi ayrı ve belgelenmiş bir tohum alır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-6 — Kestiriciler aynı veri setinde karşılaştırılmalı (Yüksek)

**Sorun.** Şartname kestiriciyi (ML, MLR, WLSMV) koşul ızgarasına koyuyor. Seed formülü koşul indeksine bağlı olduğu için her kestirici başka veri setleriyle çalışır. Kestiriciler arasındaki fark, örnekleme gürültüsüyle karışır.

**Düzeltme.** Her tekrarda aynı veri seti seçilen bütün kestiricilerle analiz edilir (ortak rastgele sayılar; Morris vd., 2019). Kestirici bir "analiz faktörü" olur, "veri üretim faktörü" olmaz.

**Uyumluluk notu.** Referans simülasyon paketinin bunu nasıl yaptığını göremedim. Paket gelince §11.4 uyumu yeniden denetlenecek.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-7 — Veri üretimi tanımları (Orta)

**Düzeltme (9.2).**
- Θ_ref = I − diag(Λ Ψ_ref Λ′), yani referans grupta var(y*) = 1.
- **Yük DIF'i:** Θ sabit tutulursa odak grupta var(y*) değişir. Θ yeniden ölçeklenirse artık varyansı değişir. Varsayılan "Θ sabit" olur ve rapor bunu yazar.
- **Eşik kayması:** referans grubun SD(y*) birimiyle verilir.
- **Kategori oranları:** referans grubun oranlarıdır; eşikler bunlardan Φ⁻¹ ile türetilir.
- **ML ile uydurulmuş popülasyon (9.1 a):** parametreler gözlenen 1–5 metriğindedir. Bu kaynaktan yalnızca sürekli veri üretilebilir. Sıralı üretim için popülasyon WLSMV/theta modelinden ya da elle tanımlanmalıdır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-8 — I. tip hata kabul ölçütü (Orta)

**Kanıt (V05 f).** R = 1000 ve α = ,05 için MCSE = ,0069 ve %95 binom aralığı [,037; ,064]. Şartnamedeki ,03–,07 aralığı yaklaşık ±2,9 MCSE'ye karşılık gelir. Bradley'nin (1978) liberal ölçütü ise ,025–,075'tir.

Asıl sorun şu: nominal düzeye yakınlık yalnızca varsayımlar sağlandığında kuramsal olarak güvence altındadır. Örneğin sürekli normal veride, yeterli N ile ML. WLSMV ve sıralı veride bu bir yazılım doğruluğu ölçütü değil, yöntemin ampirik bir özelliğidir.

**Düzeltme.**
- Yazılım kabul testi sürekli-normal ve ML kontrol senaryosunda yapılır.
- WLSMV sonuçları "bilgi" olarak raporlanır.
- Hangi karşılaştırmanın sınandığı yazılır: biçimsel–metrik ve metrik–skaler.
- Oranlar hem "her adım ayrı" hem de "ardışık karar" olarak raporlanır.
- Payda, uygun çözüm veren tekrarlardır (bkz. MC-9).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-9 — Payda ve hata türleri (Orta)

**Düzeltme.**
- Yeniden üretim yapılmaz, R sabittir.
- Hata türleri ayrı ayrı sayılır: yakınsamama, uygunsuz çözüm, grupta boş kategori, diğer.
- Bütün ölçütler hem "yakınsayan + uygun" hem de "yakınsayan" alt kümelerde verilir; birincil olan ilkidir.
- MCSE, etkin R ile hesaplanır.
- Boş kategori nedeniyle oluşan kayıp küçük N'de rastgele olmayan bir kayıptır. Rapor bunu açıkça yazar.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-10 — AFA'da "doğru yapı" ölçütü (Orta)

**Düzeltme.**
- İki ölçüt ayrı raporlanır: (a) AFA gerçek k ile çalıştırılır; (b) uçtan uca, paralel analizin önerdiği k ile çalıştırılır. (b)'de k ≠ gerçek k ise tekrar başarısız sayılır.
- Atama kuralı: bir madde mutlak değerce en büyük yükü taşıdığı faktöre atanır; bu yük ≥ ,30 olmalıdır (ayarlanabilir). Çapraz yük kuralı ayrıca tanımlanır.
- Faktör eşleme: k ≤ 8 için bütün permütasyonlar denenir; işaret düzeltmesi yapılır.
- Ek ölçüt olarak Tucker uyum katsayısı verilir; ≥ ,95 benzer kabul edilir (Lorenzo-Seva & ten Berge, 2006).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### MC-11 — Örneklem büyüklüğü önerisinin tanımı (Orta)

**Düzeltme.** Önerilen N, ızgaradaki öyle en küçük N'dir ki seçilen bütün ölçütler hem o N'de hem de ondan büyük bütün ızgara N'lerinde sağlanır. Ölçütler nokta kestirimlerle sınanır; MCSE yanlarında gösterilir. İsteğe bağlı olarak "güven aralığının alt sınırı ≥ ölçüt" kuralı seçilebilir. Öneri, ızgara çözünürlüğüyle sınırlıdır ve rapor bunu yazar.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 7. Veri temizleme (M1)

### CL-1 — Kural sırası ve düz yanıtın ters kodlamaya göre konumu (Yüksek)

**Sorun.** Ters kodlamadan **sonra** düz yanıt aranırsa iki hata oluşur:
- Karışık yönlü bir ölçekte hep aynı yanıtı veren kişi artık sabit görünmez.
- Tutarlı yanıt veren bir kişi ise sabit görünür.

Şartnamede kuralların uygulanma sırası tanımlı değil. Aralık dışı değerin satırı mı sildiği yoksa değeri mi eksik yaptığı da belirsiz. Bu belirsizlikler §11.3'teki sayıları doğrudan etkiler.

**Önerilen sıra.**
1. Geçersiz grup.
2. Aralık dışı değer (satır silinir).
3. Eksik değer (liste bazında silme).
4. Düz yanıt — **ham** yanıtlarda aranır.
5. Ters kodlama.

Her adım kaç satırın neden çıktığını raporlar; bir satır yalnızca ilk eşleştiği kuralda sayılır.

**Uyarı.** §11.3'ün tutması için bu sıranın BİDEKÇET çalışmasında kullanılan sırayla aynı olması gerekir. **Bunu yalnızca Zafer doğrulayabilir.**

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### CL-2 — Düz yanıt silmenin bedeli (Orta)

Bütün maddeleri aynı yönde olan bir ölçekte, gerçekten en uçta olan ve tutarlı yanıt veren katılımcı da düz yanıtçı gibi görünür. Bu kişileri silmek dağılımın tavanını kırpar (Meade & Craig, 2012; Curran, 2016).

**Düzeltme.** Bütün maddeler aynı yöndeyse kural varsayılan olarak açık kalır ama bir uyarı verilir. Rapora "düz yanıt silinmeden" duyarlılık satırı eklenebilir.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 8. Mimari, tekrarlanabilirlik ve arayüz

### ARCH-1 — plumber tek iş parçacıklıdır (Yüksek)

**Sorun.** Şartname yalnızca "uzun" analizlerin iş kuyruğuna gideceğini söylüyor. Ancak tek bir WLSMV değişmezlik zinciri ya da skor testi bile saniyeler sürebilir. plumber o sırada `/health`, `/jobs/{id}` dâhil hiçbir isteğe yanıt veremez.

**Düzeltme.**
- Bütün analiz uç noktaları mirai işçisinde çalışır ve promise döndürür.
- Ana süreç yalnızca yönlendirme, oturum ve iş durumu işlerini yapar.
- Faz 0'daki `/health` ve `/versions` ana süreçte kalır, çünkü hızlıdır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### REP-1 — Sürüm sabitleme (Yüksek)

**Sorun.** §11.3 değerleri "R 4.4.3 ve lavaan 0.7.2" ile doğrulanmış. Ancak alfa, KMO, HTMT ve omega satırları psych ve semTools'a bağlı ve bu paketlerin sürümleri yazmıyor. Ayrıca semTools sürümleri arasında dönüş tipleri değişiyor: 0.5-10'da `compRelSEM` liste döndürüyor (V06 c).

**Düzeltme.**
- `renv.lock` bu incelemede doğrulanan sürümlerle sabitlenir: lavaan 0.7-2, psych 2.6.9, semTools 0.5-10, GPArotation 2026.8-2.
- lavaan 0.7-3'e geçiş ayrı bir doğrulama turu gerektirir.
- **Zafer'den, BİDEKÇET analizlerinin yapıldığı oturumun `sessionInfo()` çıktısını istiyorum.**

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### REP-2 — "Birebir" tanımı (Orta)

**Düzeltme.** Referans değerler raporlandıkları basamakta karşılaştırılır: |x − ref| ≤ 0,5 × 10⁻ᵈ (d = ondalık basamak sayısı). Docker imajında BLAS/LAPACK sabitlenir; `sessionInfo()` çıktısındaki BLAS bilgisi kayda girer. Ayrıca AFA döndürmesi de rastgele başlangıçlara bağlıdır (bkz. EFA-2).

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### REP-3 — Yuvarlama ve biçim R'de yapılmalı (Orta)

**Sorun.** JavaScript'te `(1.005).toFixed(2)` sonucu `"1.00"`dır. Ön yüz yuvarlama yaparsa arayüzdeki sayı, Word raporundaki (R/officer) sayıdan farklı çıkabilir.

**Düzeltme.**
- R her sayı için iki değer döndürür: tam değer ve dile göre biçimlenmiş metin.
- APA 7'de değeri 1'i geçemeyen istatistiklerde baştaki sıfır yazılmaz (r, p, α, CFI, RMSEA, standardize yük): ",794" ve ".794".
- Ön yüz yalnızca R'nin biçimlediği metni gösterir.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### REP-4 — Eksik girdiler (Orta)

Şunlar bana verilmedi:
- `docs/reference_simulation/` paketi,
- `ozet_tablolar.csv`,
- "Senaryo B"nin tanımı,
- BİDEKÇET verisi.

**Sonuç.**
- Faz 1–3'teki §11.3 kabul testleri yalnızca senin makinende, `tests/private/` altında koşulabilir. Bunun için koşum iskeletini hazırlayacağım.
- Faz 4'ten önce referans simülasyon paketine ihtiyacım var.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### REP-5 — Gerçek veriyle çalışan işlerde devam etme (Düşük)

"Kesilirse devam etme" özelliği parçaları diske yazmayı gerektirir. Gerçek veri içeren işlerde (Bollen–Stine, büyük skor testi tabloları) bu, §10'daki "diske yazılmaz" kuralıyla çelişir.

**Düzeltme.** Devam etme yalnızca simülasyon işlerinde, yani sentetik veride vardır. Gerçek veri içeren işler kesilince baştan çalışır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### ARCH-2 — Node sürümü (Orta)

Node 20'nin güvenlik desteği 30 Nisan 2026'da sona erdi. Node 24 LTS'nin güvenlik desteği 30 Nisan 2028'e, Node 26 LTS'ninki 30 Nisan 2029'a kadar sürüyor ([endoflife.date](https://endoflife.date/nodejs)).

**Düzeltme.** Hedef sürüm Node 24 LTS olur; CI Node 24 ve 26'da koşar. Bu, şartnamedeki "Node 20+" ifadesinin içinde kalır, bu yüzden Faz 0'a uyguladım.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### ARCH-3 — Çevrimdışı varlıklar (Orta)

"Yerel modda dışarıya hiçbir istek gitmez" kuralı, yazı tiplerinin ve grafik kütüphanelerinin de pakete gömülmesini gerektirir. Google Fonts ya da başka bir CDN kullanılamaz.

**Düzeltme.** JetBrains Mono `@fontsource` ile (OFL lisansı) yerelden yüklenir. Faz 0'a uygulandı.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### ARCH-4 — Açık temada kontrast (Orta)

**Kanıt (V07).** ARES-1 vurgularının WCAG kontrast oranları:

| Renk | Koyu zeminde (#070B10) | Beyaz zeminde |
|---|---|---|
| #00E5FF camgöbeği | 12,83:1 | **1,54:1** |
| #FFB300 kehribar | 10,99:1 | **1,79:1** |

Şartnamenin kendi şartı olan 4.5:1, açık temada sağlanmıyor.

**Düzeltme.** Açık temada vurgular koyulaştırılır:
- #00707F camgöbeği: beyazda 5,79:1, #F4F7FA zeminde 5,39:1.
- #8A5A00 kehribar: beyazda 5,93:1, #F4F7FA zeminde 5,51:1.

Koyu tema şartnamedeki renkleri aynen kullanır. Kontrast bir vitest testiyle sürekli denetlenir. Faz 0'a uygulandı.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### REP-6 — JSON'da sessiz yuvarlama (Yüksek; Faz 0'da bulundu ve düzeltildi)

**Kanıt (`engine/tests/testthat/test-json.R`).**
- plumber'ın varsayılan JSON serileştiricisi jsonlite'ın `digits = 4` ayarını kullanır.
- `digits = NA` ayarı bile yalnızca 15 anlamlı basamak yazar. Bu yüzden π ve 1/3 gibi değerler JSON'dan geri okunduğunda birebir aynı çıkmaz.
- Çift duyarlıklı sayının kayıpsız gidiş-dönüşü için 17 anlamlı basamak gerekir. Bu, M12'deki "aynı veri yüklenirse sonuçlar yeniden üretilip karşılaştırılır" adımının doğru çalışması için de şarttır.

**Düzeltme (v1.1, §8).** "Bütün sayılar 17 anlamlı basamakla (`digits = I(17)`) serileştirilir; ekranda gösterilecek biçimli metin ayrıca döner (REP-3)." Faz 0'a uygulandı ve testle güvenceye alındı.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### ARCH-8 — UTF-8 yerel ayarı zorunlu (Orta; Faz 0'da bulundu ve düzeltildi)

**Kanıt.** `C` yerel ayarında R, Türkçe karakter içeren kaynak dosyaları ilk ASCII dışı karakterde kesti. Fonksiyonlar uyarısız biçimde yüklenmedi; plumber, `register_planned_endpoints` bulunamadığı için açılamadı.

**Düzeltme (v1.1, §4 ve §5).**
- Motor, UTF-8 yerel ayarı yoksa açık bir hata iletisiyle durur (`engine/R/00_locale.R`).
- Docker imajı `LANG=C.UTF-8` ile çalışır.
- Bir test, C yerel ayarında bu hatanın gerçekten verildiğini denetler.

Faz 0'a uygulandı.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

---

## 9. Yapay zekâ modülü ve düşük önemli maddeler

### AI-1 — Sayı denetleyici kendi başına yeterli değil (Yüksek)

Denetleyici yalnızca sonuçlarda **hiç bulunmayan** sayıları yakalar. Şu durumları yakalayamaz:
- Yanlış yere bağlanmış sayı. Örneğin sonuçta 2 faktör önerilmişken metin "3 faktör" diyor, ama 3 başka bir yerde sd olarak geçiyor.
- Yazıyla yazılmış sayılar: "iki faktör", "yüzde elli".
- Türkçede yüzde işaretinin başa gelmesi (%5).
- Aralıklar ("0,30–0,40") ve Unicode eksi işareti.

Ayrıca "%100 yakalar" ölçütü, test metinlerini de geliştirici yazdığı için döngüseldir.

**Düzeltme.**
- Yapay zekâ sayı yerine sonuç anahtarına bağlı yer tutucular yazar, örneğin `{{cfa.fit.cfi_scaled}}`.
- Ağ geçidi bu yer tutucuları R JSON'undaki biçimli değerlerle doldurur.
- Metinde kalan her rakam ya da sayı sözcüğü işaretlenir.
- Mevcut denetleyici bu sistemin yedeği olarak kalır.
- Test derlemi yukarıdaki zor durumları içerir.

Bu, Faz 6 kapsamındadır.

**Karar:** ☐ Onay ☐ Ret ☐ Değiştir

### Düşük önemli maddeler

| ID | Madde ve öneri | Karar |
|---|---|---|
| W-6 | "İyi/kabul edilebilir uyum" eşikleri (Hu & Bentler, 1999) ML/sürekli kökenlidir. WLSMV'de CFI ve RMSEA farklı davranır (Xia & Yang, 2019). Eşik kaynağı tabloda yazılmalı. | ☐ Onay ☐ Ret |
| PA-6 | Karar destek kutusu yalnızca iç simülasyona değil, yayımlanmış kaynağa da dayanmalı (Crawford vd., 2010; Garrido vd., 2013). | ☐ Onay ☐ Ret |
| MC-12 | Simüle normal referansla paralel analizde referans dağılımı yalnızca (N, p)'ye bağlıdır. Hücre başına bir kez hesaplanıp bütün tekrarlarda kullanılabilir; bu, dağılım bakımından eşdeğerdir ve maliyeti yaklaşık R kat düşürür. RNG akışı değiştiği için ayrı belgelenmelidir. | ☐ Onay ☐ Ret |
| MC-13 | Uydurulmuş modelden kurulan popülasyon, örnek kestirimlerini gerçek değer sayar. Rapora bir duyarlılık seçeneği (ör. yükler −,05) ve sınırlılık cümlesi eklenmeli (Hoenig & Heisey, 2001). | ☐ Onay ☐ Ret |
| EFA-1 | `cor = "poly"` ile `fm = "ml"` seçilirse uyarı verilmeli; minres/uls önerilmeli. | ☐ Onay ☐ Ret |
| EFA-2 | psych 2.6.9'da `fa()` varsayılan olarak `n.rotations = 20` rastgele başlangıç kullanır. Yükler tohuma göre değişir (oblimin: 6×10⁻⁶; geominQ: 1×10⁻⁵, V09). Tohum ve `n.rotations` kayda girmeli. Yerel minimumlar için bkz. Hattori, Zhang ve Preacher (2017). | ☐ Onay ☐ Ret |
| REL-1 | semTools 0.5-10 varsayılanları `htmt2 = TRUE` ve `absolute = TRUE`'dur (V06 a). htmt2 seçimi değeri ,194'ten ,298'e çıkarıyor. Ters maddeler yeniden kodlanmadan `absolute = FALSE` seçilirse sonuç NaN oluyor (V06 b). `ord.scale` omega'yı ,849'dan ,872'ye, `obs.var` ,806'dan ,816'ya değiştiriyor (V06 c). Bütün seçenekler kayda girmeli; §11.3'teki HTMT satırına `absolute` ve korelasyon türü eklenmeli. | ☐ Onay ☐ Ret |
| REL-2 | ,70 / ,50 / ,85 eşikleri için kaynak verilmeli (Fornell & Larcker, 1981; Henseler vd., 2015; Roemer vd., 2021). Sıralı veride AVE y* ölçeğindedir; tabloda bu yazmalı. | ☐ Onay ☐ Ret |
| CL-3 | Liste bazında silme MCAR varsayar. Madde bazında eksiklik oranı tablosu eklenmeli. FIML v2 adayı olmalı (Bollen–Stine ile uyumsuz olduğunu da not et). | ☐ Onay ☐ Ret |
| ITEM-1 | Çarpıklık ve basıklık türü yazılmalı (`psych::describe` type = 3, fazla basıklık). Mardia testinin Likert verisinde neredeyse her zaman anlamlı çıktığı notu eklenmeli. | ☐ Onay ☐ Ret |
| ARCH-5 | Uzun Türkçe metinde tek genişlikli yazı tipi okunurluğu düşürür. Öneri: sayılar, kod ve tablolar JetBrains Mono, gövde metni sans-serif. Faz 0'da şartname aynen uygulandı, yazı tipi tek bir değişkenle değiştirilebiliyor. | ☐ Onay ☐ Ret |
| ARCH-6 | plumber 1.3.3 (Ocak 2026) korunmalı; plumber2 henüz 0.2.0 sürümünde. | ☐ Onay ☐ Ret |
| ARCH-7 | Hugging Face Space yeniden başladığında oturumlar silinir; bu gizlilikle uyumludur ve belgelenmeli. "Bellekten silinir" ifadesi R'nin belleği güvenli biçimde sıfırlamadığını da yazmalı. | ☐ Onay ☐ Ret |
| AI-2 | Yapay zekâya giden tablolar yalnızca toplu bilgi içermeli. Satır kimliği ya da kişi bazında uzaklık gibi bilgiler gönderilmemeli. | ☐ Onay ☐ Ret |
| PRIV-1 | T.C. kimlik numarası algılaması 11 hane ve sağlama algoritmasıyla yapılmalı. Arayüz bunun sezgisel bir yöntem olduğunu ve garanti vermediğini yazmalı. | ☐ Onay ☐ Ret |

---

## 10. Zafer'den gereken bilgiler

1. §11.3 "WLSMV Model 4 CFI .908 / .931": `cfi.scaled` mi, `cfi.robust` mu? (W-1)
2. §11.3 HTMT ,773: Pearson mı polikorik mi, `absolute` TRUE mu FALSE mu? (REL-1)
3. BİDEKÇET temizleme sırası: aralık dışı değer satırı mı silindi, değer mi eksik yapıldı? Düz yanıt ters kodlamadan önce mi arandı? (CL-1)
4. BİDEKÇET analiz oturumunun `sessionInfo()` çıktısı. (REP-1)
5. `docs/reference_simulation/` paketi ve `ozet_tablolar.csv`; Senaryo B'nin tanımı; ΔCFI/ΔRMSEA birleşik kuralı (VE mi VEYA mı); kestiriciler aynı veri setinde mi çalıştırıldı? (I-2, MC-6, REP-4)
6. Bu belgedeki her madde için Onay / Ret / Değiştir kararı.

---

## 11. Faz 0'a etkisi

Aşağıdaki maddeler şartnamenin kendi sınırları içinde kaldığı için Faz 0'a **uygulandı**. Reddedersen geri alınır.

- **ARCH-2:** Node 24 hedefi (şartname: Node 20+).
- **ARCH-3:** Yazı tipleri yerelden yükleniyor (şartname: yerel modda dış istek yok).
- **ARCH-4:** Açık temada koyulaştırılmış vurgular (şartname: kontrast ≥ 4.5:1).
- **REP-1:** `renv.lock` bu incelemedeki sürümlerle (şartname: sürüm sabitleme).
- **REP-6:** JSON'da 17 anlamlı basamak (şartname: sayılar yalnızca R'den gelir, yuvarlanmadan).
- **ARCH-8:** UTF-8 yerel ayarı denetimi (şartname: Türkçe karakterli sütun adları desteklenir).
- Henüz uygulanmamış uç noktalar **501** ve şartnamedeki hata biçimiyle döner; sahte sonuç üretmez (AGENTS kuralı 2).
- CORS varsayılanı hem `localhost:5173` hem `127.0.0.1:5173` kaynaklarını kapsar. Ekran görüntüsü denetiminde ikincisinin engellendiği görüldü.

Geri kalan bütün maddeler ilgili fazda, onayından sonra uygulanacak.

---

## Kaynaklar (bu incelemede eklenenler)

- Bollen, K. A. (1989). *Structural equations with latent variables*. Wiley.
- Bollen, K. A., & Stine, R. A. (1992). Bootstrapping goodness-of-fit measures in structural equation models. *Sociological Methods & Research, 21*(2), 205–229.
- Bradley, J. V. (1978). Robustness? *British Journal of Mathematical and Statistical Psychology, 31*(2), 144–152.
- Collins, L. M., Schafer, J. L., & Kam, C.-M. (2001). A comparison of inclusive and restrictive strategies in modern missing data procedures. *Psychological Methods, 6*(4), 330–351.
- Crawford, A. V., Green, S. B., Levy, R., Lo, W.-J., Scott, L., Svetina, D., & Thompson, M. S. (2010). Evaluation of parallel analysis methods for determining the number of factors. *Educational and Psychological Measurement, 70*(6), 885–901.
- Curran, P. G. (2016). Methods for the detection of carelessly invalid responses in survey data. *Journal of Experimental Social Psychology, 66*, 4–19.
- Davison, A. C., & Hinkley, D. V. (1997). *Bootstrap methods and their application*. Cambridge University Press.
- Fornell, C., & Larcker, D. F. (1981). Evaluating structural equation models with unobservable variables and measurement error. *Journal of Marketing Research, 18*(1), 39–50.
- Garrido, L. E., Abad, F. J., & Ponsoda, V. (2013). A new look at Horn's parallel analysis with ordinal variables. *Psychological Methods, 18*(4), 454–474.
- Green, S. B., & Yang, Y. (2009). Reliability of summed item scores using structural equation modeling: An alternative to coefficient alpha. *Psychometrika, 74*(1), 155–167.
- Hancock, G. R. (2001). Effect size, power, and sample size determination for structured means modeling and MIMIC approaches to between-groups hypothesis testing of means on a single latent construct. *Psychometrika, 66*(3), 373–388.
- Hattori, M., Zhang, G., & Preacher, K. J. (2017). Multiple local solutions and geomin rotation. *Multivariate Behavioral Research, 52*(6), 720–731.
- Henseler, J., Ringle, C. M., & Sarstedt, M. (2015). A new criterion for assessing discriminant validity in variance-based structural equation modeling. *Journal of the Academy of Marketing Science, 43*(1), 115–135.
- Hoenig, J. M., & Heisey, D. M. (2001). The abuse of power: The pervasive fallacy of power calculations for data analysis. *The American Statistician, 55*(1), 19–24.
- Hu, L., & Bentler, P. M. (1999). Cutoff criteria for fit indexes in covariance structure analysis. *Structural Equation Modeling, 6*(1), 1–55.
- Lorenzo-Seva, U., & ten Berge, J. M. F. (2006). Tucker's congruence coefficient as a meaningful index of factor similarity. *Methodology, 2*(2), 57–64.
- Meade, A. W., & Craig, S. B. (2012). Identifying careless responses in survey data. *Psychological Methods, 17*(3), 437–455.
- Morris, T. P., White, I. R., & Crowther, M. J. (2019). Using simulation studies to evaluate statistical methods. *Statistics in Medicine, 38*(11), 2074–2102.
- Roemer, E., Schuberth, F., & Henseler, J. (2021). HTMT2 — an improved criterion for assessing discriminant validity in structural equation modeling. *Industrial Management & Data Systems, 121*(12), 2637–2650.
- Sass, D. A., Schmitt, T. A., & Marsh, H. W. (2014). Evaluating model fit with ordered categorical data within a measurement invariance framework: A comparison of estimators. *Structural Equation Modeling, 21*(2), 167–180.
- Satorra, A. (2000). Scaled and adjusted restricted tests in multi-sample analysis of moment structures. In R. D. H. Heijmans, D. S. G. Pollock, & A. Satorra (Eds.), *Innovations in multivariate statistical analysis* (pp. 233–247). Kluwer.
- Satorra, A., & Bentler, P. M. (2001). A scaled difference chi-square test statistic for moment structure analysis. *Psychometrika, 66*(4), 507–514.
- Satorra, A., & Bentler, P. M. (2010). Ensuring positiveness of the scaled difference chi-square test statistic. *Psychometrika, 75*(2), 243–248.
- Savalei, V. (2021). Improving fit indices in structural equation modeling with categorical data. *Multivariate Behavioral Research, 56*(3), 390–407.
- Steenkamp, J.-B. E. M., & Baumgartner, H. (1998). Assessing measurement invariance in cross-national consumer research. *Journal of Consumer Research, 25*(1), 78–90.
- Velicer, W. F. (1976). Determining the number of components from the matrix of partial correlations. *Psychometrika, 41*(3), 321–327.
- Velicer, W. F., Eaton, C. A., & Fava, J. L. (2000). Construct explication through factor or component analysis: A review and evaluation of alternative procedures for determining the number of factors or components. In R. D. Goffin & E. Helmes (Eds.), *Problems and solutions in human assessment* (pp. 41–71). Kluwer.
- Xia, Y., & Yang, Y. (2019). RMSEA, CFI, and TLI in structural equation modeling with ordered categorical data: The story they tell depends on the estimation methods. *Behavior Research Methods, 51*(1), 409–428.
