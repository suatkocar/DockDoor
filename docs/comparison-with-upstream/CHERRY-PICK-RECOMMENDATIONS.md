# Cherry-Pick Recommendations (Usage-Based)

**Date:** 2026-03-09
**Based on:** Actual UserDefaults analysis + codebase review

---

## Usage Profile

- **Window Switcher ana mod** — Ctrl+Cmd+Tab, instant mode, 4x4 grid, width-based layout, classic ordering
- **Dock hover aktif** — gestures, scroll, live preview (dock'ta açık, switcher'da kapalı)
- **Cmd+Tab enhancements KAPALI**
- **Search KAPALI** switcher'da
- **Active app indicator KAPALI**
- **Auto-hide dock YOK**
- **Animasyon YOK** — showAnimations=0, fadeOutDuration=0, openDelay=0
- **Space filtering KAPALI** — tüm space'lerden pencere
- **Liquid Glass açık** — variant 19, opacity 0.8
- **Gestures açık** — swipe down=minimize, left=fillLeftHalf, right=fillRightHalf, up=quit
- **Group by App açık** (dock)
- **Settings bir kere ayarlanmış, bir daha açılmamış**

---

## TIER 1: Kritik Crash Fix'leri

| # | Karar | Gerekçe |
|---|-------|---------|
| **1.1** LimitedTaskGroup crash | **AL** | Crash fix, herkesi etkiler. Windowless app kodumuzla conflict var ama çözülür. |
| **1.2** Dock icon tıklama crash | **AL** | Dock hover aktif kullanılıyor. |
| **1.3** Sleep/wake preview | **AL** | Herkes etkilenir. |
| **1.4** Media widget memory leak | **ALMA** | Spotify/Music dock hover sık kullanılmıyorsa 400MB leak tetiklenmez. Diff çok büyük, risk/fayda düşük. |

---

## TIER 2: Major Bug Fix'leri

### AL (6 item)

| # | Fix | Gerekçe |
|---|-----|---------|
| **2.1** | Event tap lag | **ÖNCELİKLİ.** `instantWindowSwitcher=1` — performans kritik. Her keyDown'da AX call input lag demek. En çok hissedilecek fix. |
| **2.2** | Dock hover stale cache | Dock hover aktif. Yeni açılan pencere görünmüyorsa direkt etkilenirsin. |
| **2.5** | Liquid glass freeze | `useLiquidGlass=1`. macOS 26'da freeze olursa direkt etkilenirsin. |
| **2.6** | Dock click preview dışı | Dock hover aktif. Preview dışı tıklama yanlış aksiyon tetikliyor. |
| **2.10** | Non-grouped app sırası | `groupAppInstancesInDock=1`. Group by App açık, sıra bozulması direkt etkilenir. |
| **2.15** | Trackpad swipe false trigger | Gestures aktif. Yanlış tap tetiklenmesi sinir bozucu. |

### TARTIS (2 item)

| # | Fix | Gerekçe |
|---|-----|---------|
| **2.7** | Windowless app hideWindow | Bizim windowless app kodumuz farklı. Kontrol lazım — muhtemelen zaten handle ediyoruzdur. |
| **2.9** | Stale orientation flag | `useWidthBasedLayout=1`. Bin-packing ile çakışabilir ama kontrol etmek lazım. |

### ALMA (7 item)

| # | Fix | Neden almıyoruz |
|---|-----|-----------------|
| **2.3** | Stale space ID cache | `showWindowsFromCurrentSpaceOnlyInSwitcher=0` — space filtering kapalı. |
| **2.4** | Space filtering bozuk | Aynı — space filtering kullanılmıyor. 4 dosya risk almaya değmez. |
| **2.8** | Cache state override | Coordinator yapımız farklı (SelectionState ayrımı). Conflict riski yüksek. |
| **2.11** | Active app indicator | `showActiveAppIndicator=0` — kapalı. Faydası yok. |
| **2.12** | Tab hijacking Cmd+Tab | `enableCmdTabEnhancements=0` — Cmd+Tab kapalı. İrrelevant. |
| **2.13** | Dock auto-hide restore | Auto-hide dock yok. |
| **2.14** | Preview bounce | Auto-hide dock yok + 0s animasyon yok. |

