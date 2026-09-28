# Saha aşınması ve kaleci toparlanması

[Örnek galeri](../artifacts/turf-keeper/index.html) · [Kaleci animasyonu](../artifacts/turf-keeper/keeper-recovery.mp4)

## Saha

Mevcut kısa ömürlü taban/kayma izlerine maç boyunca kalan bir yüzey belleği eklendi. Gerçek ayak basışı, vuruş sırasında destek ayağı, kayma ve yere inen kalecinin hareketi temas ettikleri bölgede iz biriktirir. Dar top izleri daha düşük ağırlıkla katkıda bulunur. Yoğun kullanılan kale önü böylece yerel olarak aşınır; dokunulmayan bölgeler aynı miktarda eskimez.

Çim ezilmesi ve kopmuş çim iki ayrı kanalda saklanır. Yağmur mevcut toprak izini koyulaştırır, yeni temasın izini güçlendirir. Çim yüzeyinin ince kabarıklığı aşınan yerde azalır; çizgi boyası sınırlı miktarda yıpranır ve okunabilir kalır. Taze krampon izlerinde taban dişleri, kaymalarda düzensiz kenarlar vardır.

- Yüzey belleği `384 × 544 RG8`: yaklaşık 408 KiB görüntü verisi ve aynı boyutta GPU dokusu. Kirlenen doku en fazla saniyede dört kez yüklenir.
- Mevcut 3072 iz örneği havuzu korunur. Bu havuz eski izleri yeniden kullansa veya taze izler sönse bile çimdeki birikmiş aşınma kalır.
- Yeni maçta bellek temizlenir. Duraklatma ve tekrar oynatma yeni temas yazmaz. Yağmurun durması aşınmayı silmez.
- Aşınma katmanı görseldir; top direnci veya oyuncu tutunması için ek fizik katsayısı getirmez. Mevcut yağmur/çamur fiziği devam eder.
- Tekrar, mevcut maçın saha durumunu gösterir; aşınma dokusu geçmiş karelere ayrı ayrı kaydedilmez.

## Kaleci

Dalış yere temas ettikten sonra kısa bir fiziksel kaymayla söner. Yağmurda bu sönme biraz uzar. Havada yeni bir erişim alanı veya otomatik kurtarış eklenmez. Kurtarış kararı mevcut okuma, eldiven mesafesi ve top hızı kurallarıyla verilir.

Tutulan top, temas noktasından gövdenin önündeki taşıma noktasına geçer. Eldeki mevcut fiziksel top bu hedefi izler; animasyon topun konumunu doğrudan değiştirmez. Serbest el yere dayandığında top iki elin ortalamasına bağlanmadığı için zemine çekilmez.

Toparlanırken alttaki kol ve yük alan diz dalış yönüne ve kalecinin baktığı yöne göre seçilir. Avuç açılır ve çime paralel döner. Alçak top kapatmada kalça alçalır, dizler katlanır; el desteğinin ardından hazır duruşa dönülür. Elden dağıtım ve topu yere bırakma, bu tutuşu normal şekilde bitirir.

Top yeterince uzaktayken ve hızlı bir şut tehdidi yokken kaleci savunmadaki mevcut bir takım arkadaşına kısa işaret yapar. Jest en az yedi saniye aralıkla tetiklenir; top yaklaşınca veya hızlı gelince hemen iptal edilir. Oyun duruşları ve yeni maç geçişleri bu durumu temizler.

## Doğrulama

Godot 4.7.2 üzerinde davranış testleri:

| Test | Başarılı kontrol |
| --- | ---: |
| `turf_keeper_check.gd` | 39 |
| `weather_check.gd` | 19 |
| `keeper_handling_check.gd` | 22 |
| `high_save_contact_check.gd` | 8 |
| `keeper_possession_check.gd` | 56 |
| `keeper_balance_check.gd` | 18 |
| `keeper_readiness_check.gd` | 5 |
| `motion_contact_check.gd` | 76 |
| **Toplam** | **243** |

Yeni kontroller gerçek ayak basışlarını, hareketsiz oyuncunun iz üretmemesini, yerel aşınmayı, yağmur farkını, iz havuzu yenilendiğinde kalıcılığı, fiziksel kaymayı, duraklatma/tekrar korumalarını ve yeni maç temizliğini kapsar. Kaleci iki takımda ve iki dalış yönünde kontrol edilir; alçak top toparlanması, tutuşun korunması, dağıtıma dönüş ve savunma jestinin iptali de sınanır.

Sabit dalış örneğinde inişten sonraki kayma kuru zeminde yaklaşık 0,42 m, yağmurda 0,59 m ölçüldü. Tam destek anında avuç merkezi zeminden yaklaşık 5,5 cm yukarıdadır; eldiven geometrisi zemine oturur. Bu değerler örnek dalışa aittir, bütün kurtarışlar için sabit mesafe değildir.

Ek `wet_turf_shader_check.gd` render kontrolü geçti: kuru görünüm ve dört yağmur geçişi doğrulandı. Son galeri renderında script veya shader derleme hatası görülmedi. Başsız macOS çalıştırmalarında mevcut sistem sertifikası ve bazı testlerin kapanışında nesne temizleme uyarıları görülebilir; yukarıdaki sayılar davranış kontrollerinin sonucudur.

Dokuz oyun karesi tek tek incelendi; kaleci videosu 1440 × 900, 60 kare, 30 kare/saniye ve 2 saniyedir. Kamera, saha trafiği ve kurtarış sonrası tutuş çekim için hazırlanmıştır. Galeri bir maçın tamamını simüle etmiş gibi sunulmaz.

```sh
godot --headless --path . --script tests/turf_keeper_check.gd
godot --path . --script tests/turf_keeper_gallery.gd
ffmpeg -y -framerate 30 -i /tmp/sefc-turf-keeper/frames/recovery-%03d.png -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart artifacts/turf-keeper/keeper-recovery.mp4
```
