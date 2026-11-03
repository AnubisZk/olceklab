# Devir notu (Faz 5 sonu + Faz 7 hazırlığı → Faz 7a, 6, 7b)

> **Codex devamı, 3 Kasım 2026:** Aşağıdaki metin özgün devir bağlamını korur. Staged hazırlık `6bfcf9d` ile commit edildi; Faz 7a yayın hazırlığı `e7b311f` ile ilerletildi. Kullanıcı GitHub hedefini `AnubisZk/olceklab` olarak belirledi ve Docker kurulumu yerine yayın dosyalarının hazırlanmasını seçti. Güncel durum, test kanıtları ve kalan işler: [RELEASE_7A_TR.md](RELEASE_7A_TR.md). Canlıya alma henüz tamamlanmadı.

Tarih: 3 Kasım 2026. Bu not, depoyu devralan kodlama ajanı (Codex) için yazılmıştır. Kurallar `AGENTS.md` ve
`SPEC.md` (v1.3) içindedir; bu not onların yerini tutmaz.

## 1. Durum

SPEC §12'deki Faz 0–5 tamamlandı. Her fazın commit'i ayrıdır (`git log`). Kısa özet:

| Faz | Modüller | Arayüz | Kanıt |
|---|---|---|---|
| 1 | M1 temizleme, M2 madde, M3 uygunluk, M4 paralel analiz | Veri, Madde analizi, Faktör sayısı | `docs/test-logs/faz1/` |
| 2 | M5 AFA, M6 DFA + karşılaştırma + Bollen–Stine, M7 güvenirlik/HTMT | AFA, DFA (model kurucu, yol şeması), Güvenirlik | `docs/test-logs/faz2/` |
| 3 | M8 değişmezlik (sürekli, kategorik), skor testleri, gizil ortalamalar | Değişmezlik + kısmi değişmezlik sihirbazı | `docs/test-logs/faz3/` |
| 4 | M9 simülasyon, iş sistemi (kes/sürdür), bağımsız R paketi | Simülasyon | `docs/test-logs/faz4/` |
| 5 | M10 Word raporu, CSV, SVG/PNG; M12 proje dışa/içe aktarma ve yeniden üretim | Rapor, Başlangıç → Projeyi içe aktar | `docs/test-logs/faz5/` |

Son ölçümler (bu ortamda, R 4.4.3, Linux, 2 çekirdek):

- **R motoru:** 1137 test geçti, 0 başarısız (`docs/test-logs/faz5/engine-testthat.txt`). 2 test atlandı; bunlar özel BİDEKÇET testleridir.
- **Ön yüz:** vitest 96/96 (`docs/test-logs/faz5/web-vitest.txt`); typecheck ve build temiz.
- **Playwright uçtan uca:** Faz 1–5 için 5/5 geçti (`docs/test-logs/faz5/e2e-playwright.txt`). Testler bu ortamda önceden kurulu Chromium (build 1243) ile koştu; bkz. §3.
- **Gerçek Firefox akışları:** ekrandaki ya da indirilen dosyadaki metinler, bağımsız R hesabıyla karşılaştırıldı. Sonuçlar: Faz 1 9/9, Faz 2 38/38, Faz 3 38/38, Faz 4 127/127, Faz 5 39/39 aynı.

Doğrulama kayıtlarının tamamı `docs/VALIDATION.md` dosyasında, yöntem ayrıntıları `docs/METHODS_TR.md` dosyasındadır.

## 2. Faz 5'ten sonra yapılanlar (3 Kasım 2026, Codex dışında)

Bu değişiklikler çalışma ağacında **hazırlanmış (staged) ama commit edilmemiş** durumda. İlk iş olarak gözden geçirip tek commit yapın, ör. `Faz 7 hazırlık: kullanıcı kılavuzu, kurulum belgesi, dağıtım dosyaları; SPEC v1.3`.

| Dosya | İçerik |
|---|---|
| `docs/USER_GUIDE_TR.md` | Kullanıcı kılavuzu, 13 bölüm. Faz 7'nin kılavuz ölçütü karşılandı. |
| `docs/img/01–16_*.png` | Kılavuzdaki ekran görüntüleri. Yerelde çalışan gerçek motor + arayüz ile HolzingerSwineford1939 örneğinden alındı. |
| `docs/KURULUM_TR.md` | Hugging Face Space, Netlify, yerel Docker, CORS ve özel testler için adım adım kurulum. |
| `deploy/hf-space/Dockerfile`, `deploy/hf-space/README.md` | Motor Space'i için: `engine/Dockerfile` + çevrim içi ortam değişkenleri, Space YAML başlığı (`sdk: docker`, `app_port: 8000`). Lisans satırı yok; lisans belge sahibinin kararı (SPEC §14 madde 6). |
| `deploy/netlify/_redirects`, `_headers`, `netlify.toml` | SPA yönlendirmesi (`/* /index.html 200`), güvenlik başlıkları, `publish = "."`. |
| `SPEC.md` v1.3 | M11'e genel `api` sağlayıcısı; çevrim içi modda ağ geçidi ayrı Space; motor `app_port: 8000`; §14 madde 1b. |

