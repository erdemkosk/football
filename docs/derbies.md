# Derbiler ve taraftar kimliği

110 kulübün tamamının en az bir karşılıklı ezeli rakibi vardır. Rekabetler kulüp kimliğiyle eşleşir; isim değişikliği, küme düşme veya yükselme bunları değiştirmez. Eski kayıtlar yüklenirken eksik rekabet ve taraftar bilgileri tamamlanır. Oyuncuların özellikleri ve maç sonuçları için gizli bir derbi çarpanı kullanılmaz.

Hızlı maçta kendi takımını seçtikten sonra **EZELİ RAKİBİ GETİR** düğmesi ana rakibi getirir. Rakibi onayladıktan sonra normal kadro ve maç akışı devam eder. Düğmeye fare, klavye ve kontrolcüyle ulaşılabilir. Kariyer merkezi, fikstür etiketleri ve Efsane modu yaklaşan derbiyi işaretler; lig ve kupa karşılaşmaları aynı rekabet haritasını kullanır.

Her kulübün renklerinden, armasından ve sabit kimliğinden türetilen bir taraftar profili bulunur: tribün adı, slogan, kumaş deseni ve mevcut tezahürat kayıtlarının sırası/temposu. Yeni ses kaydı eklenmez. Derbilerde:

- Açılış kamerası tribündeki takım renkli koreografiyi gösterir; törenin toplam süresi uzamaz ve mevcut atlama tuşları çalışır.
- İki kumaş, saha dışında açılır ve açılış sonrasında toplanır. Devre arasında tekrar açılmaz. Azaltılmış hareket ayarında dalgalanma ve tribün kamera geçişi kullanılmaz.
- Taraftar desteği artar; tezahürat ve davul aralıkları kısalır. Tezahüratlar üst üste binmek yerine birbirini bekler. Gol ve kurtarış tepkileri güçlenir; deplasman golünde ana tribün susar.
- Kariyerde kullanıcı oyuncuları dizide ilk sırada olsa da tribün renkleri ve baskın sesler gerçek ev sahibine aittir.
- Ses kapatma, ses seviyesi, duraklatma, kısa sunum ve antrenman ayarları korunur. Sonraki normal maç, önceki derbinin atmosferini devralmaz.

Rekabet çiftleri `scripts/rivalries.gd` içindeki `PAIRS` tablosundadır. Birden fazla rakibi olan kulüplerde ilk eşleşme hızlı maç düğmesinin getirdiği ana rakiptir. Atmosfer yoğunluğu 0–1 arasındaki `heat` değeriyle belirlenir.

## Doğrulama

```sh
godot --headless --path . --log-file /tmp/derby-engine.log --script tests/derby_check.gd
godot --headless --path . --log-file /tmp/derby-ui-engine.log --script tests/derby_ui_check.gd
godot --path . --log-file /tmp/derby-visual-engine.log --script tests/derby_ui_check.gd -- --visual
```

İlk test veri kapsamını, eski kayıtları, ses/tribün tepkilerini, deplasman eşleşmesini ve atmosferin sıfırlanmasını sınar. İkincisi gerçek kontrolcü olaylarıyla rakip seçer, derbiyi başlatır ve iki kariyer modundaki akışı doğrular. Görsel çalıştırma `/tmp/sefc-derby-*.png` dosyalarını üretir; test kayıtları da `/tmp` altında kalır.
