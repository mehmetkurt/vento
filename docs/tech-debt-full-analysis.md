---
cursor:
  subagentId: "bc-eb645155-d77e-5750-b4d0-9c5df0777eda"
---

# Vento ekosistemi — teknik borç tam analizi (SSOT)

**Görev:** VEN-209  
**Tarih:** 2026-11-24 (Europe/Istanbul)  
**Tür:** Salt analiz — kod / test / PR / git **yok**  
**Birincil çıktı (bu dosya):** Agent Store `docs/tech-debt-full-analysis.md`  
**Kaynak birleştirme:** `technical-debt-analysis.md`, `tech-debt-comparison.md`, `tech-debt-prompt-list.md`, `internal/ven-78-tech-debt-progress.md`, `multi-brand-module-analysis.md` (§7.3), `internal/reminder-advance-notify-plan.md`, repo `APPLICATION_ANALYSIS.md`, Wave 1–3 landing notları (`internal/ven-119`…`ven-135`), güncel tip kod taraması; ek tarama `internal/tech-debt-scan-keygen-query-umbrella.md` ([Keygen query umbrella scan](bc-12013733-4ce2-54c7-a73d-d1ddb6493550))  

### Baseline (temiz tip; kirli WIP dokunulmadı)

| Repo | Branch / tip | SHA (kısa) | Sürüm / şema |
| --- | --- | --- | --- |
| umbrella `vento` | `main` | `8e82ef6` | 4 submodule pin |
| `ventoPOS` | `master` HEAD | `e3e1e98` | **3.1.8+64**, şema **v36** |
| `ventoPOS_Keygen` | `master` HEAD | `29298f6` | **1.1.5+7** |
| `vento_query_api` | `main` | `66b0e1e` | Vitest+ESLint+DTO |
| `vento_query_spa` | `main` | `b02ed5b` | Home+nginx+DTO |

**Worktree notu:** `ventoPOS` ve `ventoPOS_Keygen` checkout’larında kirli WIP var — **dokunulmadı**. WIP sürümleri HEAD’ten sapmış: POS working tree `3.1.9+70` (pubspec↔`AppInfoConstants` değerleri kendi içinde uyumlu; yorum hâlâ “Field SSOT: 3.1.8+64”), Keygen working tree `1.1.6+8`. Field/preferences SSOT pin’i hâlâ **3.1.8+64 / 1.1.5+7** (landed tip). Analiz hükümleri **HEAD tip** + WIP drift uyarısı üzerinedir.

**DTO sync:** `node tool/check_query_status_dto_sync.mjs` → **OK** (3525 bayt, aynı sha256).

---

## 1. Yönetici özeti

Wave 1–3 (16 tur) **landed**. Eski P0’lar (Keygen dist aynası, API finans/CORS, fiş URL encode, SLA Dart↔Kotlin, backup tablo boşlukları, paging SQL SSOT’un büyük kısmı) kapanmış. Asıl açık borç artık **ürün ertelenmeleri + bakım maliyeti + Soft UI token kalıntısı + doküman bayatlığı + CI zayıflığı**.

| Severity | Açık / kısmi | Landed (Wave+sonraki) | Bilinçli deferred / OUT |
| ---: | ---: | ---: | ---: |
| **P0** | **1** | 8+ | 0 (P0 deferred yok) |
| **P1** | **9** | 12+ | 2 (ürün onayı bekler) |
| **P2** | **17** | 10+ | 6+ (§7.3 vb.) |
| **P3** | **9** | — | 4+ (iOS, Riverpod göç temposu) |
| **Toplam açık takip** | **~36** | **Wave 1–3 = 16/16** | **~12 accepted** |

**Tek cümlelik hüküm:** Mimari kriz yok (presentation→DAO hard ihlal **0**). Saha güvenliği için kalan tek net P0 adayı **sürüm SSOT / release gate disiplini** (kirli WIP `3.1.9+70` / Keygen `1.1.6+8` vs landed tip + bayat yorum/doküman). Geri kalan P1’ler bakım, Soft UI token, paging kalıntısı, PowerSync ops, query marka yüzü ve hatırlatma ürün modeli.