Bu ortamda (Linux, R 4.5.3, Node 22 + Node 24) yeniden ölçülenler:
- **R testthat:** 1134 geçti, 3 atlandı, 1 başarısız. Başarısız test `test-versions.R`'dir: yerel R 4.5.3 / semTools 0.5.9, `renv.lock` ile uyuşmuyor. Kodla ilgili değil, yalnızca ortam farkı.
- **vitest:** Node 24 ile 96/96. Node 22'de `phase5Flow` testlerinden 3–4'ü düşüyor; `package.json` zaten `node >= 24` istiyor.
- **Playwright:** 5/5.
- **Özel BİDEKÇET testi:** belge sahibinin verisiyle 58/58 AYNI.
- **Docker:** hâlâ hiç derlenmedi.

## 3. Sıradaki işler

### Faz 7a — Canlıya alma (önce bu; yapay zekâsız da tam çalışır)

Hedef adresler:

| Parça | Hedef | Adres |
|---|---|---|
| Ön yüz | Netlify sitesi `olceklab` (site kimliği `45934862-1f76-42f3-b1b4-389e6335098e`) | https://olceklab.netlify.app |
| Motor | Hugging Face Space `OsirisZk/olceklab-engine`, Docker SDK, CPU basic | https://osiriszk-olceklab-engine.hf.space |

1. **Motor imajını yerelde derleyin:** `docker build -f deploy/hf-space/Dockerfile engine`, ardından `docker run -p 8000:8000` ile çalıştırın. Bu, SPEC §3'teki en büyük açık risktir. `officer`/`flextable`/`ragg` için sistem kütüphaneleri eksikse (fontconfig, freetype, harfbuzz, fribidi, libpng, libtiff, libjpeg) `engine/Dockerfile` içine `apt-get` ile ekleyin. Değişikliği `deploy/hf-space/Dockerfile`'a da taşıyın.
2. **Testleri imajın içinde çalıştırın.** `Rscript -e 'testthat::test_dir("tests/testthat")'` komutu kilitli sürümlerle 0 başarısızlık vermelidir; `test-versions.R` de geçmelidir.
3. **Space'i oluşturun ve gönderin.** `hf` CLI ya da `git push` kullanın; kök dizinde `deploy/hf-space/{Dockerfile,README.md}` + `engine/` içeriği bulunmalıdır. Belirteç (token) belge sahibinden alınır ve depoya yazılmaz.
   - Build günlüğünü izleyin.
   - `/health` → `{"status":"ok",...}` ve `/versions` yanıtlarını doğrulayın.
4. **Ön yüzü derleyin ve yayınlayın:**
   ```
   VITE_ENGINE_URL=https://osiriszk-olceklab-engine.hf.space VITE_DEPLOY_MODE=online npm run build
   ```
   - `deploy/netlify/*` dosyalarını `dist/` içine kopyalayın.
   - `netlify deploy --prod --dir dist --site 45934862-1f76-42f3-b1b4-389e6335098e` ile yayınlayın (ya da belge sahibi sürükle-bırak yapar).
5. **Canlı duman testi.** Playwright testlerini `baseURL=https://olceklab.netlify.app` ile koşun ya da en azından şu akışı elle sınayın:
   - Başlangıç → motor "Çalışıyor",
   - örnek veri → temizleme,
   - paralel analiz,
   - DFA,
   - küçük simülasyon (N = 300, 20 tekrar),
   - Word raporu.

   Ayrıca şunları denetleyin:
   - CORS: başka bir kökenden gelen istek reddedilmeli.
   - Çevrim içi sınır: tekrar × koşul > 2000 reddedilmeli.
6. **CI.** `.github/workflows/ci.yml` dosyasını GitHub'da (`AnubisZk` hesabı, depo adı belge sahibine sorulur) bir kez yeşile çıkarın. İsteğe bağlı: `main` dalına push yapıldığında Netlify ve HF Space'e otomatik dağıtım. Belirteçler GitHub Secrets'ta tutulur.
7. **Kanıt.** Çıktıları `docs/test-logs/faz7/` klasörüne koyun ve `docs/VALIDATION.md` dosyasına bir satır ekleyin.

