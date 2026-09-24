# Performans incelemesi — 23 Eylül 2026

Sonraki CPU ve animasyon düzeltmeleri ile çakışmasız FPS karşılaştırması:
[24 Eylül sonuçları](fps_results_2026_09_24.md).

Maçın tekrarlanan CPU hesapları azaltıldı. Fizik 120 Hz; oyuncu ölçeği, hız,
şut/pas kuvveti, AI zorluğu, çözünürlük, gölgeler, tribün ve yağmur kalitesi korunuyor.

- Destek oyuncularının mekânsal planı 50 ms boyunca tekrar kullanılabiliyor.
  Top sahibi, görünür/ihraç edilen oyuncular, taktik veya top konumu değişince
  erken yenileniyor. Ofsayt çizgisi ve duvar pası koşularının ömrü her fizik
  adımında denetleniyor.
- Pas tahmininde aynı sonuç tekrar çözülmüyor; durağan hedefte sabit noktaya
  ulaşıldığında döngü bitiyor. Yuvarlanma süresinin 13 adımlı çözümü aynı kalıyor.
- Pas güvenliğinde oyuncu konum/hızları bir değerlendirme içinde okunuyor.
  İlk şerit riski ayrıca korunuyor; zamana bağlı araya girme denetimleri ve
  eylemlerin puan ağırlıkları değişmiyor.
- Taktik ayrıntısı için her okumada dokuz alanlı sözlük üretilmiyor.
- Kuru sahada sıfır çıkacağı bilinen çamur hesabı atlanıyor; top direncinin iki
  bileşeni aynı çamur örneğini kullanıyor.
- Forma kiri her fizik adımında birikiyor; malzeme aktarımı ancak renk farkı
  %0,05'e veya ıslaklık farkı %0,1'e ulaştığında yapılıyor. Açık forma
  güncellemesi ve yeni forma sıfırlaması anında işleniyor.
- Değişmeyen dik çarpışma kapsülü yeniden fizik sunucusuna gönderilmiyor.
  Dalış şekli, kemik animasyonu ve ayak/el/top temasları aynı sıklıkta kalıyor.

## Grafik ölçümü

Aynı süreçte, aynı yerleşimde, sırayı dönüşümlü değiştirerek yapılan 8 çift
ölçümde destek planını her adımda yeniden hesaplamak 1.344 µs/adım, planı
koşulları geçerliyken tekrar kullanmak 279 µs/adım sürdü (medyan; yaklaşık
%79 daha az CPU süresi). Bu **yalnızca destek planlamasının** maliyetidir,
oyunun tamamında %79 FPS artışı anlamına gelmez. Ham kayıt:
`performance-planning.json`; komut seçeneği `--planning`.

Godot 4.7.2, Vulkan Mobile, RTX 3070, 1440×900, ölçek 1, VSync kapalı.
`performance_benchmark.gd` her sahnede 1,5 saniye ısınma ve 5 saniye gerçek
duvar saati örneklemesi kullanır. Grafik çalıştırmada `--fixed-fps` ve
`--disable-render-loop` kullanılmaz. Kamera, oynayan iki AI takımı, hava ve
ışık gerçek oyun sistemleridir; kareler aynı kayıt üzerinden oynatılmadığı
için canlı maçta görünen nesne sayısı ve pozisyonlar değişebilir.

| Sahne | İlk ölçüm FPS | Pass 3 | Görsel kontrol turu | Son tur |
| --- | ---: | ---: | ---: | ---: |
| Sabit gündüz | 447,7 | 426,8 | 489,1 | 328,4 |
| Gündüz maç | 44,3 | 66,2 | 64,8 | 45,7 |
| Gece maç | 29,5 | 41,1 | 28,0 | 28,7 |
| Yağmurlu gece | 22,3 | 34,8 | 30,3 | 18,9 |
| Sabit uzak stat | 207,1 | 170,5 | 179,5 | 148,1 |

Sonuçlar sabit sahnede de dalgalanıyor. Ayrıca çalışma sırasında ses varlıkları
güncellendi ve yeniden içe aktarıldı. Bu veriler tek bir kesin FPS artış yüzdesi
veya sabit 60/120 FPS iddiasını desteklemiyor. Özellikle gece/yağmurda yüksek FPS
hedefi henüz doğrulanmış değil. İlk ölçümde GPU süresi yaklaşık 1–3 ms iken canlı
maç yükünün büyümesi, CPU tarafındaki tekrarları önceliklendirmeyi destekledi.
Fizik monitörünün kare başına süresi tek bir 120 Hz adımın maliyeti sanılmamalı.

Ham kayıtlar: `performance-before.json`, `performance-pass3.json`,
`performance-after.json`, `performance-final.json`. Görsel kontrol için
`performance-after-day-match.png` ve `performance-after-rain-match.png` kullanıldı.

## Tekrar çalıştırma

```powershell
godot --headless --editor --path . --import
godot --path . --script tests/performance_benchmark.gd -- --label=local
godot --headless --path . --disable-render-loop --script tests/performance_benchmark.gd -- --cpu --label=cpu-local
godot --headless --path . --fixed-fps 120 --disable-render-loop --script tests/performance_safety_check.gd
```

FPS ölçümü sırasında başka test süreci çalıştırılmamalı. `--capture` ekran
görüntülerini ölçüm penceresinin sonunda kaydeder. Kullanıcının kayıtlı ekran
ayarlarına yazılmaz. `performance_profile.gd` yalnızca bellekte kopyalanan
betikleri ölçer; üretim maç döngüsüne profil kodu eklemez.

Görsel malzeme/MultiMesh renk okumaları için `match_presentation_check.gd`
gerçek çizim açıkken çalıştırılır; headless Dummy renderer renk verisini
doğrulamak için uygun değildir.

## Davranış doğrulaması

365 kısa/odaklı kontrol geçti: performans güvenliği (17), takım kimliği (36),
AI hücum (37), pas/kaleci dağıtımı (43), rakip kararları (53), top direnci (15),
nişan/temas (9), forma/vücut (30), hareket/temas (76), kaleci dengesi (18),
gerçek çizimle maç sunumu (31). Performans güvenliği ayrıca 147 kuru/ıslak/çamur
örneğinde eski yuvarlanma çözücüsüyle eşdeğerliği sınar. Kaleci denge testinin
eşitlik senaryosu, farklı kulüp özelliklerini eşitleyerek taraf avantajını
ölçer; oyun kalecilerinin gerçek özellikleri değiştirilmez.

Canlı maç akışı da 28/28 geçti; toplam **393 kontrol, 0 başarısızlık**.
Normal ve zor zorlukta birer dakika aktif futbol, duran toplar, kuru/ıslak
zeminde hareketli alıcı ve duvar pası sınandı. Normal maçta 24, zor maçta 29
fiziksel vuruş teması oluştu; iki senaryoda da boşa çıkan temas sayısı sıfırdı.
Sonuç: `perf-ai_match_flow_check.log`.