### Envanter yöntemleri (yapıldı)

1. Önceki Wave/raporlar landed vs open işaretlendi.  
2. Kod taraması: TODO/FIXME (gerçek yorum seyrek), Soft UI hardcode, StateNotifier, catch, god-file, skip test, CA import.  
3. Mimari: CA guard, Riverpod monolit, migration zinciri v36.  
4. Veri: backup/sync matrisi (W2-01), receipt sequences, PowerSync iskeleti.  
5. Güvenlik/lisans: Keygen SecureStorage + file history; public key sibling gate bat’ta.  
6. UX/ürün: multi-brand §7.3, reminder N-before-N plan.  
7. Test/CI: POS ~250 `*_test.dart`; ui-audit workflow `continue-on-error`; umbrella CI yok.  
8. Performans: adres bakımı sublist, debtors istemci paging, tracking monolit.  
9. Release/ops: field SSOT 3.1.8+64 / Keygen 1.1.5+7; Keygen→POS dist mirror **yok**.

---

## 2. Landed vs open vs deferred

### 2.1 Wave 1–3 (TD-W*) — tamamı landed

| ID | Konu | Durum | Kanıt |
| --- | --- | --- | --- |
| TD-W1-01 | Keygen APK → `ventoPOS/dist` mirror kaldırma | **Landed** | `build/vento-unified-safe-release.bat` “never mirror Keygen APK”; `ven-119` |
| TD-W1-02 | API extras + `waivedAmount` + CORS/trustProxy | **Landed** | `order-financial.ts`, compose CORS default SPA origin; `ven-120` |
| TD-W1-03 | Fiş URL `Uri.encodeComponent` / SPA decode | **Landed** | `order_status_query_url.dart`, `decodeReceiptNo.ts`; `ven-121` |
| TD-W1-04 | Licensing docs + query submodule governance | **Landed** | kök `AGENTS.md` 4 modül; `ven-122` |
| TD-W2-01 | Backup/sync tablo kapsaması | **Landed** | on-site/reminders/company_info_urls/neighborhoods; `ven-123` |
| TD-W2-02 | PG index + API lazy reconnect | **Landed** | `ven-124` |
| TD-W2-03 | SPA Home + TZ + nginx headers | **Landed** | `HomePage`, `ven-125` |
| TD-W2-04 | Orders client filters → SQL SSOT | **Landed** | `onlyOverdueSla` / `onlyDeliveredWithOpenDebt` SQL; orders auto-continue **1**; `ven-126` |
| TD-W3-01 | UI audit kapısı + dilimleme + ölü DAO export | **Landed** | `.github/workflows/ui-audit.yml`; `ven-128` |
| TD-W3-02 | `distribution_dao` dilimleme | **Landed** | facade ~65 + parts; `ven-129` |
| TD-W3-03 | Form controller dilimleme | **Landed** | `carpet_order_form/*` parçaları; `ven-130` |
| TD-W3-04 | `GmailContactSyncHandler` dilimleme | **Landed** | handler ~335 satır; `ven-131` |
| TD-W3-05 | API/SPA Vitest+ESLint + DTO kopya sync | **Landed** | DTO check OK; `ven-132` |
| TD-W3-06 | Keygen lint + file JSON history backup | **Landed** | strict analysis + `keygen_history_backup_file_service.dart`; `ven-133` |
| TD-W3-07 | `sqlite3_flutter_libs` +eol kaldır + skip test + ESC/POS dil | **Landed** | pubspec yorum; skip yok; `ven-134` |
| TD-W3-08 | AppLogger + Zone FakeAsync + bat `lib/` runtimeType tarama | **Landed** | `ven-135` |

### 2.2 VEN-78 / Caller ID / paging (eski A raporu P0/P1)

