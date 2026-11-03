# ÖlçekLab Kurulum ve Yayına Alma

Bu belge ÖlçekLab'i iki parça olarak yayına almayı anlatır:

| Parça | Nerede çalışır | Adres |
|---|---|---|
| Web arayüzü (statik dosyalar) | Netlify, proje adı `olceklab` | https://olceklab.netlify.app |
| R analiz motoru (Docker) | Hugging Face Space, `OsirisZk/olceklab-engine` | https://osiriszk-olceklab-engine.hf.space |

Arayüz, motor adresiyle birlikte derlenmiştir (`VITE_ENGINE_URL=https://osiriszk-olceklab-engine.hf.space`, `VITE_DEPLOY_MODE=online`). Motor yalnızca `https://olceklab.netlify.app` adresinden gelen isteklere izin verir (`ALLOWED_ORIGINS`). Bu iki adresten biri değişirse Bölüm 5'teki adımları uygulayın.

---

## 1. R motorunu Hugging Face Space olarak kurma

1. https://huggingface.co/new-space adresini açın.
2. Formu şöyle doldurun:
   - **Owner:** `OsirisZk`
   - **Space name:** `olceklab-engine`
   - **SDK:** Docker → **Blank**
   - **Hardware:** CPU basic (ücretsiz; 2 vCPU, 16 GB RAM)
   - **Visibility:** Public. Arayüz motora tarayıcıdan doğrudan bağlanır; özel (private) Space buna izin vermez.
3. **Create Space** düğmesine basın.
4. Açılan sayfada **Files → Add file → Upload files** yolunu izleyin. `olceklab-hf-space.zip` dosyasını açtığınızda çıkan **içeriği** sürükleyip bırakın: `Dockerfile`, `README.md`, `plumber.R`, `run.R`, `healthcheck.R`, `renv.lock`, `.dockerignore`, `R/` ve `tests/`.
   - Bu dosyalar klasörün içinde değil, deponun kök dizininde olmalıdır.
   - `README.md` dosyasının başındaki `sdk: docker` ve `app_port: 8000` satırları Space'in ayarlarıdır; bunları silmeyin.
   - `.dockerignore` gizli bir dosya olduğu için görünmeyebilir. Yüklenmezse sorun çıkmaz.
5. **Commit changes to main** ile yüklemeyi onaylayın. Derleme kendiliğinden başlar.
6. **Logs → Build** sekmesinden derlemeyi izleyin.
   - İlk derleme uzun sürer: R paketleri `renv.lock` dosyasındaki sürümlerle kurulur. Süre Hugging Face sunucusunun yüküne göre değişir.
   - Durum **Running** olunca derleme bitmiştir.
7. Tarayıcıda https://osiriszk-olceklab-engine.hf.space/health adresini açın. Motor çalışıyorsa JSON biçiminde bir durum yanıtı döner. https://osiriszk-olceklab-engine.hf.space/versions adresi R ve paket sürümlerini gösterir.

**Motorun ayarları:** Ortam değişkenleri `Dockerfile` içine yazılmıştır, Space ayarlarından ayrıca girmeniz gerekmez:

```
ALLOWED_ORIGINS=https://olceklab.netlify.app
ONLINE_LIMITS=true
ONLINE_MAX_REPLICATIONS_X_CONDITIONS=2000
ONLINE_MAX_WORKERS=2
ONLINE_JOB_TIMEOUT_SECONDS=3600
ENGINE_WORKERS=2
JOBS_DIR=/tmp/olceklab-jobs
```

İsterseniz bunları **Settings → Variables and secrets** bölümünden değiştirebilirsiniz. Orada tanımlanan değer `Dockerfile` içindekinin yerine geçer.

**Derleme hata verirse:** Build günlüğünün son 50–100 satırını kopyalayın. Hatanın büyük olasılıkla hangi paketten kaynaklandığı bu satırlarda görünür.

> Ücretsiz Space'ler bir süre kullanılmadığında uyku moduna geçer. İlk istek motoru uyandırır; bu birkaç dakika sürebilir. Arayüzdeki **Yeniden dene** düğmesi bu durum içindir.

---

## 2. Arayüzü Netlify'a yükleme

1. https://app.netlify.com/projects/olceklab/deploys adresini açın.
2. `olceklab-netlify.zip` dosyasını açın. Çıkan klasörde `index.html`, `assets/`, `_redirects`, `_headers` ve `netlify.toml` bulunur.
3. Bu klasörü sayfanın altındaki **"Drag and drop your project output folder here"** alanına sürükleyip bırakın.
4. Yükleme birkaç saniyede biter ve yayın https://olceklab.netlify.app adresine geçer.

`_redirects` dosyası, sayfa yenilendiğinde ya da doğrudan bir alt adres (ör. `/dfa`) açıldığında 404 hatası alınmamasını sağlar. `_headers` dosyası güvenlik başlıklarını ekler.

---

