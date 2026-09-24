# Gece / orta saha kare süresi — 24 Eylül 2026

## Sonuç

Gece düşük FPS ve dalgalanma tamamen çözülmedi. Kalite, AI seçenekleri, fizik 120 Hz, çözünürlük, ışıklar ve gölgeler düşürülmedi. Bu tur yalnız sonucu değiştirmeyen pas riski erken çıkışı ve tribün shader parametrelerinin tek okuma ile dağıtılması uygulandı.

Pas riski 1 olduğunda kalan işlemler yalnızca en fazla 1 olan değerlerle maksimum alır. Sonuç zaten doymuş olduğundan sonraki örnekler aynı risk sonucunu değiştiremez. Diğer dönüş alanları (erişilebilirlik, varış marjı, ilk şerit riski) hesaplanmaya devam eder.

400 kuru/ıslak, hareketli oyuncu, yerden/havadan pas senaryosunda eski/yeni değerlendirme sözlükleri tam eşit (130 doymuş risk); 0 başarısızlık. Ortalama alt sistem süresi 99,045 → 89,295 µs (~%9,8). Gerçek pas/kaleci dağıtımı testi 43/43 geçti.

## Kamera konumunu ayıran ölçüm

1440×900, Vulkan Mobile, RTX 3070, VSync kapalı. Aynı sabit oyuncu yerleşiminde maç hesapları kapalı, yalnız kamera/top/kontrol edilen oyuncunun konumu değişiyor. 0,7 s ısınma + 2,5 s örnekleme; kısa ve yön gösterici bir teşhis, uzun süreli FPS garantisi değildir.

| Sabit kamera hedefi | Gündüz önce FPS | Gece önce FPS |
|---|---:|---:|
| z=-32 | 456,7 | 306,9 |
| Orta saha | 543,3 | 331,4 |
| z=32 | 496,5 | 305,7 |

Bu koşullarda orta saha çizimi daha yavaş değil. Kullanıcının canlı orta saha gözlemi, sabit kamerayla yeniden üretilemedi; karar/temas yükü veya canlı görünürlük değişimi ayrıca incelenmeli. Genel oyunda merkez daima hızlıdır sonucu çıkarılamaz.

Aynı kısa gece canlı testinde önce 52,87 FPS / p95 22,652 ms, sonra 54,58 FPS / p95 21,944 ms. Canlı maçlar tam aynı kaydı oynatmadığından küçük fark kesin genel FPS kazancı değildir. Son GPU ortalaması 3,70 ms, render CPU 3,38 ms, fizik monitörü kare başına 5,41 ms. Bu metrikler örtüşebilir; basitçe toplanmaz.

## Ayrı render thread denemesi

Yalnız komut satırıyla denendi, projeye kaydedilmedi. Godot deneysel özellik uyarısı ve boş doku güncelleme hataları verdi. Ayrıca benchmark'ın render sürelerini her kare sorgulaması bu modda senkronizasyon uyarıları üretti. Bu nedenle sayıları güvenilir iyileşme karşılaştırması olarak kullanılmadı ve ayar etkinleştirilmedi. Normal Safe modu korundu.

## CPU dağılımı

`night_cpu_profile.gd` yalnız bellekteki betik kopyasını sarar; üretim koduna profil dalı eklemez. 10 saniyelik canlı koşuda duran oyun evreleri de var (744 fizik çağrısına karşılık 86 AI çağrısı); ortalamalar yalnız aktif futbolun maliyeti olarak yorumlanmamalı. İç içe ölçümler toplanmaz.

| İş | Ortalama µs | p95 µs | Maksimum µs |
|---|---:|---:|---:|
| Ana fizik döngüsü | 3516 | 4419 | 7546 |
| Ana kare güncellemesi | 788 | 1709 | 3236 |
| AI çağrısı | 965 | 1433 | 2055 |
| Kamera | 63 | 78 | 152 |
| Stat skoru | 18 | 24 | 84 |

Kamera veya skor yazısı tek başına büyük düşüşü açıklamıyor. CPU simülasyonu ile gece çizim işinin birleşimi öncelikli sorun olarak kalıyor. Henüz sabit 60/120 FPS doğrulanmadı.

Ham dosyalar: `night-position-safe.log`, `night-position-final.log`, `night-cpu-profile.log`, `delivery-saturation.log`. Testler `night_position_profile.gd`, `night_cpu_profile.gd`, `delivery_saturation_check.gd`. Ortamdaki shader-cache erişim/sertifika uyarıları devam ediyor.