| Madde | Durum |
| --- | --- |
| Dart↔Kotlin SLA sözleşmesi + golden | **Landed** (`DeliverySlaContract`, `CallerIdSlaContract.kt`, cross-lang test) |
| CallerId SQL ↔ Drift kolon sözleşmesi | **Landed** (`CallerIdSqlSchemaContract.kt`) |
| `kCustomerPageSize` = global 20 | **Landed** |
| Overlay `MAX_STACKED_OVERLAYS=3` | **Landed** |
| `subcontractorsDaoProvider` safe-export temizliği | **Landed** (W3-01) |
| Servis listesi auto-`loadMore` telafisi | **Kısmi açık** — servis tarafında `kMaxClientEmptyAutoContinues=3` hâlâ var → **TD-N-P1-01** |
| UX local branch entegrasyon | **Kapanmış/geçersiz** — Soft UI `design`→master merge sonrası ayrı UX worktree borcu güncel tipte yok |

### 2.3 Multi-brand / Soft UI / fabrika / hatırlatma

| Madde | Durum |
| --- | --- |
| Multi-brand v1 + v1.1 + VEN-196 polish | **Landed** (şema 36, CRUD, `{marka}`, seed, rota WA) |
| Multi-brand §7.3 (fiş/kasa/logo/query/randevu brand) | **Deferred** (bilinçli) |
| Filtre sheet marka bölümü / designer preview brand | **Open P2** (opsiyonel) |
| Soft UI master merge | **Landed** (kalan: token hardcode borcu) |
| Fabrika iade hesap görünümü (VEN-199) | **Landed** (plan + merge notu) |
| Reminder N-before-N / leadTime | **Deferred / onay bekliyor** (`reminder-advance-notify-plan.md`) |

### 2.4 APPLICATION_ANALYSIS.md (repo kök)

| Boyut | Belge iddiası (14 Kas) | Güncel tip | Sonuç |
| --- | --- | --- | --- |
| POS sürüm | 2.8.4+25 | **3.1.8+64** | **Bayat — P1 doküman** |
| Şema | v16 / 23 tablo | **v36** + brands/reminders/on-site/… | **Bayat — P1** |
| Test | 143 / 808 | ~**250** dosya / VEN-206 **1243** pass | **Bayat** |
| CA ihlalleri | presentation DAO sızıntısı | Guard + hard **0** | Eski bulgular landed |
| PowerSync | yanıltıcı canlı etiket düzeltildi | Mode + connector var; filo/host ops hâlâ borç | Kısmi |
| Keygen seed | SecureStorage göç | SecureStorage-only + fail-closed | Landed |

**Sonuç:** `APPLICATION_ANALYSIS.md` tarihsel kayıt olarak değerli; **operasyonel SSOT değil**. Güncelleme veya “SUPERSEDED by tech-debt-full-analysis + AGENTS.md” bandı önerilir (**TD-N-P1-02**).

---

## 3. Tarama metrikleri (2026-11-24 tip)

| Metrik | Değer | Yorum |
| --- | ---: | --- |
| presentation→DAO/DB hard import | **0** | `check_presentation_layer_imports` yüzeyi temiz |
| `BorderRadius.circular` (presentation) | **344** | Soft UI / `AppRadius` borcu (P2) |
| `Color(0x…)` (presentation) | **4** | Az; temizlenmeli |
| `Colors.grey` / `blueGrey` (presentation) | **2** | Soft debt |
| `VisualDensity.compact` | **0** | AGENTS kuralı tutuluyor |
| `extends StateNotifier` | **49** | Notifier göçü P2/P3 |
| `catch (_)` (lib) | **~232** | W3-08 kritikleri logladı; hot-path bilinçli sessizlik kaldı |
| `skip: true` test | **0** | W3-07 sonrası |
| `*_test.dart` (POS) | **~250** | VEN-206: 1243 pass |
| Keygen test dosyası | **3** (~15 pass clean tip) | |
| API `*.test.ts` | **7** | |
| SPA smoke test | **1** | |
| En büyük god-file’lar | `orders_dao` ~2943, `distribution_provider` ~2572, `drift_address_maintenance_repository` ~2472, `carpet_order` ~2300, `interactive_label_canvas` ~1301 | W3 dilimleme sonrası hâlâ P1/P2 |
| `Widget _build*` (presentation) | **~24** | 1-widget kuralı soft ihlal adayı |
| POS `.github` | `ui-audit.yml` only (`continue-on-error`) | Full analyze/test CI yok |
| Umbrella `.github/workflows` | **yok** | |
| DTO sync tool | **OK** | |
| Field SSOT (HEAD) | POS **3.1.8+64** / Keygen **1.1.5+7** | Kirli WIP’te `fallbackPubspecVersionSpec` drift **riski** |

