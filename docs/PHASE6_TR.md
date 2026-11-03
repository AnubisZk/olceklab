# Faz 6 — yapay zekâ yorum asistanı

3 Kasım 2026. Kod uygulandı; Docker/R ve tam tarayıcı kabulü CI'da doğrulanmayı bekliyor. Canlı Faz 7a sitesinde AI hâlâ kapalıdır.

## Uygulama

- `none` dış istek yapmaz. `local`, `api` ve `evren` ortak chat/completions istemcisini kullanır. `api` Bearer, `evren` X-API-Key gönderir. EVREN başlığı ve yolu, kullanıcının sağladığı EVREN LLM API panelindeki belgeye dayanır. Şartlar uygulama tarafından otomatik kabul edilmez.
- Kullanıcının model tercihi: `google/gemma-4-31b`. Gerçek base URL, gizli anahtar ve hesap erişim/kota doğrulaması henüz tamamlanmadı. Bunlar kodda varsayılmaz.
- Ağ geçidi yalnızca kayıt kimliği, modül, dil ve biçimli toplu tablolar kabul eder. Modele sadece üretilmiş yer tutucu anahtarları ve açıklama talimatları gider. Ham veri, dosya adı, veri özeti, R betiği ve tablo değerleri isteme girmez.
- R'nin biçimlediği hücreler yer tutuculara aynen konur. Bilinmeyen anahtarlar, rakamlar, yüzde/aralık/Unicode eksi ve TR/EN sayı sözcükleri denetlenir. Sayının başka bir hücreyle tesadüfen eşleşmesini yeterli saymayız: modelin elle yazdığı sayılar da reddedilir. Bu, özgün tolerans önerisinden daha temkinli bir köken denetimidir; gündelik dilde kullanılan sayı sözcükleri de işaretlenebilir.
- Model değerleri görmez; istem, uyum/anlamlılık/güvenirlik hakkında büyüklüğe dayalı karar vermesini yasaklar. Etiket ve kullanıcı incelemesi bu yüzden zorunludur.
- İstek/IP sınırı, gövde/token/yanıt boyutu ve zaman aşımı uygulanır. CORS kaynağı gerçek isteklerde reddedilir. `AI_TRUST_PROXY_HOPS=0` varsayılanı, istemcinin X-Forwarded-For ile sınırı aşmasını engeller. Üretimde proxy zinciri doğrulanmadan değiştirilmemelidir; CORS kimlik doğrulama değildir.
- Yanıt/günlük/hata içeriğine anahtar aktarılmaz. Sağlayıcı hata gövdesi kullanıcıya yansıtılmaz; yönlendirmeler izlenmez.
- Günlükler tarayıcı belleğindedir; JSON/Markdown dışa aktarılır. Yalnızca açık onayla rapora eklenir. R, `check_passed=false`, geçersiz alanlar ve raporda bulunmayan kayıtları HTTP 422 ile reddeder; etiket ve sağlayıcı/model beyanını üretir. `check_passed` uygulama akışının beyanıdır, imzalı bir güvenlik belgesi değildir.

## Doğrulama ve çalıştırma

Yerelde gateway 34/34, web 102/102 test geçti; typecheck ve derlemeler başarılı. R/Docker bu Windows bilgisayarda kurulu olmadığından yeni R testleri burada çalıştırılmadı. Yerel sağlayıcı protokolü yalnızca localhost sahte sunucuyla doğrulandı; gerçek Ollama modeli henüz seçilip çalıştırılmadı.

```sh
docker compose -f docker-compose.yml -f docker-compose.ai-test.yml up --build --detach --wait
cd web
npx playwright test --config playwright.ai.config.ts
```

Bu test düzeni gerçek API veya ücretli model çağırmaz. Sahte sağlayıcı → ağ geçidi → arayüz → R raporu → Word içindeki etiket ve metin → günlük indirme zincirini sınar. R testleri ayrıca reddedilen AI metinlerini ve AI kullanılmayan raporun beyanını denetler.

## Kılavuz

Mevcut 13 bölümlü `USER_GUIDE_TR.md` korunur; başlangıç sayfasından GitHub bağlantısı eklenmiştir. Bölüm 12, yorum/denetim/onay/günlük akışını açıklar ve yayımlanmamış özelliği canlı özellik olarak sunmaz. Bağlantı internet gerektirir; çevrimdışı kopya depodaki `docs/USER_GUIDE_TR.md` ve `docs/img/` dizinidir.

## Kalan işler

1. GitHub'da HF Docker/R ve sahte sağlayıcılı tarayıcı kabulünü geçir; kanıtı VALIDATION'a ekle.
2. EVREN base URL'sini panelden doğrula. Gizli anahtarı yalnızca sunucu sırrı olarak ekle. Kullanıcı kendi hesabındaki kullanım şartlarını kabul etmeli.
3. Gerçek modelle kontrollü doğrulama ve bütçe/kota ayarları ardından AI ağ geçidi yayını (Faz 7b), motor/web güncellemesi ve yeni arayüz ekran görüntüleri.
