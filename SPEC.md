# ÖlçekLab — Ölçek Geliştirme ve Uyarlama Analiz Platformu
## Codex için teknik şartname (v1.2, 3 Kasım 2026)

> Çalışma adı: **ÖlçekLab**. Ad değiştirilebilir.
> Bu belge, Codex'e (ya da başka bir kodlama ajanına) verilmek üzere yazılmıştır. Belgenin tamamını depo köküne `SPEC.md` olarak koy. Bölüm 0'ı ayrıca `AGENTS.md` olarak kaydet.
> Belge sahibi: Zafer Savaş Kıvılcım (Altıeylül BİLSEM).

### Sürüm geçmişi

| Sürüm | Tarih | Değişiklik |
|---|---|---|
| 1.0 | 2 Kasım 2026 | İlk sürüm. |
| 1.1 | 2 Kasım 2026 | `SPEC_REVIEW.md`'deki 58 madde onaylanıp işlendi. Değişen her yer "(v1.1: KİMLİK)" ile işaretlidir; gerekçe ve kanıt için `SPEC_REVIEW.md` ve `review/verify/` klasörüne bakın. |
| 1.2 | 3 Kasım 2026 | Belge sahibinin Faz 1 yanıtları işlendi (`docs/validation/CODEX_YANIT_FAZ1.md`): W-1, REL-1, CL-1 ve REP-1 kapandı. M1 kural sırası, §11.3 tablosu (yeni satırlar: çok gruplu SRMR, HTMT BK–CT, WLSMV dayanıklı indeksler), HTMT ve çok gruplu SRMR varsayılanları, semTools 0.5-9 ↔ 0.5-10 denkliği (V10). Değişen yerler "(v1.2)" ile işaretlidir. |

