# Dünya sıralaması

Kariyerde **Lig & Kupalar → Dünya Sıralaması**, Efsane modunda **Lig & Fikstür → Dünya Sıralaması** üzerinden bütün 110 kulüp ve 10 lig görülebilir. Kulüp listesi onarlı sayfalara ayrılır; kendi kulübüne veya ligine doğrudan gitmek mümkündür. Oklar sezon başına göre sıra değişimini gösterir. Bunlar oyun dünyasının başarı sıralamalarıdır; gerçek dünyadan alınmış sıralamalar değildir.

## Başarı puanı

- Başlangıç puanı kulübün başlangıç itibarı ve ligin seviyesiyle belirlenir. Sonradan kadro değişmesi bu puanı sıfırlamaz.
- Oynanan ve simüle edilen maçlar aynı kuralları kullanır. Beklenmedik galibiyet daha fazla puan getirir; yenilen takım puan kaybeder. Beraberlikte favori küçük miktarda kaybedebilir.
- Elo beklentisi 400 puanlık ölçekle, normal maçlarda ev sahibine 45 puan avantajla hesaplanır. Kupa finalleri tarafsız kabul edilir. Penaltı atışları maçın beraberlik sonucunu değiştirmez.
- Lig maçı temel katsayısı 28'dir. Kısa fikstürler `sqrt(34 / max(14, maç sayısı))` ile dengelenir. Şampiyonlar Kupası katsayısı 40–52, yerel kupa 26, Süper Kupa 18'dir. Skor farkı bonusu en fazla %30'dur; dört golden sonra büyümez.
- Şampiyonlar Kupası, yerel kupa ve Süper Kupa şampiyonlarına sırasıyla 65, 30, 12; finalistlerine 25, 10, 4 ek puan verilir. Lig ilk üçü 35, 18, 10 kazanır; son üçü 8 kaybeder. İkinci ligde bu ödüllerin %70'i uygulanır. Her maç ve ödül yalnızca bir kez işlenir.
- Puanlar 900–2300 aralığındadır. Yeni sezonda başlangıca göre kazanılan veya kaybedilen puanın %96'sı korunur. Yükselen/düşen kulüp kimliğini ve geçmiş başarısını korur.

## Lig itibarı

Lig puanı, başlangıç seviyesi + kulüplerin ortalama başarı puanındaki değişimin %2,5'i + uluslararası katsayıdır. Toplam yerine ortalama kullanılır; daha fazla kulübü olan lig sırf daha çok maç oynadığı için yükselmez. Aynı lig içindeki maçlar toplam başarı puanını değiştirmez.

Şampiyonlar Kupası'nda farklı liglerden iki kulübün maçında katsayı değişimi `2,4 × (sonuç − beklenen sonuç) / ligin gerçek temsilci sayısı` olur. Sezonluk değişim ±6 ile sınırlıdır; yeni sezonda katsayının %94'ü korunur. Lig itibarı 30–96 arasında kalır. Sıralamanın yükselmesi kupa kontenjanlarını veya mevcut lig fikstürünü değiştirmez.

## Transfer etkisi

Kulüp itibarı, başlangıç itibarı + kazanılan başarı puanı / 12 olarak hesaplanır ve 35–96 aralığında tutulur. Transfer çekiciliği bunun %55'ini, en iyi 11 oyuncunun gücünün %45'ini ve `(lig itibarı − 70) × 0,18` lig etkisini kullanır.

Başarı, oyuncunun kulübe ilgi duymasını ve talep ettiği maaş primini etkiler. Satıcı kulübün kazanılmış itibarı oyuncunun piyasa değerine de yansır. AI transferleri, gelen teklifler ve kiralamalar aynı çekicilik hesabını kullanır. Yıldız oyuncuların nadir istisna kuralları, gerçek bütçe, maaş ve kadro rolü koşulları ile imzalanmış serbest kalma bedelleri korunur. Oyuncu özellikleri ve maç simülasyon güçleri sıralamayla yapay biçimde artırılmaz.

## Kayıt ve doğrulama

Puanlar, sezon başlangıç sıraları, lig katsayıları, işlenen maçlar ve ödül kayıtları kariyer dosyasında tutulur. Eski kayıtlar mevcut sezondaki oynanmış maçlar ve kayıtlı şampiyonluklardan taşınır; maaş, gelir, oyuncu gelişimi veya para ödülleri yeniden uygulanmaz. Önceki sezonların tam maç arşivi olmadığından bunlara geriye dönük puan hesaplanmaz.

`tests/world_rankings_check.gd` sonuçlar, denge, transfer etkisi, kayıt geçişi ve sezon sürekliliğini; `tests/world_rankings_ui_check.gd` iki kariyer modunda ekran ve kontrolcü akışını denetler. İkinci testin `-- --visual` seçeneği gerçek görüntüleri `/tmp/sefc-rankings-*.png` olarak kaydeder.
