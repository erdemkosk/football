# Performans incelemesi — 24 Eylül 2026

AI karar sıklığı, seçenekler, puan ağırlıkları, fizik 120 Hz ve görsel ayarlar korunuyor.

## Değişiklikler

- `attack_decisions.gd`: Bir `select` çağrısındaki seçenekler aynı baskı, yaklaşan rakip ve açık gol yolu değerlendirmesini paylaşır. Bağlam çağrı sonunda atılır; sonraki fizik adımında eski saha bilgisi kullanılmaz. `carry_target` çağrısının önbellek yan etkisi korunur.
- `motion_transition.gd`: Eklem rotasyonları dizisi her pozda silinip yeniden büyütülmez; mevcut diziye aynı quaternion değerleri yazılır. Geçiş süresi ve interpolasyon değişmez.

## Karşılaştırma ve doğrulama

`optimization_equivalence.gd`, değişiklik öncesi `optimization_decisions_before.gd` referansıyla 24 saha/hava/zorluk senaryosunda kararları, sıralanmış seçenekleri, puanları ve top sürme önbelleğini tam eşitlikle karşılaştırır: 0 başarısızlık. Alternatif sırayla 8 çift × 100 değerlendirmede orta örnek: önce 1425,73 µs, sonra 939,75 µs; yaklaşık %34 daha az süre. Bu yalnızca karar puanlama bölümüdür, tüm AI veya toplam FPS değildir.

Mevcut hücum karar testleri 33/33, animasyon sürekliliği testleri 13/13 geçti.

## Gerçek çizim

Godot 4.7.2, Vulkan Mobile, RTX 3070, 1440×900, VSync kapalı, fizik 120 Hz. Grafik benchmark'ında sabit FPS kullanılmadı. Her sahne 1,5 s ısınma + 5 s örnekleme.

| Sahne | Önce FPS | Son sürüm FPS |
|---|---:|---:|
| Sabit gündüz | 478,4 | 509,3 |
| Gündüz maç | 62,6 | 63,3 |
| Gece maç | 50,7 | 35,4 |
| Yağmurlu gece | 42,2 | 36,5 |

Sonuçlar toplam FPS artışını doğrulamıyor. Canlı maçlar aynı kayıt üzerinden oynatılmıyor; nesne sayısı ve sistem yükü değişiyor. Ara turda sabit gündüz de 335 FPS'e düştü. Gece/yağmur gerilemesi bu verilerle yalnızca kod değişikliğine bağlanamaz, fakat iyileşme olarak da sunulamaz. Eşleştirilmiş karar ölçümü daha dar ve güvenilir sonuçtur.

İlk grafik denemesinin son kısmı profil çalışmasıyla çakıştığı için ana önce–sonra tablosuna alınmadı. Ana kayıtlar `performance-optimization-baseline-clean.json` ve `performance-optimization-final.json`. Ayrıntılı ilk profil yalnızca yön göstericidir: oyuncu güncellemeleri yaklaşık 2,98 ms/adım, AI 1,06 ms/adım. Oyuncu profili çizime ertelenen bütün poz işini kapsamaz; toplam animasyon maliyeti olarak yorumlanmamalı.

Çalıştırmalarda ortam kaynaklı shader-cache erişim ve kök sertifika deposu uyarıları görüldü. Eşdeğerlik aracında çıkışta 2 ObjectDB örneği uyarısı da var; test başarısızlığı veya shader derleme hatası yok.

Sonraki büyük adım: aynı maç kaydını tekrar oynatan, fizik-adımı ve çizim-kare işini ayrı ölçen profil; oyuncu pozlarının ve render sunucusu güncellemelerinin bu kayıt üzerinde incelenmesi. Bu tur oyunun genel düşük FPS sorununu çözmüş sayılmaz.