### Faz 6 — M11 yapay zekâ yorum asistanı, API ile (SPEC §7 M11 v1.3, AI-1, AI-2)

Belge sahibinin kararı: yapay zekâ **API üzerinden** çalışacak. Bunun için genel, OpenAI uyumlu bir `api` sağlayıcısı eklenir. EVREN de belgeleri gelince aynı istemciyle (ya da ayrı bir bağdaştırıcıyla) bağlanır. `local` (Ollama) çevrimdışı kullanım için kalır.

**Ağ geçidi (`ai-gateway/`):**

1. **Sağlayıcı `api`:**
   - `config.ts` → `PROVIDERS` listesine `'api'` ekleyin.
   - Ortam değişkenleri: `AI_API_BASE_URL`, `AI_API_KEY`, `AI_API_MODEL`. Hiçbirinin varsayılan değeri yoktur; eksikse `ConfigError` verilir.
   - `providers/local.ts` içindeki OpenAI uyumlu istemciyi ortak bir `openaiCompatible.ts` dosyasına taşıyın. `api` bu istemciyi `Authorization: Bearer <AI_API_KEY>` başlığıyla kullanır.
   - Anahtar hiçbir yanıtta, günlükte ya da hata iletisinde görünmemelidir. Bunun için bir test yazın.
2. **Kötüye kullanım önlemleri (çevrim içi):**
   - IP başına dakikalık istek sınırı: `AI_RATE_LIMIT_PER_MINUTE` (önerilen varsayılan 10).
   - Çıktı token sınırı: `AI_MAX_OUTPUT_TOKENS`.
   - İstek gövdesi boyut sınırı.
   - CORS yalnızca `ALLOWED_ORIGINS`.
   - Bunların hepsi ortam değişkeninden okunur.
3. **Yer tutucu doldurma.**
   - Anahtarlar sonuç kaydındaki biçimli değerlere bağlanır, ör. `{{cfa.T1.cfi}}`.
   - Kayıtlarda `tables[*].rows_fmt.{tr,en}` R'nin biçimlediği metni taşır. Anahtar–değer tablolarında satır `key` sütunuyla bulunur, ör. DFA T1'de `key = "cfi"` ve sütunlar `value`, `scaled`, `robust`.
   - Bilinmeyen anahtar hata sayılır.
   - İsteme, o kayıtta geçerli anahtarların listesi verilir. Modele sayıların kendisi değil, yalnızca anahtar adları ve anlamları gönderilir. Böylece model sayı kopyalayamaz.
4. **Sayı denetleyici (`numberCheck.ts`, SPEC AI-1).**
   - Ayıklanacak biçimler:
     - Türkçe ondalık virgülü;
     - baştaki sıfırı yazılmamış değerler (`,931`);
     - başa gelen yüzde (`%5`, `−%1,0`);
     - aralıklar (`[,071; ,114]`);
     - Unicode eksi (`−`);
     - yazıyla sayılar (`iki`, `yüzde elli`, İngilizcede `two`, `fifty percent`).
   - Test derleminde uydurulmuş sayıların %100'ü yakalanmalıdır. Derlem, gerçek fikstür kayıtlarından (`web/tests/fixtures/`) türetilir. Uydurulmuş örnekler elle yazılabilir; bunlar hesap sonucu değil, yanlış metin örnekleridir.
5. **Oturum günlüğü:**
   - İstem ve yanıt kaydedilir; ham veri, anahtar ve IP kaydedilmez.
   - Kayıt; sağlayıcı adını, model adını, zaman damgasını ve sayı denetimi sonucunu içerir.
   - Günlük JSON ve Markdown olarak dışa aktarılır. Makalelerdeki yapay zekâ kullanım beyanı içindir.

**Motor (`engine/`):**

6. **Rapora ekleme:**
   - `POST /reports/docx` ve `POST /reports/preview` uç noktalarına isteğe bağlı `ai_texts` alanı eklenir: `[{record_id, text, check_passed, provider, model}]`.
   - `check_passed = false` olan metin reddedilir (HTTP 422).
   - Kabul edilen metin "Yapay zekâ yorumu — doğrulayınız" etiketiyle eklenir.
   - Raporun yapay zekâ beyanı, kullanılan sağlayıcı ve modele göre R'de üretilir. Yapay zekâ metni eklenmemişse bugünkü "yapay zekâ kullanılmamıştır" beyanı korunur.

