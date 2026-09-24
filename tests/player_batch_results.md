# Oyuncu çizimi ve zemin hesabı optimizasyonu — 24 Eylül 2026

Oyuncu başına 15 ayrı, sabit geometrili parça aynı altı malzemeyi kullanan
tek skinned mesh altında toplandı. Bu **tek çizim çağrısı** demek değildir:
altı malzeme yüzeyi ayrı çizilir. Her köşe yalnız kendi eklemine bağlıdır;
geometri sadeleştirilmedi. Baskılı ve bükülen gövde, saç, yüz, göz, krampon,
kaptan bandı ve kaleci eldivenleri mevcut özel yollarında kalır.

Kaynak eklemler, ayak/el temas konumları, animasyon hesapları ve AI aynı kalır.
Yalnız çizilen köşelerin dönüşümü GPU skinning yoluna taşınır. Değişmeyen
kemik dönüşümleri tekrar gönderilmez. Eski 15 çizim düğümü sahneden ayrılır;
ölçüm için `--unbatched-players` ile geri açılabilir. Normal oyunda yeni yol
açıktır; headless simülasyon çizim nesnesi oluşturmaz.

Oyuncunun hareketinden önce değişmeyen çamur değeri hız, kirlenme ve tutuş
için bir kez hesaplanır. Hareketten sonraki ayak izi hesabı yeni konumdan
yeniden örneklenir; eski değer sonraki adıma taşınmaz.

## Ölçüm yöntemi

Windows, i5-13400F / RTX 3070, Godot 4.7.2 Mobile/Vulkan, gerçek release
export, 1440×900, VSync kapalı, FPS sınırı yok. AI iki takımı yönetir;
22 oyuncu aktiftir. Fizik 120 Hz'de kalır. Her koşuda 1,5 saniye ısınma,
5 saniye ölçüm; yalnız aktif oyun kareleri kabul edilir. Üç turda eski/yeni
sırası ters çevrilir. Isınma örneği sonuçlara dahil edilmez.

Karşılaştırmanın iki tarafında da mevcut C++ hesapları ve son zemin paylaşımı
açıktır; tablo oyuncu çizimi değişikliğinin etkisini ayırır. Aynı maç kaydının
birebir oynatımı değildir; sistem yükü ve maç akışı küçük farklar oluşturabilir.
Bu yüzden kısa tek koşu yerine üç tur ortancası raporlanır. MacBook üzerinde
ölçüm yapılmadı; buradaki sayılar bu Windows bilgisayarına aittir.

## Doğrulama

Nihai üç tur ortancası (`performance-player-batch-release-final.json`):

| Aktif 11'e 11 maç | Eski çizim FPS | Yeni çizim FPS | Artış | p95 kare süresi, eski → yeni |
| --- | ---: | ---: | ---: | ---: |
| Gündüz | 91,24 | 96,37 | %5,6 | 13,90 → 13,46 ms |
| Gece | 63,67 | 71,00 | %11,5 | 17,70 → 16,12 ms |
| Gece + yağmur | 60,13 | 64,96 | %8,0 | 17,92 → 17,21 ms |

18 örneğin tamamında en az 300 aktif oyun karesi ölçüldü; duraklama veya
duran top kareleri sonuçlara katılmadı. Fizik frekansı 119,87–120,04 Hz.
Gece çizim çağrısı ortancası yaklaşık 1335 → 801 (%40 azalma).
Önceki ayrı üç tur ölçümü de `performance-player-batch-release.json` içindedir:
gece 65,09 → 70,94, yağmur 58,34 → 64,70 FPS. İki koşuda da artış gözlendi;
kesin sabit bir yüzde veya bütün donanımlar için garanti çıkarılmaz.

**Sabit 120 FPS henüz sağlanmadı.** Son gece ölçümünde fizik yaklaşık
4,8 ms/adım, render CPU yaklaşık 2,83 ms/kare. Gece p95 16,12 ms;
120 FPS için gereken toplam kare bütçesi 8,33 ms. Bu değişiklik gerçek
bir iyileştirmedir; oyunun artık her koşulda 120 FPS olduğu iddia edilmez.

- `player_batch_check.gd`: oyuncu, kaleci ve hakemde 180 farklı poz/vücut
  ölçüsü; 449.400 köşe, sıfır hata. Üçgenler ve UV'ler korunur. En büyük
  dünya konumu farkı 0,000008544 m; aydınlatma normal vektörü farkı 0,00008525.
  Gerçek Vulkan skeleton dönüşümleri okunarak kontrol edildi. El/ayak temas
  noktaları birebir aynı.
- `player_batch_visual_check.gd`: aynı sabit yakın planın kuru ve ıslak
  önce/sonra görüntüleri. Kuru görüntüde kanal başına ortalama fark
  0,000013835 / 255; ıslakta 0,000004431 / 255. 16 seviyeden büyük fark yok.
  Görüntüler `batch-visual-*-before.png` / `batch-visual-*-after.png`.
- `player_surface_reuse_check.gd`: altı çamur bölgesi ve altı ıslaklık düzeyi,
  10.081 kontrol, sıfır hata. Konum, hız, stamina, kirlenme, gövde ve eklemler
  birebir aynı. İlgili üç örnekleme işi 3,60 → 1,46 µs; bu **toplam FPS**
  kazanımı değildir.
- Gerçek Vulkan sunum kontrolü: 53/53 geçti; oyuncu değişikliği, yakın plan,
  gece, ıslak temas, tribün ve canlı maç görüntüleri `batch-verified-*.png`.
- Hareket, ayak teması, top sürme, animasyon geçişi, beden dili, tekrar,
  çizim pozu ve önceki FPS regresyonları yeniden çalıştırıldı; hepsi geçti.
- `weather_check.gd`: tutuş, top yuvarlanması/sekmesi, çamur izleri,
  duraklatma ve tekrar dahil sıfır hata.

İlk tanı denemelerindeki sabit sahne ve ardışık farklı maç konumları genel
FPS sonucu olarak kullanılmadı. Nihai ölçüm ayrı release export içinde yapıldı.
Sandbox günlüklerinde shader cache / sertifika deposu erişim uyarıları vardır;
betik yükleme veya geometri testi hatasıyla karıştırılmadı. Bazı mevcut headless
maç testleri çıkışta ObjectDB referans uyarısı verir.

## Yeniden çalıştırma

`tools/stage_release_benchmark.py --player-batch` geçici bir release ölçüm
projesi hazırlar. Ana oyun sahnesi ve kullanıcı ayarları değiştirilmez.
`tests/player_batch_benchmark.gd` editör çalıştırıcısında da kullanılabilir;
onun sonuçları release sonuçlarıyla aynı tabloya karıştırılmamalıdır.

Grafikli FPS ölçümünde `--fixed-fps` kullanılmaz. Bu seçenek yalnız davranış
doğrulamalarında sabit simülasyon adımı için kullanılmıştır.
