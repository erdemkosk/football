# Transfer görüşmeleri

Teknik direktör kariyerinde **Kulüp → Gelen transfer teklifleri → Pazarlık yap**
oyuncuya gelen bonservis teklifini açar. Mevcut kulüp teklifini, piyasa değerini,
son karar tarihini ve görüşme geçmişini birlikte gösterir. Karşı bonservis
istenebilir, kulübün son teklifi kabul edilebilir veya reddedilebilir. Kiralık
teklifler mevcut sözleşme akışını kullanır.

Kulüpler haftalık olarak satış listesinde olmayan, kadrolarını geliştirebilecek
oyuncularla da ilgilenir. Teklif tavanı değer, mevki ihtiyacı, transfer bütçesi ve
imza sonrası iki aylık maaş rezerviyle sınırlıdır. Aynı talebi tekrarlamak fiyatı
artırmaz; üç başarısız turda alıcı çekilir. Aynı kulüp aynı oyuncu için 14 gün
yeniden teklif vermez. Satış tamamlanınca diğer teklifler kapanır. Görüşme
sırasında para ödenmez; imza anında bütçe, kadro ve oyuncu rızası yeniden kontrol
edilir. Satış payları gerçek bonservisten ödenir.

Oyuncu satın alırken satıcı kulüp makul tekliflerde küçük bir indirim yapabilir:
satış listesinde %6'ya, normal oyuncuda %2'ye, 80+ güçte %0.5'e kadar. Rakip
kulübün teklifi alt sınırı korur. Son fiyat ve pazarlık denemeleri kayda yazılır;
ekranı yeniden açmak veya kaydı yüklemek görüşmeyi sıfırlamaz. Bir görüşme yedi
gün geçerlidir; süresi dolan anlaşma imzalanamaz. Yıldızların küçük kulüplere
gitme isteği ve olağanüstü ücret beklentisi korunur.

Efsane kariyerinde **Teklifler** sekmesi maaş, imza parası, 1–5 yıl sözleşme ve
beklenen rolü birlikte görüşür. Güncel kulüp teklifi ile oyuncunun henüz
göndermediği talep ayrı gösterilir; imza düğmesi kulübün güncel teklifini kabul
eder. En fazla üç karşı teklif sunulur. Kulüp maaş tavanı ilk teklifin yaklaşık
%30 üstüdür; ayrıca gerçek oyuncu gücüne göre maaş üst sınırı vardır. Sık kulüp
değiştirmek maaşı sınırsız katlamaz. İmza parası da garantili gelir sınırına dahildir. İyi
performans, mevcut güç ve oynanan süre teklif getirir; potansiyel tek başına
üst düzey kulübe sıçrama sağlamaz. İlk 11 beklentisi otomatik forma garantisi
değildir. Kullanıcı imzalamadan AI kişisel kariyer oyuncusunu transfer edemez.

Doğrulama: `tests/transfer_negotiations_check.gd` ekonomi, karşı teklifler,
bekleme süreleri, kayıt/yükleme ve kişisel kulüp değişimini;
`tests/transfer_negotiations_ui_check.gd` gerçek gamepad akışını ve ekranları
sınar. `-- --visual` ekran görüntülerini `/tmp/sefc-transfer-*.png` olarak üretir;
`--compact` küçük pencereyi de denetler.
