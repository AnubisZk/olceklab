# Faz 7a — yayın adayı ve kalan doğrulamalar

Tarih: 3 Kasım 2026. Durum: **yayın adayı hazır; canlıya alma kabulü henüz tamamlanmadı.** Kullanıcı bu bilgisayarda Docker kurmak yerine yayın dosyalarının hazırlanmasını ve kalan kontrollerin belgelenmesini seçti.

GitHub hedefi: <https://github.com/AnubisZk/olceklab>. Yerel `origin` bu adrese ayarlandı. Bu çalışmada GitHub'a push veya Hugging Face/Netlify yayını yapılmadı.

## Yapılan değişiklikler

- Devirdeki 26 staged dosya `6bfcf9d` commit'iyle korundu.
- İki motor Dockerfile'ında UID 1000 kullanıcısına `/app/test-results` yazma hakkı verildi. Paketlerin sistem kütüphaneleri zaten listeleniyordu; doğrulanmamış ek bağımlılık eklenmedi.
- İzin verilmeyen `Origin` başlığı artık 403 `origin_not_allowed` ile reddedilir. GET, OPTIONS ve basit POST için R regresyon testleri eklendi. Origin başlığı olmayan sağlık/CLI istekleri çalışmaya devam eder; bu kontrol kimlik doğrulama yerine geçmez.
- Faz 4 Playwright akışı motor adresini gerçek başlatma yanıtından alır; canlı testte localhost'a dönmez.
- Ayrı çevrim içi test takımı: sürümler, CORS, 2000 sınırı; örnek veri → temizleme → paralel analiz → DFA → N=300/20 tekrar → Word indirme.
- CI motor testlerini doğrudan HF Docker imajında çalıştırır ve JUnit çıktısını alır. Compose akışı önce yerel, sonra çevrim içi modda sınanır. `workflow_dispatch` eklendi. **İş akışı henüz GitHub'da çalıştırılmadı.**
- `deploy/prepare-release.mjs`: Windows/Linux üzerinde çevrim içi web derlemesi ve HF dizinini hazırlar; AI kapalıdır. Motor için yalnızca Git tarafından izlenen R kodu, test betikleri ve açıkça izin verilen sentetik XLSX fikstürleri kopyalanır. Gerçek veri, `.env`, Git geçmişi ve `node_modules` yayın paketine alınmaz. Dosya SHA-256 değerleri `manifest.json` içinde bulunur.

## Bu bilgisayarda doğrulananlar

Windows; Node 24.22.1; taşınabilir npm 11.19.1. Paket kilitleri değiştirilmedi.

| Kontrol | Durum | Kanıt |
|---|---|---|
| Web vitest | 96/96 geçti | `test-logs/faz7/web-vitest.txt` |
| Gateway vitest | 11/11 geçti | `test-logs/faz7/ai-gateway-vitest.txt` |
| Web ve gateway typecheck | Geçti | `test-logs/faz7/*-typecheck.txt` |
| Gateway derleme | Geçti | `test-logs/faz7/ai-gateway-build.txt` |
| Çevrim içi web derleme (AI kapalı) | Geçti; ECharts parçası için 500 kB boyut uyarısı var | `test-logs/faz7/web-online-build.txt` |
| Paketleme ve iki Dockerfile'ın tutarlılığı | 2/2 geçti | `test-logs/faz7/deploy-tests.txt` |
| Yayın içeriği ve YAML yapıları | 121 dosya SHA-256 doğrulandı; motor URL'si, SPA yönlendirmesi, HF portu ve localhost adreslerinin bulunmaması doğrulandı | `test-logs/faz7/release-verification.txt` |
| Çevrim içi Playwright test keşfi | 2 test bulundu; çalıştırma değildir | `test-logs/faz7/online-test-list.txt` |
| Docker / R / uçtan uca akış | Koşmadı: Docker, R ve WSL yok | `test-logs/faz7/environment.txt` |
| Hedef adresler | Netlify kökü ve HF `/health`: HTTP 404 | `test-logs/faz7/endpoint-probe.txt` |

Geçmiş Faz 1–5 sonuçları güncel kodun yeniden doğrulandığı anlamına gelmez. Özellikle yeni R CORS davranışı Docker'da çalıştırılmayı bekler. Özel BİDEKÇET testi ve LibreOffice testi için gerekli ortam yoksa atlamalar ayrıca raporlanmalıdır.

