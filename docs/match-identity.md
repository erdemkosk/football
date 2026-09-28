# Maçın görsel kimliği

Oyunun mevcut Godot sahnesine bağlı görsel efektler ve ortak yayın grafikleri. Örnekler: [galeri](../artifacts/match-identity/index.html), [power shot videosu](../artifacts/match-identity/power-shot.mp4).

## Efektler ve tetikleyicileri

| Olay | Görünüm | Tetikleyici |
| --- | --- | --- |
| Power shot hazırlığı | Krampon altında daralan, parçalı turuncu ışık | Gerçek şut dolumu / hazırlanma süresi |
| Power shot | Turuncu parıltı, kısa temas halkası, parlak merkezli iz | Başarılı güçlü vuruş |
| Plase | İki ince turkuaz şerit | Gerçekten falso verilmiş normal şut |
| Kusursuz zamanlama | İnce altın halka | Başarılı temasta zamanlama katsayısı 1'in üzerinde |
| Hızlanma / çalım | Krampon hizasında iki kısa çizgi, çim veya su parçaları | İlk hızlanma, keskin yön değişimi veya yeni çalım |
| Kaleci teması | Beyaz parıltı ve ince halka; ıslak havada su parçaları | Eldiven–top teması |
| Gol | Takım renkli LED panolar, golcü isimli alt bant | Stadyumun gerçek gol olayı |

Yere yakın temas halkaları çim üzerinde açılır; havadaki temas halkaları kameraya döner. Şut, plase ve hızlanma izleri kısa süreli tutulur. Skor, güç göstergesi, gol bandı ve tekrar geçişi üç eğik çizgi ve kesik şerit motifini paylaşır.

## Sınırlar ve erişilebilirlik

- Efektler top ve oyuncu fiziğine yazmaz; kamera ayarlarını değiştirmez.
- 28 yeniden kullanılan temas/koşu kartı ve altı adet 10 parçacıklı yayıcı vardır. Normal koşu sürekli parçacık üretmez; hızlanma tepkisi 0,65 saniye beklemeyle sınırlandırılır.
- Top izi en fazla 32 noktadan ve 6 metreden oluşur. Tekrar, duraklama, topun yeniden konumlandırılması ve yeni temaslar eski izleri temizler.
- Azaltılmış hareket ayarı top ve krampon izlerini, parçacıkları, gol bandının kaymasını ve gol LED hareketini kapatır. Temas halkaları sabit boyutta söner.
- Menü ve tekrar sırasında canlı temas efektleri temizlenir. Duraklama görsel olay süresini dondurur.

## Doğrulama

Godot 4.7.2 üzerinde beş test grubu, toplam 198 başarılı kontrol:

| Test | Sonuç |
| --- | --- |
| `match_identity_check.gd` | 20 / 20 |
| `power_shot_trail_check.gd` | 21 / 21 |
| `advanced_play_check.gd` | 111 / 111 |
| `replay_comfort_check.gd` | 31 / 31 |
| `presentation_polish_check.gd` | 15 / 15 |

Ek `aim_contact_check.gd` testi, pas önizlemesi boşken `velocity` alanını okumaya çalıştığı için 13. satırda durdu. Aynı hata bu değişikliklerden önceki dosyalarla oluşturulan ayrı proje kopyasında da tekrarlandı; bu test geçen kontrol sayısına dahil edilmedi.

Metal/Mobile render ile yedi gerçek oyun karesi ve 54 karelik video çekildi. Görsel incelemede temas halkaları inceltildi ve yere yakın halkaların çim tarafından kesilmesi düzeltildi. Kamera ve olaylar çekim betiğinde inceleme için hazırlanır; görüntüler oyunun gerçek modelleri, fizik sistemi ve efektlerinden gelir. Video 24 kare/saniyede 2,25 saniyedir.

Örnekleri yeniden üretme:

```sh
godot --path . --script tests/match_identity_gallery.gd
ffmpeg -y -framerate 24 -i /tmp/sefc-match-identity/frames/power-%03d.png -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart artifacts/match-identity/power-shot.mp4
```
