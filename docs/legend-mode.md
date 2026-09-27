# Efsane futbolcu kariyeri

Ana menüde **Efsane · Futbolcu Kariyeri** üzerinden açılır. Teknik direktör
kariyerinden bağımsız üç kayıt yuvası kullanır (`sefc_legend_1.save` vb.).

- Oyuncu 18 yaşında, mevkiye göre yaklaşık 50–58 genel güçle başlar. Ad,
  kulüp, on mevki, baskın ayak, boy, kilo ve görünüş seçilir. Maç süresi ve
  zorluk oluşturma sırasında ayarlanır.
- Yeni oyuncu yedektir. İstenirse kulübede geçen bölüm simüle edilerek
  planlanan giriş dakikasına ilerlenir; oyuncu sahaya normal değişiklikle girer.
- Kontrol kimliğe bağlıdır. Pas, otomatik oyuncu seçimi, santra, duran top ve
  penaltılar başka futbolcuya kontrol geçiremez. Normal pas tuşu (varsayılan S /
  Xbox A) topsuzken pas ister; takım arkadaşı açık bir pas yolu arar.
- İlk 11 için en az üç maç, 60 teknik direktör güveni, 5.5 form ve %65 kondisyon
  gerekir. Seçilen mevkideki rakiple güç farkı en fazla yedi olmalıdır.
  Öğrenilmiş ek mevkide üç puan uyum indirimi uygulanır. Mevkinin gerektirdiği
  özelliklerle güç hesaplanır; ana mevki puanı tek başına yeterli değildir.
- Her yedi kariyer gününde üç gerçek, altı denemelik antrenman yapılabilir.
  Not, özelliklere dağıtılan gelişim puanını belirler. Bir özellikte 100 puan
  birikmesi o özelliğe +1 verir. Gelişim 65, 75 ve 85 genel güçte yavaşlar;
  92 genel potansiyel ve 95 özellik sınırı vardır.
- Maç notu goller, asistler, tamamlanan paslar, müdahaleler, kurtarışlar,
  pozisyon disiplini, top kayıpları ve kartları değerlendirir. Gerçek oynanan
  süre, güven ve gelişim ödülünü ölçekler. Aynı maç/çalışma iki kez ödül vermez.
  Antrenman tek başına güveni 58'in üstüne çıkarmaz. Hareketsiz maçlardan
  olumlu güven ödülü alınmaz.
- Saha oyuncuları iki ek mevkiyi sırayla öğrenebilir. Bir mevki yaklaşık 6–8
  başarılı çalışma ister. Kaleci kariyerleri kaleci olarak devam eder;
  dağıtım antrenmanı kalecilik özelliklerini geliştirir. Emeklilikte istatistikler
  kayıtta kalır, yeni maç ve antrenman sona erer.

Oyuncunun özellikleri doğrudan mevcut maç oyuncusuna uygulanır. Teknik direktör
modunun pasif genç gelişimi kişisel kariyere ikinci kez ödül vermez. AI transfer
pazarı futbolcuyu kullanıcının haberi olmadan satamaz; sözleşmesi sezon geçişinde
korunur. Bu sürümde kullanıcıya yönelik transfer görüşmesi ekranı yoktur.

## Doğrulama

`tests/legend_career_check.gd`: başlangıç/gelişim dengesi, kayıt ayrımı, antrenman,
gerçek değişiklik, pas çağrısına cevap, duran top ve penaltı kontrolü, maç sonucu.

`tests/legend_roles_check.gd`: ilk 11, kaleci, kırmızı kart, öğrenilmiş mevki,
emeklilik kaydı.

`tests/legend_ui_check.gd`: ana menüden gamepad ile oluşturma ve kariyer akışı.
`-- --visual` ekran görüntülerini `/tmp/sefc-legend-*.png` olarak çıkarır;
`--compact` küçük pencereyi doğrular.

Örnek: `godot --headless --fixed-fps 60 --path . --log-file /tmp/legend.log --script tests/legend_career_check.gd`
