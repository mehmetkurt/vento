# VentoPOS Sürüm Notları — 3.1.2 sonrası (güncel)

**Şu anki sürüm:** VentoPOS **3.2.1 (build 73)**  
**Nereden beri:** 3.1.2 (build 52)  
**Tarih:** 24 Kasım 2026  
**Kimler için:** Sahada telefonla çalışan ekipler, ofis / kasa / rapor bakışı  
**Kod ucu:** umbrella `main` · ventoPOS `master` `3d0f563` (şema **v37**) · sürüm: lokal `pubspec.yaml` + `AppInfoConstants` (`3.2.1+73`) · APK `VentoPOS-v3.2.1-build73-release.apk`

---

## Kısa özet

Uygulama hem daha ferah görünüyor hem günlük işi hızlandıracak şekilde düzenlendi. Ekranlar Soft UI ile yumuşadı; birden fazla marka (firma adı) tek telefonda yönetilebiliyor; rota, teslimat WhatsApp’ı, fason borç ve adres bakımı daha net. İleri tarihli alım / teslim / randevu hatırlatmalarında **kaç gün önce** ve **kaç kez** ayarı eklendi. Eski telefonlara üzerine yazarak güncelleme yolu aynı; mevcut lisanslar bozulmaz.

---

## Görünüm

- Üst bar marka mavisi; yazılar ve ikonlar beyaz.
- Yazılar daha okunaklı; kartlar yumuşak köşeli ve sade gölgeli.
- Ana sayfa, sipariş / servis listeleri, formlar, rota ve ayarlar aynı yumuşak görünüme çekildi.
- Üst barda yazıcı, senkron ve ayarlar artık kısa ikonlar; bekleyen hatırlatma varsa zil üzerinde sayı görünür.

---

## Marka (birden fazla firma adı)

- Katalog’dan **Marka Yönetimi** ile marka ekleyip düzenleyebilirsiniz.
- Birden fazla aktif marka varsa üst barda marka değiştirici çıkar.
- Yeni sipariş / servis talebinde marka seçebilirsiniz.
- Liste ve raporlarda markaya göre süzebilirsiniz.
- WhatsApp ve etiket yazdırırken doğru marka adı kullanılır.
- İlk açılışta varsayılan marka sihirbazı çıkar (boş kurulumda yönlendirir).

---

## Sipariş, teslimat ve WhatsApp

- Sipariş detayında atölye adımları varsayılan olarak kapalıdır; **«Daha fazla»** ile açılır — ekran daha sade kalır.
- Sipariş **Teslim Edildi** olunca WhatsApp paneli **mutlaka** açılır (kapatılamaz). Göndermeseniz bile sonra hatırlatma kuyruğuna düşebilir.
- Borçlu / açık hesap teslimatlarda ayrı «borçlu teslim» mesaj şablonu kullanılır.
- Sipariş listesinde açılmış kartta fiş mesajı (WhatsApp) ikonu vardır.
- İade fiş öneki ayarda **en fazla 1 harf** (ör. `İ`). Ekranda `İ#2026` gibi görünür; telefonda ve sorgu linkinde `#` yoktur (`İ2026`).

---

## Rota ve dağıtım

- Araç yükü bitmeden rota **başlamaz**.
- Aynı anda **yalnızca bir aktif rota** olabilir.
- Aktif rota ve durak kartları daraltılıp açılabilir; duraklarda ara / doğrudan WhatsApp kısayolları vardır.
- Durak sırasını sürükleyerek veya yukarı-aşağı ile değiştirebilirsiniz; elle verdiğiniz sıra korunur.

---

## Fason / iade yıkama

- İade siparişleri fasona **yıkamaya gidebilir**; varsayılan olarak fason **borcuna yazılmaz** (0 TL).
- İsterseniz «İadeleri fason borcuna dahil et» ile borca ekleyebilirsiniz.
- Fabrika kartlarında borç / m² özetinde **«İadeler hariç»** yazısı görünür; iade adedi ayrı bilgi şeridinde durur.

