# Poz, karakter geometrisi ve saha taraması — 24 Eylül 2026

## Uygulama

- Locomotion sonunda ayak konumu, eklem değişmediyse tekrar okunmaz. IK çalıştıysa o ayağın dünya konumu yeniden alınır. İki ayağın sonucu mevcut diziye yazılır. Pelvis/oyuncu değişikliklerinin üzerinden veri taşınmaz.
- Top sürme pozunda pelvis ayarlandıktan sonra ters dünya dönüşümü iki bacak çözümü için paylaşılır. Bu iki işlem yalnız pelvisin çocuklarını değiştirir.
- Saha oyuncularının aynı malzemeli el, dirsek ve önkolu aynı mesh içinde çizilir. El düğümleri temas, kupa ve hakem bayrağı gibi bağlantılar için aynı dönüşümle korunur. Kaleci eldivenleri ve animasyonlu eklemler birleştirilmez.
- Pas devamı aramasında rakiplerin tahmini konumları ve ofsayt çizgisi bir kez çıkarılır. Veri yalnız bu eşzamanlı değerlendirmede yaşar; sonraki çağrı yeniden hesaplar. Aday sırası, eşikler ve puan formülleri korunur.

## Ölçüm

- Aynı durum/süreç, alternatif sıra, 8 çift karar ölçümünde: **754,57 → 667,75 µs** (yaklaşık %11,5 azalma). Bu toplam AI veya FPS değildir; bu turdan hemen önceki sürümle karşılaştırmadır.
- Test saha oyuncusunda mesh içeren nesneler **29 → 27**. 20 saha oyuncusunda toplam 40 çizim nesnesi azalır. Gerçek karede draw-call farkı görünürlük ve gölge geçişlerine bağlıdır.
- Sabit girdili poz mikro ölçümü **49,857 → 50,129 µs**: animasyon CPU hızlanması doğrulanmadı. Dönüşüm tekrarlarının azalması tek başına toplam poz süresinde ölçülebilir kazanç göstermedi.
- Genel maç FPS'i bu turda ölçülmedi; 120 FPS veya toplam yüzde kazanç iddiası yok.

## Doğrulama

- 360 koşu/top sürme pozu: eski/yeni eklem dönüşümleri, el noktaları ve ayak temas noktaları eşdeğer (`is_equal_approx`). Birleştirilen iki önkol/el grubunda üçgen sayısı ve üçgen köşe konumları da karşılaştırıldı: 0 başarısızlık.
- 24 AI senaryosu: seçilen karar, sıralama, puanlar ve top sürme önbelleği tam eşit; 0 başarısızlık.
- Temas 76/76; top sürme 5/5; hücum kararları 33/33; gerçek çizim ve canlı maç sunumu 53/53.
- Referanslar yalnız tests altındadır: `footballer_mesh_before.gd`, `locomotion_transforms_before.gd`, `carry_transforms_before.gd`, `dribble_transforms_before.gd`, `decisions_scans_before.gd`.
- Araçlar: `pose_mesh_reuse_check.gd`, `decisions_scans_check.gd`; çıktılar `pose-mesh-reuse.log`, `decisions-scans.log`.

Ortamda önceki shader önbelleği erişimi/sertifika deposu uyarıları sürüyor. Bazı headless kontroller çıkışta ObjectDB sızıntısı uyarısı veriyor; fonksiyonel kontroller başarısız olmadı.
