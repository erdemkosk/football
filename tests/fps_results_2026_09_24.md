# FPS düzeltmesi — 24 Eylül 2026

Bu değişiklik çözünürlük, gölge, yağmur, tribün veya oyuncu modelini azaltmaz.
Fizik ve top teması 120 Hz olarak kalır.

## Uygulanan değişiklikler

- Destek koşularında rakip konumları aynı plan içinde bir kez okunur. Pas
  koridoru ve boş alan hesabı, aynı sonuç veren düzlemsel mesafe hesabını kullanır.
- Hücum yerleşiminde aynı hedefin pas güvenliği her aday oyuncu için tekrar
  hesaplanmaz. Ofsayt çizgisi plan başında okunur; mevcut canlı ofsayt kontrolü sürer.
- Baskı altındaki top sürmede rakiplerin üç tahmin zamanı bir kez hazırlanır;
  tüm yönler aynı tahminleri karşılaştırır. Karar puanları ve AI zorluğu değişmez.
- Aynı konum, hız, falso ve hava direnciyle istenen top uçuşu tekrar kullanılır.
  Sekme veya hız/falso değişikliği önbelleği hemen geçersiz kılar. Çağıran kodun
  tahmin dizisini değiştirmesi diğer sorguları etkilemez.
- Topun uzağındaki normal koşu ve hakem pozları çizilecek kare için hazırlanır.
  Vuruşlar, top kontrolü, kaleciler, mücadeleler, fren ve ayak basarak dönüşler
  fizik adımında kalır. Biriken animasyon süresi kaybolmaz. Tekrar kaydı pozları
  kaydetmeden önce tamamlar.

## Doğrulama

`fps_regression_check.gd` eski hesapların bağımsız referansını çalıştırır.
80 rastgele yerleşimde destek hedefleri/rolleri ve top sürme yönleri aynıdır.
İki ayrı ölçümde destek hesabı yaklaşık %60, baskı altında yön araması yaklaşık
%78 daha az CPU süresi aldı. Bu oranlar tüm oyunun FPS artışı değildir.

`render_pose_check.gd`, 120 Hz fizik sırasında 20 FPS çizim taklidiyle koşu,
sprint, dönüş ve frenlemeyi karşılaştırır. Stamina farkı sıfır; en büyük ayak
konumu farkı 6,8 mm. İki tam frekanslı oyuncuda da görülen 1,67 mm başlangıç
zemin yerleşme farkı ayrıca referans modunda doğrulandı.

AI hücumu, hücum kararları, animasyon sürekliliği, top sürme/vuruş, ikili
mücadele, tekrar, hakem, hava topu yardımı, kafa, vole ve performans güvenliği
regresyonları geçti. Yeni regresyon 10, poz testi 4 kontrol içerir.

## FPS ölçüm yöntemi

Godot 4.7.2, Vulkan Mobile, RTX 3070, 1440×900, render ölçeği 1, 120 Hz fizik.
VSync ve FPS sınırı yalnızca testte kapalıdır. Sabit FPS komutuyla ölçüm yapılmaz.
`fps_compare_benchmark.gd` aynı süreçte eski/yeni AI hesaplarını ve koşu poz
zamanlamasını değiştirir; ikinci turda sıra ters çevrilir. Isınmadan sonra
gündüz, gece ve yağmur sahnelerinde beşer saniyelik örnek alınır. Duran oyun
kareleri FPS hesabına dahil edilmez. 120 aktif kareden az örnek geçersiz işaretlenir.

Ara turlarda başka Godot testlerinin başlatıldığı gözlendi; bu eşzamanlı yük
fizik hızını da düşürdüğü için bu turlar teslim karşılaştırmasına alınmadı.
Teslim ölçümü tek karşılaştırma turudur (`-- --single`). Süreç denetimi bu
çalıştırmada başka Godot testi başlatılmadığını doğruladı; mevcut editör süreci
açık kaldı. Isınma örneği hariç altı örneğin tamamı aktif oyun ve geçerlidir.

| Sahne | Önce FPS | Sonra FPS | Artış | Önce p95 kare | Sonra p95 kare |
|---|---:|---:|---:|---:|---:|
| Gündüz | 56,26 | 69,49 | %23,5 | 25,47 ms | 17,04 ms |
| Gece | 32,05 | 50,58 | %57,8 | 46,56 ms | 23,90 ms |
| Gece + yağmur | 31,33 | 47,07 | %50,2 | 41,42 ms | 25,19 ms |

Fizik 119,95–120,43 Hz aralığında kaldı; maç yavaşlatılarak FPS kazanılmadı.
Bu ölçüm gece/yağmurda sabit 60 FPS sağlandığı anlamına gelmez. Farklı
çözünürlük, maç pozisyonu ve eşzamanlı uygulama yükü sonucu değiştirebilir.
Önceki yol, bu değişiklikteki AI planlama ve poz zamanlama iyileştirmelerini
geri alan test referansıdır; top uçuşu önbelleği iki varyantta da etkindir.

Ham veri: `performance-paired-fps.json`; çıktı: `fps-delivery.log`;
süreç denetimi: `fps-delivery-interference.log` (boş, çakışma yok).
Poz doğrulaması: `fps-pose-verified.log`; karar/önbellek doğrulaması:
`fps-confirmed-fps_regression_check.log`.
