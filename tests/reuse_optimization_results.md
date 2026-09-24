# Hesap ve veri tekrarlarını azaltma — 24 Eylül 2026

Bu tur AI karar sıklığını, seçenekleri, fizik hızını veya görsel ayrıntıyı azaltmaz.

- Karar değerlendirmesinde kaleci hariç baskı ve tehdit bilgisi aynı çağrı boyunca paylaşılır. Pas hedefinin şut kalitesi bir seçenekte tekrar hesaplanmaz. Sonraki değerlendirmeye saha verisi taşınmaz; top sürme önbelleğini güncelleyen çağrı korunur.
- Yer gölgesi/ıslak yansıma güncellemesinde oyuncu ve hakem dizileri birleştirilmez. Her oyuncu için sekiz iç içe parça dizisi ve sabit yerel dönüşümler yeniden üretilmez. Sekiz elemanlı çalışma dizisi tekrar kullanılır; eklem referansları her oyuncuda yenilenir.
- Aynı MultiMesh yuvasının rengi, görünür örnek sayısı, yansıma görünürlüğü ve shader ıslaklık/saat değeri değişmediyse tekrar gönderilmez. Karşılaştırmalar tam eşitlik kullanır; eşik nedeniyle küçük değişimler atlanmaz. Hareketli parça dönüşümleri her güncellemede gönderilmeye devam eder.

## Eşleştirilmiş CPU ölçümleri

Her karşılaştırma aynı süreçte, sıra dönüşümlü 8 çift ölçüm; raporlanan süre sıralanmış örneklerin ortadaki üst değeridir. Bunlar alt sistem süreleridir, genel FPS kazancı değildir.

| Bölüm | Önce µs | Sonra µs | Azalma |
|---|---:|---:|---:|
| Kuru zemin yer gölgeleri | 85,84 | 77,065 | %10,2 |
| Islak zemin yer gölgeleri ve yansımalar | 265,135 | 177,81 | %32,9 |
| Karar seçeneklerini puanlama | 1020,36 | 878,87 | %13,9 |

Yansıma ölçümü sabit yerleşimde tekrarlanan 200 güncelleme içerir; hareketli maçın tüm performansını temsil etmez. Karar karşılaştırması bu turdan hemen önceki kodla yapılmıştır; önceki %34 sonucuyla toplanamaz.

## Doğrulama

- Gerçek Vulkan Mobile renderer üzerinde 18 kuru/ıslak, değişen görünürlük, renk, konum ve poz senaryosu; 3118 görünür örneğin dönüşümü/rengi eski sürümle tam eşit. Görünürlük, örnek sayısı ve shader saat/ıslaklık değerleri de karşılaştırıldı: 0 başarısızlık.
- 24 AI senaryosunda karar, sıralı seçenekler, puanlar ve top sürme önbelleği aynı: 0 başarısızlık.
- Mevcut hücum kararları: 33/33. Gerçek çizimle maç sunumu ve canlı ıslak maç: 37/37.

Referans dosyaları `presence_before.gd` ve `decisions_reuse_before.gd` yalnız test içindir. Tekrar çalıştırma: `godot --path . --script tests/presence_reuse_check.gd` ve `godot --headless --path . --script tests/decisions_reuse_check.gd`.

Bu turda genel FPS benchmark'ı yapılmadı. Çalıştırma ortamında daha önce görülen kullanıcı shader önbelleği erişimi ve sistem sertifika deposu uyarıları sürüyor.
