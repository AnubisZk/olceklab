# Yöntem notları (Faz 2–5: M5–M10, M12)

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

# Ölçme değişmezliği (M8, Faz 3)

- **Sürekli yaklaşım:** `lavaan::cfa(model, group, group.label, group.equal, group.partial, estimator, likelihood, std.lv)`.
  Adımlar: biçimsel → metrik (`loadings`) → skaler (+ `intercepts`) → isteğe bağlı katı (+ `residuals`).
  Grup sırası `group.label` ile açıkça verilir; ilk grup referanstır (Veri sayfasındaki geçerli değer sırası ya da seçilen referans).
- **Kategorik yaklaşım:** `semTools::measEq.syntax(parameterization = "theta", ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016")`
  ile her adımın sözdizimi üretilir ve `lavaan::cfa(..., estimator = "WLSMV", parameterization = "theta")` ile kestirilir.
  Adımlar: biçimsel → eşikler → + yükler → + kesişimler → + artık varyanslar. Bütün maddeler üç kategoriliyse eşik adımı
  biçimselle eşdeğerdir ve atlanır; ikili madde içeren ölçeklerde kategorik değişmezlik v1'de kapalıdır.
- **Kararlar:** Δ = kısıtlı − daha az kısıtlı. ΔCFI ≥ −,01; ΔRMSEA ≤ ,015; ΔSRMR ≤ ,030 (yük adımı) / ≤ ,010 (diğer adımlar);
  Δχ² p ≥ ,05. Her ölçüt ayrı sütundadır; isteğe bağlı birleşik kural ΔCFI VE/VEYA ΔRMSEA'dır. MLR ve WLSMV'de Δ'lar
  ölçeklenmiş indekslerle hesaplanır. ΔSRMR varsayılan olarak Bentler'in ortalamasız SRMR'siyle hesaplanır (§11.3).
- **Kısmi değişmezlik:** `lavTestScore(univariate = TRUE)` skor testleri; parametre adları `parTable` ile okunur. Sıralama
  ML'de χ²'ye, MLR/WLSMV'de ölçeklenmiş χ²'ye göredir. Serbest bırakma kullanıcının onayıyla yapılır ve bütün gruplarda
  geçerlidir (`group.partial`). Yükü serbest bırakılan maddenin kesişimi varsayılan olarak kısıtlı kalır.
