# Cherry-Pick Decision List

Her item icin karar: **AL** / **ALMA** / **TARTIS**
Test: Neyi test etmen gerekir

---

## TIER 1: Kritik Crash Fix'leri (4 item)

Bunlar "soru sormadan al" kategorisi ama yine de senin kararın.

### 1.1 LimitedTaskGroup crash fix → structured concurrency
- **Ne:** Window discovery sirasinda concurrency bug'i yuzunden crash. TaskGroup + timeout ile degistirilmis.
- **Risk:** ORTA — `LimitedTaskGroup.swift` ve `WindowUtil.swift` degisiyor, bizim windowless app kodumuzla conflict olabilir
- **Test:** Cmd+Tab ac/kapa 20 kez hizlica, cok pencereli uygulamalari gec gec, crash olmuyor mu bak
- **Karar:** ___

### 1.2 DockDoor'un kendi dock icon'una tiklaninca crash
- **Ne:** DD'nin dock'taki iconuna tiklaninca crash. Guard eklenmis.
- **Risk:** DUSUK — `DockObserver.swift`'te kucuk bir guard
- **Test:** DockDoor'un dock icon'una tikla, crash olmadigini dogrula
- **Karar:** ___

### 1.3 Sleep'ten uyaninca preview'lar bozulma
- **Ne:** Sleep sonrasi window level kayboluyor, preview render olmuyor. `AppDelegate.swift`'e wake handler eklenmis (+14 satir).
- **Risk:** DUSUK — izole degisiklik, baska bir seyi bozmaz
- **Test:** Mac'i uyut, uyandır, dock hover ve Cmd+Tab'in calistigini dogrula
- **Karar:** ___

### 1.4 Media widget memory leak + osascript process pileup
- **Ne:** Spotify/Apple Music hover'da RAM 400MB+ cikiyor, NSAppleScript thread-safe degil → process birikimi. Singleton cache + osascript runner ile duzeltilmis.
- **Risk:** YUKSEK — media widget mimarisi tamamen degismis, buyuk diff
- **Test:** Spotify dock icon uzerinde hizlica gidip gel 50 kez, Activity Monitor'de RAM izle
- **Karar:** ___

---

## TIER 2: Major Bug Fix'leri (15 item)

Bunlar kullanici deneyimini ciddi etkileyen bug'lar.

### 2.1 Event tap lag — her keyDown'da pahali AX call
- **Ne:** `shouldIgnoreKeybindForFrontmostApp()` her tus basilisinda cagriliyordu → sistem geneli input lag. Keycode match'ten sonraya ertelendi.
- **Risk:** DUSUK — `KeybindHelper.swift`'te kucuk sira degisikligi
- **Test:** Herhangi bir uygulamada hizli yazip event lag olmadigini hisset
- **Karar:** ___

### 2.2 Dock hover'da stale cache gosterme
- **Ne:** Cache'te olan uygulamada yeni acilan pencereler gosterilmiyordu. Cache-vs-refresh logic degismis.
- **Risk:** ORTA — `DockObserver.swift` dock hover mantigi degisiyor
- **Test:** Bir uygulamada yeni pencere ac, dock'ta hover et, yeni pencere gorunuyor mu
- **Karar:** ___

### 2.3 Stale space ID'li pencereler cache'e giriyor
- **Ne:** Yanlis Space'deki pencereler preview'da gorunuyordu. Cache insertion'da space ID validasyonu eklenmis.
- **Risk:** DUSUK — `WindowDiscoveryShared.swift`'te guard
- **Test:** 2 Space kullan, Space 2'deyken Space 1 pencerelerinin gozukmedigini dogrula
- **Karar:** ___

### 2.4 Space filtering dock preview ve Cmd+Tab'da calismiyor
- **Ne:** Filtreleme mantigi butun modlarda bozuktu. 4 dosyada duzeltme.
- **Risk:** ORTA — birden fazla dosyada degisiklik
- **Test:** Space filtresi ac, farkli Space'lerde dock hover + Cmd+Tab test et
- **Karar:** ___

### 2.5 Liquid glass freeze (macOS 26)
- **Ne:** Blur efekti window server tarafindan "unaware" isaretlenince donuyor. Recovery logic eklenmis.
- **Risk:** DUSUK — `BlurView.swift`'e +42 satir recovery
- **Test:** macOS Tahoe'da uzun sureli kullanim, blur donuyor mu
- **Karar:** ___

### 2.6 Dock click aksiyonu preview disinda tetikleniyor
- **Ne:** Preview alaninin disina tiklayinca da minimize/hide aksiyonu calisiyordu.
- **Risk:** DUSUK — mouse position check eklenmis
- **Test:** Dock icon'a tikla ama preview'in disinda, yanlis aksiyon olmuyor mu
- **Karar:** ___

### 2.7 Penceresi olmayan app hover'da hideWindow() cagriliyor
- **Ne:** Penceresi olmayan uygulama uzerinde hover → gereksiz hideWindow() → dock/diger pencereler bozuluyor
- **Risk:** DUSUK — kucuk guard
- **Test:** Windowless app (Finder Dock icon ama pencere yok) uzerinde hover et
- **Karar:** ___

