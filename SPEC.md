# ÖlçekLab — Ölçek Geliştirme ve Uyarlama Analiz Platformu
## Codex için teknik şartname (v1.0, 2 Kasım 2026)

> Çalışma adı: **ÖlçekLab**. Ad değiştirilebilir.
> Bu belge, Codex'e (ya da başka bir kodlama ajanına) verilmek üzere yazılmıştır. Belgenin tamamını depo köküne `SPEC.md` olarak koy. Bölüm 0'ı ayrıca `AGENTS.md` olarak kaydet.
> Belge sahibi: Zafer Savaş Kıvılcım (Altıeylül BİLSEM).

---

## 0. Kodlama ajanı için çalışma kuralları (AGENTS.md)

1. **Sayısal sonuçların tek kaynağı R motorudur.** Bütün istatistiksel hesaplar `engine/` altındaki R kodunda, aşağıda adı verilen R paketleriyle yapılır. JavaScript/TypeScript ve Python tarafında istatistik yeniden hesaplanmaz. Yapay zekâ modülü hiçbir sayı üretmez.
2. **Asla sonuç uydurma.** Bir fonksiyon hata verirse hatayı kullanıcıya göster. Örnek, sahte ya da yer tutucu sayı gösterme. Testlerde beklenen değerleri elle yazma; Bölüm 11'deki referans değerleri kullan ya da referans fonksiyonu doğrudan çağırarak üret.
3. **Aşamalı çalış.** Bölüm 12'deki faz sırasını izle. Her fazın kabul ölçütlerini sağlayan testler geçmeden bir sonraki faza geçme.
4. **Her değişiklikten sonra testleri çalıştır.** R için `testthat`, ön yüz için `vitest` ve uçtan uca testler için `playwright`.
5. **Bilmediğin bir dış API'yi varsayma.** EVREN API'sinin ayrıntıları (uç noktalar, kimlik doğrulama, model adları) bu belgede yoktur. Bağdaştırıcıyı yapılandırılabilir yaz, gerçek değerleri `.env` dosyasından oku ve belgelenmemiş alanları uydurma.
6. **Gizlilik varsayılandır.** Yüklenen veriler diske kalıcı yazılmaz (Bölüm 10).
7. **Arayüz dili Türkçedir**, İngilizce seçeneği vardır. Kod, değişken ve fonksiyon adları İngilizcedir.
8. Paket sürümlerini `renv.lock` ve `package-lock.json` ile sabitle. Kullandığın sürümleri `docs/VERSIONS.md` dosyasına yaz.

---

## 1. Amaç ve kapsam

ÖlçekLab, öğretmenlerin, lisansüstü öğrencilerin ve araştırmacıların ölçek geliştirme ve uyarlama çalışmalarında gereken analizleri tek bir web arayüzünden, tekrarlanabilir biçimde yapmalarını sağlar:

- veri temizleme ve madde analizi,
- faktör sayısının belirlenmesi (**paralel analiz** dâhil),
- açımlayıcı ve doğrulayıcı faktör analizi,
- güvenirlik ve geçerlik göstergeleri,
- gruplar arası ölçme değişmezliği,
- **Monte Carlo simülasyonu** ile örneklem büyüklüğü ve güç analizi,
- APA 7 biçiminde Türkçe/İngilizce raporlama,
- isteğe bağlı, **çevrimdışı çalışabilen yapay zekâ yorum asistanı** (yerel model ya da EVREN).

Platform iki biçimde çalışır:
- **Yerel/çevrimdışı mod:** Her şey kullanıcının bilgisayarında, internet olmadan Docker Compose ile çalışır. Öğrenci verisiyle çalışırken önerilen mod budur.
- **Çevrim içi mod:** Ön yüz Netlify'da, R motoru Hugging Face Spaces'te (Docker) çalışır. Demo ve anonim veriler için uygundur.

Kapsam dışı (v1): Madde tepki kuramı (IRT), ağ psikometrisi (EGA), boylamsal değişmezlik. Bunlar Bölüm 13'te ileri sürüm olarak listelenmiştir.

---

## 2. Temel ilkeler

| İlke | Uygulama |
|---|---|
| Doğruluk | Hesaplar yalnızca olgun R paketleriyle yapılır: lavaan, psych, semTools, GPArotation, MASS. Her çıktıda paket sürümleri gösterilir. |
| Tekrarlanabilirlik | Her analiz; kullanılan ayarları, tohum değerini, paket sürümlerini ve analizi baştan üreten **bağımsız bir R betiğini** dışa aktarır. |
| Şeffaflık | Her tablonun altında hangi fonksiyonun hangi ayarlarla çalıştığı yazar ("Kaynak: psych::fa.parallel, fa = 'pc', n.iter = 1000, quant = .95"). |
| Gizlilik | Veriler bellekte işlenir, kalıcı saklanmaz. Yapay zekâya varsayılan olarak ham veri değil, yalnızca sonuç özetleri gönderilir. |
| Sınırların görünürlüğü | Simülasyon çıktıları her yerde "SİMÜLASYON — sentetik veri; geçerlik kanıtı değildir" etiketiyle gösterilir. |
| Yapay zekâ sınırı | Yapay zekâ yorumlar ve açıklar; analiz kararı vermez ve sayı üretmez. Yazdığı metindeki sayılar otomatik denetlenir (Bölüm 7, M11). |

---

## 3. Mimari

