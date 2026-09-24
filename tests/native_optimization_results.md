# C++ ve animasyon optimizasyonu — 24 Eylül 2026

## Sonuç

**Aktif 11'e 11 maçta bütün hava koşullarında sabit 120 FPS hedefi karşılanmadı.**
C++'ın bu hedefi tek başına sağlayacağı doğrulanmadı. Bu değişiklik görsel kalite,
ışık/gölge, çözünürlük, AI adayları/karar sıklığı veya 120 Hz fiziği azaltmaz.

Windows x86-64 için gerçekten derlenmiş ve oyunda çalışan C++ GDExtension eklendi.
Taşınan işler: havadan pasın ilk hızı, falsosuz top uçuşu örnekleme ve pas kesme
riski iç döngüsü. Aynı işlemlerin GDScript yolu diğer platformlarda ve DLL yokken
korunur. Mac üzerinde yeni ölçüm yapılmadı. Derleme ve paketleme ayrıntıları
`native/README.md` içindedir.

Koşu pozunda aynı düğümler bir defa alınır; eklemin birden fazla eksen değişikliği
aynı yerel vektörde hesaplanıp tek setter çağrısıyla yazılır. Hareket adımında
tekrarlanan enerji/ivme çarpanları paylaşılır. Dünya konumunu kullanan temas
işlemlerinin sırası değiştirilmez.

## Hesap eşitliği ve yerel süreler

| Deney | Kontrol | Sonuç | Önce → sonra |
|---|---:|---|---|
| Havadan pas / falsosuz uçuş | 54.000 | Tam eşit, 0 hata | İlk hız hesabı 24,50 → 2,66 µs |
| Tam pas değerlendirme sözlüğü | 4.800 | Tam eşit, 0 hata | 76,56 → 58,14 µs |
| Hareket, stamina, eklemler ve ayak | 16.800 | Tam eşit, 0 hata | Poz hesabı 63,71 → 57,93 µs |

Bu oranlar bütün oyunun FPS artışı değildir. Karşılaştırmalar eski/yeni sırayı
değiştirir. Top testi hava direnci, konum, hız, uçuş süresi ve örnek sayısını;
pas testi kuru/ıslak hava, zorluk, hareketli/gizli/ihraç edilmiş oyuncular,
alıcısız pas ve yerden/havadan rotaları içerir.

Falsolu uçuşu C++'a taşıyan ilk denemede üç noktada en fazla 0,000000715 metre
fark çıktı. O kod kaldırıldı; falsolu uçuş özgün GDScript hesabında kalır.
Native C++ derlemesinde fast-math ve FMA kapalıdır.

## Gerçek dağıtım sürümü FPS

Godot 4.7.2 resmi Windows release template, Vulkan Mobile, i5-13400F / RTX 3070,
1440×900, mevcut MSAA/ışık/gölge ayarları. VSync ve FPS tavanı yalnız testte
kapalı. Grafik testinde `--fixed-fps` kullanılmadı. Her örnekte 1,5 s ısınma
ve 5 s kayıt; duran oyun kareleri dışarıda. İki turda C++ açık/kapalı sıra ters
çevrildi. 12 örneğin tamamı 120'den fazla aktif kare içeriyor.

| Koşul | GDScript FPS, iki tur | C++ FPS, iki tur | C++ p95 kare süresi |
|---|---|---|---|
| Gündüz | 94,40 / 94,19 | 86,28 / 95,62 | 15,16 / 13,59 ms |
| Gece | 68,85 / 67,05 | 67,58 / 69,17 | 16,96 / 16,24 ms |
| Gece + yağmur | 63,39 / 60,92 | 63,05 / 60,89 | 17,07 / 19,15 ms |

Fizik bütün örneklerde yaklaşık 119,9–120,1 Hz. C++ **bu kısa canlı koşularda
tutarlı bir toplam FPS kazancı sağlamadı**; izole hesap kazanımları doğrulandı.
Canlı maçlar tam aynı kaydın oynatımı değildir; konum/görünür nesne sayısı ve
sistem yükü değişebilir. Sayılardan C++'ın genel olarak daha hızlı/yavaş olduğu
veya sabit 60/120 FPS garantisi çıkarılamaz. İstenen 120 FPS'in kare bütçesi
8,33 ms; gece p95 bunun yaklaşık iki katı.

