# VentoPOS Sürüm Notları — 3.2.1+73 sonrası → 3.2.2 (build 76)

**Şu anki sürüm:** VentoPOS **3.2.2 (build 76)**  
**Kapsam:** Yalnızca **3.2.1+73 saha build’inden sonra** gelen ürün değişiklikleri (eski 3.1.x kümülatif notlar yok).  
**Tarih:** 25 Kasım 2026 (Europe/Istanbul)  
**Kimler için:** Saha operatörleri, ofis, arayan kimliği ve fason hesabı kullanan ekipler  
**Kod ucu:** umbrella `main` `32cccd1` · ventoPOS `master` `cc54b65`

---

## Kısa özet

**3.2.2** ile saha build’i güncellenir. Tam teslimde WhatsApp teşekkür / açık hesap mesajı otomatik açılır. Müşteri adresinde eksik GPS, sipariş çevir / kaydet / etiket sırasında arka planda tamamlanır. İlçe–mahalle kataloğu doğru çekilir; mahalle listesi için ilçe seçimi zorunlu. Arayan kimliğinde sahte borç ve absürt bekleme günü düzelir. Fason listesi Soft UI’ye çekilir; aktarımlar güne göre gruplanır, iadeler kırmızı çerçeveyle seçilir.

---

## Teslimde otomatik WhatsApp

- Sipariş **tamamen** teslim edilince (kısmi teslim değil) WhatsApp otomatik açılır.
- Ödeme alındıysa teşekkür şablonu; borç / açık hesapsa açık hesap şablonu seçilir.
- Geçersiz veya silinmiş telefonda mesaj açılmaz; hatırlatma kuyruğuna düşer.
- Karttaki manuel **«Fiş Mesajı»** aynı yerde durur.

---

## Müşteri GPS (arka plan)

- Adreste enlem/boylam yoksa: **Siparişe Çevir**, **Kaydet** veya **Etiket Bas** sırasında arka planda GPS yazılır.
- Mevcut pin ezilmez; GPS kapalıysa işlem yine devam eder (kısa uyarı).

---

## Adres / mahalle kataloğu

- Resmi ilçe ve mahalle listesi Türkiye API’den eksiksiz çekilir (ör. Güngören mahalleleri görünür).
- Mahalle listesi için **ilçe filtresi zorunlu**; rastgele / eksik mahalle karışıklığı azalır.

---

## Arayan kimliği

- **Borç** rozeti yalnızca **teslim edilmiş** ve ödenmemiş siparişlerde görünür; yıkamadaki tutar borç sayılmaz.
- Bekleme günü doğru hesaplanır (eski ~20.000 gün hatası yok).

---

## Fason fabrika listesi (Soft UI)

- Liste başlığı: **«Fason Fabrikalar & Hesaplar»**.
- Üst bardaki **«Yeni Fabrika»** kaldırıldı; ekleme yalnızca alttaki **+** FAB ile.
- **«Toplu Gönder»** üst barda kaldı.

---

## Fason detay — Halılar (aktarım günü)

- **Halılar** sekmesinde aktarımlar **aktarım gününe** göre gruplanır.
- Gün satırına dokununca grup açılır / kapanır; özet: sipariş · adet · m².

---

## İade kartları

- İade aktarımlarında **kırmızı çerçeve** ve **«İade»** / **«İade · 0 TL»** etiketi; normal fasonla karışmaz.

---

## Güncelleme notu

- Üzerine yazarak (in-place) güncelleme; lisans ve mevcut veriler bozulmaz.
- Saha APK adı: `VentoPOS-v3.2.2-build76-release.apk` (build çıktısına göre).
- Bu notlar **3.2.1+73 sonrası** gelişmeleri kapsar; Soft UI marka / rota / eski kümülatif maddeler buraya taşınmadı.