---

## Adres bakımı

- Ayarlardaki adres bakımı, çalıştığınız ile göre ilçe / mahalle listeler.
- Mahalle eşleşmeleri güncel katalogdan daha düzgün dolar.
- Yanlış ilçe / mahalledeki müşterileri başka yere **toplu aktarabilirsiniz**.

---

## Raporlar

- Eski tek «Fabrika & Kasa» sekmesi ayrıldı: **Fabrika** ve **Kasa** ayrı bakılır.
- Menüden de Fason Fabrika Raporu ile Kasa & Alacak ayrı açılır.
- Raporlarda marka süzgeci kullanılabilir.

---

## Sipariş sorgu (müşteri sitesi)

- WhatsApp’taki sorgu linki Türkçe / önekli fişlerde kırılmaz.
- **sorgu.altigenhaliyikama.com** ana sayfasından fiş + telefon ile bakılabilir.
- Ek hizmetler ve küsürat / feragat tutarları müşteri ekranında doğru görünür.

---

## Hatırlatmalar

- Vadesi gelen her hatırlatma için ayrı bildirim gider; uygulama yeniden açılınca aynı hatırlatmanın peş peşe yağması azaltıldı.
- Üst bardaki zilden Hatırlatmalar ekranına hızlı geçiş.
- **İleri tarihli** alım, teslim ve yerinde randevu hatırlatmalarında:
  - **Önceden** — olaydan kaç gün / saat önce bildirim başlasın (varsayılan: 1 gün önce).
  - **Sonlu / Sürekli** — Sonlu seçilirse **kaç kez** bildirilsin (varsayılan: 3 kez); Sürekli seçilirse iş bitene kadar aralıklarla devam eder.
- Bu ayarlar Hatırlatmalar → ilgili modül satırından düzenlenir (şema v37; üzerine yazarak güncellemede otomatik gelir).

---

## Yedekleme ve güncelleme

- Yedek; yerinde randevu, hatırlatma, sorgu adresi ve mahalle gibi alanları da daha eksiksiz alır.
- Saha telefonuna **üzerine yazarak** kurulum yapılır; uygulama kimliği ve imza aynı kalır, lisans yeniden istenmez.
- Lisans anahtar uygulaması (Keygen) ayrıdır; müşteri POS klasörüne karıştırılmamalıdır.

---

## Sahada dikkat edilecekler

1. Kurulum sonrası uygulama bilgisinde **3.2.1 (73)** görünmeli.
2. Gerçek saha kurulumunda «Demo Veri Yükle» **kapalıdır** — müşteri cihazında demo menüsü olmamalı.
3. İade önekini tek harf tutun; ayara `#` yazmayın.
4. Firma ayarında sorgu taban adresi dolu olsun (ör. `https://sorgu.altigenhaliyikama.com`).
5. İkinci rota açılmıyorsa önce aktif rotayı bitirin veya iptal edin.
6. Rota başlamıyorsa araç yük listesini tamamlayın.
7. Teslim sonrası WhatsApp paneli bilerek zorunludur; «Şimdi Değil / Kapat» ile kapatıp işe devam edebilirsiniz.
8. Müşteriye verdiğiniz sorgu linkinde `#` olmamalı (`…/status/İ2026` doğru).
9. İleri tarih hatırlatmada «Sonlu» + «kaç kez» doldurulmazsa varsayılan **3 kez** kullanılır.

---

## Keygen

Saha için Keygen sürümü: **1.1.6 (build 8)** (imza anahtarı yalnızca telefonun güvenli deposunda).

---

## Dokümantasyon (ofis / geliştirme)

- Teknik borç tam analizi umbrella `docs/tech-debt-full-analysis.md` altında aynalanır.
- Bu uca kadar test paketi yeşil doğrulanmıştır (ventoPOS `3d0f563` / şema v37).