---

## 4. Full backlog (açık / kısmi / deferred)

Her madde: **ID · severity · alan · kanıt · etki · önerilen fix · efor · field-upgrade riski**.

### 4.1 P0

| ID | Severity | Alan | Kanıt | Etki | Önerilen fix | Efor | Field upgrade |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **TD-N-P0-01** | P0 | Release / version SSOT | Landed tip POS **3.1.8+64** / Keygen **1.1.5+7**; WIP tree POS **3.1.9+70** + Keygen **1.1.6+8** (pubspec↔constants kendi içinde uyumlu); `AppInfoConstants` yorumu hâlâ “Field SSOT: 3.1.8+64”; store/release notes Keygen **1.1.5** diyebilir | Yanlış “field current” iletişimi; WIP commit edilmeden release karışırsa filo karışıklığı | WIP’i branch’le izole et veya Mehmet onaylı bump olarak land et; yorum/preferences/release-notes’u aynı pin’e çek; bat gate | S | **Yüksek** (imza değil; filo iletişim + upgrade doğrulama) |

> Not: Klasik “lisans kırılır / migration bozar” P0’ları Wave’lerde kapanmış. Bu P0 **süreç/SSOT** riskidir; ürün kodu bug’ı değil.

### 4.2 P1 (açık)

| ID | Severity | Alan | Kanıt | Etki | Önerilen fix | Efor | Field upgrade |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **TD-N-P1-01** | P1 | Paging | `paginated_service_requests_provider.dart` `kMaxClientEmptyAutoContinues = 3` | Boş sayfa → sessiz N sayfa yükleme; batarya/CPU | SQL filtreyi tam SSOT yap; auto-continue ≤1 veya kaldır; test | M | Düşük |
| **TD-N-P1-02** | P1 | Docs | `APPLICATION_ANALYSIS.md` v16/2.8.x | Ajan/insan yanlış şema varsayar | SUPERSEDED bandı + kısa “güncel gerçekler” bölümü veya arşiv | S | Yok |
| **TD-N-P1-03** | P1 | God-file | `orders_dao.dart` ~2943 | Regresyon / review maliyeti; UoW riski | W3-02 tarzı part/mixin dilimleme; davranış kilidi testleri | L | Orta (davranış kayması riski) |
| **TD-N-P1-04** | P1 | God-file | `distribution_provider.dart` ~2572 | Rota invariant kırılganlığı | Facade slice; single-active-route / load checklist testleri zorunlu | L | Orta |
| **TD-N-P1-05** | P1 | Adres bakımı | `drift_address_maintenance_repository.dart` ~2472 + `sublist` paging | Bellek / sahte paging | Gerçek SQL LIMIT/OFFSET; chunk UI | L | Düşük |
| **TD-N-P1-06** | P1 | Soft UI | `BorderRadius.circular` ×344 presentation | `design.md` / Soft UI 1:1 sapması | Kademeli `AppRadius`; audit gate’i sertleştir (şimdi informational) | M–L | Yok |
| **TD-N-P1-07** | P1 | CI | Yalnız `ui-audit.yml` + `continue-on-error`; umbrella CI yok | Kırmızı land riski | Analyze+test workflow (veya mevcut bat gate’i CI’ya bağla) | M | Yok |
| **TD-N-P1-08** | P1 | Query marka yüzü | API `companyName: null`; SPA `branding/altigen.ts` sabit | Multi-brand filoda müşteri yanlış firma adı görür | Mehmet onayı + DTO `companyName`/`brandName` + sync; Soft UI SPA ayrı | M | Web only; POS field upgrade yok |
| **TD-N-P1-09** | P1 | Hatırlatma ürün | `reminder-advance-notify-plan.md` — `leadTime`/`maxOccurrences` yok | İleri tarihli alım/teslim spam veya kaçırma | Ürün onayı → Drift v37+ migration (forward-only) + scanner | L | **Orta** (şema; HARD GATE) |