```
┌──────────────────────────────┐        ┌───────────────────────────────────────┐
│  Ön yüz (web)                │  HTTP  │  R analiz motoru (plumber API)        │
│  Vite + React + TypeScript   │◄──────►│  lavaan · psych · semTools · MASS     │
│  Türkçe arayüz, grafikler    │  JSON  │  iş kuyruğu (mirai) · rapor (officer) │
└──────────────┬───────────────┘        └───────────────────┬───────────────────┘
               │                                            │
               │ (isteğe bağlı)                             │ sonuç özeti (JSON)
               ▼                                            ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  Yapay zekâ ağ geçidi (ai-gateway, Node/TypeScript)                          │
│  sağlayıcılar: none | local (Ollama / llama.cpp, OpenAI uyumlu) | evren      │
│  sayı denetleyici · istem kayıtları · çıktı etiketleme                       │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Neden R?** Kategorik verilerde WLSMV kestirimi, Wu ve Estabrook (2016) tanımlamalı ölçme değişmezliği ve skor testleri için lavaan/semTools'a eşdeğer olgun bir Python veya JavaScript uygulaması yoktur. Bu nedenle bütün istatistik R'de yapılır.

### 3.1 Dağıtım biçimleri

| Mod | Bileşenler | Not |
|---|---|---|
| Yerel (çevrimdışı) | `docker compose up` → `web` (5173), `engine` (8000), `ai-gateway` (8787), isteğe bağlı `ollama` (11434) | İnternet gerekmez. Simülasyon sınırları yalnızca makinenin gücüyle sınırlıdır. |
| Çevrim içi | `web` → Netlify; `engine` → Hugging Face Spaces (Docker SDK, `app_port: 7860`) | Simülasyon için tekrar sınırı uygulanır (Bölüm 7, M9). Yapay zekâ varsayılan olarak kapalıdır. |
| EVREN | `ai-gateway` → EVREN LLM API; isteğe bağlı olarak büyük simülasyonlar için EVREN hesaplama düğümü | Uç nokta ve kimlik bilgileri `.env` dosyasından okunur (Bölüm 7, M11 ve Bölüm 14). |

---

## 4. Teknoloji yığını

- **R motoru:** R ≥ 4.4; plumber (API); lavaan, semTools, psych, GPArotation, MASS; mirai (arka plan işleri); officer ve flextable (Word raporu); jsonlite; readxl; testthat.
- **Ön yüz:** Vite, React, TypeScript; TanStack Query; grafikler için Apache ECharts; tablolar için TanStack Table; i18next (TR/EN); vitest; playwright.
- **Yapay zekâ ağ geçidi:** Node 20+, TypeScript, Fastify. OpenAI uyumlu sohbet tamamlama istemcisi; Ollama'nın varsayılan adresi `http://localhost:11434/v1`.
- **Paketleme:** Docker; docker-compose.yml; Hugging Face Space için ayrı `engine/Dockerfile`.
- **Tasarım dili:** ARES-1 (koyu arka plan `#070B10`, camgöbeği `#00E5FF` ve kehribar `#FFB300` vurgular, JetBrains Mono). Açık tema da olmalıdır; erişilebilirlik için kontrast oranı en az 4.5:1.

---

## 5. Klasör yapısı

```
olceklab/
├── AGENTS.md                 # Bölüm 0
├── SPEC.md                   # bu belge
├── docker-compose.yml
├── .env.example              # AI_PROVIDER, EVREN_*, OLLAMA_*, ENGINE_URL, ONLINE_LIMITS
├── engine/                   # R analiz motoru
│   ├── Dockerfile
│   ├── renv.lock
│   ├── plumber.R             # API giriş noktası
│   ├── R/
│   │   ├── data_clean.R      # M1
│   │   ├── item_analysis.R   # M2
│   │   ├── suitability.R     # M3
│   │   ├── factor_number.R   # M4 (paralel analiz, MAP, scree)
│   │   ├── efa.R             # M5
│   │   ├── cfa.R             # M6
│   │   ├── reliability.R     # M7
│   │   ├── invariance.R      # M8
│   │   ├── simulation/       # M9
│   │   │   ├── population.R  # popülasyon modeli kurma
│   │   │   ├── generate.R    # veri üretimi
│   │   │   ├── replicate.R   # tek tekrar analizi
│   │   │   ├── summarise.R   # özetleme
│   │   │   └── export.R      # bağımsız R paketi dışa aktarma
│   │   ├── report.R          # M10
│   │   ├── script_export.R   # M12
│   │   └── jobs.R            # iş kuyruğu
│   └── tests/testthat/
├── web/                      # ön yüz
│   ├── src/pages/ ...        # Bölüm 9
│   └── tests/
├── ai-gateway/               # M11
│   ├── src/providers/{none,local,evren}.ts
│   ├── src/numberCheck.ts
│   └── tests/
└── docs/
    ├── VERSIONS.md
    ├── VALIDATION.md         # Bölüm 11 sonuçları
    └── USER_GUIDE_TR.md
```

---

## 6. Veri modeli

### 6.1 Veri seti
- Biçimler: CSV (UTF-8, `;` ya da `,` ayraçlı), XLSX. Türkçe karakterli sütun adları desteklenir.
- Kullanıcı yükleme sonrasında her sütunun rolünü belirler: `item` (madde), `group` (grup değişkeni), `id`, `ignore`.
- Madde ayarları: kategori sayısı (ör. 1–5), ters madde mi, alt boyut (isteğe bağlı).
- Veri seti oturum belleğinde tutulur; kimliği `dataset_id` olur. Veri SHA-256 özetiyle tanımlanır; veri kendisi saklanmaz.