### 2.8 Cache state background refresh'i eziyor
- **Ne:** Cache'ten gosterilen preview'in background renkleri, sonradan gelen refresh degerlerini override ediyordu.
- **Risk:** ORTA — PreviewStateCoordinator degisikligi, bizim coordinator farkli
- **Test:** Hizlica farkli app'ler arasinda hover et, renkler dogru mu
- **Karar:** ___

### 2.9 Window switcher stale orientation flag
- **Ne:** Farkli code path'ler horizontal/vertical yonunu farkli hesapliyordu → yanlis layout.
- **Risk:** ORTA — layout kodu degisiyor, bizim bin-packing ile conflict olabilir
- **Test:** Window switcher'i ac, layout dogru mu (horizontal/vertical)
- **Karar:** ___

### 2.10 Non-grouped app'lerde pencere sirasi bozulma
- **Ne:** "Group by App" acikken gruplu OLMAYAN app'lerin de sirasi bozuluyordu.
- **Risk:** DUSUK — O(n) algoritma degisikligi
- **Test:** Group by App ac, farkli app pencerelerinin siralamasi dogru mu
- **Karar:** ___

### 2.11 Active app indicator fullscreen + dock size
- **Ne:** Fullscreen space'te indicator gorunuyordu + dock boyutu degisince misalign oluyordu
- **Risk:** DUSUK — izole indicator kodu
- **Test:** Fullscreen app ac, indicator olmadigini dogrula. App kapat, indicator hizasini kontrol et.
- **Karar:** ___

### 2.12 Tab hijacking Cmd+Tab modunda
- **Ne:** Cmd+Tab modunda Tab tusu DockDoor cycle ediyordu, sistem switcher'a gecmiyordu.
- **Risk:** DUSUK — KeybindHelper'da guard
- **Test:** Cmd+Tab aç, Tab'a bas, beklenen davranis mi
- **Karar:** ___

### 2.13 Dock auto-hide restore edilmiyor (preview visible olmadan dismiss)
- **Ne:** Preview gorünür olmadan dismiss edilince dock gizli kaliyordu (kalici).
- **Risk:** DUSUK — `hideWindow()` icindeki sira degisikligi
- **Test:** Auto-hide dock + hizlica hover edip çek, dock geri cikiyor mu
- **Karar:** ___

### 2.14 Preview bounce (duplicate AX notification, auto-hide dock 0s)
- **Ne:** Dock auto-hide 0s animasyonla ayni icon icin tekrarlanan AX notlari → preview titriyor.
- **Risk:** ORTA — element identity tracking ekleniyor
- **Test:** Auto-hide dock 0s animasyonla hover et, titremiyor mu
- **Karar:** ___

### 2.15 Trackpad swipe sirasinda yanlis tap tetiklenmesi
- **Ne:** Hizli trackpad swipe'da tap aksiyonu (hide window) yanlis tetikleniyordu.
- **Risk:** DUSUK — gesture handler'da suppression
- **Test:** Trackpad ile hizlica swipe et, pencere gizlenmiyor mu yanlis yere
- **Karar:** ___

---

## TIER 3: Feature'lar (hangilerini almak istersin?)

### 3.1 Settings reorganizasyonu (10 tab, reusable components)
- **Ne:** Flat 6 tab → 9-10 focused tab (Dock Previews, Window Switcher, Cmd+Tab ayri ayri). Reusable component'lar (SettingsGroup, SettingsToggleRow, vs.)
- **Risk:** COK YUKSEK — tum settings view'lari silip basa yazilmis, en buyuk conflict kaynagi
- **Test:** Her ayar sayfasini ac/kapa, tum toggle/slider'lar calisiyor mu
- **Not:** Bu en buyuk is. Almak istersen ayri bir branch'te yapmak lazim.
- **Karar:** ___

### 3.2 Window order persistence (restart sonrasi sira korunuyor)
- **Ne:** Yeni `WindowOrderPersistence.swift` dosyasi. Quit'te kaydet, launch'ta yukle.
- **Risk:** DUSUK — yeni dosya + consts.swift'e key + AppDelegate'e save/load
- **Test:** DD'yi kapat/ac, pencere sirasi korunuyor mu
- **Karar:** ___

### 3.3 mergeWindowsIfShowing() — seamless pencere guncelleme
- **Ne:** Switcher acikken pencere listesi degistiginde flicker olmadan guncelliyor.
- **Risk:** ORTA — coordinator + SharedPreviewWindowCoordinator degisikligi
- **Test:** Switcher acikken yeni pencere ac, smooth ekleniyor mu
- **Karar:** ___

### 3.4 Adjustable window switcher position (offset slider'lar)
- **Ne:** Yatay/dikey offset slider'lar + ust kenara sabitlme opsiyonu. Buyuk ekranlar icin faydali.
- **Risk:** DUSUK — consts + coordinator positioning
- **Test:** Offset'leri deistir, switcher dogru yerde mi
- **Karar:** ___