## 3. Yayından sonra denetim

Aşağıdaki adımları sırayla yapın. Hepsi tamamlanırsa kurulum tamamdır.

1. https://olceklab.netlify.app adresini açın. Başlangıç sayfasındaki **R analiz motoru** kutusu "Çalışıyor" göstermeli ve R/paket sürümlerini listelemelidir.
2. **Örnek veriyle dene → HolzingerSwineford1939** yolunu izleyin. Ardından **Rolleri kaydet → Temizlemeyi çalıştır** adımlarını yapın.
3. **Paralel analiz** sayfasında **Faktör sayısını belirle** düğmesine basın.
4. **DFA** sayfasında bir model kurup çalıştırın.
5. **Simülasyon** sayfasında küçük bir iş başlatın (ör. N = 300, 20 tekrar) ve tamamlanmasını bekleyin.
6. **Rapor** sayfasında **Word raporu oluştur** düğmesine basın ve inen `.docx` dosyasını açın.

Motor kutusu "Bağlantı kurulamadı" diyorsa:
- Önce `/health` adresini doğrudan açın.
  - O adres de açılmıyorsa sorun Space'tedir (uyku modu ya da derleme hatası).
  - `/health` açılıyor ama arayüz bağlanamıyorsa tarayıcının geliştirici konsolunda (F12 → Console) "CORS" uyarısı arayın ve Bölüm 5'e bakın.

---

## 4. Yerel (çevrimdışı) kurulum

Kişisel veri içeren gerçek çalışmalarda önerilen kullanım budur. Veri bilgisayardan çıkmaz ve simülasyon sınırları uygulanmaz.

**Gereken:** Docker Desktop.

```bash
unzip olceklab-faz7.zip && cd olceklab
docker compose up --build engine web
```

- Tarayıcıda http://localhost:5173 adresini açın. Motor http://localhost:8000 adresinde çalışır.
- İlk derleme R paketlerini kurduğu için uzun sürer. Sonraki açılışlarda yalnızca `docker compose up engine web` yeterlidir.
- `ai-gateway` ve `ollama` servisleri yapay zekâ modülü içindir. Bu modül henüz tamamlanmadığı için (Faz 6) yukarıdaki komut onları başlatmaz.

---

## 5. Adres değişirse (CORS)

**Arayüzün adresi değişirse** (ör. kendi alan adınızı bağlarsanız): Hugging Face Space'te **Settings → Variables and secrets → New variable** ile şu değişkeni ekleyin:

```
ALLOWED_ORIGINS=https://olceklab.netlify.app,https://yeni-adres.org
```

Space yeniden başlar.

**Motorun adresi değişirse:** Arayüzü yeni adresle yeniden derleyin (Node 24 gerekir):

```bash
cd web
npm ci
VITE_ENGINE_URL=https://yeni-motor-adresi VITE_DEPLOY_MODE=online npm run build
cp ../deploy/netlify/_redirects ../deploy/netlify/_headers dist/   # ya da olceklab-netlify.zip içindekileri kopyalayın
```

Ardından `dist/` klasörünü Bölüm 2'deki gibi Netlify'a sürükleyin.

---

## 6. Gerçek veriyle doğrulama (yalnızca kendi bilgisayarınızda)

Makaledeki BİDEKÇET değerlerinin platformla birebir üretildiğini sınamak için:

```bash
cd engine
BIDEKCET_DATA_DIR=/ham/veri/klasoru LANG=C.UTF-8 Rscript tests/private/run_bidekcet.R
```

- Sonuç `tests/private/bidekcet_sonuc.csv` dosyasına yazılır. Bu dosya `.gitignore` ile depodan dışarıda tutulur ve yalnızca toplu sonuçları içerir.
- Ham Excel dosyaları KVKK gereği hiçbir pakete, depoya ya da Space'e eklenmemelidir.

---

## 7. Yayın paketinde neler test edildi?

| Test | Ortam | Sonuç |
|---|---|---|
| R motoru birim testleri (testthat) | R 4.5.3, yerel | 1134 başarılı, 3 atlandı, 1 başarısız: `test-versions.R` kurulu sürümleri `renv.lock` ile karşılaştırır. Yerel ortamda R 4.5.3 / semTools 0.5.9, kilit dosyasında R 4.4.3 / semTools 0.5-10 olduğu için bu test başarısız olur. Docker imajı kilitli sürümleri kurduğu için orada bu fark oluşmaz. |
| Web birim testleri (vitest) | Node 24 | 96/96 başarılı |
| Uçtan uca testler (Playwright, Faz 1–5 akışları) | Yerel motor + yerel arayüz | 5/5 başarılı |
| BİDEKÇET gerçek veri testi | Yerel, ham veri | 58/58 değer makaledekiyle aynı |
| Docker imajı derlemesi | — | **Henüz denenmedi.** İlk gerçek derleme Hugging Face'te ya da yerel Docker'da yapılacak. |