- **Gizil ortalamalar:** her faktörde yükü ve kesişimi (kategorikte eşikleri) değişmez en az iki madde varsa hesaplanır.
  Skaler modelle eşdeğer bir model kurulur: referans grupta ortalama 0, varyans 1; diğer gruplarda ortalama κ ve varyans ψ
  etiketlenir ve `d := κ / sqrt(((n₁ − 1) · 1 + (n₂ − 1) · ψ) / (n₁ + n₂ − 2))` (Hancock, 2001) ya da `d := κ / 1`
  (referans grup SS'si) tanımlanır. SH ve güven aralığı lavaan'ın delta yönteminden gelir. Motor iki modelin χ²'sinin
  aynı olduğunu denetler.

# Monte Carlo simülasyonu (M9, Faz 4)

> Her simülasyon tablosu, şekli ve paketi şu etiketi taşır: **SİMÜLASYON — sentetik veri; ölçeğin geçerliğine kanıt değildir.**
> Simülasyon bir tasarım aracıdır (örneklem büyüklüğü, kestirici seçimi, DIF'e duyarlılık); gerçek verinin yerini tutmaz.

## Popülasyon ve veri üretimi

- Tanım: faktörler ve maddeleri (basit yapı), standardize yükler Λ, faktör korelasyonları Ψ, veri türü (sürekli/sıralı),
  sıralı veride kategori oranları (ortak ya da madde başına), gruplar (ilki referans; diğerlerinde gizil ortalama α_g ve
  isteğe bağlı gizil varyans) ve DIF senaryoları (eşik/kesişim kayması ya da yük farkı). Kontrol (değişmez) senaryosu her
  zaman birinci senaryodur. Tanım R'de doğrulanır (`normalize_population`); geçersiz tanım `422 invalid_population` döndürür.
- Gizil yanıt yaklaşımı: η ~ N(α_g, Ψ_g) (`MASS::mvrnorm`), y* = Λ_g η + ε, ε ~ N(0, Θ), Θ = I − diag(ΛΨΛ′) (referans
  grupta var(y*) = 1). Sıralı veride y*, referans grubun kategori oranlarından Φ⁻¹ ile türetilen eşiklerde kesilir. Eşik/kesişim
  DIF'i odak gruptaki eşikleri (kesişimi) SD(y*) = 1 biriminde kaydırır; yük DIF'inde Θ sabit kalır.
- Grup büyüklükleri: n₁ = round(N · oran₁), son grup N − Σ. Oranlar R'de normalleştirilir (70/30 ≡ ,7/,3).
- **RNG ve tohum kuralı:** her tekrardan önce `RNGkind("Mersenne-Twister", "Inversion", "Rejection")` ve
  `set.seed(seed + 10000 · koşul + tekrar)`. Tüketim sırası sabittir: gruplar sırayla; her grupta önce η, sonra ε (n × p).
  Paralel analiz referansı koşul başına tekrar = 0 tohumuyla üretilir. Böylece sonuç, parça büyüklüğünden, işçi sayısından
  ve işin kesilip sürdürülmesinden bağımsızdır (testle doğrulanır).
- Koşul ızgarası: N × oran × senaryo; senaryo en hızlı değişir. Koşul indeksi tohuma girer; `params.json` her koşulun ilk ve
  son tohumunu yazar.

## Her tekrarda yapılan analizler

- **Ortak rastgele sayılar (MC-6):** aynı tekrar seçilen bütün kestiricilerle (ML, MLR, WLSMV) aynı veri üzerinde analiz edilir.
- **DFA:** referans grupta `lavaan::cfa(std.lv = TRUE)`; WLSMV'de `ordered`. Hata türleri ayrı sayılır (MC-9): yakınsamama,
  uygunsuz çözüm (`post.check` başarısız), grupta boş kategori (WLSMV), diğer. Hatalı tekrarlar atılmaz; birincil özetler
  uygun çözümlerden, duyarlılık özetleri yakınsayan çözümlerden hesaplanır.
- **Ölçme değişmezliği:** biçimsel → metrik → skaler (M8 ile aynı çağrılar; WLSMV'de `measEq.syntax`, theta,
  Wu–Estabrook). Δχ² `lavTestLRT` (ML standart, MLR Satorra–Bentler 2001 → negatifse 2010, WLSMV Satorra 2000); ΔCFI, ΔRMSEA,
  ΔSRMR (Bentler ortalamasız) ayrı ölçütlerdir. Her adım ayrı sınanır; ayrıca "ardışık" oran (önceki adımlar Δχ² ile
  reddedilmediyse reddetme) verilir.
- **Güvenirlik:** α (`psych::alpha`) ve ω (`semTools::compRelSEM`, `obs.var = TRUE`).
- **Paralel analiz (isteğe bağlı):** koşul başına bir kez üretilen referans özdeğerlerle (varsayılan; MC-12) ya da her tekrarda
  `psych::fa.parallel` ile.

## Gerçek değerler ve özetler

- Sürekli veride gerçek değer üretim parametresidir. Sıralı veri ML/MLR ile analiz edilirse kesikli puanların kesin popülasyon
  kovaryansı (`pbivnorm` ile iki değişkenli normal olasılıklar) hesaplanır ve model bu matrise uydurularak **sözde-gerçek**
  değerler elde edilir; WLSMV'de gerçek değerler y* ölçeğindeki üretim parametreleri ve eşiklerdir. Tablolarda kaynak
  ("üretim" / "sözde-gerçek") ayrı sütundadır. Popülasyon α'sı aynı popülasyon matrisinden hesaplanır.
- Yanlılık = ortalama − gerçek; göreli yanlılık = yanlılık / gerçek (|gerçek| ≥ ,10 ise); standartlaştırılmış yanlılık =
  yanlılık / ampirik SS; SH göreli yanlılığı = (ortalama SH − ampirik SS) / ampirik SS; kapsama = %95 GA'nın gerçek değeri
  içerme oranı; RMSE. Monte Carlo standart hataları: yanlılık için SS/√R, oranlar için √(p(1 − p)/R).
- **Örneklem önerisi (MC-11):** ölçütlerin (uygun çözüm oranı ≥ ,95; |göreli yanlılık| ≤ ,10; |SH göreli yanlılığı| ≤ ,10;
  kapsama ,91–,98; DIF senaryosunda seçilen adımda güç ≥ ,80) o N'de **ve ızgaradaki bütün daha büyük N'lerde** sağlandığı en
  küçük N. Hiçbir N'de sağlanmazsa "ızgarada yok" yazılır.
- Şekiller: güç eğrisi (her senaryo × kestirici × adım × oran için Δχ² reddetme oranı; kontrol senaryosunda I. tip hata) ve
  göreli yanlılık ısı haritası (gerçek değeri 0 olan parametrede standartlaştırılmış yanlılık, * ile işaretli).

## İş sistemi

- `POST /simulations` işi oluşturur; tekrarlar parçalara bölünür ve `mirai` işçilerinde çalışır (en fazla işçi sayısı kadar
  parça aynı anda). Her parça kendi `.rds` dosyasına atomik olarak yazılır. `POST /jobs/{id}/cancel` yeni parça başlatmaz;
  `POST /jobs/{id}/resume` yalnızca eksik parçaları çalıştırır. `GET /jobs/{id}` ilerlemeyi, geçen ve kalan süreyi R'de
  biçimlenmiş metinle verir.
- `POST /simulations/estimate`: en büyük N'li koşulda iki tekrar ölçülür ve işçi sayısına bölünür; **üst sınırdır**.
- Çevrim içi mod (`ONLINE_LIMITS=true`): tekrar × koşul (`ONLINE_MAX_REPLICATIONS_X_CONDITIONS`), işçi
  (`ONLINE_MAX_WORKERS`) ve süre (`ONLINE_JOB_TIMEOUT_SECONDS`) sınırları uygulanır; aşılırsa bağımsız paket önerilir.
- İş dosyaları yalnızca sentetik veriden türetilmiş özetleri içerir (`JOBS_DIR`); yüklenen veri diske yazılmaz.
  "DFA sonucundan kur" yalnızca özet parametreleri (standardize yükler, faktör korelasyonları, kategori oranları) taşır.

## Bağımsız R paketi

`GET /simulations/{id}/package` bir .zip verir: `params.json` (tanım, RNG, tohum kuralı, koşullar, kestirilen nicelikler),
`02_simulasyon.R` (motorun fonksiyonlarının birebir kopyası; kesilirse eksik parçalardan devam eder), `03_gercek_degerler.R`,
`05_ozet.R`, `04_calistir.sh` (`CEKIRDEK=4 sh 04_calistir.sh`) ve `BENIOKU.md`. Paket aynı sürümlerle aynı tekrarları ve
aynı özeti üretir (ayrı süreçte test edilir); sürüm farkında betikler uyarı verir.

## DFA sonucundan popülasyon

Örnek kestirimleri gerçek değer kabul edildiği için sonuçlar iyimser olabilir (Hoenig ve Heisey, 2001); "duyarlılık
kaydırması" bütün standardize yükleri verilen miktar kadar azaltır. Model ML/MLR ile kestirildiyse yalnızca sürekli veri
üretilir (MC-7). İkinci düzey ve çapraz yüklü modellerden popülasyon kurulmaz.

# Raporlama (M10, Faz 5)

- `POST /reports/docx` (`analysis_ids`, `lang`, `title`) seçilen analiz kayıtlarından bir Word belgesi kurar (`officer` +
  `flextable`). `POST /reports/preview` aynı metinleri ve tablo numaralarını önizleme için döndürür.
- **Tablolar:** her tablo kaydın `rows_fmt` değerleriyle (R'nin biçimlediği metin) doldurulur; hiçbir sayı yeniden
  hesaplanmaz ya da biçimlenmez. APA 7 düzeni: "Tablo N" (kalın), başlık (italik), `flextable::theme_apa`, sayı sütunları
  sağa yaslı, altında "*Not.*" + kaydın notu (kaynak fonksiyon ve ayarlar) + sürüm satırı ve analiz kimliği. Tablolar rapor
  boyunca ardışık numaralanır.
- **Yöntem/Bulgular taslak metni:** modül başına önceden yazılmış şablon cümleleri (TR/EN). Sayılar tabloların biçimli
  değerlerinden alınır; bir değer kayıtta yoksa o cümle yazılmaz. Bu bölüm **yapay zekâ kullanmaz**; test, şablon
  metinlerdeki her sayının kayıtta bulunduğunu denetler. İstatistik simgeleri (χ, p, α, ω, κ, d) italik yazılır.
- Simülasyon kayıtlarında SİMÜLASYON etiketi ve bir "Sınırlılıklar" paragrafı (popülasyon modeline bağlılık, ızgara
  çözünürlüğü, Hoenig ve Heisey, 2001; sözde-gerçek değerler) her zaman eklenir.
- **Kaynakça:** metinde anılan yöntem kaynakları ile R'nin ve kullanılan paketlerin kendi `citation()` kayıtları.
- **Yazılım ve tekrarlanabilirlik bölümü:** R ve paket sürümleri, RNG türü, her analizin kimliği, tohumu ve veri özeti
  (SHA-256).
- **CSV:** `GET /analyses/{id}/tables/{tid}/csv?lang=tr|en&values=formatted|raw`. Biçimli dosya ekrandaki metindir
  (TR'de `;` ayırıcı, UTF-8 BOM); ham dosya sayıları 17 anlamlı basamakla (`%.17g`, nokta ondalık) verir.
- **Grafikler:** her grafiğin altında SVG ve PNG indirme düğmeleri vardır. SVG, ekrandaki çizimin kendisidir; PNG bu SVG'nin
  2× ölçekle rasterleştirilmiş hâlidir. Çizimdeki bütün sayılar R'den gelir.

# Tekrarlanabilirlik ve proje dosyası (M12, Faz 5)

- Her analizin bağımsız R betiği (Faz 1'den beri): veri yolu yer tutucusu, paket sürümü, RNG türü ve tohum denetimi.
- **Dışa aktarma** `POST /projects/export` (`dataset_id`, `analysis_ids`, `include_data`, `data_consent`) bir
  `.olceklab.zip` verir:
  - `manifest.json`: biçim sürümü, motor sürümleri, veri adı/kaynağı/SHA-256 özeti/boyutu, sütun rollerinin ve temizleme
    kurallarının **özgün istek gövdeleri**, analizlerin sırası ve her birinin özgün istek gövdesi;
  - `analyses/NN_modul.json`: tam sonuç kayıtları (17 anlamlı basamak); `scripts/NN_modul.R`: R betikleri;
  - `versions.json`: R, paketler, BLAS/LAPACK, RNG; `BENIOKU.md`;
  - `data/<dosya>`: yalnızca `include_data` **ve** `data_consent` ile (yoksa `422 consent_required`). Özgün dosya baytları
    yalnızca bellekte tutulur; örnek veri setleri pakete eklenmez, adıyla yeniden yüklenir.
- **İçe aktarma** `POST /projects/import` (zip baytları) manifest'i okur, veri dosyası varsa SHA-256 özetini denetler
  (uyuşmazsa `422 hash_mismatch`) ve sürüm uyuşmazlıklarını (R, paketler, BLAS) uyarı olarak döndürür.
- **Yeniden üretim** `POST /projects/{id}/reproduce`: veri projeden, örnek veriden ya da kullanıcının yeniden yüklediği
  dosyadan (`dataset_id`; özet projedekiyle aynı olmalıdır) alınır; roller ve temizleme özgün isteklerle uygulanır; analizler
  özgün istek gövdeleriyle aynı uç nokta fonksiyonlarıyla işçide yeniden çalıştırılır. Her kayıt, eskisiyle aynı JSON
  serileştirmesinden (17 anlamlı basamak) geçirilip `results` ve tabloların ham ve biçimli değerleri yaprak yaprak
  karşılaştırılır; sonuç "Aynı (n değer)" ya da "Farklı: k / n değer; en büyük sayısal fark …" olarak raporlanır. Kimlik,
  zaman damgası ve betik karşılaştırılmaz. Yeniden üretilen oturum arayüze geri yüklenir; analizlere devam edilebilir.
- Gizlilik: zip yalnızca işlem süresince geçici dizinde bulunur ve hemen silinir (test edilir); içe aktarılan proje bellekte
  ve oturum süresiyle (SESSION_TTL_MINUTES) tutulur.
