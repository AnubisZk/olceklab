# Devir notu (Faz 5 sonu → Faz 6–7)

Tarih: 3 Kasım 2026. Bu not, depoyu devralan kodlama ajanı (Codex) için yazılmıştır. Kurallar `AGENTS.md` ve
`SPEC.md` (v1.2) içindedir; bu not onların yerini tutmaz.

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

## 2. Sıradaki işler

### Faz 6 — M11 yapay zekâ yorum asistanı (SPEC §7 M11, SPEC_REVIEW AI-1, AI-2)

`ai-gateway/` iskeleti hazır. Fastify ile `none`, `local` ve `evren` sağlayıcıları var; `numberCheck.ts` bilinçli olarak hata verir.

Yapılacaklar:

1. **Yer tutucu doldurma.**
   - Anahtarlar sonuç kaydındaki biçimli değerlere bağlanır, ör. `{{cfa.T1.cfi}}`.
   - Kayıtlarda `tables[*].rows_fmt.{tr,en}` R'nin biçimlediği metni taşır. Anahtar–değer tablolarında satır `key` sütunuyla bulunur, ör. DFA T1'de `key = "cfi"` ve sütunlar `value`, `scaled`, `robust`.
   - Bilinmeyen anahtar hata sayılır.
2. **Sayı denetleyici (SPEC AI-1).**
   - Ayıklanacak biçimler:
     - Türkçe ondalık virgülü;
     - baştaki sıfırı yazılmamış değerler (`,931`);
     - başa gelen yüzde (`%5`, `−%1,0`);
     - aralıklar (`[,071; ,114]`);
     - Unicode eksi (`−`);
     - yazıyla sayılar.
   - Test derleminde uydurulmuş sayıların %100'ü yakalanmalıdır.
3. **Rapora ekleme.**
   - Yapay zekâ metni yalnızca kullanıcı onayıyla ve "Yapay zekâ yorumu — doğrulayınız" etiketiyle eklenir.
   - Eşleşmeyen sayı içeren metin rapora eklenemez.
   - Bunun için rapor uç noktalarına (`POST /reports/docx`, `POST /reports/preview`) isteğe bağlı bir `ai_texts` alanı eklenmelidir. Şu an rapor metinleri yalnızca şablondandır ve "yapay zekâ kullanılmamıştır" beyanını taşır.
4. **Oturum günlüğü** (istem ve yanıt, ham veri olmadan) ve bu günlüğün dışa aktarılması.
5. **EVREN:** uç nokta, kimlik doğrulama ve model adı belgelenmeden hiçbir şey varsayılmaz (AGENTS.md kural 5). Değerler `.env` dosyasından okunur.

### Faz 7 — Dağıtım ve kılavuz

- Netlify (ön yüz) ve Hugging Face Space (motor; `engine/Dockerfile` 1000 numaralı kullanıcıyla çalışır).
- Çevrim içi modda `ONLINE_LIMITS=true` ayarlanır (`.env.example`, `docker-compose.yml`).
- `docs/USER_GUIDE_TR.md` henüz boş.

## 3. Bu ortamda doğrulanamayanlar (ilk iş olarak denetleyin)

- **`docker compose up --build` ve GitHub Actions (`.github/workflows/ci.yml`).** Docker daemon'u yoktu ve GitHub hesabı bağlı değildi; ikisi de hiç koşmadı.
  - Motor imajı `renv::restore` kullanıyor. `officer` ve `flextable` için sistem kütüphaneleri gerekebilir: fontconfig, freetype, harfbuzz, fribidi, libpng.
  - CI motor işinde de aynı risk var.
- **Playwright tarayıcısı.** Yapılandırma, Playwright'ın kendi Chromium'unu bekler (`npx playwright install --with-deps chromium`). Bu ortamda yalnızca eski bir yapı vardı; testler git'e girmeyen `web/playwright.local.config.ts` ile koşturuldu.
- **§11.3 BİDEKÇET gerçek verisi.** Testler yalnızca belge sahibinin makinesinde koşar (KVKK; veri depoda yok):
  `cd engine && BIDEKCET_DATA_DIR=… LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R`
  Sentetik dosyalarla düzenek, sahibin referans betiğiyle birebir aynı sonuç veriyor (`test-bidekcet-harness.R`).
- **§11.4 referans simülasyonu** yok; REP-4 paketi bekleniyor. Yazılım kabulü olarak 1000 tekrarlık I. tip hata testi geçti: metrik ,051, skaler ,040.
- **LibreOffice ile docx → PDF testi** (`test-report.R`), `soffice` yoksa atlanır. CI'da büyük olasılıkla atlanacaktır.

## 4. Bilinen sınırlar ve bilinçli kararlar

- **SB2001 negatif Δχ² → SB2010 dalı** gerçek veride bulunamadı. Bu dal sahte bir ilk sonuçla sınandı (`test-cfa-compare.R`).
- **Kategorik değişmezlik ikili maddelerde v1'de kapalıdır.** Üç kategoride eşik adımı atlanır.
- **Simülasyon:**
  - WLSMV'de ω'nın popülasyon değeri hesaplanmaz (—).
  - Sıralı veri ML/MLR ile analiz edilirse gerçek değerler sözde-gerçek değerlerdir.
  - T4'teki "ölçü türü" (I. tip hata / güç / karışık) adıma ve DIF türüne göre belirlenir (`sim_step_kind`).
- **Proje dosyası (M12)** veri setine bağlı analizleri içerir. Simülasyonun tekrarlanabilirliği bağımsız R paketiyle sağlanır; simülasyon kayıtları rapora eklenebilir ama proje dosyasına girmez.
- **Word raporu ana süreçte üretilir.** Bu bir analiz değildir ve ~1 sn sürer. Proje yeniden üretimi ise mirai işçisinde çalışır.
- **Yüklenen dosyanın özgün baytları** yalnızca bellekte tutulur (`ds$raw`), böylece kullanıcı onayıyla projeye eklenebilir. Proje zip'i yalnızca işlem süresince geçici dizinde bulunur.

## 5. Bu depoda yaşanmış tuzaklar (tekrarlamayın)

- **plumber JSON ayrıştırıcısı.** Faz 2+ uç noktalarında `#* @parser json list(simplifyVector = FALSE)` kullanılır. Basitleştirme, iç içe listeleri veri çerçevesine çevirir.
- **R'de `$` kısmi eşleşme yapar.** `cell$invariance` yokken `invariance_status` döndü ve tek gruplu simülasyon çöktü. Liste alanları için `[["ad"]]` kullanın.
- **`auto_unbox = TRUE` ile uzunluğu 1 olan vektör JSON'da skaler olur, `NULL` ise `null` olur.** Ön yüzün dizi beklediği her alan `I(...)` ile sarılmalı ya da `character(0)` döndürmelidir. Örnekler: kaynakça, not listeleri, `diffs`.
- **`@serializer contentType` uç noktalarında hata gövdesi.** Hata işleyicisi `res$serializer` değerini JSON'a çevirir (`engine_error_handler`); bunu kaldırmayın.
- **Sayılar ön yüzde biçimlenmez.** Yeni metin gerekiyorsa R'de `fmt_*` ile üretip `text_tr`/`text_en` olarak gönderin.
- **Fikstürler gerçek motor çıktısıdır.** Motor değişince `LANG=C.UTF-8 Rscript web/tests/fixtures/generate.R` (depo kökünden) ile yeniden üretin.