Hazır dosyalar: `olceklab-netlify.zip` (statik web), `olceklab-hf-space.zip` (motor kaynakları), `olceklab-phase7a-source.zip` (güncel kaynak depo; bağımlılıklar ve Git geçmişi hariç). Yayın adayı `e7b311f` kaynak commit'inden oluşturuldu; `release-candidate/manifest.json` dosya bazında SHA-256 içerir. Sonraki belge/kanıt commit'i uygulama kodunu değiştirmez.

## Paketleri yeniden üretme

Node 24+, npm ve Git gerekir. Depo kökünden:

```bash
npm --prefix web ci
node --test deploy/prepare-release.test.mjs
node deploy/prepare-release.mjs --output dist/release
```

Çıktı dizini önceden varsa komut durur; yeni bir `--output` seçin. `hf-space/` içeriği Space deposunun köküne, `netlify/` içeriği statik siteye gider. Yalnız motor kaynakları için `--engine-only` kullanılabilir. Web varsayılan olarak `https://osiriszk-olceklab-engine.hf.space` adresiyle ve AI kapalı olarak derlenir. Adres `VITE_ENGINE_URL` ortam değişkeniyle değiştirilebilir; karşılık gelen `ALLOWED_ORIGINS` ayrıca kontrol edilmelidir.

## Kalan kabul adımları — sırayla

1. Docker bulunan makinede **yayınlanacak HF imajını** derleyin ve testleri çalıştırın:

   ```bash
   docker build --progress=plain -f deploy/hf-space/Dockerfile -t olceklab-engine:phase7a engine
   docker run --name olceklab-engine-tests -e ONLINE_LIMITS=false olceklab-engine:phase7a Rscript tests/testthat.R
   docker cp olceklab-engine-tests:/app/test-results engine/test-results
   docker rm olceklab-engine-tests
   ```

   Tam test takımı yerel varsayılanlarla koşar; kendi çevrim içi sınır testleri ortamı ayrı kurar. `test-versions.R` dâhil sıfır başarısızlık gerekir. `engine/test-results/testthat.xml` ve konsol çıktısını `docs/test-logs/faz7/` altına kaydedin. İnternet yalnızca ilk imaj/paket indirmeleri için gerekir.

2. Yerel Compose ve mevcut 5 uçtan uca testi çalıştırın:

   ```bash
   docker compose up --build --detach --wait --wait-timeout 900
   cd web
   npx playwright install chromium
   npx playwright test
   ```

3. GitHub'a değişiklikleri gönderip `.github/workflows/ci.yml` iş akışını yeşile çıkarın. Bu iş akışı ayrıca çevrim içi modu ve iki yeni duman testini koşar. Yerel test sonuçları GitHub CI sonucu yerine geçmez.

4. İmaj kabulü geçince HF kaynak paketinin **içeriğini** `OsirisZk/olceklab-engine` Space'ine yükleyin. Docker SDK ve `app_port: 8000`; `README.md`, `Dockerfile`, R dosyaları kökte olmalı. Derleme günlüğünü saklayın. `/health` ve `/versions` gerçek, başarılı JSON yanıtı vermeli. HF/Netlify oturum açma bilgileri platformlarda tutulmalı; anahtarları sohbete veya depoya yazmayın.

5. `netlify/` içeriğini `olceklab` sitesine yayınlayın (site kimliği `45934862-1f76-42f3-b1b4-389e6335098e`). `_headers` ve `_redirects` dosyalarını da yükleyin.

6. `web/` dizininde hedef adreslere bağlı testleri çalıştırın:

   ```bash
   npx playwright test --config playwright.online.config.ts
   ```

   Varsayılan hedefler yukarıdaki canlı adreslerdir. Farklı hedefler için `E2E_BASE_URL` (web) ve `ENGINE_URL` (motor) değişkenlerini birlikte ayarlayın. HF uyku modundaysa önce `/health` ile motorun hazır olmasını bekleyin. JUnit: `web/test-results/online.xml`; hata izleri: `web/test-results/online/`.

7. Canlı akış, sürümler, CORS ve sınırlar geçince kanıtları `docs/VALIDATION.md` içine işleyin. Faz 7a o zaman tamamlanmış sayılır. Faz 6/API sağlayıcısı ve Faz 7b bu çalışmada uygulanmadı.

Docker Space ayarları ve UID 1000 gereksinimi için [Hugging Face belgeleri](https://huggingface.co/docs/hub/spaces-sdks-docker).
