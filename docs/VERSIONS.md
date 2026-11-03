# Kullanılan sürümler

Son güncelleme: 3 Kasım 2026 (Faz 5). Faz 3–5'te yeni paket eklenmedi; `pbivnorm` ve `zip` (Faz 4'ten beri kullanılıyor) artık analiz kayıtlarındaki sürüm listesine de yazılıyor.

## 1. Testlerin gerçekten koştuğu ortam

Bu bölümdeki sürümler kurulu ortamdan okunmuştur (`npm ls`, `renv.lock`, `R.version`).

| Bileşen | Sürüm |
|---|---|
| İşletim sistemi | Ubuntu 24.04.5 LTS (Linux 6.18), 2 çekirdek |
| R | 4.4.3 (conda-forge derlemesi) |
| BLAS / LAPACK | OpenBLAS 0.3.34 |
| Node.js / npm | 24.22.1 / 11.19.1 |

### R paketleri (`engine/renv.lock`, toplam 102 paket, hepsi CRAN kaynaklı)

| Paket | Sürüm |
|---|---|
| lavaan | 0.7-2 |
| semTools | 0.5-10 (§11.3 değerleri 0.5-9 ile üretildi; ilgili fonksiyonlar iki sürümde birebir aynı, V10) |
| psych | 2.6.9 |
| GPArotation | 2026.8-2 |
| MASS | 7.3-66 |
| mvtnorm | 1.4-2 |
| pbivnorm | 0.6.0 |
| plumber | 1.3.3 |
| httpuv | 1.6.17 |
| mirai | 2.7.2 |
| nanonext | 1.10.4 |
| officer | 0.7.7 |
| flextable | 0.10.3 |
| jsonlite | 2.0.0 |
| readxl | 1.6.0 |
| digest | 0.6.39 |
| testthat | 3.3.2 |
| callr | 3.7.6 |
| httr2 | 1.3.0 |
| renv | 1.3.1 |

lavaan, psych, semTools ve GPArotation, CRAN'ın GitHub aynasındaki sürüm etiketlerinden kuruldu (`github.com/cran/<paket>`). Diğer paketler conda-forge üzerinden kuruldu. `renv.lock` bu kütüphaneden `engine/scripts/lock.R` ile üretildi.

### Ön yüz (`web/package-lock.json`)

| Paket | Sürüm |
|---|---|
| react / react-dom | 19.3.1 |
| react-router | 8.5.1 |
| @tanstack/react-query | 5.105.2 |
| i18next / react-i18next | 26.7.1 / 17.1.11 |
| @fontsource/jetbrains-mono | 5.3.0 |
| vite / @vitejs/plugin-react | 8.3.5 / 6.2.1 |
| typescript | 7.0.2 |
| vitest / jsdom | 5.1.0 / 30.1.3 |
| @testing-library/react / jest-dom / user-event | 16.3.3 / 7.0.1 / 14.6.8 |
| @types/react / @types/react-dom | 19.3.0 / 19.3.0 |
| echarts | 6.1.0 (Faz 1) |
| @tanstack/react-table | 8.21.3 (Faz 1; 9.x yayımlanmış, ancak kararlı v8 API'si seçildi) |
| @playwright/test | 1.64.1. Faz 5'te uçtan uca testler bu ortamda önceden kurulu Chromium (build 1243) ile koştu; depodaki yapılandırma Playwright'ın kendi tarayıcısını (`npx playwright install chromium`) bekler |
| @types/node | 24.19.2 (Faz 1, yalnızca testler için) |

### Yapay zekâ ağ geçidi (`ai-gateway/package-lock.json`)

| Paket | Sürüm |
|---|---|
| fastify | 5.12.8 |
| typescript | 7.0.2 |
| vitest | 5.1.0 |
| @types/node | 24.19.2 |

## 2. Docker hedefleri (bu oturumda derlenemedi)

Bu ortamda Docker daemon'ı yoktu ve Docker Hub ile Posit Package Manager erişime kapalıydı. Bu yüzden aşağıdaki imajlar **derlenip denenmedi**. İlk başarılı derlemeden sonra imaj özetleri (digest) buraya yazılacak.

| Servis | Temel imaj | Sabitlik |
|---|---|---|
| engine | `rocker/r-ver:4.4.3` | R sürümü sabit |
| engine paketleri | PPM anlık görüntüsü `2026-10-31` + `renv.lock` | paket sürümleri sabit |
| web (derleme) | `node:24-alpine` | yalnızca ana sürüm sabit → digest sabitlenecek |
| web (sunum) | `nginx:stable-alpine` | kayan etiket → digest sabitlenecek |
| ai-gateway | `node:24-alpine` | yalnızca ana sürüm sabit → digest sabitlenecek |
| ollama (isteğe bağlı) | `ollama/ollama:latest` | Faz 6'da model seçimiyle sabitlenecek |

**Bilinen fark:** Bu ortamda R, OpenBLAS kullanıyor. `rocker/r-ver` imajının BLAS'ı farklı olabilir. §11.3 değerleri raporlanan basamakta karşılaştırılacağı için bunun sonucu değiştirmesi beklenmez, ama `/versions` uç noktası BLAS bilgisini her zaman döndürür ve analiz kaydına yazılacaktır (SPEC_REVIEW REP-2).

### Doğrulama araçları (yalnızca testlerde)

| Araç | Kullanım |
|---|---|
| LibreOffice (soffice, headless) | `test-report.R`: Word raporunun açılıp PDF'e dönüştürülebildiği denetlenir; yoksa test atlanır |
| Firefox + geckodriver, Selenium, python-docx | `docs/test-logs/faz*/browser_flow.py`: gerçek tarayıcı akışları; indirilen .docx python-docx ile okunur |
