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
regresyonları geçti. Yeni regresyon 10, poz testi 3 kontrol içerir.

## FPS ölçüm yöntemi

Godot 4.7.2, Vulkan Mobile, RTX 3070, 1440×900, render ölçeği 1, 120 Hz fizik.
VSync ve FPS sınırı yalnızca testte kapalıdır. Sabit FPS komutuyla ölçüm yapılmaz.
`fps_compare_benchmark.gd` aynı süreçte eski/yeni AI hesaplarını ve koşu poz
zamanlamasını değiştirir; ikinci turda sıra ters çevrilir. Isınmadan sonra
gündüz, gece ve yağmur sahnelerinde beşer saniyelik örnek alınır. Duran oyun
kareleri FPS hesabına dahil edilmez. 120 aktif kareden az örnek geçersiz işaretlenir.

Son tur sırasında başka Godot testlerinin başlatıldığı gözlendi; bu eşzamanlı
yük, fizik hızını da düşürdüğü için o tur karşılaştırma kanıtı sayılmaz.
Ham kayıt: `fps-paired-final.log`; süreç çakışması olmayan son turun kaydı
`fps-paired-clean.log`, ek süreç denetimi `fps-clean-interference.log`.