### 4.3 P2 (açık)

| ID | Severity | Alan | Kanıt | Etki | Önerilen fix | Efor | Field upgrade |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **TD-N-P2-01** | P2 | Riverpod | 49× `StateNotifier` | Modern API drift; bakım | Kademeli `Notifier` göçü (modül modül) | L | Yok |
| **TD-N-P2-02** | P2 | Debtors paging | `debtors_list_tab_view.dart` `_visibleCount` | SQL paging ile karışık model | Global list SSOT | M | Yok |
| **TD-N-P2-03** | P2 | Catch/log | ~232 `catch (_)` | Sessiz saha hatası | Kritik yollara AppLogger; hot-path whitelist belgele | M | Yok |
| **TD-N-P2-04** | P2 | Soft UI | `Color(0x)`×4, `Colors.grey/blueGrey`×2 | Token ihlali | `AppColors` | S | Yok |
| **TD-N-P2-05** | P2 | God widget | `interactive_label_canvas.dart` ~1301 | 1-widget / review | Parça widget extract | L | Yok |
| **TD-N-P2-06** | P2 | God domain | `carpet_order.dart` ~2300, `label_template_config.dart` ~1941 | Domain süngeri | Saf model / extension ayır | L | Dikkatli |
| **TD-N-P2-07** | P2 | Tracking monolit | `tracking_notifier_base` ~1016 + payment facade ~1410 | İş kuralı UI-komşu | Daha fazla facade slice | L | Orta |
| **TD-N-P2-08** | P2 | `_build*` | ~24 `Widget _build` | 1-widget soft ihlal | Extract files | M | Yok |
| **TD-N-P2-09** | P2 | Multi-brand UX | Filtre sheet’te marka bölümü yok | Operatör parity | Soft UI sheet section | S | Yok |
| **TD-N-P2-10** | P2 | Multi-brand UX | Label designer preview hâlâ company | Tasarım modu sapması | Preview brand resolve (print yolu OK) | S | Yok |
| **TD-N-P2-11** | P2 | PowerSync ops | Schema/outbox/`ConfiguredPowerSyncConnectorAdapter` var; host DDL/sync_rules/filo runbook | “Açık sanılıp sync yok” / kısmi sync | Operasyon runbook + host checklist; canlıyı ürün olarak belgele | M | Host |
| **TD-N-P2-12** | P2 | Release bat | `vento-unified-safe-release.bat` poliglot monolit | Bakım / mutex | Modülerleştirme (davranış koru) | L | **Yüksek dikkat** (release path) |
| **TD-N-P2-13** | P2 | sqlite transitive | `pubspec.lock` hâlâ `sqlite3_flutter_libs` (drift_flutter) | +eol gürültü | Dokümante accepted; kırma | S | Düşük |
| **TD-N-P2-14** | P2 | Store docs bayat | `technical-debt-analysis.md` v29/UX branch dönemi | Çift SSOT | Bu dosyaya “superseded” pointer | S | Yok |
| **TD-N-P2-15** | P2 | Docs / AGENTS | Kök `AGENTS.md` multi-brand ↔ query `companyName`/SPA Altıgen köprüsünü anlatmıyor; umbrella root `design.md` yok (`ventoPOS/design.md` var) | Ajan yanlış “tek marka web” varsayar | AGENTS’e kısa bridge + design.md pointer; §7.3 cross-link | S | Yok |
| **TD-N-P2-16** | P2 | Query ops | W2-02 index’ler README’de; host uygulaması bu submodule dışı | Seq scan / stale host | powersync host checklist + `POWERSYNC_HOST_INDEX_MIGRATION.md` doğrula | M | Host |
| **TD-N-P2-17** | P2 | Docs / skill | `ventopos-safe-release` SKILL runtimeType tarama metni `lib/data|domain`; bat **tüm `lib/`** | Ajan dar tarama sanır | SKILL’i bat ile hizala | S | Yok |