**Ön yüz (`web/`):**

7. **Analiz sonuç kartlarında "Yapay zekâ ile yorumla" düğmesi.** Yalnızca `VITE_AI_GATEWAY_URL` tanımlıysa ve `/health` ile sağlayıcı ≠ `none` ise görünür.
   - Yanıt metni etiketli bir kutuda gösterilir.
   - Eşleşmeyen sayılar kırmızıyla işaretlenir ve metnin üstünde uyarı çıkar.
   - Metin, **Rapora ekle (onaylıyorum)** düğmesiyle rapora eklenir; denetimden geçemeyen metinde bu düğme kapalıdır.
8. **Ayarlar sayfası:**
   - sağlayıcı ve model adının gösterimi (ağ geçidinden okunur, anahtar gösterilmez),
   - gizlilik notu ("Yapay zekâya yalnızca toplu sonuç tabloları gönderilir"),
   - oturum günlüğünü dışa aktarma.
9. **i18n:** TR ve EN metinleri.

**Dağıtım (Faz 7b):**

10. **Ağ geçidini ayrı bir Space olarak yayınlayın:** `OsirisZk/olceklab-ai` (Docker SDK, `ai-gateway/Dockerfile`, `app_port` = `AI_GATEWAY_PORT`).
    - Space **Secrets**: `AI_API_KEY`.
    - Space **Variables**: `AI_PROVIDER=api`, `AI_API_BASE_URL`, `AI_API_MODEL`, `ALLOWED_ORIGINS=https://olceklab.netlify.app` ve sınırlar.
11. **Ön yüzü yeniden derleyin:** `VITE_AI_GATEWAY_URL=https://osiriszk-olceklab-ai.hf.space` ile derleyip yeniden yayınlayın. Kılavuzun 12. bölümünü ("henüz etkin değil") güncelleyin ve yapay zekâ akışı için ekran görüntüsü ekleyin.

**Faz 6 kabul ölçütleri:**
- `none` modunda hiçbir dış istek gitmez (test).
- `api` modunda sahte (mock) bir OpenAI uyumlu sunucuyla uçtan uca akış çalışır: yorum → denetim → rapora ekleme → docx'te etiketli metin. Testlerde gerçek API çağrılmaz.
- Sayı denetleyici %100 yakalar.
- Anahtar sızıntısı testi geçer.
- Hız sınırı testi geçer.
- Ağ bağlantısı kesikken `local` sağlayıcı çalışır (Ollama ile; yerel testte).

### Belge sahibinden alınacaklar (varsaymayın; SPEC §14)

- **`api` için:** sağlayıcı, model adı, temel adres ve aylık bütçe. Anahtar yalnızca Space Secrets'a girilir; sohbete ya da depoya yazılmaz.
- **EVREN için:** belgeli uç nokta, kimlik doğrulama biçimi ve model adı. Bu bilgiler gelene kadar `evren.ts` 501 döndürmeye devam eder.
- **`local` için:** Ollama model adı.
- **Hugging Face ve Netlify erişimi:** HF belirteci ya da Space'i belge sahibinin oluşturması; Netlify erişimi.
- **Lisans** (SPEC §14 madde 6) ve GitHub depo adı.

## 4. Bu ortamda doğrulanamayanlar (ilk iş olarak denetleyin)

- **`docker compose up --build` ve GitHub Actions (`.github/workflows/ci.yml`).** Docker daemon'u yoktu ve GitHub hesabı bağlı değildi; ikisi de hiç koşmadı.
  - Motor imajı `renv::restore` kullanıyor; `officer` ve `flextable` için sistem kütüphaneleri gerekebilir.
  - CI motor işinde de aynı risk var.
- **Netlify ve Hugging Face'e gönderim.** Bu ortamdan iki servise de ağ erişimi yoktu, bu yüzden canlı yayın hiç yapılmadı.
- **Playwright tarayıcısı.** Yapılandırma, Playwright'ın kendi Chromium'unu bekler (`npx playwright install --with-deps chromium`). Testler git'e girmeyen yerel bir yapılandırmayla, önceden kurulu Chromium ile koşturuldu.
- **§11.3 BİDEKÇET gerçek verisi.** Testler yalnızca belge sahibinin makinesinde koşar (KVKK; veri depoda yok):
  `cd engine && BIDEKCET_DATA_DIR=… LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R`
  Son çalıştırmada 58/58 aynı çıktı.