---

## TIER 3: Feature'lar

### AL (4 item)

| # | Feature | Gerekçe |
|---|---------|---------|
| **3.2** | Window order persistence | `useClassicWindowOrdering=1`, `recentlyUsed` sort. Restart sonrası sıra korunması faydalı. Düşük risk (yeni dosya). |
| **3.7** | Force switcher direction | `switcherMaxColumns=4`, `switcherMaxRows=4`. Yönü zorlamak basit ve faydalı. |
| **3.11** | Manual dark mode override | Liquid glass aktif, tema kontrolü önemli. Düşük risk. |
| **3.13** | Per-feature hidden window toggles | Switcher'da minimized/hidden ayrı kontrol mantıklı. Düşük risk. |

### TARTIS (2 item)

| # | Feature | Gerekçe |
|---|---------|---------|
| **3.4** | Adjustable switcher position | `screenWithMouse` kullanılıyor. Offset slider'lar faydalı olabilir ama acil ihtiyaç yok. |
| **3.8** | Customizable cycle key | Cycle key faydalı olabilir ama search trigger irrelevant (`enableWindowSwitcherSearch=0`). |

### ALMA (9 item)

| # | Feature | Neden almıyoruz |
|---|---------|-----------------|
| **3.1** | Settings reorganizasyonu | Settings bir kere ayarlanmış, bir daha açılmamış. Maximum risk, sıfır fayda. |
| **3.3** | mergeWindowsIfShowing | Kendi refreshUI resize fix'imiz var. Upstream çözümü gereksiz. |
| **3.5** | Single-entry app grouping | Karmaşıklık, niş kullanım. |
| **3.6** | Cmd+Tab backward nav | `enableCmdTabEnhancements=0`. İrrelevant. |
| **3.9** | Auto-select first Cmd+Tab | `enableCmdTabEnhancements=0`. İrrelevant. |
| **3.10** | AppleScript scripting | Niş, personal use'da gereksiz. |
| **3.12** | Dock preview anchoring | Auto-hide dock yok. |
| **3.14** | Compact mode traffic light | `switcherDisableDockStyleTrafficLights=1`. Zaten kapalı. |
| **3.15** | Onboarding + CLI | Gereksiz karmaşıklık. |

---

## TIER 4: Minor Fix'ler

**Toplu AL** — hepsi düşük risk. Conflict çıkarsa o item atılır.

---

## Final Tablo

| Kategori | AL | TARTIS | ALMA |
|----------|-----|--------|------|
| Tier 1 | 1.1, 1.2, 1.3 | — | 1.4 |
| Tier 2 | 2.1, 2.2, 2.5, 2.6, 2.10, 2.15 | 2.7, 2.9 | 2.3, 2.4, 2.8, 2.11, 2.12, 2.13, 2.14 |
| Tier 3 | 3.2, 3.7, 3.11, 3.13 | 3.4, 3.8 | 3.1, 3.3, 3.5, 3.6, 3.9, 3.10, 3.12, 3.14, 3.15 |
| Tier 4 | toplu | — | — |

**Toplam: 13 AL + ~10 minor + 4 TARTIS + 20 ALMA**

---

## Önerilen Dalga Sırası

1. **Dalga 1:** 1.1 + 1.2 + 1.3 (crash fix'ler)
2. **Dalga 2:** 2.1 + 2.6 + 2.10 + 2.15 (düşük riskli bug fix'ler)
3. **Dalga 3:** 2.2 + 2.5 (ORTA riskli bug fix'ler)
4. **Dalga 4:** 3.2 + 3.7 + 3.11 + 3.13 (düşük riskli feature'lar)
5. **Dalga 5:** Tier 4 toplu
6. **Dalga 6:** TARTIS'lar (2.7, 2.9, 3.4, 3.8) teker teker değerlendirme
