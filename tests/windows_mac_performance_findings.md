# Windows / Mac performans incelemesi — 24 Eylül 2026

## Doğrulanan Windows koşulları

- CPU: Intel Core i5-13400F, 16 mantıksal işlemci.
- GPU: NVIDIA RTX 3070, sürücü 610.88.
- Windows güç planı: Yüksek performans. Değiştirilmedi.
- Godot 4.7.2; 1440×900; VSync kapalı; FPS sınırsız; fizik 120 Hz.
- Kullanıcının açık Godot süreci (PID 16892) kapatılmadı. Bir 3 saniyelik örnekte tek çekirdeğin yaklaşık %11'i kadar CPU kullandı; sonraki örnekte başlıca tüketiciler arasında değildi. Bu, sürekli ağır yük veya farkın ana nedeni olduğunun kanıtı değildir.
- GPU bir çizim denemesi sırasında P0 / 1845 MHz / 63°C durumuna çıktı. Sürekli düşük güç durumuna kilitlenmiş olduğuna dair kanıt yok; bu örnek termal sınır incelemesi değildir.

## Bölümleri durdurarak teşhis

`fps_bottleneck.gd`, yağmurlu gece. Bunlar optimizasyon/oynanabilir FPS sonuçları değildir: simülasyon durdurmak oynanışı kaldırır. Devam eden maçın konumu ve görünür nesneler de değişir.

| Durum | Vulkan Mobile FPS | D3D12 Mobile FPS |
|---|---:|---:|
| Aktif maç, ilk örnek | 43,1 | 53,1 |
| Ana maç fizik döngüsü durdurulmuş | 137,5 | 129,4 |
| Ana kare döngüsü de durdurulmuş | 282,8 | 287,2 |
| Aktif maç, son örnek | 63,0 | 63,5 |

Aktif maçta ölçülen GPU süresi Vulkan'da yaklaşık 3,4–3,6 ms; D3D12 Mobile'da 3,85–3,87 ms. Genel kare süreleri daha yüksek. CPU maç/oyuncu güncelleme ve çizim hazırlığı öncelikli inceleme alanlarıdır. Godot'un fizik monitörü kare başına maliyettir, tek 120 Hz adım maliyeti değildir.

Yalnız sürücüyü değiştirerek 120 FPS elde edilmedi. İlk D3D12 denemesi otomatik Forward+ seçti; eşdeğer kıyas için ayrıca açıkça Mobile seçilerek tekrarlandı. Kalıcı sürücü veya kalite ayarı değiştirilmedi. İki canlı koşu tam deterministik olmadığından D3D12 için yüzde kazanç iddiası yok.

Shader önbelleği kullanıcı klasörüne erişim uyarısı var; kısa testlerde ısınma/derleme etkisi olasılığı dışlanmadı. Kök sertifika deposu uyarısı da mevcut. Bunların FPS farkını tek başına açıkladığı gösterilmedi.

## Mac için kesinleşmeyenler

Kullanıcı M4 Pro'da aktif 11'e 11 maçta sabit 120 FPS gördüğünü doğruladı. Mac'e araç erişimi olmadığı için aynı kaynak sürümü, build türü, çözünürlük, saat/hava, renderer ve kare zamanları doğrulanamadı. Mevcut FPS HUD kodu çizim karelerini sayıyor; fizik 120 Hz değerini FPS olarak göstermiyor. ProMotion/VSync 120 tavanı olasıdır fakat aktif maçın 120 FPS üretmesini tek başına açıklamaz.

Platform/CPU farkının payını ölçmek için aynı proje sürümünde:

```sh
godot --path . --script tests/platform_performance.gd -- --label=mac-m4pro
```

Bu araç aynı mevcut benchmark'ı 1440×900, sınırsız FPS, VSync kapalı çalıştırır; cihaz, motor/build ve renderer bilgilerini ayrıca yazdırır. Grafik benchmark'ında `--fixed-fps` veya `--headless` kullanılmamalı. Windows'ta aynı komuta `--label=windows-platform` verilebilir. Sonuç `tests/performance-<label>.json` olur. Normal kullanıcı ayarlarına kaydetmez.

Kaynaklar: [Godot renderer özellikleri](https://docs.godotengine.org/en/stable/about/list_of_features.html), [M4 Pro MacBook Pro ekran özellikleri](https://support.apple.com/en-ie/121553).