### 3.5 Single-entry app grouping (VS Code gibi cok pencereli app'ler tek gozukur)
- **Ne:** Belirli app'ler switcher'da tek entry, tiklaninca tumunu goster.
- **Risk:** ORTA — window discovery + filter + UI
- **Test:** VS Code'u ekle, switcher'da tek gorunuyor mu, tiklaninca tumunu gosteriyor mu
- **Karar:** ___

### 3.6 Cmd+Tab backward navigation (Shift+Tab)
- **Ne:** Shift+Tab ile geri gitme + ozellestirillebilir geri tus.
- **Risk:** DUSUK — KeybindHelper'da duzeltme
- **Test:** Cmd+Tab aç, Shift+Tab geri gidiyor mu
- **Karar:** ___

### 3.7 Force window switcher direction (horizontal/vertical)
- **Ne:** Switcher yonunu zorlama opsiyonu.
- **Risk:** DUSUK — enum + setting + layout check
- **Test:** Yonu degistir, dogru layout mu
- **Karar:** ___

### 3.8 Customizable cycle key + search trigger key
- **Ne:** Tab yerine baska tus ile cycle, / yerine baska tus ile arama.
- **Risk:** DUSUK — KeyCaptureButton component + settings
- **Test:** Tuslari degistir, calisiyorlar mi
- **Karar:** ___

### 3.9 Auto-select first window in Cmd+Tab
- **Ne:** Cmd+Tab acilinca ilk pencere otomatik secili.
- **Risk:** DUSUK — tek satirlik degisiklik
- **Test:** Cmd+Tab aç, ilk pencere secili mi
- **Karar:** ___

### 3.10 AppleScript scripting dictionary
- **Ne:** DockDoor'a AppleScript ile komut gonderebilme (preview goster/gizle, pencere listele, aksiyon yap).
- **Risk:** ORTA — yeni dosyalar + Info.plist
- **Test:** Script Editor'dan komutlari dene
- **Karar:** ___

### 3.11 Manual dark mode override
- **Ne:** System/Light/Dark secimi. Sistem ayarindan bagimsiz.
- **Risk:** DUSUK — AppDelegate + setting
- **Test:** Dark/Light/System sec, dogru mu
- **Karar:** ___

### 3.12 Dock preview position anchoring (auto-hide dock icin)
- **Ne:** Auto-hide dock'ta icon frame cache'leniyor, preview ziplamasi onleniyor.
- **Risk:** ORTA — coordinator'da anchoring logic
- **Test:** Auto-hide dock + hover, preview zipliyor mu
- **Karar:** ___

### 3.13 Per-feature hidden window toggle'lari
- **Ne:** Dock preview, Cmd+Tab, Window Switcher icin ayri ayri minimized/hidden filtreleme.
- **Risk:** DUSUK — 2 yeni bool + filtering logic
- **Test:** Her mod icin minimized goster/gizle ayri calisiyor mu
- **Karar:** ___

### 3.14 Compact mode'da traffic light gizleme
- **Ne:** Community PR — compact/list modunda traffic light butonlarini gizleme.
- **Risk:** DUSUK — kucuk UI toggle
- **Test:** Compact modda traffic light'lar gizleniyor mu
- **Karar:** ___

### 3.15 Onboarding redesign + CLI support
- **Ne:** Yeni intro ekranlari + `dockdoor` CLI komutu (applescript bridge).
- **Risk:** ORTA — yeni view'lar + CLI binary
- **Test:** Ilk acilis flow'u, CLI komutu
- **Karar:** ___

---

## TIER 4: Minor Fix'ler (toplu al/alma)

| # | Fix | Risk | Karar |
|---|-----|------|-------|
| 4.1 | Window preview corner radius | DUSUK | ___ |
| 4.2 | Animation timing macOS 26 | DUSUK | ___ |
| 4.3 | Widget spacing globalPadding scaling | DUSUK | ___ |
| 4.4 | AX validation flag preservation | DUSUK | ___ |
| 4.5 | Screen recording popup (cache timer) | DUSUK | ___ |
| 4.6 | Settings window resize | DUSUK | ___ |
| 4.7 | Initial selection reset | DUSUK | ___ |
| 4.8 | Exact modifier match for shortcuts | DUSUK | ___ |
| 4.9 | Live preview dock gap (scaledToFit) | DUSUK | ___ |
| 4.10 | Compact mode sizing | DUSUK | ___ |

---

## Strateji Notu

Her tier'i ayri bir dalga olarak yapmayi oneriyorum:
1. **Dalga 1:** Tier 1 crash fix'leri → build → test → commit
2. **Dalga 2:** Sectigin Tier 2 bug fix'leri → build → test → commit
3. **Dalga 3:** Sectigin Tier 3 feature'lar (her biri ayri commit)
4. **Dalga 4:** Tier 4 minor fix'ler toplu

Her dalga sonrasi test edip onay verirsin, devam ederiz.