### 6.2 Analiz kaydı (her modül çıktısı bu yapıda döner)
```json
{
  "analysis_id": "uuid",
  "module": "factor_number",
  "dataset_hash": "sha256:...",
  "settings": { "...": "..." },
  "seed": 20261030,
  "engine": { "R": "4.4.3", "packages": { "psych": "2.6.9", "lavaan": "0.7.2" } },
  "results": { "...": "modüle özgü, yalnızca R'den gelen sayılar" },
  "tables": [ { "id": "T1", "title_tr": "...", "columns": [], "rows": [], "note_tr": "Kaynak: ..." } ],
  "figures": [ { "id": "F1", "type": "scree", "data": {} } ],
  "warnings": [ "..." ],
  "r_script": "bu analizi baştan üreten R kodu",
  "created_at": "ISO-8601"
}
```

---

## 7. Modüller

Her modül için: **amaç → girdiler → R uygulaması → çıktılar → kabul ölçütleri.**

### M1 — Veri yükleme ve temizleme
- **Girdiler:** dosya, sütun rolleri, kurallar (aşağıda).
- **Kurallar (her biri açılıp kapatılabilir; kaç satırın neden çıkarıldığı raporlanır):**
  - eksik yanıtı olan satırlar (liste bazında silme; v1'de atama yok),
  - aralık dışı değerler,
  - bütün maddelere aynı yanıtı veren satırlar (düz yanıt),
  - grup değişkeni geçersiz olan satırlar,
  - ters maddelerin yeniden kodlanması.
- **Çıktı:** temizleme özet tablosu ("Ham: 279 → hatalı grup 2 → eksik 5 → düz yanıt 16 → analiz: 256"), temiz veri (yalnızca oturumda).
- **Kabul:** Bölüm 11.3'teki BİDEKÇET temizleme sayıları birebir elde edilir.

### M2 — Betimsel istatistikler ve madde analizi
- **R:** `psych::describe`, `psych::alpha` (`item.stats$r.drop`, `alpha.drop`), kategori frekansları, taban ve tavan yüzdeleri.
- **Çıktı:** madde tablosu (ortalama, SS, çarpıklık, basıklık, düzeltilmiş madde-toplam r, madde silinirse alfa), kategori dağılımı ısı haritası.
- **Uyarılar:** madde-toplam r < .30; boş kategori; |çarpıklık| > 2.

### M3 — Faktör analizine uygunluk
- **R:** `psych::KMO`, `psych::cortest.bartlett`, `psych::mardia`.
- **Çıktı:** KMO (toplam ve madde bazında MSA), Bartlett χ², sd, p, Mardia b1p, b2p ve testleri.

### M4 — Faktör sayısının belirlenmesi (paralel analiz modülü — öncelikli)
- **Paralel analiz (Horn, 1965)** — `psych::fa.parallel` sarmalanır; ayrıca motor içinde şeffaf bir yeniden uygulama (`factor_number.R::parallel_manual`) bulunur ve testlerde ikisinin sonuçları karşılaştırılır.
  - Ayarlar:
    - `extraction`: `pc` | `fa` | `both`
    - `correlation`: `pearson` | `polychoric`
    - `reference`: `simulated_normal` | `resampled` (sütun permütasyonu)
    - `n_iter` (varsayılan 1000)
    - `criterion`: `quantile` (varsayılan .95) | `mean`
    - `fm` (FA için; varsayılan `minres`)
    - `seed`
  - Çıktı: gözlenen ve referans özdeğer tablosu, önerilen faktör/bileşen sayısı, kesişimli scree grafiği.
- **Velicer MAP testi:** `psych::vss(...)$map`; önerilen sayı.
- **Klasik ölçütler:** özdeğer > 1 sayısı (yalnızca bilgi olarak) ve scree grafiği.
- **Karar destek kutusu** (şablon metin; yapay zekâ değil): "Paralel analiz X, MAP Y faktör önermektedir. Faktörler arası korelasyonlar yüksek olduğunda paralel analiz faktör sayısını düşük kestirebilir; faktör sayısı kararı kuramsal yapı ve rakip DFA modelleriyle birlikte verilmelidir." Bu uyarı, ilgili simülasyon bulgusuna dayanır. Kullanıcı M9 ile kendi yapısı için bunu sınayabilir.
- **Kabul:** Bölüm 11'deki referans veri setlerinde `psych::fa.parallel` ile aynı önerilen sayı; BİDEKÇET verisinde iki kademede de 2 bileşen; aynı tohumla tekrar çalıştırıldığında aynı özdeğerler.

### M5 — Açımlayıcı faktör analizi
- **R:** `psych::fa` (`fm`: `ml`, `minres`, `pa`; `rotate`: `oblimin`, `promax`, `varimax`, `geominQ`), `cor`: `cor` | `poly`.
- **Çıktı:** örüntü katsayıları (kullanıcının belirlediği eşik altı gizlenebilir, ör. .30), ortak varyanslar, faktörler arası korelasyonlar, açıklanan varyans, çapraz yük ve Heywood uyarıları.
- **Not:** Faktör sırası ve işaretleri yazılıma göre değişebilir; arayüz faktörleri yeniden sıralayıp adlandırmaya izin verir.

### M6 — Doğrulayıcı faktör analizi ve model karşılaştırma
- **Model kurucu:** maddeleri faktörlere sürükle-bırak → otomatik lavaan sözdizimi. Gelişmiş kullanıcılar için doğrudan sözdizimi düzenleyici. Hata kovaryansı ekleme.
- **R:** `lavaan::cfa`.
  - `estimator`: `ML` (`likelihood`: `normal` | `wishart`), `MLR`, `WLSMV` (`ordered = maddeler`).
  - `std.lv` seçeneği.
  - İsteğe bağlı Bollen–Stine: `test = "bollen.stine", bootstrap = B`; p değeri `lavInspect(fit, "test")$bollen.stine$pvalue` ile alınır.
- **Çıktı:** uyum indeksleri (χ², sd, p, χ²/sd, CFI, TLI, RMSEA ve %90 GA, SRMR; WLSMV'de `.scaled` değerler), standardize yükler, faktör korelasyonları, uygunsuz çözüm denetimi (`lavInspect(fit, "post.check")`), yol şeması (SVG).
- **Model karşılaştırma:** birden çok model aynı tabloda; iç içe modeller için `lavTestLRT` (ölçeklenmiş fark testi WLSMV/MLR'de otomatik), iç içe olmayanlar için AIC/BIC.
- **Modifikasyon indeksleri:** `modindices` ile gösterilir. Kuramsal gerekçe olmadan serbest bırakmanın riskleri hakkında sabit bir uyarı metni eşlik eder.
- **Kabul:** Bölüm 11.3'teki BİDEKÇET χ² değerleri (Wishart) birebir; HolzingerSwineford1939 için `lavaan` belgesindeki bilinen modelle aynı uyum değerleri.

### M7 — Güvenirlik ve geçerlik
- **R:**
  - `psych::alpha` (toplam ve alt boyut alfa);
  - `semTools::compRelSEM` (omega/CR; `obs.var` seçeneği gösterilir; WLSMV'de `ord.scale = TRUE`);
  - `semTools::AVE`;
  - `semTools::htmt` (`htmt2` seçeneği gösterilir).
- **Not:** HTMT için ham korelasyon ya da mutlak değer seçimi arayüzde açıkça yazılır, çünkü bu seçim sonucu değiştirebilir.
- **Çıktı:** faktör × gösterge tablosu, ,70 / ,50 / ,85 eşiklerine göre görsel işaretleme (eşikler ayarlanabilir).

### M8 — Ölçme değişmezliği ve gizil ortalamalar
- **Sürekli yaklaşım (ML/MLR):** biçimsel → metrik (`loadings`) → skaler (`intercepts`) → isteğe bağlı katı (`residuals`), `group.equal`.
- **Kategorik yaklaşım (WLSMV):** `semTools::measEq.syntax(..., parameterization = "theta", ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016")`. Metrik adımda eşik ve yük birlikte kısıtlanır.
- **Karar ölçütleri** (kullanıcı ayarlayabilir; varsayılanlar):
  - ΔCFI ≥ −,01 (Cheung & Rensvold, 2002),
  - ΔRMSEA ≤ ,015 (Chen, 2007),
  - Δχ² (α = ,05).
  - Çıktı tablosu her ölçütün kararını ayrı sütunda gösterir.
- **Kısmi değişmezlik sihirbazı** (Byrne vd., 1989):
  1. `lavTestScore` ile kısıtların skor testi tablosu gösterilir; parametre etiketleri `parTable` ile okunur hâle getirilir.
  2. Kullanıcı en büyük değerli kısıtı **kendisi onaylayarak** serbest bırakır (`group.partial`). Otomatik serbest bırakma yalnızca "öneri" olarak sunulur.
  3. Her adımda yeni Δχ², ΔCFI, ΔRMSEA gösterilir.
  4. "Veri güdümlü serbest bırakmalar bağımsız örneklemde doğrulanmalıdır" uyarısı sabittir.
- **Gizil ortalamalar:** referans grupta ortalama 0; diğer grupların farkı, SH, z, p ve d (fark / ilgili grubun gizil SS).
- **Kabul:** Bölüm 11.3'teki BİDEKÇET değişmezlik ve kısmi değişmezlik değerleri.

### M9 — Monte Carlo simülasyonu (çekirdek modül)

Muthén ve Muthén'in (2002) yaklaşımıyla, kullanıcının kendi ölçek yapısı için örneklem büyüklüğü, güç ve yöntem davranışını inceler. Bu modül, BİDEKÇET çalışmasında kullanılan simülasyonun genelleştirilmiş hâlidir; o çalışmanın kodu `docs/reference_simulation/` altında örnek olarak bulunur.

**9.1 Popülasyon modeli** — üç yoldan biriyle kurulur:
- (a) **Uydurulmuş modelden:** M6/M8'de kestirilen modelin parametreleri (yükler, eşikler/kesişimler, gizil kovaryanslar, gizil ortalamalar, artık varyanslar) alınır. Ham veri simülasyona aktarılmaz; yalnızca bu özet parametreler kullanılır.
- (b) **Elle tanım:** madde-faktör eşleşmesi, standardize yükler, faktör korelasyonları, kategori sayısı ve kategori oranları (eşikler bunlardan türetilir).
- (c) **JSON dosyasından içe aktarma** (`population.json`).

**9.2 Veri üretimi** (`generate.R`): gizil yanıt yaklaşımı.
- Gizil faktörler η ~ N(α_g, Ψ_g) dağılımından üretilir (`MASS::mvrnorm`).
- Gizil yanıtlar y* = Λη + ε olarak hesaplanır.
- Sıralı veri için y* eşiklerde kesilir; sürekli seçenek de vardır.
- Çok gruplu üretim desteklenir; grup oranları ayarlanabilir.

**9.3 Koşullar (tam çaprazlanmış ızgara):**
- toplam N listesi (ör. 300, 600, 1000, 1500),
- grup oranı (ör. 50/50, 70/30),
- **farklılık (DIF) senaryoları:** seçilen maddelerde ve seçilen grupta
  - eşik/kesişim kayması (SD(y*) cinsinden),
  - yük farkı,
  - "değişmez" kontrol senaryosu,
- kestirim yöntemi (ML, MLR, WLSMV),
- tekrar sayısı R (varsayılan 1000).

**9.4 Her tekrarda yapılan analizler** (kullanıcı seçer):
- paralel analiz ve MAP (önerilen sayı),
- AFA ile yapının doğru bulunma oranı. Ölçüt: faktörler en iyi permütasyonla eşlenir ve bütün maddeler doğru faktöre atanırsa yapı doğru bulunmuş sayılır;
- DFA uyumu, yükler, güvenirlik;
- rakip model karşılaştırması (ör. özgün yapı ile önerilen yapı);
- değişmezlik testleri (Δχ², ΔCFI, ΔRMSEA kararları).

**9.5 Çıktı ölçütleri:**
- yakınsama oranı ve uygun çözüm oranı (ayrı ayrı);
- boş kategori oranı;
- paralel analiz ve MAP'in önerdiği faktör sayısının dağılımı;
- AFA'da doğru yapı oranı;
- uyum indekslerinin ortalaması, SS ve 2,5–97,5 yüzdelikleri; iyi ve kabul edilebilir uyum oranları;
- parametre göreli yanlılığı, RMSE ve deneysel SS;
- alfa ve omega yanlılığı;
- değişmezlikte I. tip hata (kontrol senaryosu) ve güç (DIF senaryoları);
- her oran için Monte Carlo standart hatası;
- **örneklem büyüklüğü önerisi:** kullanıcının seçtiği ölçütlerin hepsini sağlayan en küçük N. Varsayılan ölçütler:
  - uygun çözüm ≥ ,95,
  - |göreli yanlılık| < ,10,
  - güç ≥ ,80.
  Rapor, hangi ölçütün Muthén ve Muthén'den (2002) geldiğini, hangisinin kullanıcı tanımlı olduğunu ayrı ayrı yazar.

**9.6 Gerçek değerler:** Yanlılık hesabı için her senaryoda büyük bir popülasyon örneklemi (ör. N = 200.000) üretilir ve aynı kestiricilerle analiz edilir.

**9.7 İş sistemi** (`jobs.R`, mirai):
- Simülasyon arka planda, parçalar hâlinde (ör. 250 tekrarlık) ve paralel işçilerle çalışır.
- Her parça diske `.rds` olarak yazılır, böylece iş kesilirse kaldığı yerden devam eder.
- Arayüzde ilerleme çubuğu, tahmini kalan süre, iptal ve devam düğmeleri vardır.
- Her tekrarın tohumu `seed + 10000*koşul + tekrar` biçimindedir; her veri seti tek başına yeniden üretilebilir.
- Hatalı tekrarlar atılmaz; hata mesajıyla birlikte kaydedilir ve oranı raporlanır.
- **Çevrim içi mod sınırları** (`.env` ile ayarlanır): toplam tekrar × koşul ≤ 2.000, en fazla 2 işçi, iş başına süre sınırı. Bu sınırı aşan işler için kullanıcıya bağımsız R paketi indirme seçeneği sunulur (9.8).
- Yerel modda sınır yoktur.

**9.8 Bağımsız paket dışa aktarma:** Simülasyon, bilgisayarda ya da EVREN gibi bir hesaplama ortamında çalıştırılabilecek bir zip olarak indirilebilir. Paketin içeriği:
- `params.json`,
- `02_simulasyon.R`,
- `03_gercek_degerler.R`,
- `04_calistir.sh`,
- `05_ozet.R`,
- `BENIOKU.md`.

**9.9 Etiketleme:** Simülasyon sonuç sayfaları, tabloları ve raporları kalıcı olarak "SİMÜLASYON — sentetik veri; ölçeğin geçerliğine kanıt değildir" etiketini taşır. Rapor modülü, simülasyon için hazır bir sınırlılıklar paragrafı ekler.

**Kabul:**
- Aynı tohum ve aynı sürümlerle iki çalıştırma birebir aynı sonucu verir.
- Kesilip yeniden başlatılan bir iş, kesintisiz çalışmayla aynı sonucu verir.
- Kontrol senaryosunda Δχ² I. tip hata oranı ,05 civarındadır (1000 tekrarla ,03–,07).
- `docs/reference_simulation` ile aynı ayarlar verildiğinde Bölüm 11.4'teki değerler elde edilir.

### M10 — Raporlama
- APA 7 biçiminde tablolar (Türkçe ondalık virgülü ya da İngilizce nokta seçeneğiyle), Word (`officer` + `flextable`) ve CSV dışa aktarma; grafikler SVG/PNG.
- **Yöntem/Bulgular taslak metni:** Önceden yazılmış şablon cümlelerdir; sayılar doğrudan sonuç JSON'undan yerleştirilir. Bu bölüm **yapay zekâ kullanmaz**.
- Her tablonun altında kaynak satırı bulunur (fonksiyon, ayarlar, sürüm).

### M11 — Yapay zekâ yorum asistanı (isteğe bağlı, varsayılan: kapalı)

**Sağlayıcılar** (`AI_PROVIDER`):
- `none`: varsayılan.
- `local`: tamamen çevrimdışı çalışır. Ollama ya da llama.cpp sunucusu kullanılır (OpenAI uyumlu `/v1/chat/completions`). Model adı `.env` dosyasından okunur. Yerel modda internet bağlantısı olmadan çalışmalıdır.
- `evren`: EVREN platformunun LLM API'si. Uç nokta, kimlik doğrulama başlığı ve model adı `.env` dosyasından okunur (`EVREN_BASE_URL`, `EVREN_API_KEY`, `EVREN_MODEL`). API OpenAI uyumluysa `local` istemcisi yeniden kullanılır; değilse `providers/evren.ts` içinde EVREN belgelerine göre ayrı bir bağdaştırıcı yazılır. **Bu ayrıntılar belgelenmeden varsayılmaz** (Bölüm 14).

**Görevleri:**
- seçilen analiz çıktısını sade Türkçeyle açıklamak,
- sonuçlara göre olası sonraki adımları önermek (ör. "kısmi değişmezlik sihirbazını deneyebilirsiniz"),
- kullanıcının sorduğu kavramları açıklamak.

**Yapamayacakları** (istem ve ağ geçidi düzeyinde zorunlu):
- sayı üretmek ya da hesaplamak,
- model seçmek veya kısıt serbest bırakmak,
- ham veriyi görmek. Varsayılan olarak yalnızca `results` ve `tables` gönderilir; ham veri gönderimi yerel modda bile ayrı bir onay gerektirir.

**Sayı denetleyici** (`numberCheck.ts`):
1. Yapay zekâ metnindeki bütün sayılar ayıklanır (Türkçe virgül, baştaki sıfırı yazılmayan değerler ve yüzdeler dâhil).
2. Her sayı, istemde gönderilen sonuç JSON'undaki değerlerle karşılaştırılır (yuvarlama toleransıyla).
3. Eşleşmeyen sayılar kırmızıyla işaretlenir ve metnin üstünde "Bu yanıtta sonuçlarda bulunmayan sayılar var" uyarısı çıkar.
4. Eşleşmeyen sayı içeren metin rapora eklenemez.

**Etiket ve kayıt:**
- Yapay zekâ metinleri her zaman "Yapay zekâ yorumu — doğrulayınız" etiketiyle gösterilir.
- Rapora yalnızca kullanıcı onayıyla ve etiketiyle eklenebilir.
- Her istem ve yanıt (ham veri olmadan) oturum günlüğüne yazılır. Bu günlük, makalelerdeki yapay zekâ kullanım beyanı için dışa aktarılabilir.

**Kabul:**
- Ağ bağlantısı kesik yerel modda `local` sağlayıcı çalışır.
- Sayı denetleyici, test metinlerinde uydurulmuş sayıları %100 yakalar.
- `none` modunda hiçbir dış istek gitmez.

### M12 — Tekrarlanabilirlik ve proje dosyası
- Her analiz için bağımsız çalışabilen bir R betiği üretilir (veri yolu yer tutucuyla).
- **Proje dışa aktarma** (`.olceklab.zip`) şunları içerir:
  - ayarlar,
  - sonuç JSON'ları,
  - R betikleri,
  - sürüm bilgisi,
  - veri özeti (SHA-256).
  Veri dosyası varsayılan olarak pakete eklenmez; eklenmesi için kullanıcının açık onayı gerekir.
- Proje içe aktarıldığında aynı veri yüklenirse sonuçlar yeniden üretilip karşılaştırılır.

---

## 8. API (R motoru, plumber)

| Yöntem | Yol | Açıklama |
|---|---|---|
| POST | `/datasets` | Dosya yükle → `dataset_id`, sütun önizlemesi |
| POST | `/datasets/{id}/roles` | Sütun rollerini ve madde ayarlarını kaydet |
| POST | `/datasets/{id}/clean` | M1 |
| POST | `/analyses/item` | M2 |
| POST | `/analyses/suitability` | M3 |
| POST | `/analyses/factor-number` | M4 |
| POST | `/analyses/efa` | M5 |
| POST | `/analyses/cfa` | M6 (tek model) |
| POST | `/analyses/cfa/compare` | M6 (çoklu model) |
| POST | `/analyses/reliability` | M7 |
| POST | `/analyses/invariance` | M8 |
| POST | `/analyses/invariance/score-tests` | M8 skor testleri |
| POST | `/simulations` | M9 işi başlat → `job_id` |
| GET | `/jobs/{id}` | durum, ilerleme, tahmini süre |
| POST | `/jobs/{id}/cancel` · `/jobs/{id}/resume` | iş denetimi |
| GET | `/simulations/{id}/results` | özet sonuçlar |
| GET | `/simulations/{id}/package` | bağımsız R paketi (zip) |
| POST | `/reports/docx` | M10 |
| GET | `/analyses/{id}/script` | M12 R betiği |
| GET | `/health` · `/versions` | sağlık ve sürüm bilgisi |

- Bütün yanıtlar Bölüm 6.2'deki yapıdadır.
- Hatalar `{ "error": { "code": "...", "message_tr": "...", "detail": "R hata metni" } }` biçimindedir.
- Uzun analizler (Bollen–Stine, büyük simülasyon) iş kuyruğuna gider.

---

## 9. Arayüz (sayfa akışı)

1. **Başlangıç:** yeni proje, proje içe aktarma, örnek veriyle deneme (HolzingerSwineford1939; psych içinden bir veri seti).
2. **Veri:** yükle → sütun rolleri → temizleme kuralları → temizleme özeti.
3. **Madde analizi** ve **uygunluk.**
4. **Faktör sayısı:** paralel analiz ayarları, scree grafiği, karar destek kutusu.
5. **AFA.**
6. **DFA:** model kurucu, rakip model karşılaştırma tablosu, yol şeması.
7. **Güvenirlik ve geçerlik.**
8. **Değişmezlik:** grup seçimi, adım adım sonuçlar, kısmi değişmezlik sihirbazı, gizil ortalamalar.
9. **Simülasyon:**
   - popülasyon modeli (uydurulmuş modelden ya da elle),
   - koşul ızgarası,
   - tahmini süre hesabı (çalıştırmadan önce birkaç tekrarla ölçülür),
   - iş takibi,
   - sonuç panoları (güç eğrileri, doğru yapı oranı, yanlılık ısı haritası, örneklem önerisi).
10. **Rapor:** tablo ve paragraf seçimi, Word/CSV dışa aktarma, simülasyon sınırlılık paragrafı.
11. **Yapay zekâ paneli** (açıksa): her sonuç sayfasında yan panel, sayı denetimi uyarıları.
12. **Ayarlar:** dil, ondalık biçimi, yapay zekâ sağlayıcısı, çevrim içi/yerel mod bilgisi, gizlilik bildirimi.

Her sonuç sayfasında "Bu analizin R kodunu indir" ve "Bu sonucu rapora ekle" düğmeleri bulunur.

---

## 10. Güvenlik ve gizlilik (KVKK)

- Yüklenen veriler diske kalıcı yazılmaz. Oturum belleği 60 dakika işlem olmadığında silinir. Simülasyon parçaları yalnızca sentetik veri içerir.
- Dosya boyutu sınırı (çevrim içi: 10 MB) ve satır sınırı ayarlanabilir.
- Yükleme ekranında, öğrenci verisinin kimlik bilgisi (ad, numara, T.C. kimlik no) içermemesi gerektiğini belirten bir uyarı ve "kimlik sütunlarını otomatik algıla ve kaldır" seçeneği bulunur.
- Çevrim içi modda HTTPS, CORS yalnızca ön yüz alan adına açık, istek hız sınırlaması.
- Yerel modda dışarıya hiçbir istek gitmez; telemetri yoktur. Yapay zekâ `none` ya da `local` olmalıdır.
- Gizlilik bildirimi `docs/` ve Ayarlar sayfasında yer alır.

---

## 11. Doğrulama ve test

### 11.1 Birim testleri (testthat)
- Her R fonksiyonu için girdi doğrulama ve hata yolu testleri.
- `factor_number.R::parallel_manual` ile `psych::fa.parallel` aynı tohumla aynı önerilen sayıyı verir.

### 11.2 Genel referans veri setleri
- `lavaan::HolzingerSwineford1939`: üç faktörlü klasik modelin uyumu; değerler testte `lavaan::cfa` doğrudan çağrılarak üretilir ve motor çıktısıyla karşılaştırılır.
- `psych` paketindeki bir kişilik veri seti (ör. `bfi`): paralel analiz, AFA ve alfa için.

### 11.3 BİDEKÇET regresyon testleri (özel; veriler depoya konmaz)

Ham veri KVKK kapsamında olduğu için bu testler yalnızca yerelde, `tests/private/` altında, veri dosyası mevcutsa çalışır. Beklenen değerler aşağıdadır; bunlar R 4.4.3 ve lavaan 0.7.2 ile doğrulanmıştır.

| Analiz | Ayar | Beklenen değer |
|---|---|---|
| Temizleme | Bölüm M1 kuralları | Ortaokul 253 → 250 (düz yanıt 3); Lise 279 → 277 (hatalı sınıf 2) → 256 (eksik 5, düz yanıt 16) |
| Toplam alfa (12 madde) | psych::alpha | Ortaokul .794; Lise .836 |
| KMO | psych::KMO | Ortaokul .805; Lise .821 |
| Paralel analiz | fa = "pc", n.iter = 1000 | Her iki kademede 2 bileşen |
| DFA Model 4 χ² | ML, likelihood = "wishart" | Ortaokul 147.844 (sd 48); Lise 133.325 (sd 48) |
| DFA Model 1 χ² | aynı | Ortaokul 179.058 (sd 51); Lise 178.149 (sd 51) |
| Δχ² Model 1–Model 4 | anova | Ortaokul 31.21 (sd 3); Lise 44.82 (sd 3) |
| Değişmezlik χ² | wishart, std.lv | Biçimsel 281.168 (96); Metrik 299.621 (104); Skaler 319.77 (112) |
| Kısmi metrik | group.partial = "CT=~M10" | Biçimselle Δχ²(7) = 3.64, p = .821 |
| Kısmi skaler | + "M4~1" | Kısmi metrikle Δχ²(7) = 11.80, p = .107 |
| HTMT (ortaokul, BK–FM) | htmt2 = FALSE | .773 |
| WLSMV Model 4 | ordered, std.lv | Ortaokul CFI .908; Lise CFI .931 |

Faktör adları: BK = M4, M5, M6, M8; FM = M1, M2, M3; KD = M9, M11; CT = M10, M12, M13. M7 analiz dışıdır.

### 11.4 Simülasyon referansı
`docs/reference_simulation/` paketindeki ayarlarla (tohum 20261030; N = 300, 600, 1000, 1500; 1000 tekrar) beklenen değerler `ozet_tablolar.csv` dosyasındadır. Örnek: N = 600, Senaryo B'de skaler Δχ² gücü .808; ΔCFI/ΔRMSEA gücü .460. Hızlı CI testi için her koşulda 20 tekrarlık küçük bir sürüm koşulur. Bu küçük sürümde birebir değerler değil, aynı tohumla tekrar üretilebilirlik test edilir.

### 11.5 Uçtan uca testler (playwright)
Örnek veriyle bütün akış: yükle → temizle → paralel analiz → DFA → değişmezlik → küçük simülasyon → Word raporu indir.

### 11.6 Doğrulama raporu
`docs/VALIDATION.md` dosyasında bütün referans karşılaştırmalarının sonuçları ve tarihleri tutulur.

---

## 12. Aşamalar (fazlar) ve kabul ölçütleri

| Faz | İçerik | Bitti sayılması için |
|---|---|---|
| 0 | Depo iskeleti, Docker Compose, plumber `/health`, React kabuğu, i18n, ARES-1 teması | `docker compose up` ile üç servis ayağa kalkar; CI çalışır |
| 1 | M1, M2, M3, **M4 (paralel analiz)** + arayüz sayfaları | 11.2 ve 11.3'teki ilgili testler geçer; paralel analiz grafiği ve tablosu görünür |
| 2 | M5, M6, M7 | DFA χ² değerleri birebir; model karşılaştırma tablosu |
| 3 | M8 (sürekli ve kategorik) + kısmi değişmezlik sihirbazı + gizil ortalamalar | 11.3'teki değişmezlik satırları geçer |
| 4 | **M9 simülasyon** + iş sistemi + bağımsız paket dışa aktarma | M9 kabul ölçütleri; kes-devam testi; çevrim içi sınırlar |
| 5 | M10 rapor, M12 tekrarlanabilirlik | Word raporu açılır; dışa aktarılan R betiği bağımsız çalışır ve aynı sonucu verir |
| 6 | M11 yapay zekâ (none/local/evren) + sayı denetleyici | Çevrimdışı yerel model çalışır; sayı denetleyici testleri %100 |
| 7 | Dağıtım: Netlify + Hugging Face Space; kullanıcı kılavuzu | Canlı demo; `docs/USER_GUIDE_TR.md` |

---

## 13. İleri sürüm fikirleri (v1 kapsamı dışında)
- Madde tepki kuramı (`mirt`) ve DIF analizi.
- Ağ psikometrisi / keşfedici grafik analizi.
- Örneklemi bölerek AFA/DFA (çapraz geçerleme) sihirbazı.
- Ölçüt geçerliği ve ölçüt bağıntılı analizler.
- Büyük simülasyonları EVREN hesaplama düğümlerine gönderme (yalnızca EVREN iş API'si belgelendikten sonra).

---

## 14. Zafer'in doldurması gereken bilgiler (Codex bunları varsaymamalı)

1. **EVREN LLM API:** temel adres, kimlik doğrulama yöntemi (başlık adı/biçimi), kullanılabilir model adları, OpenAI uyumlu olup olmadığı, istek ve token sınırları.
2. **EVREN hesaplama/iş API'si** (ileride simülasyon için): iş gönderme biçimi, Docker imajı desteği, kota.
3. **Yerel model:** Ollama ile kullanılacak model adı (Türkçe yanıt kalitesi iyi bir model seçilmeli) ve donanım (ör. RTX 5060 masaüstü).
4. **Alan adı ve barındırma:** Netlify sitesi adı; Hugging Face Space adı (ör. `OsirisZk/olceklab-engine`).
5. **Platformun adı** ve logosu.
6. **Lisans:** açık kaynak (ör. MIT ya da GPL-3; R paketlerinin lisanslarıyla uyumlu olmalı).

---

## 15. Codex'e verilecek ilk görev (kopyala-yapıştır)

```
Bu depoda SPEC.md ve AGENTS.md dosyalarını oku. Faz 0'ı uygula:
- Bölüm 5'teki klasör yapısını oluştur.
- engine/: R 4.4 tabanlı Dockerfile, renv ile lavaan, semTools, psych, GPArotation, MASS, plumber, mirai, officer, flextable, jsonlite, readxl, testthat kur; /health ve /versions uç noktalarını yaz.
- web/: Vite + React + TypeScript; i18next ile TR/EN; ARES-1 koyu ve açık tema; Bölüm 9'daki sayfalar için boş rotalar.
- ai-gateway/: Fastify iskeleti; AI_PROVIDER=none varsayılanı; henüz dış istek yok.
- docker-compose.yml ile üç servisi bağla; .env.example oluştur.
- CI: R testleri (testthat), web testleri (vitest).
Bittiğinde çalıştırdığın testlerin çıktısını ve docs/VERSIONS.md içeriğini göster. Faz 1'e geçmeden dur.
```

Sonraki fazlar için aynı kalıbı kullan: "SPEC.md Bölüm 12, Faz N'yi uygula; kabul ölçütlerini sağlayan testleri yaz ve çalıştır; çıktıyı göster; bir sonraki faza geçmeden dur."

---

## Kaynaklar (platform içinde atıf yapılan yöntemler)

- Byrne, B. M., Shavelson, R. J., & Muthén, B. (1989). Testing for the equivalence of factor covariance and mean structures: The issue of partial measurement invariance. *Psychological Bulletin, 105*(3), 456–466.
- Chen, F. F. (2007). Sensitivity of goodness of fit indexes to lack of measurement invariance. *Structural Equation Modeling, 14*(3), 464–504.
- Cheung, G. W., & Rensvold, R. B. (2002). Evaluating goodness-of-fit indexes for testing measurement invariance. *Structural Equation Modeling, 9*(2), 233–255.
- Horn, J. L. (1965). A rationale and test for the number of factors in factor analysis. *Psychometrika, 30*(2), 179–185.
- Muthén, L. K., & Muthén, B. O. (2002). How to use a Monte Carlo study to decide on sample size and determine power. *Structural Equation Modeling, 9*(4), 599–620.
- Rosseel, Y. (2012). lavaan: An R package for structural equation modeling. *Journal of Statistical Software, 48*(2), 1–36.
- Wu, H., & Estabrook, R. (2016). Identification of confirmatory factor analysis models of different levels of invariance for ordered categorical outcomes. *Psychometrika, 81*(4), 1014–1045.
