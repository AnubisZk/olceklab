---
title: ÖlçekLab R Analiz Motoru
emoji: 📐
colorFrom: gray
colorTo: blue
sdk: docker
app_port: 8000
pinned: false
short_description: Ölçek geliştirme analizleri için R motoru (lavaan, psych)
---

# ÖlçekLab — R analiz motoru

Bu Space, ÖlçekLab web arayüzünün (https://olceklab.netlify.app) kullandığı R analiz motorudur.
Bütün istatistiksel hesaplar burada lavaan, psych ve semTools paketleriyle yapılır.

- Sağlık denetimi: `/health` · sürüm bilgisi: `/versions`
- Çevrim içi mod sınırları açıktır (`ONLINE_LIMITS=true`): simülasyonda tekrar × koşul ≤ 2000, en fazla 2 işçi, iş başına en fazla 1 saat.
- Yüklenen veriler diske kalıcı yazılmaz; oturum 60 dakika işlem olmazsa silinir.
- Öğrenci verisi gibi kişisel veriler için yerel (çevrimdışı) kurulum önerilir.
