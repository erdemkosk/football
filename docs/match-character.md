# Sahanın karakteri

Önerilen yedi ek özellik mevcut Godot maç akışına bağlandı. [12 karelik galeri](../artifacts/match-character/index.html) ve [birlikte gol sevinci videosu](../artifacts/match-character/team-celebration.mp4).

## Eklenen davranışlar

| Özellik | Oyundaki karşılığı |
| --- | --- |
| Oyuncu imzaları | Dört kalıcı hareket karakteri: çevik, güçlü, sakin, akıcı. Koşu salınımı, dirsek ve gövde duruşu; şut hazırlığı, karşılama ve giriş selamlaması farklılaşır. Kişisel gol sevinçleri korunur. |
| Çalım izleri | Dönüşte yay, elasticoda S, kısa kaçışlarda iki köşeli çizgi, top kaldırmada kemer. Her çalımda en fazla bir efekt, başarılı gerçek ayak temasından sonra çıkar. Sahte şut/pas ve reddedilen çalım efekt üretmez. |
| Direk tepkisi | Çarpma noktasında 0,18 saniyelik beyaz ışık; en yakın görünen direk parçasında 0,45 saniyede sönen küçük titreşim. Fizik çarpışma yüzeyi hareket etmez. |
| Golün çizgi anı | Gol tekrarında topun tamamının çizgiyi geçtiği kareye enterpolasyon ve 0,85 saniyelik duraklama. Golcü, vuruş anındaki hız ve kale merkezine yatay mesafe kartta gösterilir. |
| Kulüp girişi | Takım renkli iki tünel hattı, büyük kumaş pankartlar ve iki takımdan birer oyuncunun isim/numara/karakter kartıyla tanıtılması. |
| Takım arkadaşı tepkileri | Dokuz metreden uzun tamamlanan pasın ardından pas verenden kısa işaret; kaçan şutta yakındaki saha oyuncusundan destek; golcüyle yakın takım arkadaşının buluşup el çakışması. |
| Bölgesel tribün tepkileri | Tehlikeli atakta topun bulunduğu yönden başlayan, 24 bölüme yayılan beklenti; kaçan şutta taraftarların ellerini başlarına götürüp omuzlarını düşürmesi. |

## Yaşam döngüsü ve sınırlar

- İmza hareketleri temas bacağını veya oyuncu fiziğini değiştirmez. Sosyal tepkiler kontrolü kilitlemez; hareket ve topa müdahale ihtiyaçları önceliklidir. Pas işaretleri dört saniyelik beklemeyle sınırlandırılır.
- El çakışması oyuncular buluşma noktalarına vardığında başlar, 1,05 saniye sonra mevcut sevinçler devam eder. Golü geçme ve sahayı sıfırlama ortak hedefleri temizler.
- Çalım ve temas efektleri mevcut 28 kartlık havuzu kullanır. Tribün tepkileri mevcut örneklenmiş seyirci materyallerinde hesaplanır; her seyirci için yeni CPU animasyonu açılmaz.
- Girişte iki gölgesiz ışık kullanılır; tünel sunumu maç girişi dışında gizlenir. Giriş Space/Enter ile geçilebilir; duraklatma zamanını korur. Antrenman giriş sunumu çalıştırmaz.
- Azaltılmış hareket çalım izlerini, direk titreşimini ve ışık dalgalanmasını kapatır; tanıtım kamerası geniş planda kalır. Gol karesi bu ayarda 0,55 saniye, kısa sunum ayarında 0,38 saniye bekler.
- Gol karesi yalnızca gol tekrarındadır. Anlık tekrar etkilenmez; duraklatma bekleme süresini de dondurur. Tekrar bitişi canlı topun konum, hız ve donma durumunu geri yükler.
- Gol kartı hız olarak gerçek ilk vuruş hızını kullanır; çizgiyi geçiş hızını göstermez. Mesafe vuruş noktasından kale merkezine yatay uzaklıktır. Doğrulanabilir şut kaydı yoksa veya kendi kalesine golse hız/mesafe “—” olarak gösterilir.

## Doğrulama

Godot 4.7.2 üzerinde sekiz test grubunda 281 başarılı kontrol:

| Test | Sonuç |
| --- | --- |
| `match_character_check.gd` | 41 / 41 |
| `match_identity_check.gd` | 20 / 20 |
| `body_language_check.gd` | 37 / 37 |
| `player_personality_check.gd` | 56 / 56 |
| `ground_skills_check.gd` | 55 / 55 |
| `replay_comfort_check.gd` | 31 / 31 |
| `ceremony_check.gd` | 15 / 15 |
| `crowd_check.gd` | 26 / 26 |

Ek `goal_celebration_check.gd` grubunda iki kontrol başarısız: gol yiyen takımın santra pasıyla oyunu serbest bırakması ve gol sevincinden dönüşte oyuncu/top sürekliliği. Bu iki başarısızlık, değişiklik öncesi dosyalarla hazırlanmış ayrı proje kopyasında aynı şekilde tekrarlandı. Yukarıdaki 281 başarılı kontrole bu grup dahil edilmedi; mevcut santra sorunları bu çalışmada çözülmedi.

Başlıca yeni kontroller: erken veya yinelenen çalım efekti üretmeme, direk titreşiminde fizik yüzeylerini koruma, el çakışmasından kişisel sevince dönüş, giriş geçişlerinin temizlenmesi, gerçek vuruş ölçümleri, top yarıçapını hesaba katan gol karesi ve duraklatılan tekrar zamanının korunması. Başsız macOS çalıştırmalarında sistem sertifikası ve bazı testlerin çıkışında nesne/kaynak temizleme uyarıları da var; başarılı kontrol sayıları bu uyarıların giderildiği anlamına gelmez.

Metal/Mobile render ile 12 kare ve 42 karelik animasyon çekildi. Görüntüler tek tek incelendi; el hedefi, kaçan şut duruşu, destek işaretinin yönü, kart yerleşimi ve giriş ışıkları kontrol edildi. Galeri olayları ve kamera açıları çekim için hazırlanır. Gol kartı gerçek fiziksel vuruş kaydından üretilir. Video 1440 × 900, 24 kare/saniye ve 1,75 saniyedir.

```sh
godot --headless --path . --script tests/match_character_check.gd
godot --path . --script tests/match_character_gallery.gd
ffmpeg -y -framerate 24 -i /tmp/sefc-match-character/frames/celebration-%03d.png -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart artifacts/match-character/team-celebration.mp4
```