### 4.4 P3

| ID | Severity | Alan | Kanıt | Etki | Önerilen fix | Efor | Field upgrade |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **TD-N-P3-01** | P3 | CPCL adları | `Cpcl*` API uyumluluk adları | Yeni ajan yanılsaması | Yorum/README (kırıcı rename yok) | S | Yok (rename riskli) |
| **TD-N-P3-02** | P3 | Generated diff | `app_database.g.dart` devasa | PR gürültüsü | Review checklist | S | Yok |
| **TD-N-P3-03** | P3 | Caller ID chrome | Native XML renk ≠ Flutter tokens | Görsel drift | Token sözlüğü | M | Yok |
| **TD-N-P3-04** | P3 | Deep-link filtre | Caller ID `filterOrdersByCustomer` global state | Liste kirlenmesi | Scoped navigation args | M | Yok |
| **TD-N-P3-05** | P3 | Stale proposal docs | `unified-backup-proposal.md` vb. | Yanlış yol | Arşiv bandı | S | Yok |
| **TD-N-P3-06** | P3 | Keygen prefs history | File export landed; prefs hâlâ runtime store | Admin cihaz yedek karmaşası | Prefs→file primary dokümantasyon | S | Keygen only |
| **TD-N-P3-07** | P3 | Query API TODO | `status-verify.ts` “non-public schema” TODO | `SCHEMA_NOT_READY` belirsizliği | Host schema doğrula veya TODO kapat | S | Host |
| **TD-N-P3-08** | P3 | Keygen Soft UI | Tekrarlayan `BoxDecoration`; POS `design_system` yok | Bakım | İsteğe bağlı atom extract | M | Keygen only |
| **TD-N-P3-09** | P3 | trustProxy split | Kod default `false`; compose `TRUST_PROXY=true` | Proxy arkasında rate-limit IP sapması (compose dışı deploy) | Deploy notunu AGENTS/README’de vurgula (davranış OK) | S | Web |

### 4.5 Deferred / accepted risk (bilinçli)

| ID | Kaynak | Neden accepted | Yeniden açma koşulu |
| --- | --- | --- | --- |
| **DEF-MB-01** | Multi-brand §7.3 | Marka fiş dizisi — UNIQUE + query URL firma geneli | Mehmet + query stack tasarımı |
| **DEF-MB-02** | §7.3 | Marka kasa/borç defteri | Ayrı muhasebe kararı |
| **DEF-MB-03** | §7.3 | Marka WhatsApp şablon seti | Talep |
| **DEF-MB-04** | §7.3 | Yerinde randevu `brand_id` | Randevu fazı |
| **DEF-MB-05** | §7.3 | Marka logosu / app skin | Medya+backup+Soft UI şişmesi |
| **DEF-MB-06** | §7.3 / prefs | Query SPA/API marka adı (= TD-N-P1-08 ürün kapısı) | Mehmet onayı |
| **DEF-MB-07** | §7.3 | `applicationId` / lisans bölme | **Yapılmaz** (HARD GATE) |
| **DEF-REM-01** | Reminder plan | N gün önce / N kez — ürün onayı yok | Mehmet 4 soruyu kilitler |
| **DEF-RV-01** | tech-debt-prompt-list | Riverpod Notifier göçü Wave setine alınmadı | Bakım penceresi |
| **DEF-IOS-01** | preferences | `ios` dalı hands-off | Mehmet explicit |
| **DEF-PS-01** | B07 / ürün | Çift yönlü “her cihaz anında” vaadi ürünleştirilmeden | Filo PowerSync GA kararı |
| **DEF-SQL-01** | W3-07 | drift_flutter transitive `sqlite3_flutter_libs` +eol | Upstream temizlenene kadar |

---

## 5. Alan bazlı derin notlar

### 5.1 Mimari / Clean Architecture

