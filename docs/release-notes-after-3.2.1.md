# VentoPOS Sürüm Notları — 3.2.1+73 sonrası

**Şu anki sürüm:** VentoPOS **3.2.2 (build 75)** — lokal `pubspec.yaml` / `AppInfoConstants`  
**Nereden beri:** **3.2.1 (build 73)** saha release’inden sonra (eski 3.1.2→3.2.1 kümülatif notlar kaldırıldı)  
**Tarih:** 24 Kasım 2026  
**Kimler için:** Fason / fabrika hesabı bakan saha ve ofis ekipleri  
**Kod ucu:** umbrella `main` `c372504` · ventoPOS `master` `21c1998`

---

## Kısa özet

**3.2.1+73** saha build’inden sonra yalnızca fason ekranları sadeleştirildi. Fabrika listesi Soft UI ile daha net; «Yeni Fabrika» üst bardan kalktı, ekleme yalnızca yuvarlak **+** FAB ile. Fabrika detayında **Halılar** aktarımları güne göre gruplanıp açılıp kapanıyor. İade aktarımları kırmızı çerçeve ve **İade** etiketiyle hemen seçiliyor.

---

## Fason fabrika listesi (Soft UI)

- Liste başlığı Soft UI ile uyumlu: **«Fason Fabrikalar & Hesaplar»**.
- Üst bardaki **«Yeni Fabrika»** yazısı / düğmesi kaldırıldı; ekran daha sakin.
- Yeni fabrika eklemek için yalnızca alttaki **ikon-only FAB** (**+**) kullanılır (tooltip: Yeni Fabrika).
- «Toplu Gönder» üst barda kaldı; toplu fason gönderimi aynı yerden.

---

## Fason detay — Halılar (aktarım günü)

- Detaydaki **Halılar** sekmesinde aktarımlar **aktarım gününe** göre gruplanır.
- Gün satırına dokununca grup **açılır / kapanır** (expand / collapse).
- Gün satırında özet: sipariş adedi · adet · m² görünür; açınca o güne ait kartlar listelenir.

---

## İade kartları

- İade / iade aktarımı kartlarında **kırmızı border** vardır.
- Kartta **«İade»** (yalnız yıkama ise **«İade · 0 TL»**) etiketi görünür; normal fason halılarla karışmaz.

---

## Güncelleme notu

- Bu notlar **yalnızca 3.2.1+73 sonrasını** kapsar; Soft UI marka / rota / arayan kimliği vb. eski kümülatif maddeler buraya taşınmadı.
- Üzerine yazarak güncelleme yolu aynı; lisans ve veri bozulmaz.
