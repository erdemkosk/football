# Efsane: teklifler, kişisel para ve ekipman

Efsane modundaki **Teklifler** sayfası oyuncuya gelen sözleşmeleri gösterir. **Ekipman & Cüzdan** sayfasında kişisel bakiye, kuşanılan ekipman ve son hesap hareketleri bulunur. Kulüp bütçesi kişisel alışverişte kullanılamaz.

## Mantıklı aralıklarla teklifler

Otomatik ilgi için en az üç oynanmış maç, toplam 90 dakika ve en az 5,8 form gerekir. Pozisyon fark etmez; kaleciler ve savunmacılar gol atmak zorunda değildir. Gün bilgisi olan kariyerlerde son maçın üzerinden 60 gün geçtiğinde yeni güncel performans beklenir. Eski maç raporlarında gün bulunmuyorsa ilk yeni rapora kadar mevcut form kullanılır.

Açık kişisel görüşme varken yenisi üretilmez; yeni teklifler arasında en az 21 gün vardır. Yeni bir kulübe imzadan sonra 45 günlük alışma dönemi uygulanır. Mağazayı veya teklif sayfasını tekrar açmak ve kaydı yüklemek bu süreleri sıfırlamaz. Teklifler haftalık gözlemden gelir; takımın kadro ihtiyacı, oyuncunun bugünkü gücü, kulüp/lig itibarı ve gerçek bütçe sınırları korunur. Transfer döneminde dahi her kulübün ilgi göstermesi garanti değildir.

Kişisel teklifin süresi en fazla 10 gündür; kayıt döneminin sonunu aşamaz. Takvimi ilerletirken teklif geldiğinde kariyer merkezinde bildirim görünür. Teklifte ilginin sportif nedeni, maaş, imza parası ve kadro rolü gösterilir. Son karar oyuncudadır.

## Kişisel kazanç

- Maaş, kulübün gerçek aylık bordrosuyla birlikte ayın 1'inde cüzdana girer. Kulüpten ikinci kez kesilmez.
- Sözleşmedeki maç, gol ve şampiyonluk primleri, gerçekten hak edildiklerinde cüzdana yatar. Yeni Efsane oyuncusunun ilk sözleşmesinde €150 maç primi vardır.
- Kabul edilen kişisel transferin imza parası oyuncunundur. Bonservis satıcı kulübe gider; oyuncunun cüzdanına geçmez.
- Her maaş dönemi, maç primi ve imza ödemesi yalnızca bir kez işlenir. Bakiyenin hesabı toplam kazanılan eksi toplam harcanandır. Son 30 işlem kayıtta tutulur; ekranda son beşi gösterilir.

Yeni kariyer sıfır kişisel bakiyeyle ve ücretsiz kulüp kramponuyla başlar. Eski kayıtlar da bu nötr başlangıca taşınır; geçmişe dönük tahmini para üretilmez. Para ve ekipman kulüp değişiminde ve sezon geçişinde korunur.

## Ekipman dengesi

Aynı anda **bir krampon ve bir destek** kuşanılır. Satın alma tek seferliktir; sahip olunan ürünler ücretsiz değiştirilebilir. Sahadayken veya antrenman sürerken değişiklik yapılamaz. Kaydetme başarısız olursa alışveriş geri alınır.

| Ekipman | Bedel | Kuşanıldığındaki etki |
| --- | ---: | --- |
| Kulüp kramponu | Ücretsiz | Ek etki yok |
| İlk Dokunuş | €1.200 | Kontrol +1, pas +1 |
| Sürat | €3.200 | Hız +3, ivmelenme +2, kontrol −1 |
| Oyun Kurucu | €3.200 | Kontrol +3, pas +2, hız −1 |
| Bitirici | €3.200 | Şut +3, denge +1, dayanıklılık −1 |
| Destek tabanlığı | €1.800 | Dayanıklılık +2, denge +1 |
| Kaleci eldiveni | €2.600 | Top tutuşu +3, refleks +2; yalnızca kaleci |
| Toparlanma seti | €2.400 | Günlük kondisyon yenilenmesine +0,8 yüzde puan; sakatlığı iyileştirmez |

Etkiler gerçek maç ve antrenman kimliğine uygulanır; yedekten girişte de korunur. Kramponun rengi sahadaki modelde değişir. Temel özellikler, potansiyel, teknik direktörün yetenek değerlendirmesi ve transfer değeri ekipmanla artırılmaz. Kalıcı gelişim antrenman ve maçlardan kazanılır. Özellikler 95 üstüne çıkamaz; her özellik için toplam ekipman katkısı −3 ile +4 arasında sınırlıdır.

## Kontroller

`legend_equipment_check.gd`: bordro, primler, alışveriş, kayıt hatasında geri alma, eski kayıt geçişi ve sezon devamlılığı.

`legend_interest_check.gd`: güncel performans, tüm ana pozisyonlar, teklif aralıkları, kayıt dönemi, imza ödemesi ve tekrarların engellenmesi.

`legend_equipment_ui_check.gd`: gerçek kontrolcüyle mağaza, gelir geçmişi ve teklif ekranı; gerçek antrenman ve oyuncu değişikliğinde etki ve krampon görünümü. `-- --visual` gerçek pencere görüntülerini `/tmp/sefc-personal-*.png` olarak kaydeder; `--compact` daha küçük pencereyi sınar.