Kaynak: `performance-native-release-final.json`. Geçici, ayrı proje oluşturma
aracı `tools/stage_release_benchmark.py`; üretim ana sahnesi ve export preset'i
değiştirilmez. Windows export eklentisi DLL'yi `native/bin/` altına kopyalar;
release çalıştırıcısında `debug=false`, `native=true` yüklemesi doğrulandı.
Son export günlüğünde betik parse hatası yok. İlk denemedeki benchmark girinti
hatası giderildi ve export/ölçüm yeniden yapıldı; ilk sayılar sonuç tablosunda
kullanılmadı.

Editör çalıştırıcısındaki önceki C++ karşılaştırması
`performance-native-paired.json` içindedir. Bu ayrı koşuda henüz son poz
optimizasyonu yoktu; editör/release farkının tamamı tek bir değişikliğe
atfedilemez.

## Davranış ve sunum testleri

`native-regressions.json`: 14 grubun tamamı geçti: top direnci, iniş, uzun havadan
pas, AI pas/dağıtım, AI hücumu, hücum kararları, hareket, ayak teması, top sürme
pozu, animasyon geçişleri, beden dili, tekrar, önceki FPS regresyonları ve
çizim pozu. Bunlar doğruluk testleri; sabit zaman adımı ile çalıştırıldılar,
FPS ölçümü olarak kullanılmadılar.

Uzun havadan pas testi eski anında fırlatma davranışını beklediği için hem
C++ açık hem kapalı dört kontrol başarısızdı. Test artık gerçek ayak temasını
bekliyor, gönderilen hızın önizlemeyle aynı olduğunu ve kuru/ıslak zeminde
fiziksel inişi doğruluyor. Her iki yolda 23/23 geçti; oyun değiştirilmedi.

Sunum testinde bir PNG yazımı başarısız oldu; çıktılar ayrı dosya önekiyle
yeniden alındı. Ayrıca eski 12 m 'kale çevresi' küresi tribünün ilk sıralarını
da içerdiği için rastlantısal yanlış hata üretiyordu. Test gerçek kale bölgesini
kontrol edecek ve bütün başlangıç parçacıklarını tribünde arayacak şekilde
düzeltildi. Tribün/parçacık üretim kodu değiştirilmedi.
Son gerçek Vulkan sunum koşusu **53/53 geçti** (`native-presentation-verified.log`).
Oyuncu ve gece ekran görüntüleri ayrıca gözle incelendi; test çıktıları
`native-verified-*.png` dosyalarındadır.

## Kalan darboğaz

İç içe animasyon profilinde oyuncu başına başlangıç pozu/hareket yaklaşık
24,3 µs, ayak yerleşimi 7,1 µs, geçiş 6,0 µs, bakış/tepki/kumaş 10,3 µs idi.
Bu ölçümler yeni yerel poz iyileştirmesinden öncedir; toplam maç süresi değildir.
Native pas döngüsü bu işlerin veya motorun çizim/gölge hazırlığının yerini almaz.
Kalan hedef için oyuncu pozlarının ve çizim hazırlığının daha kapsamlı yeniden
düzenlenmesi ve aynı kayıt üzerinde kare sürelerinin ölçülmesi gerekir. Bu
rapor oyunu 'tamamen optimize edildi' olarak ilan etmez.

Sandbox'ta shader cache kullanıcı dizini ve kök sertifika deposu uyarıları vardı.
Bazı headless testlerde çıkışta ObjectDB referans uyarıları da oluştu. Bunlar
gizlenmedi; export/oyun betiği yükleme başarısıyla karıştırılmadı.

Kaynak belgeler: [Godot C++ GDExtension](https://docs.godotengine.org/en/4.4/tutorials/scripting/gdextension/gdextension_cpp_example.html),
[native kütüphane export API'si](https://docs.godotengine.org/en/stable/classes/class_editorexportplugin.html#class-editorexportplugin-method-add-shared-object),
[resmi 4.7.2 dağıtımı](https://godotengine.org/download/archive/4.7.2-stable/).