- **§11.4 referans simülasyonu** yok; REP-4 paketi bekleniyor. Yazılım kabulü olarak 1000 tekrarlık I. tip hata testi geçti: metrik ,051, skaler ,040.
- **LibreOffice ile docx → PDF testi** (`test-report.R`), `soffice` yoksa atlanır.

## 5. Bilinen sınırlar ve bilinçli kararlar

- **SB2001 negatif Δχ² → SB2010 dalı** gerçek veride bulunamadı. Bu dal sahte bir ilk sonuçla sınandı (`test-cfa-compare.R`).
- **Kategorik değişmezlik ikili maddelerde v1'de kapalıdır.** Üç kategoride eşik adımı atlanır.
- **Simülasyon:**
  - WLSMV'de ω'nın popülasyon değeri hesaplanmaz (—).
  - Sıralı veri ML/MLR ile analiz edilirse gerçek değerler sözde-gerçek değerlerdir.
  - T4'teki "ölçü türü" (I. tip hata / güç / karışık) adıma ve DIF türüne göre belirlenir (`sim_step_kind`).
- **Proje dosyası (M12)** veri setine bağlı analizleri içerir. Simülasyonun tekrarlanabilirliği bağımsız R paketiyle sağlanır; simülasyon kayıtları rapora eklenebilir ama proje dosyasına girmez.
- **Word raporu ana süreçte üretilir.** Bu bir analiz değildir ve ~1 sn sürer. Proje yeniden üretimi ise mirai işçisinde çalışır.
- **Yüklenen dosyanın özgün baytları** yalnızca bellekte tutulur (`ds$raw`), böylece kullanıcı onayıyla projeye eklenebilir. Proje zip'i yalnızca işlem süresince geçici dizinde bulunur.

## 6. Bu depoda yaşanmış tuzaklar (tekrarlamayın)

- **plumber JSON ayrıştırıcısı.** Faz 2+ uç noktalarında `#* @parser json list(simplifyVector = FALSE)` kullanılır. Basitleştirme, iç içe listeleri veri çerçevesine çevirir.
- **R'de `$` kısmi eşleşme yapar.** `cell$invariance` yokken `invariance_status` döndü ve tek gruplu simülasyon çöktü. Liste alanları için `[["ad"]]` kullanın.
- **`auto_unbox = TRUE` ile uzunluğu 1 olan vektör JSON'da skaler olur, `NULL` ise `null` olur.** Ön yüzün dizi beklediği her alan `I(...)` ile sarılmalı ya da `character(0)` döndürmelidir. Örnekler: kaynakça, not listeleri, `diffs`.
- **`@serializer contentType` uç noktalarında hata gövdesi.** Hata işleyicisi `res$serializer` değerini JSON'a çevirir (`engine_error_handler`); bunu kaldırmayın.
- **Sayılar ön yüzde biçimlenmez.** Yeni metin gerekiyorsa R'de `fmt_*` ile üretip `text_tr`/`text_en` olarak gönderin.
- **Fikstürler gerçek motor çıktısıdır.** Motor değişince `LANG=C.UTF-8 Rscript web/tests/fixtures/generate.R` (depo kökünden) ile yeniden üretin.

## 7. Codex'e verilecek görev (kopyala-yapıştır)

```
Bu depoda AGENTS.md, SPEC.md (v1.3) ve docs/HANDOFF_CODEX.md dosyalarını oku.
1) Hazırlanmış (staged) değişiklikleri gözden geçir ve tek commit yap.
2) HANDOFF §3 "Faz 7a — Canlıya alma" adımlarını uygula: motor imajını yerelde derle ve imaj içinde testleri 0 başarısızlıkla geçir; OsirisZk/olceklab-engine Space'ine gönder; ön yüzü online derleyip Netlify'a (olceklab) yayınla; canlı duman testini yap ve çıktıları docs/test-logs/faz7/ altına koy. Belirteç gerekirse benden iste; hiçbir anahtarı depoya yazma.
3) Faz 7a bittiğinde dur, canlı adresleri ve test çıktısını göster.
4) Onayımdan sonra HANDOFF §3 "Faz 6" maddelerini uygula: `api` sağlayıcısı, yer tutucu + sayı denetleyici, rapora onaylı ekleme, oturum günlüğü. Testlerde gerçek API çağırma; sahte OpenAI uyumlu sunucu kullan. Sağlayıcı, model ve adres bilgisini benden iste; varsayma.
5) Faz 6 kabul ölçütleri geçince Faz 7b'yi (ağ geçidi Space'i + ön yüzü yeniden derleme + kılavuz güncellemesi) uygula ve dur.
```