**Açıklama bekleyen noktalar.** W-1, REL-1, CL-1 ve REP-1 3 Kasım 2026'da yanıtlandı (v1.2). Yalnızca şu madde belge sahibinin yanıtını bekliyor ve ⏳ ile işaretli:
- Referans simülasyon paketi (REP-4; Faz 4'ten önce gerekir).

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
9. **Rastgelelik açıkça yönetilir.** Rastgele sayı kullanan her çağrıdan önce `RNGkind("Mersenne-Twister", "Inversion", "Rejection")` ve `set.seed()` ayarlanır. psych fonksiyonları `options(mc.cores = 1)` ile çağrılır. Tohum, RNG türü ve çekirdek ayarı analiz kaydına yazılır. (v1.1: PA-1, BS-2, EFA-2, MC-5)
10. **Sayılar yuvarlanmadan taşınır, biçimlenmiş hâlleri R'de üretilir.** JSON'da sayılar 17 anlamlı basamakla yazılır. Ekranda ve raporda görünen metin hâli R tarafından üretilir; ön yüz sayı yuvarlamaz ve biçimlendirmez. (v1.1: REP-3, REP-6)
11. **Motor UTF-8 yerel ayarında çalışır.** Aksi hâlde açık bir hatayla durur. (v1.1: ARCH-8)

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

Kapsam dışı (v1):
- Madde tepki kuramı (IRT),
- ağ psikometrisi (EGA),
- boylamsal değişmezlik,
- ikili (iki kategorili) maddelerde kategorik ölçme değişmezliği (v1.1: I-1).

Bunlar Bölüm 13'te ileri sürüm olarak listelenmiştir.

---

## 2. Temel ilkeler

| İlke | Uygulama |
|---|---|
| Doğruluk | Hesaplar yalnızca olgun R paketleriyle yapılır: lavaan, psych, semTools, GPArotation, MASS. Her çıktıda paket sürümleri gösterilir. |
| Tekrarlanabilirlik | Her analiz şunları dışa aktarır: kullanılan ayarlar, tohum değeri, RNG türü, paket sürümleri ve analizi baştan üreten **bağımsız bir R betiği**. |
| Şeffaflık | Her tablonun altında hangi fonksiyonun hangi ayarlarla çalıştığı yazar (ör. "Kaynak: psych::fa.parallel, fa = 'pc', n.iter = 1000, quant = .95, mc.cores = 1"). Eşiklerin kaynağı da yazar (v1.1: W-6, REL-2). |
| Gizlilik | Veriler bellekte işlenir, kalıcı saklanmaz. Yapay zekâya varsayılan olarak ham veri değil, yalnızca toplu sonuç özetleri gönderilir. |
| Sınırların görünürlüğü | Simülasyon çıktıları her yerde "SİMÜLASYON — sentetik veri; geçerlik kanıtı değildir" etiketiyle gösterilir. |
| Yapay zekâ sınırı | Yapay zekâ yorumlar ve açıklar; analiz kararı vermez ve sayı üretmez. Sayılar metne yer tutucularla, R sonuçlarından yerleştirilir (Bölüm 7, M11). |

---

## 3. Mimari

```
┌──────────────────────────────┐        ┌───────────────────────────────────────┐
│  Ön yüz (web)                │  HTTP  │  R analiz motoru (plumber API)        │
│  Vite + React + TypeScript   │◄──────►│  lavaan · psych · semTools · MASS     │
│  Türkçe arayüz, grafikler    │  JSON  │  işçiler (mirai) · rapor (officer)    │
└──────────────┬───────────────┘        └───────────────────┬───────────────────┘
               │                                            │
               │ (isteğe bağlı)                             │ sonuç özeti (JSON)
               ▼                                            ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│  Yapay zekâ ağ geçidi (ai-gateway, Node/TypeScript)                          │
│  sağlayıcılar: none | local (Ollama / llama.cpp, OpenAI uyumlu) | evren      │
│  yer tutucu doldurma · sayı denetleyici · istem kayıtları · çıktı etiketleme │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Neden R?** Kategorik verilerde WLSMV kestirimi, Wu ve Estabrook (2016) tanımlamalı ölçme değişmezliği ve skor testleri için lavaan/semTools'a eşdeğer olgun bir Python veya JavaScript uygulaması yoktur. Bu nedenle bütün istatistik R'de yapılır.

**İşçi modeli (v1.1: ARCH-1).** plumber tek iş parçacıklıdır. Bu yüzden ana süreç yalnızca yönlendirme, oturum yönetimi ve iş durumu işlerini yapar. **Bütün analizler** mirai işçilerinde çalışır ve promise olarak döner. Böylece uzun bir analiz sürerken `/health` ve `/jobs/{id}` yanıt vermeye devam eder. Veri işçiye bellek üzerinden gönderilir, diske yazılmaz.

### 3.1 Dağıtım biçimleri

| Mod | Bileşenler | Not |
|---|---|---|
| Yerel (çevrimdışı) | `docker compose up` → `web` (5173), `engine` (8000), `ai-gateway` (8787), isteğe bağlı `ollama` (11434) | İnternet gerekmez. Simülasyon sınırları yalnızca makinenin gücüyle sınırlıdır. Yazı tipleri ve kütüphaneler pakete gömülüdür (v1.1: ARCH-3). |
| Çevrim içi | `web` → Netlify; `engine` → Hugging Face Spaces (Docker SDK, `app_port: 7860`) | Simülasyon için tekrar sınırı uygulanır (Bölüm 7, M9). Yapay zekâ varsayılan olarak kapalıdır. Space yeniden başlayınca oturumlar silinir (v1.1: ARCH-7). |
| EVREN | `ai-gateway` → EVREN LLM API; isteğe bağlı olarak büyük simülasyonlar için EVREN hesaplama düğümü | Uç nokta ve kimlik bilgileri `.env` dosyasından okunur (Bölüm 7, M11 ve Bölüm 14). |

---

## 4. Teknoloji yığını

- **R motoru:** R 4.4.3 (sabit; §11.3 doğrulama sürümü); plumber 1.x (API); lavaan 0.7-2, semTools 0.5-10, psych 2.6.9, GPArotation 2026.8-2, MASS; mirai (işçiler); officer ve flextable (Word raporu); jsonlite; readxl; digest; testthat. Sürüm yükseltme ayrı bir doğrulama turu gerektirir (v1.1: REP-1). Yerel ayar `C.UTF-8`'dir (v1.1: ARCH-8).
  - §11.3 değerleri semTools 0.5-9 ile üretildi. 0.5-9 ile 0.5-10 arasındaki kaynak farkı yalnızca `measEq.syntax()`'ın `update()` yöntemi, `chisqSmallN()` ve `permuteMeasEq()` içindedir; `htmt`, `compRelSEM`, `AVE` ve `measEq.syntax` çıktıları iki sürümde birebir aynıdır (`review/verify/V10`). Bu yüzden 0.5-10 korunur (v1.2).
- **Ön yüz:** Vite, React, TypeScript; TanStack Query; grafikler için Apache ECharts; tablolar için TanStack Table; i18next (TR/EN); vitest; playwright.
- **Yapay zekâ ağ geçidi:** Node 24 LTS (CI'da 24 ve 26 ile de sınanır), TypeScript, Fastify. OpenAI uyumlu sohbet tamamlama istemcisi; Ollama'nın varsayılan adresi `http://localhost:11434/v1` (v1.1: ARCH-2).
- **Paketleme:** Docker; docker-compose.yml; Hugging Face Space için aynı `engine/Dockerfile` (bağlantı noktası `PORT` ortam değişkeninden okunur).
- **Tasarım dili:** ARES-1.
  - Koyu tema: arka plan `#070B10`, camgöbeği `#00E5FF` ve kehribar `#FFB300` vurgular.
  - Açık tema: vurgular `#00707F` (camgöbeği) ve `#8A5A00` (kehribar). Şartnamenin koyu tema vurguları beyaz zeminde 4.5:1 kontrastı sağlamaz (v1.1: ARCH-4).
  - Yazı tipi JetBrains Mono; gövde metni için ayrı bir yazı tipi tek bir değişkenle seçilebilir (v1.1: ARCH-5).
  - Bütün metin/zemin çiftlerinde kontrast en az 4.5:1'dir ve bir testle sürekli denetlenir.

---

## 5. Klasör yapısı

```
olceklab/
├── AGENTS.md                 # Bölüm 0
├── SPEC.md                   # bu belge
├── SPEC_REVIEW.md            # v1.0 incelemesi ve gerekçeler
├── docker-compose.yml
├── .env.example              # AI_PROVIDER, EVREN_*, OLLAMA_*, ALLOWED_ORIGINS, ONLINE_*
├── engine/                   # R analiz motoru
│   ├── Dockerfile
│   ├── renv.lock
│   ├── plumber.R             # API giriş noktası
│   ├── R/
│   │   ├── 00_locale.R       # UTF-8 denetimi
│   │   ├── json.R · errors.R · format.R · record.R · session.R · workers.R
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
│   └── tests/
│       ├── testthat/
│       └── private/          # BİDEKÇET testleri (veri depoya girmez)
├── web/                      # ön yüz
│   ├── src/pages/ ...        # Bölüm 9
│   └── tests/                # vitest; e2e/ altında playwright
├── ai-gateway/               # M11
│   ├── src/providers/{none,local,evren}.ts
│   ├── src/numberCheck.ts
│   └── tests/
├── review/verify/            # şartname incelemesinin doğrulama betikleri
└── docs/
    ├── VERSIONS.md
    ├── VALIDATION.md         # Bölüm 11 sonuçları
    └── USER_GUIDE_TR.md
```

---

## 6. Veri modeli

### 6.1 Veri seti
- **Biçimler:** CSV (UTF-8, `;` ya da `,` ayraçlı) ve XLSX. Türkçe karakterli sütun adları desteklenir. UTF-8 olmayan dosya açık bir hata iletisiyle reddedilir.
- **XLSX okuma:** readxl dosya yolu gerektirir. Bu yüzden dosya, Linux'ta bellek tabanlı `/dev/shm` altında kısa süre tutulur ve okunur okunmaz silinir. Gizlilik bildirimi bunu açıkça yazar.
- **Sütun rolleri:** Kullanıcı yükleme sonrasında her sütunun rolünü belirler: `item` (madde), `group` (grup değişkeni; en fazla bir tane), `id`, `ignore`.
- **Madde ayarları:** en küçük ve en büyük kategori (ör. 1–5), ters madde mi, alt boyut (isteğe bağlı).
- **Oturum:** Veri seti oturum belleğinde tutulur; kimliği `dataset_id` olur. Veri, ham baytlarının SHA-256 özetiyle tanımlanır; veri kendisi saklanmaz.

### 6.2 Analiz kaydı (her modül çıktısı bu yapıda döner)
```json
{
  "analysis_id": "uuid",
  "module": "factor_number",
  "dataset_hash": "sha256:...",
  "settings": { "...": "..." },
  "seed": 20261030,
  "rng": { "kind": "Mersenne-Twister", "normal_kind": "Inversion", "sample_kind": "Rejection", "mc_cores": 1 },
  "engine": { "R": "4.4.3", "packages": { "psych": "2.6.9", "lavaan": "0.7.2" }, "blas": "..." },
  "results": { "...": "modüle özgü, yalnızca R'den gelen sayılar (17 anlamlı basamak)" },
  "tables": [ {
    "id": "T1", "title_tr": "...", "title_en": "...",
    "columns": [ { "key": "...", "label_tr": "...", "label_en": "...", "type": "number|text" } ],
    "rows": [ { "...": "ham değer" } ],
    "rows_fmt": { "tr": [ { "...": ",794" } ], "en": [ { "...": ".794" } ] },
    "note_tr": "Kaynak: ...", "note_en": "Source: ..."
  } ],
  "figures": [ { "id": "F1", "type": "scree", "data": {} } ],
  "warnings": [ { "code": "...", "message_tr": "...", "message_en": "..." } ],
  "r_script": "bu analizi baştan üreten R kodu",
  "created_at": "ISO-8601"
}
```
(v1.1: REP-3, REP-6, BS-2, PA-1.)

---

## 7. Modüller

Her modül şu sırayla tanımlanır: **amaç → girdiler → R uygulaması → çıktılar → kabul ölçütleri.**

### M1 — Veri yükleme ve temizleme
- **Girdiler:** dosya, sütun rolleri, kurallar (aşağıda).
- **Kurallar.** Her kural açılıp kapatılabilir. Kurallar **bu sırayla** uygulanır. Bir satır yalnızca ilk eşleştiği kuralda sayılır ve her adımda kaç satırın neden çıkarıldığı raporlanır (v1.1: CL-1; sıra v1.2'de BİDEKÇET çalışmasının sırasıyla aynı yapıldı):
  1. **Geçersiz grup:** grup değeri eksik ya da kullanıcının verdiği geçerli değerler listesinde yok.
  2. **Eksik yanıt:** maddelerden en az birinde değer yok; liste bazında silme; v1'de atama yok. Madde bazında eksiklik oranı ayrıca raporlanır (v1.1: CL-3). Yalnızca `item` rolündeki sütunlara bakılır.
  3. **Aralık dışı değer:** maddelerden birinde değer, tanımlı en küçük–en büyük aralığın dışında ya da tam sayı değil. Satır silinir.
  4. **Düz yanıt:** bütün maddelere aynı yanıtı veren satırlar. **Ham** (ters kodlanmamış) yanıtlarda aranır. Ölçekte ters madde yoksa, uç ama tutarlı yanıtları da silebileceği uyarısı gösterilir (v1.1: CL-2).
  5. **Ters kodlama:** x′ = en küçük + en büyük − x.
- Kuralların hepsi satır bazlı olduğu için analize kalan satırlar sıradan bağımsızdır; sıra yalnızca bir satırın hangi adımda sayıldığını belirler. Hem eksik hem aralık dışı değeri olan satır "eksik" adımında sayılır (v1.2).
- Sütun adlarının başındaki ve sonundaki boşluklar okuma sırasında atılır (ör. `"Madde1 "` → `Madde1`). Kırpılınca aynı adı taşıyan sütunlar hata verir (v1.2).
- **Kimlik sütunu algılama (v1.1: PRIV-1):** sütun adlarına (ad, soyad, numara, no, tc, kimlik, id) ve değerlere bakılır. T.C. kimlik numarası için 11 hane ve sağlama algoritması kullanılır. Sonuç yalnızca öneridir; arayüz bunun garanti olmadığını yazar.
- **Örnek veri setleri:** `POST /datasets/examples/{name}` ile `HolzingerSwineford1939` (lavaan) ve `bfi` (psych) yüklenebilir.
- **Çıktı:** temizleme özet tablosu (ör. "Ham: 279 → hatalı grup 2 → eksik 5 → düz yanıt 16 → analiz: 256") ve temiz veri (yalnızca oturumda).
- **Kabul:** Bölüm 11.3'teki BİDEKÇET temizleme sayıları birebir elde edilir.

### M2 — Betimsel istatistikler ve madde analizi
- **R:** `psych::describe` (type = 3; basıklık fazla basıklıktır), `psych::alpha` (`item.stats$r.drop`, `alpha.drop`), kategori frekansları, taban ve tavan yüzdeleri (v1.1: ITEM-1).
- **Çıktı:**
  - madde tablosu: ortalama, SS, çarpıklık, basıklık, düzeltilmiş madde-toplam r, madde silinirse alfa,
  - kategori dağılımı ısı haritası,
  - madde bazında eksiklik oranı (ham veride).
- **Uyarılar:** madde-toplam r < .30; boş kategori; |çarpıklık| > 2.

### M3 — Faktör analizine uygunluk
- **R:** `psych::KMO`, `psych::cortest.bartlett`, `psych::mardia`.
- **Çıktı:** KMO (toplam ve madde bazında MSA), Bartlett χ², sd, p, Mardia b1p, b2p ve testleri.
- **Not:** Mardia testinin Likert verisinde neredeyse her zaman anlamlı çıktığı yazılır. Polikorik korelasyonla Bartlett testinin normal kuram varsayımına dayandığı da belirtilir (v1.1: ITEM-1).

### M4 — Faktör sayısının belirlenmesi (paralel analiz modülü — öncelikli)
- **Paralel analiz (Horn, 1965):** `psych::fa.parallel` sarmalanır. Ayrıca motor içinde şeffaf bir yeniden uygulama (`factor_number.R::parallel_manual`) bulunur ve testlerde ikisinin sonuçları karşılaştırılır.
- **Ayarlar:**
  - `extraction`: `pc` | `fa` | `both`
  - `correlation`: `pearson` | `polychoric`
  - `reference` (v1.1: PA-2):
    - `simulated_normal` → psych'te `sim = TRUE`,
    - `resampled_bootstrap` → psych'te `sim = FALSE`; sütun içinde yerine koyarak örnekleme,
    - `permutation` → yalnızca `parallel_manual`; sütun içi permütasyon; psych ile karşılaştırılmaz.
  - `n_iter`: varsayılan 1000; her zaman açıkça verilir, çünkü psych'in varsayılanı 20'dir (v1.1: PA-5).
  - `criterion`: `quantile` (varsayılan .95) | `mean`. İki referans da psych'in döndürdüğü `$values` matrisinden R'de hesaplanır. Tabloda karar için kullanılan referans işaretlenir. psych `mean` ölçütünü desteklemez; birebir karşılaştırma yalnızca `quantile` için yapılır (v1.1: PA-3).
  - `fm`: FA için; varsayılan `minres`.
  - `seed`.
- **Uygulama kuralları:**
  - `options(mc.cores = 1)` ve sabit RNG türü zorunludur (v1.1: PA-1).
  - `correlation = "polychoric"` iken `simulated_normal` seçilemez, çünkü psych bu durumda referansı Pearson ile hesaplar (v1.1: PA-4).
  - `parallel_manual` psych'in algoritmasını birebir izler (v1.1: PA-5):
    - FA özdeğerleri tek faktörlü `fa(nfactors = 1, fm)` çözümünden alınır,
    - sayım ardışıktır,
    - RNG tüketim sırası psych'inkiyle aynıdır.
- **Çıktı:** gözlenen ve referans özdeğer tablosu (ortalama ve yüzdelik), önerilen faktör/bileşen sayısı, kesişimli scree grafiği.
- **Velicer MAP testi:** `psych::vss(...)$map`; önerilen sayı. Tablo notunda bunun karesel kısmi korelasyonlu özgün sürüm (Velicer, 1976) olduğu ve 0 faktör öneremeyeceği yazılır (v1.1: PA-5).
- **Klasik ölçütler:** özdeğer > 1 sayısı (yalnızca bilgi olarak) ve scree grafiği.
- **Karar destek kutusu** (şablon metin; yapay zekâ değil): "Paralel analiz X, MAP Y faktör önermektedir. Faktörler arası korelasyonlar yüksek olduğunda paralel analiz faktör sayısını düşük kestirebilir; faktör sayısı kararı kuramsal yapı ve rakip DFA modelleriyle birlikte verilmelidir." Bu uyarı Crawford vd. (2010) ve Garrido vd. (2013) bulgularına dayanır (v1.1: PA-6). Kullanıcı M9 ile kendi yapısı için bunu sınayabilir.
- **Kabul:**
  - Bölüm 11'deki referans veri setlerinde `psych::fa.parallel` ile aynı önerilen sayı.
  - `parallel_manual` ile psych'in özdeğer matrisinin aynı tohumla birebir aynı olması.
  - BİDEKÇET verisinde iki kademede de 2 bileşen.
  - Aynı tohumla tekrar çalıştırıldığında, çok çekirdekli makinede de aynı özdeğerler.

### M5 — Açımlayıcı faktör analizi
- **R:** `psych::fa` (`fm`: `ml`, `minres`, `pa`; `rotate`: `oblimin`, `promax`, `varimax`, `geominQ`), `cor`: `cor` | `poly`.
- **Rastgele başlangıç (v1.1: EFA-2):** psych 2.6.9'da `fa()` varsayılan olarak `n.rotations = 20` rastgele başlangıç kullanır. Tohum ve `n.rotations` kayda yazılır.
- **Çıktı:** örüntü katsayıları (kullanıcının belirlediği eşiğin, ör. .30, altındakiler gizlenebilir), ortak varyanslar, faktörler arası korelasyonlar, açıklanan varyans, çapraz yük ve Heywood uyarıları.
- **Uyarılar:** `cor = "poly"` ile `fm = "ml"` seçilirse uyarı verilir ve minres/uls önerilir (v1.1: EFA-1).
- **Not:** Faktör sırası ve işaretleri yazılıma göre değişebilir; arayüz faktörleri yeniden sıralayıp adlandırmaya izin verir.

### M6 — Doğrulayıcı faktör analizi ve model karşılaştırma
- **Model kurucu:** maddeleri faktörlere sürükle-bırak → otomatik lavaan sözdizimi. Gelişmiş kullanıcılar için doğrudan sözdizimi düzenleyici. Hata kovaryansı ekleme. Üçten az göstergeli faktörler için uyarı (v1.1: I-4).
- **R:** `lavaan::cfa`.
  - `estimator`:
    - `ML`: `likelihood` `normal` (varsayılan) ya da `wishart` ("AMOS/LISREL uyumlu, N − 1" etiketiyle; yalnızca ML'de seçilebilir) (v1.1: W-5),
    - `MLR`,
    - `WLSMV` (`ordered = maddeler`).
  - `std.lv` seçeneği.
  - **Bollen–Stine (v1.1: BS-1…BS-3):**
    - Yalnızca şu koşullarda seçilebilir: `estimator = "ML"`, maddeler sürekli kabul edilmiş, `missing = "listwise"`. Diğer durumlarda arayüzde nedeniyle birlikte kilitlidir.
    - Çağrı: `test = "bollen.stine", bootstrap = B, iseed = seed`. Paralellik kapalıdır (`parallel = "no"`). Varsayılan B = 1000.
    - p değeri `lavInspect(fit, "test")$bollen.stine$pvalue` ile alınır.
    - Raporlananlar: istenen B, `boot.length` (B_etkin), başarısız tekrar sayısı (B − B_etkin), uygunsuz çözüm sayısı (lavaan'ın uyarısından).
    - Faz 2–3'te tek bir mirai işçisinde, istek süresince çalışır; iş kuyruğuna alınması Faz 4'teki iş sistemiyle gelir (v1.2).
    - `boot.larger = 0` ise "p < 1/B_etkin" yazılır. İsteğe bağlı "tutucu p" = (b + 1)/(B + 1) değeri R'de hesaplanır.
- **Çıktı:**
  - uyum indeksleri: χ², sd, p, χ²/sd (yalnızca ML'de ve "bilgi" etiketiyle; v1.1: W-4), CFI, TLI, RMSEA ve %90 GA, SRMR,
  - WLSMV'de iki sütun: "ölçeklenmiş (Mplus uyumlu)" `.scaled` ve "dayanıklı (Savalei, 2021)" `.robust` (v1.1: W-1). MLR'de de aynı iki sütun gösterilir: "ölçeklenmiş (Yuan–Bentler)" ve "dayanıklı (Brosseau-Liard ve Savalei)". §11.3 karşılaştırması `cfi.scaled` ile yapılır (v1.2: W-1 yanıtı),
  - standardize yükler, faktör korelasyonları,
  - uygunsuz çözüm denetimi (`lavInspect(fit, "post.check")`),
  - yol şeması (SVG).
- **Model karşılaştırma (v1.1: W-2, W-3):**
  - Birden çok model aynı tabloda gösterilir. Kestirici, `likelihood` veya N'si farklı modeller aynı tabloya alınmaz.
  - İç içe modeller için `lavTestLRT` kullanılır. Kayıtta `method` alanı yer alır: WLSMV'de `satorra.2000`, MLR'de `satorra.bentler.2001`. SB2001 negatif çıkarsa SB2010 ile yeniden hesaplanır ve uyarı eklenir.
  - Hangi model çiftlerinin iç içe olduğu `semTools::net` ile denetlenir (Bentler ve Satorra, 2010; kategorik veride Asparouhov ve Muthén, 2019). Yalnızca iç içe çiftler test edilir; eşdeğer modeller ayrıca belirtilir (v1.2).
  - Karşılaştırılan modeller aynı gözlenen değişkenleri kullanmalıdır (v1.2).
  - Ölçeklenmiş χ² değerleri asla elle çıkarılmaz.
  - İç içe olmayan modeller için AIC/BIC yalnızca ML/MLR'de gösterilir. WLSMV'de test sunulmaz; indeksler betimsel olarak yan yana konur.
- **Modifikasyon indeksleri:** `modindices` ile gösterilir. Kuramsal gerekçe olmadan serbest bırakmanın riskleri hakkında sabit bir uyarı metni eşlik eder.
- **Kabul:** Bölüm 11.3'teki BİDEKÇET χ² değerleri (Wishart) birebir; HolzingerSwineford1939 için `lavaan` belgesindeki bilinen modelle aynı uyum değerleri.

### M7 — Güvenirlik ve geçerlik
- **R:**
  - `psych::alpha` (toplam ve alt boyut alfa);
  - `semTools::compRelSEM` (omega/CR). `obs.var` seçeneği gösterilir. WLSMV'de `ord.scale = TRUE` kullanılır; bu, gözlenen toplam puanın güvenirliğidir (Green & Yang, 2009);
  - `semTools::AVE` (sıralı veride y* ölçeğindedir; tabloda yazar);
  - `semTools::htmt`. `htmt2`, `absolute` ve korelasyon türü (`ordered`) seçenekleri gösterilir ve kayda yazılır (v1.1: REL-1). Platform varsayılanları: `htmt2 = FALSE`, `absolute = TRUE`, Pearson korelasyonu. semTools'un kendi varsayılanı `htmt2 = TRUE` olduğu için ayarlar çağrıda her zaman açıkça verilir (v1.2: REL-1 yanıtı).
- **`obs.var` farkı (v1.2).** compRelSEM ω = w′ΛΦΛ′w / w′Σ̂w formülünü kullanır; pay iki seçenekte de modelden gelir.
  - `obs.var = TRUE` (semTools varsayılanı): payda gözlenen (doymuş model) kovaryans matrisidir. ω, gözlenen toplam puan varyansının modelin açıkladığı payıdır; model uyumsuzluğu paydaya yansır.
  - `obs.var = FALSE`: payda modelin örtük kovaryans matrisidir. Hata kovaryansı yoksa McDonald'ın (1999) ω = (Σλ)²ψ / ((Σλ)²ψ + Σθ) formülüne, yani yapı güvenirliğine (CR) eşittir.
  - Model veriye tam uyduğunda ikisi aynıdır. Platform hangisinin kullanıldığını tablo notuna yazar; iki formül testlerde lavaan kestirimlerinden elle yeniden hesaplanarak doğrulanır.
- **Not:** HTMT'den önce ters maddeler yeniden kodlanmış olmalıdır. Aksi hâlde `absolute = FALSE` ile sonuç tanımsız olabilir.
- **Çıktı:** faktör × gösterge tablosu. ,70 / ,50 / ,85 eşiklerine göre görsel işaretleme yapılır; eşikler ayarlanabilir ve kaynakları yazılır: Fornell ve Larcker (1981), Henseler vd. (2015), Roemer vd. (2021) (v1.1: REL-2).

### M8 — Ölçme değişmezliği ve gizil ortalamalar
- **Sürekli yaklaşım (ML/MLR):** biçimsel → metrik (`loadings`) → skaler (`intercepts`) → isteğe bağlı katı (`residuals`), `group.equal`.
- **Kategorik yaklaşım (WLSMV; v1.1: I-1):**
  - Sözdizimi: `semTools::measEq.syntax(..., parameterization = "theta", ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016")`.
  - Sıra: biçimsel → eşik → eşik + yük → eşik + yük + kesişim → + artık varyans.
  - Bütün maddeler üç kategoriliyse eşik adımı "biçimselle eşdeğer (sd farkı 0)" notuyla atlanır.
  - İkili madde içeren ölçeklerde kategorik değişmezlik v1'de kapalıdır.
  - "Metrik" ve "skaler" adları yalnızca parantez içinde takma ad olarak kullanılır.
- **Çok gruplu SRMR (v1.2).** Hem lavaan'ın `srmr` değeri hem `srmr_bentler_nomean` gösterilir; raporun varsayılan değeri `srmr_bentler_nomean`'dır (§11.3).
- **Karar ölçütleri** (kullanıcı ayarlayabilir; varsayılanlar; v1.1: I-2):
  - Tanım: Δ = kısıtlı model − daha az kısıtlı model.
  - ΔCFI ≥ −,01 (Cheung & Rensvold, 2002),
  - ΔRMSEA ≤ ,015 (Chen, 2007),
  - ΔSRMR: yük adımı için ≤ ,030, kesişim ve artık adımları için ≤ ,010 (Chen, 2007),
  - Δχ² (α = ,05). WLSMV'de Satorra (2000) farkı, MLR'de ölçeklenmiş fark kullanılır.
  - Çıktı tablosu her ölçütün kararını ayrı sütunda gösterir. Ek olarak kullanıcı tanımlı bir birleşik kural (VE/VEYA) seçilebilir ve tablo notunda yazar.
  - WLSMV tablosunda şu not bulunur: "Δ eşikleri sürekli ML simülasyonlarından türetilmiştir; WLSMV için doğrulanmamıştır. Birincil ölçüt Satorra (2000) fark testidir." Δ değerleri `.scaled` indekslerle hesaplanır, çünkü `.robust` indeksler kısıtlı çok gruplu modellerde tanımsızdır.
- **Kısmi değişmezlik sihirbazı** (Byrne vd., 1989):
  1. `lavTestScore` ile kısıtların skor testi tablosu gösterilir. Parametre etiketleri `parTable` ile okunur hâle getirilir. WLSMV ve MLR'de sıralama `X2.scaled`'e, ML'de `X2`'ye göre yapılır; iki sütun da gösterilir (v1.1: I-3).
  2. Kullanıcı en büyük değerli kısıtı **kendisi onaylayarak** serbest bırakır (`group.partial`). Otomatik serbest bırakma yalnızca "öneri" olarak sunulur. İkiden çok grupta serbest bırakmanın "bütün gruplarda" mı "tek grup çiftinde" mi yapılacağı sorulur.
  3. Yükü serbest bırakılan maddenin kesişiminin de serbest bırakılıp bırakılmayacağı açık bir seçenektir. Varsayılan "kısıtlı kalsın"dır ve tablo notunda yazar (v1.1: I-4).
  4. Her adımda yeni Δχ², ΔCFI, ΔRMSEA ve ΔSRMR gösterilir.
  5. "Veri güdümlü serbest bırakmalar bağımsız örneklemde doğrulanmalıdır" uyarısı sabittir.
- **Gizil ortalamalar (v1.1: I-4, I-5):**
  - Yalnızca her faktörde en az iki göstergenin yükü ve kesişimi (kategorikte eşikleri) değişmez kaldığında hesaplanır; aksi hâlde adım kilitlidir.
  - Referans grupta ortalama 0'dır. Diğer grupların farkı, SH, z ve p raporlanır.
  - d = fark / birleşik gizil SS (Hancock, 2001); seçenek olarak referans grup SS'si kullanılabilir.
  - d, lavaan sözdiziminde `:=` ile tanımlanır; SH ve güven aralığı lavaan'dan gelir.
- **Kabul:** Bölüm 11.3'teki BİDEKÇET değişmezlik ve kısmi değişmezlik değerleri.

### M9 — Monte Carlo simülasyonu (çekirdek modül)

Muthén ve Muthén'in (2002) yaklaşımıyla, kullanıcının kendi ölçek yapısı için örneklem büyüklüğü, güç ve yöntem davranışını inceler. Raporlama Morris, White ve Crowther'ın (2019) ADEMP yapısını izler. Bu modül, BİDEKÇET çalışmasında kullanılan simülasyonun genelleştirilmiş hâlidir; o çalışmanın kodu `docs/reference_simulation/` altında örnek olarak bulunur.

**9.1 Popülasyon modeli** — üç yoldan biriyle kurulur:
- **(a) Uydurulmuş modelden:** M6/M8'de kestirilen modelin parametreleri alınır (yükler, eşikler/kesişimler, gizil kovaryanslar, gizil ortalamalar, artık varyanslar). Ham veri simülasyona aktarılmaz; yalnızca bu özet parametreler kullanılır.
  - ML ile kestirilmiş modelden yalnızca sürekli veri üretilebilir. Sıralı üretim için WLSMV/theta modeli ya da elle tanım gerekir (v1.1: MC-7).
  - Örnek kestirimleri gerçek değer kabul edildiği için bir duyarlılık seçeneği (ör. bütün yükler −,05) ve sınırlılık cümlesi sunulur (v1.1: MC-13).
- **(b) Elle tanım:** madde-faktör eşleşmesi, standardize yükler, faktör korelasyonları, kategori sayısı ve kategori oranları. Eşikler bu oranlardan türetilir.
- **(c) JSON dosyasından içe aktarma** (`population.json`).

**9.2 Veri üretimi** (`generate.R`): gizil yanıt yaklaşımı (v1.1: MC-7).
- Gizil faktörler η ~ N(α_g, Ψ_g) dağılımından üretilir (`MASS::mvrnorm`).
- Gizil yanıtlar y* = Λη + ε, ε ~ N(0, Θ) olarak hesaplanır. Θ = I − diag(Λ Ψ_ref Λ′) alınır; böylece referans grupta var(y*) = 1 olur.
- Sıralı veri için y* eşiklerde kesilir. Eşikler referans grubun kategori oranlarından Φ⁻¹ ile türetilir. Sürekli seçenek de vardır.
- Yük DIF'inde varsayılan olarak Θ sabit tutulur (odak grupta var(y*) değişir). Eşik veya kesişim kayması referans grubun SD(y*) birimiyle verilir.
- Çok gruplu üretim desteklenir; grup oranları ayarlanabilir.

**9.3 Koşullar (tam çaprazlanmış ızgara):**
- **Veri üretim faktörleri** (tohumu belirler):
  - toplam N listesi (ör. 300, 600, 1000, 1500),
  - grup oranı (ör. 50/50, 70/30),
  - **farklılık (DIF) senaryoları:** seçilen maddelerde ve seçilen grupta eşik/kesişim kayması, yük farkı ve "değişmez" kontrol senaryosu.
- **Analiz faktörleri** (tohumu değiştirmez): kestirim yöntemi (ML, MLR, WLSMV). Her tekrarda **aynı veri seti** seçilen bütün kestiricilerle analiz edilir (ortak rastgele sayılar; v1.1: MC-6).
- Tekrar sayısı R (varsayılan 1000; en fazla 10.000; v1.1: MC-5).

**9.4 Her tekrarda yapılan analizler** (kullanıcı seçer):
- paralel analiz ve MAP (önerilen sayı). Simüle normal referansta referans dağılımı yalnızca (N, p)'ye bağlı olduğu için hücre başına bir kez hesaplanabilir; bu seçenek ve RNG akışına etkisi belgelenir (v1.1: MC-12).
- AFA ile yapının doğru bulunma oranı (v1.1: MC-10):
  - (a) gerçek k ile ve (b) paralel analizin önerdiği k ile ayrı ayrı raporlanır; (b)'de k ≠ gerçek k ise tekrar başarısızdır.
  - Atama kuralı: madde, mutlak değerce en büyük yükü taşıdığı faktöre atanır; bu yük ≥ ,30 olmalıdır (ayarlanabilir). Çapraz yük kuralı ayrıca tanımlanır.
  - Faktörler k ≤ 8 için bütün permütasyonlar denenerek eşlenir; işaret düzeltilir.
  - Ek ölçüt olarak Tucker uyum katsayısı verilir (≥ ,95; Lorenzo-Seva & ten Berge, 2006).
- DFA uyumu, yükler, güvenirlik;
- rakip model karşılaştırması (ör. özgün yapı ile önerilen yapı);
- değişmezlik testleri (Δχ², ΔCFI, ΔRMSEA, ΔSRMR kararları).

**9.5 Çıktı ölçütleri:**
- yakınsama oranı ve uygun çözüm oranı (ayrı ayrı);
- hata türleri ayrı sayılır: yakınsamama, uygunsuz çözüm, grupta boş kategori, diğer (v1.1: MC-9);
- boş kategori oranı;
- paralel analiz ve MAP'in önerdiği faktör sayısının dağılımı;
- AFA'da doğru yapı oranı;
- uyum indekslerinin ortalaması, SS ve 2,5–97,5 yüzdelikleri; iyi ve kabul edilebilir uyum oranları (eşik kaynağı yazılır; v1.1: W-6);
- **kestirilen nicelik tablosu (v1.1: MC-1):** her parametre türü için karşılaştırma ölçeği tanımlanır (yükler ve faktör korelasyonları std.all; eşikler y* ölçeği; gizil ortalama farkı referans grup SS'si). Gerçek değer kestirimle aynı ölçekte hesaplanır. Bu tablo `params.json`'a yazılır;
- parametre yanlılığı, RMSE ve deneysel SS (v1.1: MC-4):
  - |θ| ≥ ,10 için göreli yanlılık,
  - |θ| < ,10 için (eşik ayarlanabilir) ham yanlılık ve standardize yanlılık (yanlılık/SS; |%40| üzeri sorunlu; Collins vd., 2001);
- SH göreli yanlılığı: (ort(SH) − SS(θ̂)) / SS(θ̂) (v1.1: MC-3);
- %95 güven aralığı kapsama oranı (v1.1: MC-3);
- alfa ve omega yanlılığı;
- değişmezlikte I. tip hata (kontrol senaryosu) ve güç (DIF senaryoları). İkisi de "her adım ayrı" ve "ardışık karar" olarak raporlanır (v1.1: MC-8);
- her ölçüt için Monte Carlo standart hatası (etkin R ile);
- **payda (v1.1: MC-9):** yeniden üretim yapılmaz. Birincil analiz "yakınsayan + uygun" tekrarlarda, duyarlılık analizi "yakınsayan" tekrarlarda yapılır;
- **örneklem büyüklüğü önerisi (v1.1: MC-11):** öyle en küçük ızgara N'si ki seçilen bütün ölçütler hem o N'de hem de ondan büyük bütün ızgara N'lerinde sağlanır. İsteğe bağlı "güven aralığı alt sınırı ≥ ölçüt" kuralı vardır. Varsayılan ölçütler iki başlıkta verilir:
  - *Muthén ve Muthén (2002):* bütün parametrelerde |parametre yanlılığı| ≤ %10 ve |SH yanlılığı| ≤ %10; gücü incelenen parametrede |SH yanlılığı| ≤ %5; kapsama ,91–,98; güç ≥ ,80.
  - *Kullanıcı tanımlı:* uygun çözüm ≥ ,95.

**9.6 Gerçek değerler (v1.1: MC-2).** Gerçek değerin kaynağı sırasıyla şudur:
1. Model doğru ve ölçek uyumluysa üretim parametresi.
2. Kesin popülasyon momentlerine uydurulan modelin değeri (sözde-gerçek). Kesikli puanların popülasyon kovaryansı iki değişkenli normal olasılıklarından hesaplanır. ML/MLR ile sıralı veri, yanlış tanımlanmış modeller, popülasyon alfa ve omega değerleri bu yolla bulunur.
3. Kapalı biçim yoksa büyük örneklem (ör. N = 200.000); bu durumda kendi MC hatası raporlanır.

Raporda iki satır yer alır: "üretim değerinden sapma" ve "sözde-gerçek değere göre yanlılık".

**9.7 İş sistemi** (`jobs.R`, mirai):
- Simülasyon arka planda, parçalar hâlinde (ör. 250 tekrarlık) ve paralel işçilerle çalışır.
- Her parça diske `.rds` olarak yazılır, böylece iş kesilirse kaldığı yerden devam eder. Devam etme yalnızca sentetik veriyle çalışan simülasyon işlerinde vardır. Gerçek veri içeren işler (ör. Bollen–Stine) diske yazılmaz ve kesilince baştan çalışır (v1.1: REP-5).
- Arayüzde ilerleme çubuğu, tahmini kalan süre, iptal ve devam düğmeleri vardır.
- **Tohumlar (v1.1: MC-5):**
  - Her tekrarın tohumu `seed + 10000*koşul + tekrar` biçimindedir; R ≤ 10.000 sınırı denetlenir.
  - `koşul`, yalnızca veri üretim faktörlerinin kanonik sırasıyla (faktörler sabit sırada, düzeyler kullanıcı girdisi sırasında) belirlenen indekstir. Her koşulun indeksi ve tohumu `params.json`'a yazılır.
  - RNG türü `RNGkind("Mersenne-Twister", "Inversion", "Rejection")` ile açıkça ayarlanır. Popülasyon ve gerçek değer üretimi ayrı ve belgelenmiş bir tohum alır.
  - Her veri seti tek başına yeniden üretilebilir.
- Hatalı tekrarlar atılmaz; hata türü ve mesajıyla birlikte kaydedilir ve oranları raporlanır.
- **Çevrim içi mod sınırları** (`.env` ile ayarlanır): toplam tekrar × koşul ≤ 2.000, en fazla 2 işçi, iş başına süre sınırı. Bu sınırı aşan işler için kullanıcıya bağımsız R paketi indirme seçeneği sunulur (9.8).
- Yerel modda sınır yoktur.

**9.8 Bağımsız paket dışa aktarma:** Simülasyon, bilgisayarda ya da EVREN gibi bir hesaplama ortamında çalıştırılabilecek bir zip olarak indirilebilir. Paketin içeriği:
- `params.json` (koşul indeksleri, tohumlar, RNG türü ve kestirilen nicelik tablosu dâhil),
- `02_simulasyon.R`,
- `03_gercek_degerler.R`,
- `04_calistir.sh`,
- `05_ozet.R`,
- `BENIOKU.md`.

**9.9 Etiketleme:** Simülasyon sonuç sayfaları, tabloları ve raporları kalıcı olarak "SİMÜLASYON — sentetik veri; ölçeğin geçerliğine kanıt değildir" etiketini taşır. Rapor modülü, simülasyon için hazır bir sınırlılıklar paragrafı ekler.

**Kabul:**
- Aynı tohum ve aynı sürümlerle iki çalıştırma birebir aynı sonucu verir.
- Kesilip yeniden başlatılan bir iş, kesintisiz çalışmayla aynı sonucu verir.
- Yazılım kabulü: sürekli-normal veri ve ML ile kurulmuş kontrol senaryosunda Δχ² I. tip hata oranı ,05 civarındadır (1000 tekrarla ,03–,07). WLSMV ve sıralı verideki oranlar "bilgi" olarak raporlanır (v1.1: MC-8).
- ⏳ `docs/reference_simulation` ile aynı ayarlar verildiğinde Bölüm 11.4'teki değerler elde edilir. Paket gelince MC-6 uyumu denetlenecek.

### M10 — Raporlama
- APA 7 biçiminde tablolar, Word (`officer` + `flextable`) ve CSV dışa aktarma; grafikler SVG/PNG.
- **Biçim kuralları (v1.1: REP-3):** Bütün biçimleme R'de yapılır.
  - Türkçede ondalık virgülü, İngilizcede nokta kullanılır.
  - Değeri 1'i geçemeyen istatistiklerde (r, p, α, CFI, RMSEA, standardize yük) baştaki sıfır yazılmaz.
  - p < ,001 kuralı uygulanır.
  - Eksi işareti için "−" kullanılır.
- **Yöntem/Bulgular taslak metni:** Önceden yazılmış şablon cümlelerdir; sayılar doğrudan sonuç JSON'undaki biçimli değerlerden yerleştirilir. Bu bölüm **yapay zekâ kullanmaz**.
- Her tablonun altında kaynak satırı bulunur (fonksiyon, ayarlar, sürüm).

### M11 — Yapay zekâ yorum asistanı (isteğe bağlı, varsayılan: kapalı)

**Sağlayıcılar** (`AI_PROVIDER`):
- `none`: varsayılan.
- `local`: tamamen çevrimdışı çalışır. Ollama ya da llama.cpp sunucusu kullanılır (OpenAI uyumlu `/v1/chat/completions`). Model adı `.env` dosyasından okunur; tanımlı değilse ağ geçidi başlamaz. Yerel modda internet bağlantısı olmadan çalışmalıdır.
- `evren`: EVREN platformunun LLM API'si. Uç nokta, kimlik doğrulama başlığı ve model adı `.env` dosyasından okunur (`EVREN_BASE_URL`, `EVREN_API_KEY`, `EVREN_MODEL`). API OpenAI uyumluysa `local` istemcisi yeniden kullanılır; değilse `providers/evren.ts` içinde EVREN belgelerine göre ayrı bir bağdaştırıcı yazılır. **Bu ayrıntılar belgelenmeden varsayılmaz** (Bölüm 14).

**Görevleri:**
- seçilen analiz çıktısını sade Türkçeyle açıklamak,
- sonuçlara göre olası sonraki adımları önermek (ör. "kısmi değişmezlik sihirbazını deneyebilirsiniz"),
- kullanıcının sorduğu kavramları açıklamak.

**Yapamayacakları** (istem ve ağ geçidi düzeyinde zorunlu):
- sayı üretmek ya da hesaplamak,
- model seçmek veya kısıt serbest bırakmak,
- ham veriyi görmek. Varsayılan olarak yalnızca `results` ve `tables` gönderilir. Bu tablolar yalnızca toplu bilgi içerir; satır kimliği ya da kişi bazında değer gönderilmez (v1.1: AI-2). Ham veri gönderimi yerel modda bile ayrı bir onay gerektirir.

**Yer tutucu ve sayı denetimi (v1.1: AI-1):**
1. Yapay zekâ sayı yazmaz. Bunun yerine sonuç anahtarına bağlı yer tutucu kullanır (ör. `{{cfa.fit.cfi_scaled}}`). Ağ geçidi yer tutucuları R JSON'undaki biçimli değerlerle doldurur. Bilinmeyen anahtar hata sayılır.
2. Doldurmadan sonra metinde kalan her rakam ve sayı sözcüğü (`numberCheck.ts`) ayıklanır. Bu kapsama Türkçe ondalık virgülü, baştaki sıfırı yazılmamış değerler, başa gelen yüzde işareti (%5), aralıklar, Unicode eksi işareti ve yazıyla sayılar ("iki", "yüzde elli") dâhildir.
3. Bu sayılar sonuç JSON'undaki değerlerle karşılaştırılır (yuvarlama toleransıyla). Eşleşmeyen sayılar kırmızıyla işaretlenir ve metnin üstünde "Bu yanıtta sonuçlarda bulunmayan sayılar var" uyarısı çıkar.
4. Eşleşmeyen sayı içeren metin rapora eklenemez.

**Etiket ve kayıt:**
- Yapay zekâ metinleri her zaman "Yapay zekâ yorumu — doğrulayınız" etiketiyle gösterilir.
- Rapora yalnızca kullanıcı onayıyla ve etiketiyle eklenebilir.
- Her istem ve yanıt (ham veri olmadan) oturum günlüğüne yazılır. Bu günlük, makalelerdeki yapay zekâ kullanım beyanı için dışa aktarılabilir.

**Kabul:**
- Ağ bağlantısı kesik yerel modda `local` sağlayıcı çalışır.
- Sayı denetleyici, zor durumları içeren test derleminde uydurulmuş sayıları %100 yakalar.
- `none` modunda hiçbir dış istek gitmez.

### M12 — Tekrarlanabilirlik ve proje dosyası
- Her analiz için bağımsız çalışabilen bir R betiği üretilir (veri yolu yer tutucuyla). Betik paket sürümlerini, RNG türünü ve tohumu denetler.
- **Proje dışa aktarma** (`.olceklab.zip`) şunları içerir:
  - ayarlar,
  - sonuç JSON'ları,
  - R betikleri,
  - sürüm bilgisi,
  - veri özeti (SHA-256).
  Veri dosyası varsayılan olarak pakete eklenmez; eklenmesi için kullanıcının açık onayı gerekir.
- Proje içe aktarıldığında aynı veri yüklenirse sonuçlar yeniden üretilip karşılaştırılır. Karşılaştırma 17 basamaklı değerlerle yapılır; paket sürümleri farklıysa uyarı verilir.

---

## 8. API (R motoru, plumber)

| Yöntem | Yol | Açıklama |
|---|---|---|
| POST | `/datasets` | Dosya yükle (gövde: ham dosya baytları; `?filename=`) → `dataset_id`, sütun önizlemesi, kimlik sütunu önerileri |
| POST | `/datasets/examples/{name}` | Örnek veri seti (`holzinger`, `bfi`) |
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
| POST | `/models/preview` | Model kurucu önizlemesi: lavaan sözdizimi, yapı ve uyarılar; model verilmezse M1 alt boyutlarından varsayılan model (v1.2) |
| POST | `/simulations/estimate` | M9 süre tahmini: en büyük N'li koşulda iki tekrar ölçülür; üst sınırdır (v1.2) |
| POST | `/simulations/population/from-cfa` | M9 popülasyon tanımını bir DFA sonucundan kur (`analysis_id`, `shift`); yalnızca özet parametreler (v1.2) |
| POST | `/simulations` | M9 işi başlat → `job_id` |
| GET | `/jobs/{id}` | durum, ilerleme, tahmini süre |
| POST | `/jobs/{id}/cancel` · `/jobs/{id}/resume` | iş denetimi |
| GET | `/simulations/{id}/results` | özet sonuçlar |
| GET | `/simulations/{id}/package` | bağımsız R paketi (zip) |
| POST | `/reports/docx` | M10 |
| POST | `/reports/preview` | M10 önizleme: şablon metinler (italik parçalarıyla) ve tablo numaraları (v1.2) |
| GET | `/analyses/{id}/tables/{tid}/csv` | M10 tablo CSV'si: `lang`, `values = formatted · raw` (v1.2) |
| GET | `/analyses/{id}/script` | M12 R betiği |
| POST | `/projects/export` | M12 proje dosyası (.olceklab.zip); veri yalnızca `include_data` + `data_consent` ile (v1.2) |
| POST | `/projects/import` | M12 proje dosyasını oku: özet, sürüm uyarıları (v1.2) |
| POST | `/projects/{id}/reproduce` | M12 yeniden üretim ve 17 basamaklı karşılaştırma (v1.2) |
| GET | `/health` · `/versions` | sağlık ve sürüm bilgisi |

- Bütün yanıtlar Bölüm 6.2'deki yapıdadır.
- Sayılar 17 anlamlı basamakla serileştirilir (`digits = I(17)`) (v1.1: REP-6).
- Hatalar `{ "error": { "code": "...", "message_tr": "...", "detail": "R hata metni" } }` biçimindedir. Uygulanmamış uç noktalar 501 döndürür.
- Bütün analizler mirai işçilerinde çalışır (Bölüm 3). Uzun işler (Bollen–Stine, büyük simülasyon) ayrıca iş kuyruğuna gider.

---

## 9. Arayüz (sayfa akışı)

1. **Başlangıç:** yeni proje, proje içe aktarma, örnek veriyle deneme (HolzingerSwineford1939; psych içinden bfi), R motoru durumu.
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

Her sonuç sayfasında "Bu analizin R kodunu indir" ve "Bu sonucu rapora ekle" düğmeleri bulunur. Tablolarda gösterilen bütün sayılar R'nin biçimlediği metinlerdir.

---

## 10. Güvenlik ve gizlilik (KVKK)

- Yüklenen veriler diske kalıcı yazılmaz. XLSX dosyası okunurken bellek tabanlı `/dev/shm` altında kısa süre tutulur ve hemen silinir.
- Oturum belleği 60 dakika işlem olmadığında serbest bırakılır. R'nin belleği güvenli biçimde sıfırlamadığı gizlilik bildiriminde yazar (v1.1: ARCH-7).
- Simülasyon parçaları yalnızca sentetik veri içerir.
- Dosya boyutu sınırı (çevrim içi: 10 MB) ve satır sınırı ayarlanabilir.
- Yükleme ekranında, öğrenci verisinin kimlik bilgisi (ad, numara, T.C. kimlik no) içermemesi gerektiğini belirten bir uyarı bulunur. "Kimlik sütunlarını otomatik algıla ve kaldır" seçeneği vardır; algılama sezgiseldir (v1.1: PRIV-1).
- Çevrim içi modda HTTPS kullanılır, CORS yalnızca ön yüz alan adına açıktır ve istek hız sınırlaması uygulanır.
- Yerel modda dışarıya hiçbir istek gitmez; telemetri yoktur. Yapay zekâ `none` ya da `local` olmalıdır.
- Gizlilik bildirimi `docs/` ve Ayarlar sayfasında yer alır.

---

## 11. Doğrulama ve test

### 11.1 Birim testleri (testthat)
- Her R fonksiyonu için girdi doğrulama ve hata yolu testleri.
- `factor_number.R::parallel_manual` ile `psych::fa.parallel` aynı tohumla aynı önerilen sayıyı ve aynı özdeğer matrisini verir.
- Referans değerler, raporlandıkları basamakta karşılaştırılır: |x − ref| ≤ 0,5 × 10⁻ᵈ (v1.1: REP-2).

### 11.2 Genel referans veri setleri
- `lavaan::HolzingerSwineford1939`: üç faktörlü klasik modelin uyumu; değerler testte `lavaan::cfa` doğrudan çağrılarak üretilir ve motor çıktısıyla karşılaştırılır.
- `psych::bfi`: paralel analiz, AFA ve alfa için.

### 11.3 BİDEKÇET regresyon testleri (özel; veriler depoya konmaz)

Ham veri KVKK kapsamında olduğu için bu testler yalnızca belge sahibinin makinesinde çalışır: `BIDEKCET_DATA_DIR=/veri/klasoru Rscript tests/private/run_bidekcet.R` (v1.2). Beklenen değerler aşağıdadır. Bunlar belge sahibinin referans betiğiyle (`engine/tests/reference/bidekcet_referans.R`) ham Excel dosyalarından üretilmiş; R 4.4.3 ve R 4.5.3'te, lavaan 0.7-2, psych 2.6.9 ve semTools 0.5-9 ile aynı çıkmıştır. Tam çıktı ve `sessionInfo()`: `docs/validation/bidekcet_referans_cikti_2026-11-03.txt` (v1.2: REP-1 yanıtı). Test düzeneğinin kendisi CI'da sentetik, aynı düzende dosyalarla referans betiğe karşı sınanır.

| Analiz | Ayar | Beklenen değer |
|---|---|---|
| Temizleme | Bölüm M1 kuralları ve sırası (v1.2) | Ortaokul: ham 255 → boş sınıf 2 → 253 → eksik 0 → aralık dışı 0 → düz yanıt 3 → **250**. Lise: ham 279 → geçersiz sınıf (4 ve 7) 2 → 277 → eksik 5 → 272 → aralık dışı 0 → düz yanıt 16 → **256** |
| Toplam alfa (12 madde) | psych::alpha | Ortaokul .794; Lise .836 |
| KMO | psych::KMO | Ortaokul .805; Lise .821 |
| Paralel analiz | fa = "pc", n.iter = 1000 | Her iki kademede 2 bileşen |
| DFA Model 4 χ² | ML, likelihood = "wishart" | Ortaokul 147.844 (sd 48); Lise 133.325 (sd 48) |
| DFA Model 1 χ² | aynı | Ortaokul 179.058 (sd 51); Lise 178.149 (sd 51) |
| Δχ² Model 1–Model 4 | anova | Ortaokul 31.21 (sd 3); Lise 44.82 (sd 3) |
| Değişmezlik χ² | wishart, std.lv | Biçimsel 281.168 (96); Metrik 299.621 (104); Skaler 319.77 (112) |
| Çok gruplu SRMR (v1.2) | `srmr_bentler_nomean` (rapor değeri) | Biçimsel .0626; Metrik .0710; Skaler .0713 (lavaan `srmr`: .0583; .0661; .0683) |
| Kısmi metrik | group.partial = "CT=~M10" | Biçimselle Δχ²(7) = 3.64, p = .821 |
| Kısmi skaler | + "M4~1" (M10 kesişimi kısıtlı) | Kısmi metrikle Δχ²(7) = 11.80, p = .107 |
| HTMT (ortaokul, BK–FM) | Pearson, `htmt2 = FALSE`, `absolute = TRUE` (v1.2) | .773 (`absolute = FALSE` ile de .773) |
| HTMT (ortaokul, BK–CT) (v1.2) | Pearson, `htmt2 = FALSE` | `absolute = TRUE`: .451; `absolute = FALSE`: .412 |
| WLSMV Model 4 | `ordered` = 12 madde, `std.lv = TRUE`, her kademe ayrı (v1.2) | `cfi.scaled`: Ortaokul .908; Lise .931. Ayrıca `cfi.robust` .829 / .875; `rmsea.scaled` .096 / .094; `rmsea.robust` .113 / .106 |

Faktör adları: BK = M4, M5, M6, M8; FM = M1, M2, M3; KD = M9, M11; CT = M10, M12, M13. M7 analiz dışıdır. Model 1: BK = M1–M6, M8; CT = M10, M12, M13; KD = M9, M11. Lise dosyasında maddeler `Madde1–Madde13` adını taşır. Değişmezlikte grup değişkeni kademedir (`Ortaokul`, `Lise`; referans grup Ortaokul).

### 11.4 Simülasyon referansı
⏳ `docs/reference_simulation/` paketindeki ayarlarla (tohum 20261030; N = 300, 600, 1000, 1500; 1000 tekrar) beklenen değerler `ozet_tablolar.csv` dosyasındadır. Örnek: N = 600, Senaryo B'de skaler Δχ² gücü .808; ΔCFI/ΔRMSEA gücü .460 (birleşik kuralın VE mi VEYA mı olduğu paketle doğrulanacak). Hızlı CI testi için her koşulda 20 tekrarlık küçük bir sürüm koşulur. Bu küçük sürümde birebir değerler değil, aynı tohumla tekrar üretilebilirlik test edilir.

### 11.5 Uçtan uca testler (playwright)
Örnek veriyle bütün akış: yükle → temizle → paralel analiz → DFA → değişmezlik → küçük simülasyon → Word raporu indir. Akış fazlar ilerledikçe genişletilir.

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
| 6 | M11 yapay zekâ (none/local/evren) + yer tutucu ve sayı denetleyici | Çevrimdışı yerel model çalışır; sayı denetleyici testleri %100 |
| 7 | Dağıtım: Netlify + Hugging Face Space; kullanıcı kılavuzu | Canlı demo; `docs/USER_GUIDE_TR.md` |

---

## 13. İleri sürüm fikirleri (v1 kapsamı dışında)
- Madde tepki kuramı (`mirt`) ve DIF analizi.
- Ağ psikometrisi / keşfedici grafik analizi.
- İkili maddelerde kategorik ölçme değişmezliği (Wu & Estabrook, 2016'nın ikili madde kuralları).
- Eksik veride FIML (ML/MLR; Bollen–Stine ile uyumsuzdur).
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
7. ~~**§11.3 açıklamaları**~~ — 3 Kasım 2026'da yanıtlandı (`docs/validation/CODEX_YANIT_FAZ1.md`).
8. **Referans simülasyon paketi:** `docs/reference_simulation/`, `ozet_tablolar.csv` ve Senaryo B tanımı.

---

## 15. Codex'e verilecek ilk görev (kopyala-yapıştır)

```
Bu depoda SPEC.md ve AGENTS.md dosyalarını oku. Faz 0'ı uygula:
- Bölüm 5'teki klasör yapısını oluştur.
- engine/: R 4.4.3 tabanlı Dockerfile, renv ile Bölüm 4'teki sabit sürümleri kur; /health ve /versions uç noktalarını yaz.
- web/: Vite + React + TypeScript; i18next ile TR/EN; ARES-1 koyu ve açık tema; Bölüm 9'daki sayfalar için boş rotalar.
- ai-gateway/: Fastify iskeleti; AI_PROVIDER=none varsayılanı; henüz dış istek yok.
- docker-compose.yml ile üç servisi bağla; .env.example oluştur.
- CI: R testleri (testthat), web testleri (vitest).
Bittiğinde çalıştırdığın testlerin çıktısını ve docs/VERSIONS.md içeriğini göster. Faz 1'e geçmeden dur.
```

Sonraki fazlar için aynı kalıbı kullan: "SPEC.md Bölüm 12, Faz N'yi uygula; kabul ölçütlerini sağlayan testleri yaz ve çalıştır; çıktıyı göster; bir sonraki faza geçmeden dur."

---

## Kaynaklar (platform içinde atıf yapılan yöntemler)

- Bollen, K. A. (1989). *Structural equations with latent variables*. Wiley.
- Bollen, K. A., & Stine, R. A. (1992). Bootstrapping goodness-of-fit measures in structural equation models. *Sociological Methods & Research, 21*(2), 205–229.
- Byrne, B. M., Shavelson, R. J., & Muthén, B. (1989). Testing for the equivalence of factor covariance and mean structures: The issue of partial measurement invariance. *Psychological Bulletin, 105*(3), 456–466.
- Chen, F. F. (2007). Sensitivity of goodness of fit indexes to lack of measurement invariance. *Structural Equation Modeling, 14*(3), 464–504.
- Cheung, G. W., & Rensvold, R. B. (2002). Evaluating goodness-of-fit indexes for testing measurement invariance. *Structural Equation Modeling, 9*(2), 233–255.
- Collins, L. M., Schafer, J. L., & Kam, C.-M. (2001). A comparison of inclusive and restrictive strategies in modern missing data procedures. *Psychological Methods, 6*(4), 330–351.
- Crawford, A. V., Green, S. B., Levy, R., Lo, W.-J., Scott, L., Svetina, D., & Thompson, M. S. (2010). Evaluation of parallel analysis methods for determining the number of factors. *Educational and Psychological Measurement, 70*(6), 885–901.
- Fornell, C., & Larcker, D. F. (1981). Evaluating structural equation models with unobservable variables and measurement error. *Journal of Marketing Research, 18*(1), 39–50.
- Garrido, L. E., Abad, F. J., & Ponsoda, V. (2013). A new look at Horn's parallel analysis with ordinal variables. *Psychological Methods, 18*(4), 454–474.
- Green, S. B., & Yang, Y. (2009). Reliability of summed item scores using structural equation modeling: An alternative to coefficient alpha. *Psychometrika, 74*(1), 155–167.
- Hancock, G. R. (2001). Effect size, power, and sample size determination for structured means modeling and MIMIC approaches to between-groups hypothesis testing of means on a single latent construct. *Psychometrika, 66*(3), 373–388.
- Henseler, J., Ringle, C. M., & Sarstedt, M. (2015). A new criterion for assessing discriminant validity in variance-based structural equation modeling. *Journal of the Academy of Marketing Science, 43*(1), 115–135.
- Horn, J. L. (1965). A rationale and test for the number of factors in factor analysis. *Psychometrika, 30*(2), 179–185.
- Hu, L., & Bentler, P. M. (1999). Cutoff criteria for fit indexes in covariance structure analysis. *Structural Equation Modeling, 6*(1), 1–55.
- Lorenzo-Seva, U., & ten Berge, J. M. F. (2006). Tucker's congruence coefficient as a meaningful index of factor similarity. *Methodology, 2*(2), 57–64.
- Morris, T. P., White, I. R., & Crowther, M. J. (2019). Using simulation studies to evaluate statistical methods. *Statistics in Medicine, 38*(11), 2074–2102.
- Muthén, L. K., & Muthén, B. O. (2002). How to use a Monte Carlo study to decide on sample size and determine power. *Structural Equation Modeling, 9*(4), 599–620.
- Roemer, E., Schuberth, F., & Henseler, J. (2021). HTMT2 — an improved criterion for assessing discriminant validity in structural equation modeling. *Industrial Management & Data Systems, 121*(12), 2637–2650.
- Rosseel, Y. (2012). lavaan: An R package for structural equation modeling. *Journal of Statistical Software, 48*(2), 1–36.
- Sass, D. A., Schmitt, T. A., & Marsh, H. W. (2014). Evaluating model fit with ordered categorical data within a measurement invariance framework: A comparison of estimators. *Structural Equation Modeling, 21*(2), 167–180.
- Satorra, A. (2000). Scaled and adjusted restricted tests in multi-sample analysis of moment structures. In R. D. H. Heijmans, D. S. G. Pollock, & A. Satorra (Eds.), *Innovations in multivariate statistical analysis* (pp. 233–247). Kluwer.
- Satorra, A., & Bentler, P. M. (2001). A scaled difference chi-square test statistic for moment structure analysis. *Psychometrika, 66*(4), 507–514.
- Satorra, A., & Bentler, P. M. (2010). Ensuring positiveness of the scaled difference chi-square test statistic. *Psychometrika, 75*(2), 243–248.
- Savalei, V. (2021). Improving fit indices in structural equation modeling with categorical data. *Multivariate Behavioral Research, 56*(3), 390–407.
- Steenkamp, J.-B. E. M., & Baumgartner, H. (1998). Assessing measurement invariance in cross-national consumer research. *Journal of Consumer Research, 25*(1), 78–90.
- Velicer, W. F. (1976). Determining the number of components from the matrix of partial correlations. *Psychometrika, 41*(3), 321–327.
- Wu, H., & Estabrook, R. (2016). Identification of confirmatory factor analysis models of different levels of invariance for ordered categorical outcomes. *Psychometrika, 81*(4), 1014–1045.
- Xia, Y., & Yang, Y. (2019). RMSEA, CFI, and TLI in structural equation modeling with ordered categorical data: The story they tell depends on the estimation methods. *Behavior Research Methods, 51*(1), 409–428.