- Hard ihlal **yok**; presentation safe facade + tool guard.  
- Soft borç: tanrı provider/DAO/domain (P1/P2 tablosu).  
- W3-02/03 dilimleme **landed** ama `orders_dao` / `distribution_provider` hâlâ P1.  
- Soft UI: `design.md` + AGENTS token kuralları; `BorderRadius.circular` ana sapma.

### 5.2 Veri / Drift / backup / sync

- Şema **v36**; migration zinciri uzun → saha sıçrama test yüzeyi büyük (pre_migration_snapshot mevcut — güçlü).  
- W2-01 sonrası on-site/reminders/company_info_urls/neighborhoods/brands yedek matrisinde.  
- `global_reminders` / `reminder_module_settings` sync dışı **bilinçli** (cihaz-yerel).  
- Receipt sequences: standart + iade ayrı; UNIQUE korunuyor — marka başına dizi **deferred**.  
- PowerSync: şema + connector + mode UI var; operasyonel GA ve “yanıltıcı canlı” riski P2 runbook.

### 5.3 Güvenlik / lisans

- POS yalnızca public verify key.  
- Keygen SecureStorage-only; compile-time seed fail-closed (W1-04/W3-06).  
- Bat sibling public key + runtimeType taraması.  
- Keygen→müşteri dist mirror **yok** (W1-01).  
- HARD GATE: keystore / `applicationId` / Ed25519 protokol baytları değiştirilmez.

### 5.4 UX / ürün

- Multi-brand çekirdek landed; §7.3 ertelenmiş.  
- Reminder advance plan yazılı, kod yok.  
- Query SPA marka: sabit Altıgen + `companyName: null`.  
- Soft UI landed; token hardcode kalıntısı P1/P2.

### 5.5 Test / CI / performans

- POS test hacmi güçlü (VEN-206 yeşil).  
- CI zayıf: tek informational UI audit.  
- Adres bakımı sublist + debtors `_visibleCount` + servis auto-continue = perf/paging P1/P2.  
- Tracking “hepsini yükle” tarihsel riski (APPLICATION_ANALYSIS) — paging ilerledi ama monolit state sürüyor.

### 5.6 Release / ops

- Field SSOT: POS `3.1.8+64`, Keygen `1.1.5+7`.  
- `build.bat` → `build/vento-unified-safe-release.bat`.  
- Version SSOT drift (WIP) = **TD-N-P0-01**.  
- Post-W3 full deploy tercih notu preferences’ta vardı; bu analizin kapsamı değil.

---

## 6. Önerilen dalgalar (yalnız sıralama — kod yok)

### Dalga A — SSOT / doküman / release hijyeni (önce)

1. TD-N-P0-01 version SSOT temizliği (WIP izolasyonu)  
2. TD-N-P1-02 `APPLICATION_ANALYSIS` SUPERSEDED  
3. TD-N-P2-14 eski tech-debt docs pointer  

### Dalga B — Paging / Soft UI token / CI

1. TD-N-P1-01 servis auto-continue  
2. TD-N-P2-02 debtors SQL paging  
3. TD-N-P1-06 / P2-04 Soft UI token sweep (öncelikli hot screens)  
4. TD-N-P1-07 analyze+test CI  

### Dalga C — Tanrı dosya dilimleme (davranış kilidi testleriyle)

1. TD-N-P1-03 `orders_dao`  
2. TD-N-P1-04 `distribution_provider`  
3. TD-N-P1-05 address maintenance SQL paging  
4. TD-N-P2-05/07 canvas + tracking  

### Dalga D — Ürün kapılı (Mehmet onayı şart)

1. TD-N-P1-09 reminder lead/max (DEF-REM-01)  
2. TD-N-P1-08 / DEF-MB-06 query marka adı  
3. DEF-MB-01…05 yalnızca talep gelirse  

### Dalga E — İsteğe bağlı bakım

- TD-N-P2-01 Riverpod Notifier  
- TD-N-P2-03 catch/AppLogger devam  
- TD-N-P2-11 PowerSync runbook  
- TD-N-P2-12 bat modülerleştirme  

---

