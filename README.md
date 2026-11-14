# Ktancraft

**Ktan Labs tarafından geliştirildi.**
iPhone ve iPad için, tamamen cihazın kendisinde çalışan bir voksel (blok) oyunu.

Ktancraft tek başına bir uygulamadır: içinde hiç dosya, hiç doku (texture), hiç ses ya da
hazırlanması gereken bir "oyun dosyası" yoktur. Her doku ve her dünya, cihazın kendisinde
sıfırdan üretilir. Bu yüzden kurmak için **bilgisayar gerekmez**.

---

## Kurulum — bilgisayarsız, sadece telefon

1. Bu sohbetten **`Ktancraft.zip`** dosyasını iPhone/iPad'e indir (Safari'de indirilenler `Dosyalar` uygulamasına düşer).
2. `Dosyalar` uygulamasında zip'e dokun → `Ktancraft.swiftpm` klasörü çıkar.
3. App Store'dan ücretsiz **Swift Playgrounds** uygulamasını kur (Apple'ın kendi uygulaması, Mac gerektirmez).
4. `Dosyalar`'da `Ktancraft.swiftpm` klasörüne uzun bas → **Paylaş → Swift Playgrounds'ta Aç** (ya da Swift Playgrounds'ta "Aç" ile klasörü seç).
5. Üstteki **Çalıştır (▶)** düğmesine bas. Oyun cihazında başlar.

Gereksinim: iOS/iPadOS 16 veya üzeri, yatay kullanım. Swift Playgrounds, projeyi cihazın
kendisinde derler ve çalıştırır; imzalama, hesap ya da Mac gerekmez.

---

## Kontroller

| Ne | Nasıl |
|---|---|
| Yürümek | **Sol yarı**: parmağını ekrana koy ve sürükle. Joystick parmağının altında belirir. |
| Etrafa bakmak | **Sağ yarı**: sürükle. |
| Blok kırmak | **Çekiç** tuşunu basılı tut. Sert bloklar daha uzun sürer, nişangâhın çevresinde ilerleme halkası dolar. |
| Blok koymak | **Küp** tuşuna dokun. Baktığın yüzün üstüne seçili blok gelir. |
| Zıplamak / yüzmek | **Yukarı ok**. |
| Uçuş | **Uçak** tuşu. Uçarken yukarı ok yükseltir, aşağı ok alçaltır. |
| Blok seçmek | Alttaki çubukta bir bloğa dokun (çimen, toprak, taş, parke taşı, kum, tahta, kütük, cam, yaprak). |
| Duraklatmak | Sağ üstteki **duraklat**. Orada kaydetme, doğduğun yere dönme, görüş mesafesi ve hassasiyet ayarları da var. |

Oyun duraklatıldığında, uygulama arka plana geçtiğinde ve çıkarken dünya otomatik kaydedilir.

---

## Neler var

- **Sonsuz, tohumlanmış dünya**: kıtasal gürültü, tepeler, sırt biçimli dağlar, kumsallar, kar zirveleri, mağaralar, ağaçlar. Aynı tohum → her cihazda aynı dünya.
- **Gündüz/gece döngüsü**, güneş ışığı, sis ve gökyüzü rengi görüş mesafesine göre.
- **Blok kırma/koyma** sertlik kurallarıyla, hedefleme için voksel ışın izleme (DDA).
- **Fizik**: yerçekimi, zıplama, koşma, suda yüzme, uçuş, blok çarpışmaları (eksen bazlı, alt adımlı).
- **Greedy meshing**: aynı tür blokların komşu yüzleri tek dörtgene birleşir; bu, SceneKit'i telefonda rahat tutan şeydir.
- **Dokular tamamen prosedürel**: 14 blok türü, 16×16 RGBA, cihazda piksel piksel çizilir.
- **Kayıt**: dünya = tohum + senin değişikliklerin. Dosya birkaç yüz bayt kalır, dilediğin kadar inşa edebilirsin.
- **Dünya listesi**: birden çok dünya, tarih/tohum/değişiklik sayısı ile birlikte, silinebilir.

## Yapı

```
Ktancraft.swiftpm/
  Package.swift        Swift Playgrounds uygulama bildirimi (AppleProductTypes)
  Info.plist           görünen ad, yatay mod, tam ekran
  Core/                motor — sadece Foundation, platformdan bağımsız
    Math, Noise, Block, Textures, Chunk, WorldGen, World, Mesher,
    Physics, Raycast, Inventory, SaveFile, Game
  App/                 iOS katmanı — SwiftUI + SceneKit + UIKit dokunma
    KtancraftApp, MenuView, GameView, HUDView,
    GameModel, WorldRenderer, GameSurfaceView, BlockIcon, AppState
Tests/main.swift       motorun Linux'ta çalışan test koşucusu
```

Motor (`Core/`) hiçbir Apple çerçevesi kullanmaz; bu yüzden bu depoda Linux üzerinde
derlenip test edilebiliyor. `App/` katmanı SwiftUI, SceneKit ve UIKit kullanır ve yalnızca
iOS'ta derlenir.

## İmzasız `.ipa` (bilgisayar gerekmez)

Bir `.ipa`'nın içinde **derlenmiş bir arm64 iOS uygulaması** olmak zorunda, bunu da yalnızca
macOS + Xcode yapabiliyor. Bu depo o derlemeyi **GitHub'ın ücretsiz macOS sunucusunda**
yapıyor — sende bilgisayar olmasına gerek yok, sertifika da kullanılmıyor
(`CODE_SIGNING_ALLOWED=NO`); imzalamayı sen sideload aracınla yaparsın.

1. GitHub'da yeni bir depo aç (ör. `ktancraft`; private olabilir).
2. Bu zip'in içindekilerin **hepsini** depoya yükle: `Ktancraft.swiftpm/`, `ios/`, `.github/`, `README.md`.
   (GitHub web arayüzü → **Add file → Upload files**; telefondan da yapılabilir.)
3. Depoda **Actions** sekmesi → *Build unsigned IPA* → **Run workflow**.
4. 2–4 dakika sonra iş yeşil olur. İş sayfasında **Artifacts → Ktancraft-unsigned-ipa**,
   içinde `Ktancraft-unsigned.ipa` hazır.
5. Onu kendi imzalama/sideload yolunla (SideStore, AltStore, ESign, Sideloadly…) kur.
   Derleme imzasız olduğu için kurulum tamamen senin imzana bağlı.

Bir tag atarsan (`git tag v1.0 && git push --tags`) `.ipa` ayrıca GitHub Release'e eklenir.

Notlar:

- `ios/Ktancraft.xcodeproj` bu depoda hazır geliyor (XcodeGen ile üretildi, `objectVersion 77`,
  Xcode 16 uyumlu). `ios/project.yml` tek doğruluk kaynağıdır: projeyi yeniden üretmek için
  `cd ios && xcodegen generate`.
- Xcode projesi kaynakları `../Ktancraft.swiftpm/App` ve `../Ktancraft.swiftpm/Core` altından
  doğrudan derler; Playgrounds projesi ile Xcode projesi **aynı kodu** paylaşır, kopya yoktur.
- Yalnızca `iphoneos` + `arm64` derlenir; imza, entitlement ve provisioning profile yoktur.
- App ikonu yok: derleme sırasında uyarı verir, durdurmaz. App Store'a yüklemek istersen
  Playgrounds'ta *App Settings → Custom* ile bir ikon seçmen gerekir.

### Bu depoda gerçekleşen derleme

`main` dalına yapılan push, iş akışını çalıştırdı ve derleme **geçti**: 33 saniyede
`Ktancraft-unsigned.ipa` üretildi ve artifact olarak yüklendi. Üretilen dosyanın denetimi:

- `Payload/Ktancraft.app/Ktancraft` → **Mach-O 64-bit arm64 executable**, 1.05 MB
- `CFBundleIdentifier: dev.ktanlabs.ktancraft`, `MinimumOSVersion: 16.0`, yalnız yatay
- `_CodeSignature` yok — dosya **imzasız**, imzalamayı sideload aracın yapar
- Toplam uygulama boyutu: 1.1 MB

Yeniden üretmek için: **Actions → Build unsigned IPA → Run workflow**.

## Doğrulama

`Tests/main.swift`, motoru saf Swift ile derleyip çalıştırır:

```bash
swiftc -O Core/*.swift Tests/main.swift -o ktancraft-tests && ./ktancraft-tests
```

Sonuç: **4490 kontrolün tamamı geçti** — dünya üretiminin belirlenimciliği, arazi katmanları,
su seviyesi, mağara/ağaç üretimi, greedy meshing'in yüz birleştirmesi ve indeks sınırları,
fizik (düşme, zıplama yüksekliği, duvara çarpma, uçuş), ışın izleme, blok kırma/koyma,
kayıt dosyasının gidiş-dönüşü, dokuların boyutu/opaklığı, chunk akışı ve malzeme anahtarları.

Ölçümler (Linux x86_64, 2 çekirdekli bulut VM, `-O`): arazi üretimi **~1.4 ms/chunk**
(16×96×16), mesh **~5 ms/chunk**. iPhone'da bunun altında kalması beklenir; yine de ilk
yüklemede chunk'lar kare başına 1–2 tane olacak şekilde akıtılır.

**Doğrulanmayan kısım:** bu ortamda macOS/Xcode yok, dolayısıyla `App/` katmanı (SwiftUI +
SceneKit + dokunma) cihazda derlenip çalıştırılmadı; yalnızca sözdizimi denetlendi ve gözden
geçirildi. İlk çalıştırmada küçük bir derleme düzeltmesi gerekebilir.

## Horizon hakkında

Bu depo, `horizon-rust/horizon` (Minecraft: Java Edition 26.3'ün Rust ile yeniden yazımı)
projesinin **kodu üzerine kurulmamıştır** ve onun bir çatalı değildir. Sebep teknik:

- Horizon ~1.57 milyon satır Rust'tır ve oyun varlıklarını **kendi Minecraft Java kopyandan**
  hazırlar (JDK 25 gerekir) — "bilgisayar gerekmesin" şartıyla bağdaşmaz.
- Rust'ı iOS'a derlemek macOS + Xcode ister; mağaza kısıtları ve Mojang varlıklarının
  yeniden dağıtılamaması ayrıca engeldir.

Ktancraft bunun yerine, aynı türden bir oyunu (voksel sandbox: kaz, inşa et, keşfet) iOS'un
kendi araçlarıyla, hiçbir varlık dosyası olmadan, cihazda üretilen dünyalarla sıfırdan kurar.
İsim ve marka: **Ktancraft — Ktan Labs**.

## Lisans

Bu depodaki özgün kod MIT lisansı altındadır. Ktancraft, Mojang veya Microsoft ile
ilişkili değildir; Minecraft, Mojang Synergies AB'nin ticari markasıdır.