## 7. Explicit OUT / accepted risk

- **Kod değişikliği / PR:** bu görevde yok.  
- **`ios` dalı:** dokunulmaz (preferences).  
- **Keygen / POS kirli WIP:** bozulmadı (reminder plan worker / version bump).  
- **Hard CA ihlali aramak:** tükenmiş — 0.  
- **Lisans protokolü / keystore rotate “yeniden”:** yapılmaz; süreklilik HARD GATE.  
- **Live PowerSync’i “bitmiş ürün” ilan etmek:** accepted risk değilse runbook (TD-N-P2-11); GA ayrı karar.  
- **Multi-brand §7.3:** bilinçli yapılmaz listesi (§4.5).  
- **Repo `docs/` mirror:** birincil SSOT Agent Store; umbrella `docs/` kopyası bu turda **üretilmedi** (kirli tree + no-code kuralı).

---

## 8. Kaynak haritası (birleştirilen belgeler)

| Belge | Rol | Bu SSOT’taki işlem |
| --- | --- | --- |
| `docs/technical-debt-analysis.md` | 19 Kas POS derin tarama (v29) | Landed maddeler işaretlendi; kalanlar TD-N* |
| `docs/tech-debt-comparison.md` | A vs dış HTML | Wave birleşik öncelik tarihsel |
| `docs/tech-debt-prompt-list.md` | 16 tur prompt | **16/16 landed** tablosu |
| `internal/ven-78-tech-debt-progress.md` | SLA/paging local | Landed + servis auto-continue kısmi |
| `docs/multi-brand-module-analysis.md` | Marka + §7.3 | Deferred envanter |
| `internal/reminder-advance-notify-plan.md` | N-before-N | DEF-REM-01 / TD-N-P1-09 |
| `APPLICATION_ANALYSIS.md` | 14 Kas ekosistem | Bayat → TD-N-P1-02 |
| `internal/ven-119`…`ven-135` | Wave landing | Landed kanıt |
| `internal/ven-206-test-suite-green.md` | Test yeşil | CI/test baseline |
| `preferences.md` | Field SSOT / gates | P0 SSOT + deferred politikası |
| `internal/tech-debt-scan-keygen-query-umbrella.md` | Keygen/query/umbrella teyit | TD-N-P2-15…17, P3-07…09; WIP sürüm netliği |

### 8.1 Tarama teyit (delta)

[Keygen query umbrella scan](bc-12013733-4ce2-54c7-a73d-d1ddb6493550) SSOT’u doğruladı / genişletti: W1–W3 query/Keygen landed iddiaları **doğru**; yeni ince borçlar AGENTS marka köprüsü, skill↔bat tarama metni, host index ops, API schema TODO, Keygen Soft UI atomları, trustProxy compose split. POS-odaklı paralel tarama ajanı provider kuralıyla **başarısız** oldu; POS metrikleri bu worker’ın doğrudan taramasıyla zaten SSOT’ta.

---

## 9. Top 10 — coordinator özeti (P0/P1)

1. **TD-N-P0-01** — Version SSOT / kirli WIP drift (3.1.8+64 vs WIP 3.1.9+70)  
2. **TD-N-P1-01** — Servis listesi auto-`loadMore` (max 3) hâlâ telafi  
3. **TD-N-P1-02** — `APPLICATION_ANALYSIS.md` bayat SSOT  
4. **TD-N-P1-03** — `orders_dao` ~3k god-file  
5. **TD-N-P1-04** — `distribution_provider` ~2.5k  
6. **TD-N-P1-05** — Adres bakımı in-memory `sublist` paging  
7. **TD-N-P1-06** — Soft UI `BorderRadius.circular` ×344  
8. **TD-N-P1-07** — Full analyze/test CI yok  
9. **TD-N-P1-08** — Query `companyName: null` + sabit Altıgen (ürün onayı)  
10. **TD-N-P1-09** — Reminder lead/max (şema onayı bekliyor)

---

*Salt analiz SSOT. Kod, test, commit, push, PR üretilmedi. Europe/Istanbul 2026-11-24.*
