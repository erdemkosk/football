# STARTING ELEVEN FC — SEFC

Godot ile üstten bakışlı, NSS 3'ün saha odaklı maç görünümünden esinlenen 11'e 11 futbol oyunu. İlk 2D çizim sürümü yerine 3D saha, animasyonlu oyuncular ve bağımsız bir fizik topuyla yeniden kuruldu. Modeller ve malzemeler proje içinde üretilir; stadyum ve alkış için kullanıcı tarafından sağlanan üç MP3 projeye dahildir. Ek indirme veya eklenti gerekmez.

SEFC arması ana menüde, açılış ekranında, ayar/takım/kadro başlıklarında ve maçın yayın bandında kullanılır. Koyu yeşil, krem ve altın renkli armanın ana dosyası `assets/branding/sefc-crest.png`; macOS Dock/Finder simgesi `sefc.icns`, Windows görev çubuğu/EXE simgesi `sefc.ico` dosyalarıdır. Proje adı, pencere başlığı ve uygulama paketleri **STARTING ELEVEN FC** adını kullanır. Yeni isimle henüz ayar kaydı yoksa eski sürümün ses ve tuş tercihleri okunur; sonraki kaydetme yeni oyunun kullanıcı klasörüne yapılır.

## Başlat

Godot 4.3+ ile `project.godot` dosyasını aç ve **F5** tuşuna bas. Godot 4.7.2 / macOS üzerinde doğrulandı.

```sh
godot --path .
```

Hazır masaüstü paketleri: macOS için `builds/macos/STARTING ELEVEN FC.app` (Apple Silicon + Intel), Windows 64 bit için `builds/windows/STARTING ELEVEN FC.exe`. Windows EXE oyun verisini içinde taşır. `export_presets.cfg` iki platformun uygulama adını ve yerel simgelerini içerir; test görüntüleri ve geliştirme araçları oyuna paketlenmez. Yeniden oluşturmak için Godot 4.7.2 ve aynı sürümün export şablonlarıyla:

```sh
mkdir -p builds/macos builds/windows
godot --headless --path . --export-release "macOS"
godot --headless --path . --export-release "Windows Desktop"
```

Simge boyutlarını ana PNG'den yeniden üretmek: `python3 tools/build_brand_icons.py` (macOS, Python 3 + Pillow ve sistemin `iconutil` aracı). macOS paketi yerel test için ad-hoc imzalıdır. Platform simgeleri [Godot'un yerel simge ayarları](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-application-config-macos-native-icon) ve [Windows EXE simgesi](https://docs.godotengine.org/en/stable/tutorials/export/changing_application_icon_for_windows.html) üzerinden bağlanır.

Açılışta **Hızlı Maç / Enter / Xbox A** takım seçimini açar. Kendi kulübünü ve rakibini seç, formalarını belirle, ardından kadro ve taktik ekranından maça çık. **T** kaleciye karşı antrenmanı açar. Maçlar 4 dakika sürer; gösterge 90 maç dakikasına ölçeklenir.

Ana menüde mevcut uzak stadyum açısının arkasında iki yapay zekâ takımı canlı maç oynar. Gerçek top fiziği, paslar, şutlar, hakemler, tribün tepkileri, gol sevinci ve duran toplar çalışır; kamera maç sırasında yakın plana geçmez. Maç bitince yenisi başlar. Ayarlar bu gösteri maçını duraklatır; Hızlı Maç ise skor, süre, kondisyon ve kartları temizleyerek kendi maçına hazırlanmanı sağlar.

Stadyumun çevresinde 52 detaylı bina, balkonlar, dükkân vitrinleri ve tenteler, çatı klima üniteleri, paneller ve su depoları bulunur. Kesintisiz yollar, kavşaklar, yaya geçitleri ve kaldırımlar mahalleyi birbirine bağlar. Otoparklarda ve yol kenarında takım otobüsleri dahil 92 araç; yollarda iki yönde dolaşan 28 araç vardır. Giriş meydanları, gişeler, duraklar, banklar, 58 ağaç ve 126 taraftar çevreyi doldurur. Gece pencereler, farlar ve sokak lambalarının zemindeki aydınlığı açılır. Dış çevre için ek gölgeli ışık kullanılmaz; 35 binden fazla sabit parça 145 yerel çizim grubunda birleştirilir. Hareketli trafik yalnızca uzak menü/hazırlık görünümünde güncellenir, molada durur. Saha kamerası ve arka plandaki maç korunur.

Maç iki adet iki dakikalık yarıdan oluşur. İlk yarının ve varsa uzatmasının sonunda 20 saniyelik devre arası vardır; Enter veya ekrandaki düğmeyle geçilebilir. İkinci yarıda takımlar kaleleri değiştirir, seçtiğin rakip santrayla başlar. Devrede oyuncular 20 yüzde puan enerji kazanır; skor, kartlar ve istatistikler korunur. Antrenmanda devre arası yoktur.

Normal maçlar tünel çıkışıyla açılır: üç hakemin arkasında iki sıra hâlindeki 22 oyuncu sahaya yürür, takımlar tribüne dönüp selam verir ve santra dizilişine koşar. Kamera çıkış, takım sunumu ve saha görünümü arasında geçer; maç saati ilk düdükte başlar. **Space** veya **Enter** ile herhangi bir aşamayı tek tuşta atlayabilirsin; ekrandaki “Seremoniyi geç” düğmesi de çalışır. **Esc** töreni duraklatır. Antrenman ve F2 serbest vuruş denemesi doğrudan başlar.

Golde golcü tribüne doğru koşar; diğer dokuz saha oyuncusu etrafında toplanıp kollarını açarak ve fiziksel olarak zıplayarak kutlar. Diğer takım arkadaşları alkışlar, rakipler üzülerek geri döner. Kamera kutlamaya yaklaşır; küçük gol bandı sahanın altındadır. Golü atan takımın taraftarları 19 saniyelik tepki boyunca ayağa kalkıp belirgin biçimde zıplar; kulübeler de kutlamaya katılır. Ev sahibi golünde tribün dalgası devam eder.

Kutlamadan sonra topun durduğu son konuma en yakın oyuncu aynı fiziksel topu alır; kendisi santrayı kullanmayacaksa merkezde bekleyen oyuncuya atar. Santrayı golü yiyen takım kullanır. İki takım kendi yarı sahasına döner; rakipler santra çemberinin dışında bekler. Top merkezde durup diziliş tamamlanınca düdük gelir. Santra Kıyı Spor'daysa **S'ye basıp bırakarak** başlat; rakipteyse rakip pasla başlar. Gol sonrası oyuncular ve top ışınlanmaz, maç saati kutlama/hazırlık sırasında ilerlemez. Antrenman doğrudan yeni şut denemesine döner.

## Hızlı maç, kadro ve ayarlar

Hızlı Maç sırası: **Takım ve rakip seçimi → İlk 11 ve taktik → Seremoni → Maç**. Sekiz kurgusal kulübün ayrı isimleri, kadroları, armaları ve iki forma seçeneği bulunur: Kıyı Spor, Atlas FC, Demirspor, Güneş FK, Orman Birliği, Kuzey Yıldızı, Liman Athletic ve Kapadokya SK. Formayı 3D oyuncu üzerinde görürsün; isimler, formalar, yayın grafikleri ve stadyum tabelaları seçime göre güncellenir.

Kadro ekranında ilk 11, kulübün formalarını taşıyan kartlarla saha üzerine yerleşir; yedi yedek altta birlikte görünür. Oyuncuyu, ardından yedeği tıkla veya formaları saha ile kulübe arasında sürükle. Kontrolcüde analog/D-pad ile gez, **A** ile oyuncuyu seç; seçim doğrudan uygun yedeklere geçer, tekrar **A** ile değiştir. Sağ panel gerçek isimleri, forma numaralarını ve enerjiyi karşılaştırır; kartlar ve bekleyen değişiklikler sahada işaretlenir. **Xbox X / klavye Z** son değişikliği geri alır; bekleyen değişikliği sağdaki düğmeden tek tek iptal edebilirsin. Maç öncesindeki ilk 11 düzenlemesi maç içindeki üç değişiklik hakkını tüketmez. Diziliş, pres, oyun anlayışı ve savunma çizgisi ayrı taktik bölümündedir.

**K / Xbox View** maç sırasında kadro ve taktik ekranını açar. **P** veya ana menüdeki **Ayarlar** düğmesi yalnızca ses, kontrolcü, tuş atama ve görüntü/oyun tercihlerini açar. Kadro ayarlarda bulunmaz. İki ekran da maç saatini ve fiziği duraklatır; fare, Tab/yön tuşları ve Xbox sol analog/D-pad ile kullanılır. **A** seçer, **B/Esc** geri döner. Ana menü, antrenman, hava seçimi, takım/forma seçimi, kadro/taktik, mola, devre arası ve maç sonu ekranları da tamamen kontrolcüyle kullanılabilir. Seçili düğme belirgin bir çerçeveyle gösterilir; geri dönünce seçim korunur.

Ayarlarda **sol/sağ** ses ve analog çubuklarını veya seçenekleri değiştirir; **yukarı/aşağı** satır değiştirir. **LB/RB** ayar bölümleri arasında, kadro ekranında ilk 11 ve taktik planı arasında geçer. **View** hazırlık ekranından ayarları açar. Uzun tuş listesi seçili satıra kayar. Xbox tuş ataması sırasında **View/Start** iptal eder (B oyuna atanabilir); klavye atamasını **B** ile de iptal edebilirsin. Analog menülerde kontrollü tekrar yapar; ekran geçişinde yeniden merkezlenene kadar seçimi kaydırmaz. Menü A/B işlevleri oyun içindeki özel tuş atamalarından bağımsızdır.

- **Kadro:** Yedi yedek, maç başına üç değişiklik. Kaleci kaleciyle değiştirilir; ihraç edilen oyuncu değiştirilemez. Değişiklikler ilk duraklamada gerçekleşir. Oyuncu kenara hızlı koşar; yeni isim ve forma numarasıyla yedek sahaya girer. Bu çıkışlarda kondisyon harcanmaz. Rakip de yorgun oyuncularını değiştirebilir.
- **Taktik:** 4-4-2, 4-3-3 veya 3-5-2; savunmacı/dengeli/hücumcu anlayış, pres yoğunluğu ve savunma çizgisi. Zorluk rakibin karar süresini, pas isabetini ve baskısını değiştirir.
- **Ses ve kontrol:** Stadyum, alkış ve davul seviyeleri bağımsızdır. Analog hassasiyeti, ölü bölge, titreşim ve gol tekrarı ayarlanabilir.
- **Tuş atama:** Oyun hareketleri klavyede ve Xbox tuşlarında yeniden atanabilir; çakışmalar yer değiştirir. Yön tuşları, sol analog ve menü kısayolları sabittir. Ayarlar Godot kullanıcı klasöründeki `match_settings.cfg` dosyasına kaydedilir.

Gol sonrası son beş saniye 0.8× hızla gösterilir. **Space / Enter / A** geçer; canlı maçın konumları geri yüklenip takım kutlaması devam eder. Tekrar fizik kararlarını veya skoru yeniden çalıştırmaz.

Hakem, avantajlı bir takım arkadaşı topu aldığında oyunu üç saniye sürdürür; avantaj kaybolursa ilk faul noktasına döner. Gereken sarı kart sonraki duraklamada gösterilir. Yüksek hızlı ve topa ulaşmayan ağır arkadan müdahaleler doğrudan kırmızıyla cezalandırılır. Duran top ve kutlama süreleri, dört dakikalık maç temposuna uyarlanmış en fazla altı gösterge dakikası ilave süre üretir; mola ve tekrar ilave süre kazandırmaz.

## Kontroller

**F1** veya **Kontrol Rehberi** düğmesi açılır paneli gösterir. Xbox'ta ana menüde **Y**, maçta **Start → Y** ile açılır; **B / Y** kapatır, **LB / RB** bölüm değiştirir. PlayStation'da aynı işlemler **△**, **Options → △**, **○ / △** ve **L1 / R1** ile yapılır. Klavyede **F1 / Esc** kapatır. Pas & şut, savunma, top kontrolü ve maç/menü bölümlerinde hareketlerin açıklamaları bulunur; kontrolcü ve klavye görünümü arasında geçilebilir. Rehber geçerli tuş atamalarını gösterir. Maç sırasında açmak oyunu duraklatır; ana menüdeki gösteri maçı ise panelin arkasında devam eder.

**PlayStation ve Xbox otomatik algılanır.** DualSense / DualShock cihaz adı, Sony üretici kimliği veya SDL cihaz kimliği tanındığında PlayStation simgeleri seçilir. Tanımlanamayan kontrolcüler Xbox düzenini kullanır. Maçın alt kontrol şeridinde, rehberde, menülerde ve tuş atama ekranında düğme adları yerine çizilmiş tuş simgeleri bulunur. Kol değişimi ve yeniden atama simgeleri günceller; klavye kullanıldığında klavye ipuçlarına dönülür. Simgeler bir kez hazırlanıp önbellekte tutulur.

| İşlev | PlayStation | Xbox |
| --- | --- | --- |
| Şut / topsuz ayakta müdahale | □ | X |
| Orta / topsuz kayma | ○ | B |
| Pas / pas iste | × | A |
| Ara pas / savunmada kaleciyi çıkar | △ | Y |
| Hızlı koş | R1 | RB |
| Oyuncu değiştir | L1 | LB |
| Top koruma / falsolu şut | L2 | LT |
| Anlık oyun planı | R2 + ← / ↑ / → | RT + ← / ↑ / → |
| Değişiklik önerisini kabul / geç | R2 + × / ○ | RT + A / B |
| Verkaç | L1 + × | LB + A |
| Aşırtma | L1 + □ | LB + X |
| Havadan uzun pas | L1 + △ | LB + Y |
| Yerden sert orta | ○ iki kez | B iki kez |
| Mola | Options | Start |
| Kadro / taktik | Share / Create | View |

Sol analog hareket eder; sağ analog veya yön düğmeleri koşudan bağımsız şut nişanı verir. Menülerde **×** seçer, **○** geri döner. İki kol türü aynı fiziksel düğme yerleşimini ve mevcut pas/şut fiziğini kullanır.

| Tuş | İşlev |
| --- | --- |
| Yön tuşları | Hareket; son hareket yönü şut yönüdür |
| W + yön tuşu | Stamina harcayarak sprint; yorulunca W'yi bırakıp toparlan |
| S basılı tut → bırak | Top sendeyken pas gücü ve hedef → vuruş; kısa dokunuş yakın pas. Topsuzken pas iste |
| A | Top sendeyken orta; topsuzken havadan pas iste |
| Y basılı tut → bırak | Hücumda koşu yoluna pas; savunmada basılı tutarak kaleciyi çıkar, bırakınca geri dönsün |
| D basılı tut → bırak | Şut gücü → vuruş |
| D basılıyken E / Xbox LT | Finesse: nişan değişmez, iç ayak falso uzak köşeye kıvrılır |
| D basılıyken Q / Xbox LB + X | Aşırtma: nişan değişmez, top kalecinin üzerinden yumuşak kavisle gider |
| Sol fare basılı tut → bırak | Fareye nişan alarak şut |
| Sağ fare basılı | Fare yönünde nişan |
| D basılıyken sol / sağ yön tuşu | Şut nişanını yavaşça ayarla |
| X | Kayarak müdahale |
| F1 | Kontrol rehberini aç / kapat |
| F5 / F6 / F7 | Savunmacı / dengeli / hücumcu oyun planı |
| F8 / F9 | Yorgun oyuncu değişikliği önerisini kabul et / geç |
| F | FPS panelini aç / kapat; anlık FPS, kare süresi ve performans grafiği |
| G | Ayakta top alma; boşa uzanırsan kısa toparlanma, önce rakibe temas edersen faul |
| E basılı | Top sendeyken vücuduyla koru; şut şarjındayken falso; topsuzken topa dönük yavaş savunma adımları |
| Z | Kısa vücut çalımı ve yana top dokunuşu; stamina ve bekleme süresi kullanır |
| V | Topu ileri aç, ardından yön tuşları/W ile yetiş |
| Q | Topun gidişini ve savunma konumunu gözeterek oyuncu değiştir; yön tuşu seçim yönünü etkiler |
| Tab | Tek oyuncuda kalma / takım kontrolü |
| Fare tekeri | Kamerayı yakınlaştır / uzaklaştır |
| F2 (ana menü) | Baraja karşı serbest vuruşla maça başla |
| C | Taktik saha görünümü / takip kamerası |
| F11 | Tam ekran / pencere |
| Esc | Duraklat / devam et |
| P | Ses, kontrolcü, tuş atama ve görüntü ayarları |
| K / Xbox View | Maç içinde ayrı kadro ve taktik ekranı |
| R | Antrenmanda topu yenile; molada yeni maç |
| M | Ses aç / kapat |
| H | Açık → yağmurlu → sağanak; menüde hava düğmesi de kullanılabilir |
| Space / Enter (seremonide) | Seremoniyi atlayıp santraya geç |

Xbox kontrolcüsü: **sol analog** hareket ve yön, **X** top sendeyken şut (basılı tut → bırak), topsuzken ayakta top alma, **LB + X** aşırtma, **B** top sendeyken orta, topsuzken kayarak müdahale; **A** pas (basılı tut → bırak) / topsuzken pas iste, **LB + A** verkaç, **RB** basılıyken hızlı koşma (stamina harcar), **LB** oyuncu değiştirme. Analog eğimi yürüyüş hızını belirler; merkezdeki %18 ölü bölge sürüklenmeyi önler. Duran toplarda da sol analogla nişan, X/A/B ile vuruş kullanılır. Menülerde **A** seçili düğmeyi çalıştırır; seremonide ve devre arasında devam eder. **Y** hücumda koşu yoluna pas (basılı tut → bırak), savunmada basılı tutulduğu sürece kaleciyi çıkarma, **LT** top koruma / karşılama, **RT + sol/yukarı/sağ** savunmacı/dengeli/hücumcu oyun planı, **sağ analog basma (R3)** topu ileri açma, **Start** mola ve **View** kadro ve taktik. Şut ve temaslarda ayarlanabilir titreşim vardır. Klavye çalışmaya devam eder; ekrandaki ipuçları son kullanılan girişe göre değişir. Kontrolcü bağlantısı kesilirse hazırlanan vuruş iptal edilir ve maç duraklar.

**LB + X — aşırtma:** Top sendeyken LB'yi tutup X ile şutu doldur, bırakınca top kalecinin üzerinden yumuşak bir kavisle gider. Nişan normal şutla aynıdır; falso eklenmez. Klavyede şutu doldururken **Q** aynı işi görür. LB tek başına top sendeyken bırakıldığında oyuncu değiştirir; savunmada yine basıldığı anda değiştirir.

**LB + A — verkaç:** Top sendeyken LB'yi tutup A'ya bas. Yakındaki takım arkadaşına kısa yerden pas atılır, kontrol alıcıya geçer; pası veren oyuncu içeri doğru yaklaşık 10 metre kat eder. A/Y ile geri pası sen seçersin. Koşu hedefe ulaşınca, en geç 3 saniyede veya 12 metrelik toplam yol sınırında biter; top kaybı, düdük veya koşucuya manuel müdahale de koşuyu iptal eder. Normal stamina tüketilir.

**LB + Y — havadan uzun pas:** Top sendeyken LB'yi tut, sol analogla kanadı hedefle ve Y'yi basılı tutup bırak. Kısa basış yakın, uzun basış uzak oyuncuyu tercih eder; güç 0,65 saniyede dolar. Havada çizilen yay, alıcı ve güç çubuğu vuruştan önce görünür. Pas yardımı ayarı uygulanır, ofsayttaki oyuncu hedef seçilmez; manuel modda doğrudan seçtiğin yöne oynarsın. Alıcının koşusu ve hava direnci ilk vuruşta hesaplanır; top havadayken hedef takip etmez. LB'yi önce bırakmak pası bozmaz. Tek başına Y koşu yoluna pas / savunmada kaleci çağırma olarak kalır.

**B × 2 — yerden sert orta:** B'ye 0,23 saniye içinde iki ayrı basış yap. Top yerden yaklaşık 27–31 m/sn hızla çıkar; zemin ve hava koşullarına göre sürtünmeyle yavaşlar, hedefe kendiliğinden yönelmez. İlk B kısa bir ayak hazırlığı başlatır; ikinci basış gelmezse normal havadan orta çıkar. Topsuz B hâlâ kayar; duran top kontrolleri aynıdır. Mola, top kaybı veya bağlantı kesilmesi bekleyen ortayı iptal eder.


Kıyı Spor beyaz-yeşil formayla ilk yarıda **yukarıdaki**, ikinci yarıda **aşağıdaki kaleye** hücum eder. Takım kontrolü varsayılan olarak açıktır: S/A/Y pasından sonra alıcıya, topu kazanan takım arkadaşına ve savunmada belirgin biçimde daha uygun oyuncuya geçilir. LB/Q ile yaptığın seçim kısa süre korunur; kontrol işareti yakın oyuncular arasında sürekli atlamaz. Gelen pasta analog/yön girişi yoksa alıcı topu karşılar; yön verdiğinde hareket kontrolü tamamen sendedir. Tab ile tek oyuncuda kalma açıldığında pas sonrası kontrol değiştirilmez; pas verip boşa koşarak yeniden isteyebilirsin. Topsuzken S/A oyuncu değiştirmez: el kaldırıp pas istersin. Takım arkadaşın yaklaşık üç saniye içinde uygun pas yolunu arar; koşuna göre topu önüne bırakır, gerekirse havadan oynar. Markajdaysan boşa çıkmalısın. Rakip pası kesebilir; gelen top fiziksel olarak kontrol edilir.

Bizim takımda pas, şut ve orta kararı kullanıcıya aittir. Seçili olmayan takım arkadaşları destek koşusu, bindirme, markaj ve müdahale yapabilir; top kendilerine gelince kendiliğinden pas veya şut atmazlar. S/A ile açıkça pas istemek yine takım arkadaşına pas komutu verir. Kalecimiz topu tuttuğunda kontrol ona geçer ve dağıtım komutunu bekler. Rakip ve ana menüdeki gösteri maçının iki takımı normal yapay zekâyla oynar.

Yerden pas için S'ye kısa dokunarak yakındaki oyuncuya oyna; daha uzaktaki hedef için kısa süre basılı tut. Güç 0,65 saniyede dolar ve sabit kalır. S basılıyken yön tuşları hedefi çevirir. Varsayılan yarı yardımlı pas, yönündeki takım arkadaşına nişanı ve gerekli pas hızını dengeler; kısa basış yakını, uzun basış uzağı tercih eder. Arkandaki oyuncuya otomatik dönmez. Ayarlar → Görüntü & Oyun → Pas yardımı ile Manuel / Yarı yardımlı / Yardımlı seçilebilir. Y ile top koşan arkadaşının önündeki boşluğa bırakılır; uzun basış daha ileriyi hedefler. Ofsayttaki oyuncu otomatik ara pas hedefi olmaz. Top vuruştan sonra fiziksel yolunda gider, havada hedef takip etmez. Çizgi, alıcı ve kısa/orta/uzun güç göstergesi pası önceden gösterir; turuncu çizgi araya girebilecek rakibi belirtir. S'yi bırakınca gösterilen pas çıkar. Topu kaybetmek, oyuncu değiştirmek, şuta geçmek veya duraklatmak hazırlanan pası iptal eder.

Şut, yerden/ara pas, havadan pas, orta ve duran toplar ortak bir rota gösterimi kullanır: belirgin uçuş çizgisi, yön okları, silik zemin izdüşümü ve hedef halkası. Falsolu şutta tam kavis ile kalede tahmini varış gösterilir; hedef dışarıda veya fazla yüksekse renk ve yazı değişir. Falso yönü şuta başlarken sabitlenir; nişanı çevirirken aniden tersine dönmez. Serbest vuruşta tuşu bırakınca seçilen falso koşu boyunca korunur. Ortada düşüş yeri ve alıcı, zayıf yerden pasta gerçekten ulaşılabilen mesafe gösterilir. Kısa kalan pas ayrıca belirtilir. Hızlı pas/orta sonrasında çizgi 0,75 saniyede kaybolur. Tahmin yerçekimi, hava/zemin direnci, sekme ve falsoyu kullanır; oyuncuların araya girmesi fiziksel sonucu değiştirebilir.

Klavyede şut gücü doldurulurken sol/sağ tuşlarına kısa dokunuşlarla nişan ince ayarlanır. D bırakılınca top gösterilen yönde çıkar. Fareyle şut nişanı da yumuşak döner. Xbox'ta X basılıyken sol analog şut yönünü seçer; başlangıç yönünün çevresindeki 14 derece sınırı kontrolcü için uygulanmaz. Hafif analog eğimi küçük düzeltme, tam eğim daha hızlı dönüş yapar. **D-pad veya sağ analog**, koşu yönünden bağımsız nişan verir: sol analogla sola koşarken sağa şut çekebilirsin. Bu ayrı nişanı bırakmak seçilen yönü korur; koşu yönüne geri atlamaz. X bırakıldığında top ekrandaki çizginin yönünde çıkar. D-pad duran toplarda da sağ/sol nişan düzeltmesi yapar.

Top sürme sıkı ayak kontrolü kullanır: kontrol edilen top koşu ve ani yön değişiminde ayağın hemen önünde tutulur. Sprint topu yalnızca bir adım öne açar; ayaktan koparıp bırakmaz. Bu açılış sprintin bedelidir: rakip **G / Xbox X** ile öndeki topa daha uzaktan basabilir. Sprint bırakılınca top yeniden ayağa alınır ve müdahale yine yakından, faul riskiyle yapılır. Durunca oyuncuyla birlikte durur. Top dönüş sırasında gövdenin çevresinden alınır. Pas/şut, düşme ve düdük bu kontrolü bırakır; rakip açık topa ulaşarak kapabilir. İki takım aynı kontrolü kullanır.

**Z** ile kısa bir vücut çalımı yapıp topu yana alabilirsin; **V** topu birkaç metre ileri açar ve kontrolü bırakarak sprint yarışına dönüştürür. **E** basılıyken top yakın rakibin uzağındaki ayağa alınır, oyuncu kollarını açıp gövdesiyle korur ve yavaşlar. Rakip top tarafına geçerse yine alabilir. Topsuz E, topa dönük yan adımlarla karşılamayı sağlar. **G / Xbox X** ayakta ayağını uzatarak topu dürter; sprintte öne açılmış topa daha kolay ulaşır, ayağın dibindeki topa uzanamayan müdahale otomatik kazandırmaz ve rakibe önce temas faul doğurabilir. **X** kayma olarak kalır.

Takım arkadaşları pas yolundaki rakipleri ve boş alanı değerlendiren destek noktalarına koşar. Kanatta aynı taraftaki bek bindirir; ceza sahasında yakın direk, uzak direk, geriye çıkarılan pas ve ceza sahası yayı için ayrı koşular yapılır. Pas veren oyuncu ileri verkaç koşusuna çıkar; yapay zekâ alıcısı uygun ve ofsaytsız dönüş pasını değerlendirebilir. Kontrol ettiğin oyuncunun koşusunu sen yönetirsin. Koşular stamina kullanır, top kaybında iptal olur ve iki hücum yönünde de aynı mantık uygulanır.

Kaleciler top-kale açısına yerleşir, ceza sahasında ulaşabilecekleri boş topa veya yalnız kalan hücumcuya çıkar. Şuta tepki vermeleri zaman alır; yön ve yükseklik tahminleri kusursuz değildir. Sert köşe şutları ve yakın mesafeli bitirişler kaleciyi geçebilir; kurtarış için topun eldivene veya gövdeye gerçekten yaklaşması gerekir. Yorgunluk, yağmur ve görüşü kapatan oyuncular hata olasılığını artırır. Ortanın düşüşünü hesaplayıp erişilebilir topa fiziksel olarak sıçrarlar. Eldivene gelen yavaş rakip topunu tutup pas/puntla dağıtabilirler; sert topları genellikle güvenli yana çelerken bazen önlerine sektirip ikinci vuruş fırsatı bırakırlar. Rakip kalecinin tepki ve tahmin becerisi zorluk ayarına bağlıdır. Takım arkadaşının geri pası elle yakalanmaz.

Şut gücü doldurulurken koşu adımları devam eder; dururken iki ayak yerde kalır, gövde hazırlanır ve kollar denge sağlar. Tuş bırakılınca mevcut adımdan kısa vuruşa geçilir: destek ayağı yere basar, şut bacağı ileri savrulur, gövde ve kollar birlikte döner; diz toparlanıp koşuya yumuşakça döner. Güçlü şutun savuruşu daha belirgindir. Top tuş bırakıldığı anda çıkar. Vuruş gücü tok temas sesini ve kısa kamera tepkisini değiştirir. Bu geri bildirim topun hızını/yönünü değiştirmez veya zamanı durdurmaz; normal pas ayrı ve daha hafif kalır.

Kayarak müdahalede topa temiz temasla oyuncuya çarpmanın sesi farklıdır. Gövde temasında iki oyuncunun göreli hızına bağlı itme, sendeleme veya düşüp toparlanma uygulanır. Yerde toparlanırken oyuncu topu kontrol edemez; kontrol ettiğin oyuncuya darbe geldiğinde şut/pas hazırlığı kesilir ve kısa bir ekran kenarı tepkisi görülür. Temas sesleri düdükle aynı ses kanalını paylaşmaz. Faul ve kart kararı mevcut topa önce temas kurallarıyla verilir; iki takım aynı tepkileri kullanır.

Sprint normal koşudan belirgin biçimde hızlıdır. Kesintisiz sprint yaklaşık on sekiz saniyede oyuncuyu yorar. Normal koşu daha yavaş stamina tüketir; enerji azaldıkça hız ve hızlanma düşer. Yorulan oyuncu yürüyüş temposuna geçer. Sprinti yeniden açmak için W'yi bırakmak ve en az %32 stamina toplamak gerekir. Durmak, yürümekten daha hızlı toparlar; göstergedeki çizgi geri dönüş eşiğini gösterir. Gol sonrası stamina dolmaz. Yeni maç ve yeni antrenman denemesi tam enerjiyle başlar; yapay zekâ da aynı kurallara tabidir.

## Hava ve saha

Takım seçim ekranındaki **Maç: GÜNDÜZ / GECE** düğmesiyle saati seç. Fareyle tıklanır; kontrolcüde analog/D-pad ile üzerine gelip **A** ile değiştirilir. Hava durumu bağımsızdır: açık, yağmurlu veya sağanak gece maçı oynanabilir. Gündüz sıcak renkli güneş tek bir sabit yönden gelir; oyuncuların ve stadyumun gölgeleri aynı yöne düşer. Gece güneş kapanır, tribün çatısındaki dört projektör grubu sahayı aydınlatır. Oyuncunun konumuna ve animasyonuna göre birden fazla gerçek gölge oluşur; tribünler ve dış çevre daha karanlık kalır. Maç saati seremonide, molada, gol tekrarında ve ikinci yarıda korunur. `godot --path . -- --night` gece seçili olarak açar; `--rain` ile birlikte kullanılabilir.

Menüde **H** ile açık hava, yağmur veya sağanak seç. Maç sırasında da H kullanılabilir: yağış birkaç saniyede değişir, zemin kademeli ıslanır ve yağmur kesilince yavaş kurur. Yeni maç seçilen havayla ve temiz iz katmanıyla başlar. `godot --path . -- --rain` sağanak seçili olarak açar.

Yağmurun sesi, rüzgâr yönünde düşen damlalar, yumuşayan ışık, ıslak çim ve birikintilerde halkalar bulunur. Kale ağızları ve aşınan bölgeler çamurlaşır. Islak sağlam çimde top daha fazla kayar; çamur topu yavaşlatır ve sekme yüksekliğini düşürür. Oyuncuların hızlanması ve yön değiştirmesi tutuşa bağlıdır; çamurda koşu hızı da biraz azalır. Bu etkiler iki takıma aynı biçimde uygulanır. Top, her fizik adımında bulunduğu zeminin yuvarlanma direnci ve hıza bağlı enerji kaybıyla yavaşlar; güç ilk hızı belirler. Düşük hızda sonlu sürede durur, kendi kendine yeniden hızlanmaz. Ortalar havada hava direnciyle, indikten sonra sekme ve yer direnciyle enerji kaybeder. Pas, orta ve duran top tahminleri aynı hava/zemin hesabını kullanır; top vuruştan sonra hedefe göre hızlandırılmaz veya frenlenmez.

Yere basan oyuncular ayak izi; kayarak müdahale ve kaleci dalışı geniş sürüklenme izi bırakır. Top çamur üzerinde ince bir iz açar; koşarken, kayarken ve top yuvarlanırken küçük su/çamur parçaları sıçrar. İzler 180 saniyede yavaşça silinir; çizim havuzu 3072 izle sınırlıdır ve dolunca en eski izi değiştirir. Düdük, gol veya yağmurun kesilmesi izleri silmez. M yağmur sesini de kapatır; mola yağmur hareketini ve izlerin yaşlanmasını durdurur. Yağış parçacıkları görsel efekt, top ve oyuncu tepkileri yerel yüzey katsayılarıyla fizik simülasyonudur.

## Bu sürümde

- Düdükten sonra top düşmeye, sekmeye ve yuvarlanmaya devam eder. Taç, korner, faul, penaltı, kale vuruşu ve santrada topun son konumuna en yakın oyuncu seçilir; düdük anında yakında olan oyuncu uzaklaşan topun peşinden gönderilmez. Topu alan kişi farklıysa vuruş noktasında bekleyen oyuncuya fiziksel bir yay çizerek atar ve yerine döner. Alıcı topu elleriyle karşılar; taçta başının üzerine kaldırır, yerdeki vuruşta yere yerleştirir. Topu alma, atma ve toplayıcının yerine dönüşü stamina tüketmez; normal oyunda tüketim tekrar başlar. Yerdeki vuruşta topun durması beklenir. Oyuncular dizilişlerine yürüyerek/koşarak gider, kamera topun alınmasını takip eder. Duran top hazırlığında top veya oyuncular ışınlanmaz.
- Duran toplarda hazırlık, yerleşim, düdük ve vuruş aşamaları. Serbest vuruşta mesafeye göre 3–5 kişilik baraj, rakipler için en az 9,15 m ve hücumcularla baraj arasında en az 1 m açıklık; yakın endirekt vuruşta kale çizgisi istisnası. Kaleci barajın açık tarafını kapatır; baraj şutta fiziksel gövdesiyle sıçrar. Uzaktaki serbest vuruşlarda pas yerleşimi kullanılır.
- Duran top hazırken sol/sağ yön tuşları nişanı ayarlar; S pas, A orta, D şut için basılı tutup bırakılır. Serbest vuruşta az güç daha yavaş ve yüksek yay çizen bir şut, fazla güç daha sert bir vuruş üretir. Penaltı D ile kullanılır. Oyuncu vuruşu seçmeden top yeniden oyuna girmez; rakip takım da hazırlık aşamasından geçer.
- Kornerde yakın/uzak direk koşu yerleri ve adam paylaşımı; kale vuruşunda kale alanı içinden kullanım ve rakiplerin ceza sahası dışında beklemesi; taçta çizgi üzerinde, iki elle baş üstünden fiziksel atış ve 2 m rakip mesafesi. Penaltıda 11 m noktası, çizgide kaleci, ceza sahası/yay dışında ve topun gerisinde oyuncular.
- Pas/vuruş anına göre ofsayt konumu, topa katılınca endirekt vuruş; taç, korner ve kale vuruşundan doğrudan alışta ofsayt istisnası. Savunmacıdan tesadüfi sekme veya kaleci kurtarışı önceki ofsaytı kaldırmaz. Yeniden başlatan oyuncunun çift dokunuşu endirekt vuruştur; taç/endirekt vuruştan doğrudan gol sayılmaz, doğrudan kendi kalesine duran top korner olur.
- Kayarak müdahalede temas sırası: topa önce dokunmak ile rakibe önce çarpmak ayrılır. Ceza sahasında rakibe faul penaltıdır. Yapay zekâ da müdahale yapabilir. Kontrolsüz arkadan müdahale sarı kart; basitleştirilmiş tekrarlı faul eşiği her üçüncü faulde sarı karttır. İkinci sarıda oyuncu oyundan çıkar, takım eksik kalır; yediden az oyuncuda maç bitirilir.

- Kamera ekranı kaplayan dikey sahada topu ve oyuncuyu yumuşakça takip eder.
- Göz yormayan, düşük kontrastlı çim şeritleri; mesafeye göre azalan ince doku, mat yüzey ve yumuşatılmış aydınlatma.
- Oturan, ayakta duran ve tezahürat yapan seyirciler; farklı kıyafetler, ten/saç tonları, koyu koltuklar, merdivenler, korkuluklar ve taraftar pankartları. Sakin anlarda da bağımsız gövde hareketleri sürer; küçük gruplar farklı zamanlarda ayağa kalkar, alkışlar ve kısa süre zıplar. Maç olaylarındaki güçlü tepkiler ve Meksika dalgası bu gündelik hareketlerin önüne geçer. Animasyonlar ana menüdeki gösteri maçında da çalışır ve GPU üzerinde toplu çizilir.
- Tehlikeli atakta ayağa kalkmaya başlayan tribünler; şut ve kurtarış tepkileri, golde kolları kaldırıp zıplayarak sevinme. Ev sahibi golünden sonra tribün boyunca sırayla ilerleyen Meksika dalgası; yakın skorlu maçın son bölümündeki baskıda artan destek. Deplasman bölümü kendi takımına sevinir; gol kamerası tribünü göstermek için hafifçe genişler.
- İkinci kat tribünlerle yaklaşık 6.700 seyirci, katlar arasında dolaşım alanı, köşe merdiven blokları ve camlı dış cephe. Köşeleri birleşen çelik makaslı çatı, ışık geçiren ön şerit ve çatı altı projektörleri. İki kulübenin arasında tribünün içine açılan oyuncu tüneli; saha kenarı yayın kameraları, giriş kapıları ve stadyum meydanı.
- Kale arkasında maç skorunu ve saatini takip eden iki tabela. Açılış menüsünde yavaş hareketli stadyum panoraması; stadyumun etrafı mahalle, yol ve binalarla devam eder. Maçta yukarıdan takip kamerası.
- Kale ağları, reklam panoları, kulübeler ve dinamik gölgeler.
- İki takım için şeffaf çatılı yedek kulübeleri; yedişer yedek, teknik direktör, yardımcı antrenör ve sağlık görevlisi. Teknik direktör dolaşır ve yön gösterir; yedekler tehlikeli atakta doğrulur, golde öne çıkıp alkışlar veya sevinir, yenilen gol ve kaçan fırsatta başlarını tutar. Tepki bitince yerlerine dönerler. Takım renkli koltuklar, antrenman yelekleri, taktik panosu, su şişeleri ve sağlık çantaları.
- Bel, diz ve dirsek eklemleriyle koşu; hızlanırken öne eğilme, dönüşlerde ağırlık aktarımı, yere basan destek ayağı ve vuruş takibi.
- Kaleciler topa dönük çömelir; şutun yönü/yüksekliğine göre sıçrar, eldivenlerini uzatır, yere iner ve kalkar. Kurtarış erişimi eldiven ve gövde konumuyla sınırlıdır.
- Kayarak müdahale ve çim üzerinde kayma izi.
- 0.43 kg kütleli `RigidBody3D` top; yerçekimi, hava direnci, yer sürtünmesi, falso ve sürekli çarpışma algılama. Top oyuncunun konumuna yapıştırılmaz; ayak dokunuşlarıyla ilerler.
- Yakın ayak temasında sınırlı itkiyle top sürme ve ilk kontrol; topun mevcut momentumu korunur. Pas hızı, uçuş süresi, alıcının koşusu ve rakibin araya girme ihtimali hesaba katılır. Yapay zekâ pası karşılamak için hareket eder ve ilk kontrolden sonra karar verir.
- Fiziksel kale direkleri ve üst direk; arka, yan ve üst filelerde sabit kenarlı yay ağı. Topun temas noktası esner; yatay, dikey ve çapraz ip gerilimi darbeyi çevreye yayar. File geri salınır ve zamanla durulur; sert vuruş daha büyük cep oluşturur. Çizilen file, ışık normalleri ve top teması aynı deformasyonu kullanır. Gol tekrarından önce 1,15 saniye canlı fizik devam eder; topun fileye girişi ve ağın hareketi tekrara da kaydedilir. Tekrar bitince ağın gerçek konumu ve hızı geri yüklenir. Hareketsiz file fizik hesabı yapmaz.
- Gol için topun tamamı kale çizgisini, direklerin arasından ve üst direğin altından geçmelidir.
- Her iki takımda topsuz pozisyon alma, kaleci atlayışları ve çelmeler; bizim takımda kullanıcı komutuyla pas/şut, rakipte bağımsız hücum kararları.
- Taç, korner, kale vuruşu, müdahaleden doğan serbest vuruş ve gol sonrası yeniden başlama.
- Şut, pas, kurtarış ve topa sahip olma sayacı; sonuç, duraklatma ve tekrar oynama ekranları.
- Antrenman modu, top hızı göstergesi, radar, enerji ve şut gücü göstergesi.
- Kullanıcının sağladığı gerçek stadyum ambiyansı maç boyunca döner. İkinci alkış kaydı şut, kurtarış, gol, yakın kaçan fırsat ve müdahalelerde ayrı kanalda, yumuşak giriş/çıkışla çalar. Gol daha uzun ve güçlüdür; tekrarlanan olaylar sesleri üst üste bindirmez. M tüm sesleri kapatır, mola iki kaydı da duraklatır. Topa vuruş ve düdük ayrı kanallarda kalır.
- Seremoniden maç sonuna kadar görev yapan siyah formalı orta hakem ve iki bayraklı yardımcı. Orta hakem oyunu takip eder; düdük, yön, penaltı, endirekt vuruş ve kart işaretlerini gösterir. Kart gösterimi bitmeden duran top kullanılamaz; ikinci sarıdan sonra kırmızı kart gösterilir. Endirekt vuruşta kol, başka bir oyuncunun topa temasına kadar havada kalır.
- Yardımcı hakemler kendi taç çizgilerinde top ve ikinci son savunmacının oluşturduğu ofsayt çizgisini izler. Ofsayttaki oyuncu topa müdahale ettiğinde bayrağı kaldırıp ihlalin yakın/orta/uzak bölgesini gösterirler; taç, korner ve kale vuruşunda ilgili işareti verirler. Hakemler topa ve oyunculara fiziksel engel olmaz; antrenmanda görünmezler.

Kariyer/transfer ve çevrimiçi çok oyunculu mod bu sürümde bulunmuyor. Elle oynama henüz modellenmiyor. Ofsayt gövde konumu ve topa temas üzerinden değerlendirilir; kalecinin görüşünü kapatma gibi temassız müdahaleler ayrıca modellenmez. Kaleci ve top sürme yardımları oynanabilirlik için ayarlanmış oyun davranışlarıdır.

Duran top kuralları için [IFAB serbest vuruş](https://www.theifab.com/laws/latest/free-kicks/), [penaltı](https://www.theifab.com/laws/latest/the-penalty-kick/), [taç](https://www.theifab.com/laws/latest/the-throw-in/), [kale vuruşu](https://www.theifab.com/laws/latest/the-goal-kick/) ve [ofsayt](https://www.theifab.com/laws/latest/offside/) esas alındı. Mesafeler oyun sahasının metre ölçeğindedir.

## Doğrulama

Kontrol rehberi, fare/F1/Xbox açma-kapama, sekmeler, gerçek tuş atamaları, pas/şut girdilerinin panelden oyuna sızmaması, duraklatma ve önceki ekrana dönüş: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/controls_help_check.gd`. Görsel kontrol için headless olmadan `-- --visual` ekle.

Hızlı maç akışı, bağımsız kulüp seçimi, gerçek forma/isim değişimi, ilk 11, maç başlangıcına taşıma ve ayrı ayarlar: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/prematch_check.gd`. Görsel kayıt için headless olmadan `-- --visual` ekle.

Canlı ana menü maçı, iki takımın pas/şutları, sabit stadyum kadrajı, gol/santra/taç devamlılığı, ayarlarda duraklama ve temiz maç başlangıcı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/menu_match_check.gd`. Gündüz/gece görüntüsü için headless olmadan `-- --visual` ekle.

Kadro, fiziksel değişiklik, kondisyon, taktik, zorluk, avantaj/kartlar, ilave süre, tekrar, Xbox ek tuşları ve kalıcı ayarlar: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/match_expansion_check.gd`. Görsel kayıt için headless olmadan `-- --visual` ekle.

FPS tuşu ve kare ölçümü, devre arası/atlama/dinlenme, ikinci yarı kaleleri/ofsayt/kaleciler/duran toplar ve tribün olayları: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/match_day_check.gd`. Görsel kontrol için headless olmadan `-- --visual` ekle.

İki takımdan en yakın toplayıcı, rakipten doğru takımın oyuncusuna teslim, stamina muafiyetinin görevle sınırlı olması ve yedi duran top senaryosu: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/nearest_collector_check.gd`.

Destek koşuları ve iki yönlü bindirme, verkaç tetikleme, gerçek Z/V/E/G/Q girdileri, top koruma/çalma, sprintte açılan topa ayakta müdahale, faul, kaleci açı/çıkış/orta/tutma/dağıtım ve güvenli çelme: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/gameplay_depth_check.gd`. Animasyon görüntüleri için headless olmadan `-- --visual` ekle.

Sıkı top sürme, sprintte topu bir adım öne açma, 90°/180° dönüş, duruş, şutta bırakma, sert topu yakalamama ve rakibin topu kazanması: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/close_control_check.gd`.

İki takımda gol kutlaması, fiziksel zıplama/toplanma, mola, kesintisiz top taşıma, yasal santra dizilişi, S ile başlama ve rakibin santrası: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/goal_celebration_check.gd`. Gerçek oyun kamerası, yakın plan kutlama ve santra görüntüleri için headless olmadan `-- --visual` ekle.

Filenin iç arka köşesindeki topa ulaşma ve santraya dönerken karşılaşan oyuncuların birbirinin yanından geçmesi: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/kickoff_corner_check.gd`.

Hakem takibi, iki yardımcıdaki ofsayt çizgisi, gerçek topun hakemden etkilenmeden geçmesi, bayrak/kart sırası, endirekt işareti, mola ve seremoni devamlılığı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/referee_check.gd`. Yakın plan işaretler: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/referee_visual.gd`. İşaretler için [IFAB beden dili, iletişim ve düdük rehberi](https://www.theifab.com/laws/latest/guidelines/body-language-communication-and-whistle/) esas alındı.

Şut hazırlığı/savuruşu, nişanın korunması, kontrollü kamera tepkisi, temiz/kusurlu müdahale ayrımı, fiziksel itme, düşüp toparlanma ve ses kapatma: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/impact_check.gd`. Yakın plan görüntüler: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/impact_visual.gd`.

Şutu uzun basılı tutarken iki ayağın yer teması ve adım sırası, koşu/sprintten vuruşa geçiş, kol/gövde/diz toparlanması, kısa dokunuş, iptal ve 30/120 Hz tutarlılığı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/shot_animation_check.gd`. Yakın plan kareleri için headless olmadan `-- --visual` ekle.

Tüm oyuncuların yürüyerek çıkması, diziliş, mola, maç saatinin beklemesi ve her aşamadan tek tuşla atlama: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/ceremony_check.gd`. Kamera/animasyon görüntüleri: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/ceremony_visual.gd`.

Islak/kuru zeminde gerçek top mesafesi, sekme yüksekliği, ayak ve kayma izleri, kuruma, mola ve iz havuzu: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/weather_check.gd`.

Hava görüntüleri: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/weather_visual.gd`. Yağışlı tam maç veya duran top testinde ilgili komuta `-- --rain` ekle.

Kesintisiz top fiziği, topa koşma, elle alma/taşıma, kale arkasından ve kale içinden erişim, yere bırakma ve taç kullanımı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/restart_recovery_check.gd`.

Alma, taşıma ve kaldırma animasyonlarının yakın plan görüntüleri: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/recovery_visual.gd`. Görüntüler `tests/recovery-close-*.png` olarak kaydedilir.

Duran top yerleşimleri, baraj sıçraması, gerçek tuş girdileri ve rakip vuruşu: `godot --headless --path . --fixed-fps 120 --script res://tests/set_piece_check.gd`. Görsel kontrol için headless olmadan `-- --visual` ekle.

Ofsayt/istisnalar, temas sırası, çift dokunuş, doğrudan gol kısıtları, faul/penaltı ve kartlar: `godot --headless --path . --fixed-fps 120 --script res://tests/football_rules_check.gd`.

Stadyumun menü, maç, taktik, dış cephe, tribün içi ve tünel görüntüleri: `godot --path . --script res://tests/stadium_review.gd`. Görüntüler `tests/arena-*.png` dosyalarına yazılır.

Sprint/koşu tüketimi, yorgunluk kilidi, toparlanma, gerçek hız sınırı ve sıfırlama: `godot --headless --path . --fixed-fps 120 --script res://tests/stamina_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Pas gücü, yön yardımı, hedef önizlemesi, bas/bırak, hareket halinde pas ve iptal davranışları: `godot --headless --path . --fixed-fps 120 --script res://tests/pass_skill_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Pas isteme, koşuya pas, kapalı yol, rakibin pası kesmesi, ilk kontrol ve sınırlı ayak itkisi: `godot --headless --path . --fixed-fps 120 --script res://tests/pass_request_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Kulübe kadrosu, oturma/kalkma, teknik direktör hareketi, iki takımın tepkileri ve oyun olayları: `godot --headless --path . --script res://tests/sideline_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Tribün olayları, taraftar bölümleri, dalga zamanlaması ve sıfırlama: `godot --headless --path . --script res://tests/crowd_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

File teması, sert/yumuşak şut, yan/üst ağlar, geniş titreşim dalgası, darbe sonrası salınım, sönümleme ve iki kale: `godot --headless --path . --fixed-fps 120 --script res://tests/net_check.gd` (görsel kontrol için headless olmadan `-- --visual`). İpler arasındaki gerilim darbeyi geniş alana taşır; çevredeki ağın düşük sönümlemesi belirgin geri titreşim bırakırken topun temas ettiği küçük cep ayrıca enerji emer.

Oyuncu eklemleri, kaleci sıçrama/iniş/kalkış ve kurtarış erişimi: `godot --headless --path . --script res://tests/motion_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Keskin dönüşlerde mevcut adımın destek ayağı kısa süre çime basılı kalır; kalça ağırlığı bu bacağa aktarır, gövde ve kollar dönüşü dengeler. Frenleme ayrı bir diz bükme duruşu kullanır. Savunmada yüzünü rakibe dönük tutarken yan adımlama ve kısa geriye koşu farklı adım döngüleridir. Bu katman yalnızca modeli hareket ettirir; hız, ivme, yön girdisi ve vuruş zamanlamasına bekleme eklemez. Şut, kayma, düşme, kaleci dalışı ve duran top hareketleri önceliklidir.

Destek ayağının dünya konumunu koruması, ilk fizik adımında yön tepkisi, sağ/sol/180° dönüş, yer teması, frenleme, yan/geri adımlar, şut/müdahale geçişi ve mola: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/locomotion_check.gd`. Yakın plan görüntüler için headless olmadan `-- --visual` ekle.

Canlı beden dili: Oyuncular yaklaşan pasın öncesinde kısa omuz kontrolü yapar, top kontrol mesafesine girerken bakışını yeniden topa çevirir. Koşu yönünden bağımsız baş ve göz eklemleri yerdeki ve havadaki topu sınırlı boyun açılarıyla izler. Saç, yüz ve gözler aynı baş eklemine bağlıdır. Takım arkadaşları savunmacının kapatmadığı gerçek destek koşusunu uygun eliyle gösterir; kişi başına bekleme süresi ve takım başına en fazla iki eşzamanlı işaret vardır. Top kaybedilirse el yumuşakça iner. Gerçek oyuncu çarpışmaları omuz esnemesi, denge arayan kollar, dizlerle darbe emme ve yaklaşık yarım saniyelik toparlanma üretir; hareket girdileri, hız ve vuruşlar görsel katmandan etkilenmez. Şut, kaleci, duran top, sevinç ve disiplin hareketleri önceliklidir. Yakın plandaki göz ayrıntıları 35 metreden sonra çizilmez. Yeni eklemler gol tekrarına kaydedilir; mola sırasında hareketler donar.

Bakış yönü/sınırları, pas öncesi tarama, acil top kontrolü, açık/kapalı pas yolu, sağ/sol işaret, iptal geçişi, eşzamanlılık, gerçek oyuncu teması, top saklama, giriş gecikmesi olmaması, şut/taç önceliği ve tekrar: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/body_language_check.gd`. Yakın plan görüntüler: `godot --path . --fixed-fps 120 --script res://tests/body_language_check.gd -- --visual`.

Topa göre hareketler: Kontrol ve vuruş ayağı topun oyuncuya göre konumundan, ortadaki toplarda mevcut adımdaki ayak mesafesinden seçilir. Kısa pas daha küçük salınım, sert şut kalça dönüşü ve devam hareketi kullanır; ters yön, baskı, yorgunluk ve denge kaybı gövdenin hazırlığını değiştirir. Sağ/sol ayak değişse de gövde nişan alınan tarafa döner. Animasyon vuruşu geciktirmez ve seçilen şut yönünü değiştirmez.

Yumuşak ve sert paslar farklı ayak hareketleriyle karşılanır; sert pasta bacak topun gelişiyle geri çekilir. Uygun yükseklikte yaklaşan hava topu uyluk veya göğüsle yumuşatılır ve yerçekimiyle yere düşer. İlk kontrol gerçek topa sınırlı bir fizik itkisi uygular; konumu taşınmaz. Hız, baskı, yorgunluk ve uzanma mesafesi kontrol sonrasında kalan momentumu etkiler. Son anda yetişilen topa uzanmak topu sektirebilir ve anında sahiplik sağlamaz. Koşarken kontrol mevcut adımdan başlayıp yeniden koşuya karışır.

Darbe yönü korunur: öne, arkaya ve yana düşüşlerde gövde farklı eğilir, eller zemine destek olur ve kalkışta bir bacak ağırlığı devralır. Dönen çarpışma şekli çime teğet kalır. Kaçan şut başını tutma, kesilen/kötü pas kısa özür işareti, kurtarış yakındaki takım arkadaşlarında alkış üretir. Canlı top yakına geldiğinde veya seçili oyuncuya hareket girdisi verildiğinde tepki söner; hareket ve vuruş kontrolü kilitlenmez.

Gerçek pas/şut ve kurtarış olayları, iki ayakla vuruş, yönlü gövde dönüşü, yumuşak/sert ilk kontrol, uyluk/göğüs, uzanma ve seken top, hareket geçişleri, dört yöne düşüş, el-zemin teması ve kısa tepkiler: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/context_actions_check.gd`. Yakın plan görüntüler: `godot --path . --fixed-fps 120 --script res://tests/context_actions_check.gd -- --visual`; `tests/context-*.png` dosyalarına yazılır.

Kafa vuruşu: Orta yaklaşırken normal şut tuşuna (klavye D, Xbox X, PlayStation kare) basıp yön vererek bırak. Kısa süre önce verilen komut saklanır; oyuncu topun gelişine göre fiziksel olarak yükselir, ancak top kafasına ulaşırsa vurur. Güç, temas kalitesi, baskı ve yorgunluk sonucu etkiler. D-pad/sağ analogla koşudan bağımsız nişan kullanılabilir. Yerde aynı tuş normal şut veya mevcut ayakta müdahale işlevini korur. Kafa vuruşunda göğüs kontrolü araya girmez; kaçırılan top uzaktan yön değiştirmez. Seçilmeyen takım arkadaşları kullanıcıdan habersiz kafa şutu atmaz. Mola, oyuncu değişimi ve başka bir hareket komutu bekleyen vuruşu iptal eder. Kontrol rehberi ve maç içi simgenin yanında bağlama göre “Kafa” açıklaması bulunur.

Gerçek B ortası → oyuncu seçimi → X ile kafa golü, klavye/iki kontrolcü ailesi, fiziksel yükselme ve iniş, temas mesafesi, güç/yön, boşa çıkan komut, ofsayt ve kullanıcı yetkisi: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/heading_check.gd`. Yakın plan görüntüler: `godot --path . --fixed-fps 120 --script res://tests/heading_check.gd -- --visual`.

Kaleci dengesi: 72 fiziksel şutta kolay top, uzak köşe, sert köşe ve yakın mesafe; tepki süresi, zorluk, yağmur/yorgunluk/görüş, gerçek eldiven erişimi ve canlı seken top: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/keeper_balance_check.gd`. Dalışta eldivenler aynı karşılama noktasına yaklaşır; aralarında topun kaçtığı yapay boşluk kalmaz. Tepki süresi normal zorlukta yaklaşık 0,23 saniyedir. Sert toplarda okuma hatası artar; kurtarış alanı büyütülmez ve topun sonucu önceden belirlenmez.

İki kalede, sağ/sol köşelerde, üç vuruş açısında ve farklı rastgele okumalarla 84 ek fiziksel şut: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/keeper_corner_check.gd`. Alçak, yüksek, uzak, ceza sahası içi ve sert yakın köşeler ayrı sınanır; ulaşılabilir şutların çoğunun kurtarılması ve zor bitirişlerin hâlâ gol olabilmesi birlikte kontrol edilir.

Şut hassasiyeti, nişan/gösterge tutarlılığı, E/LT finesse falso ve Q/LB aşırtma: `godot --headless --path . --script res://tests/shot_control_check.gd`

Tam falso rotası, kuru/ıslak zeminde gerçek şutla hedef karşılaştırması ve serbest vuruşta falsoyu koruma: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/finesse_guide_check.gd`. `-- --visual` yakın plan saç modeli ve şut hedefi görüntülerini alır. Saç yüzeyi başın üstünü örten, ön saç çizgisi ve ense yüksekliği ayrı modellenmiş bir ağdır; kafa içine gömülmez.

Pas/orta rota tahmini, fiziksel düşüş noktası, kısa kalan pas, aynı hızla vuruş ve çizginin kaybolması: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/pass_guide_check.gd`. `-- --visual` pas, ara pas, uzun pas, orta ve korner görüntülerini alır.

Kullanıcı komutu olmadan pas/şut atmama, topsuz destek, açık pas isteği, rakip/menü yapay zekâsı ve kaleci dağıtımı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/player_authority_check.gd`.

Gerçek golün canlı file teması, tekrar içinde ağ hareketi, fiziği iki kez çalıştırmama ve eksiksiz geri yükleme: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/net_replay_check.gd`.

Xbox'ta koşudan bağımsız D-pad/sağ analog nişanı, sol analogla tam yön değişimi, fiziksel ters yöne şut, hassasiyet ve menü/bağlantı geçişleri: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/shot_direction_pad_check.gd`.

```sh
# Fizik, maç kuralları ve gerçek klavye girdisiyle hareket ederken şut
godot --headless --path . --script res://tests/physics_check.gd

# Tam maç boyunca yapay zekâ, yeniden başlama ve bitiş
godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/simulation_check.gd

# Gerçek render üzerinden menü, maç ve antrenman görüntüleri
godot --path . --script res://tests/visual_check.gd
```

## Dosyalar

- `scripts/game.gd`: maç, kontroller, takım yapay zekâsı, kurallar, kamera.
- `scripts/support_play.gd`: boş alan ve pas yolu değerlendirmesi, verkaç, bindirme ve ceza sahası koşuları.
- `scripts/duels.gd`: çalım, top açma/koruma, ayakta müdahale ve oyuncu seçimi.
- `scripts/goalkeeping.gd`: açı kapatma, çıkış, orta takibi, yakalama, dağıtım ve yana çelme kararları.
- `scripts/goal_celebration.gd`: golcüye koşma, grup kutlaması, fiziksel sıçrama, kutlama kamerası ve santraya geçiş.
- `scripts/impact_feedback.gd`: gerçek şut ve müdahale temasına bağlı kamera, ses ve zemin parçacığı tepkileri.
- `scripts/ceremony.gd`: iki takımın tünel çıkışı, hakemler, selamlama, kamera ve atlanabilir santra hazırlığı.
- `scripts/weather.gd`: yağış, yüzey ıslaklığı/çamuru, tutuş, ses, kalıcı iz ve sıçrama havuzları.
- `scripts/set_pieces.gd`: duran top dizilişleri, korunan hazırlık, nişan, güç ve vuruş.
- `scripts/restart_recovery.gd`: fiziksel topu bulma, alma, taşıma, yerleştirme ve hazırlığa geçiş.
- `scripts/football_rules.gd`: ofsayt, yeniden başlama temas kuralları, faul/penaltı ve kartlar.
- `scripts/referees.gd` ve `scripts/referee.gd`: hakemlerin konum takibi, maç kararlarına bağlı görevleri, bayrak ve kart animasyonları.
- `scripts/ball.gd`: fizik topu, sürtünme, hava direnci, falso.
- `scripts/ball_motion.gd`: fizik ve pas tahmininde ortak yuvarlanma direnci, durma mesafesi, Magnus falso ve havadan vuruş hesabı.
- `scripts/passing.gd`: hareketli alıcıya pas yörüngesi ve pas yolundaki rakip riski.
- `scripts/goal_net.gd`: yay ağı simülasyonu, deforme ağ geometrisi ve top ile karşılıklı kuvvet aktarımı.
- `scripts/footballer.gd`: oyuncu modeli, hareket ve animasyon.
- `scripts/locomotion.gd`: yönlü adımlar, dönüş/frenleme ağırlık aktarımı ve iki eklemle destek ayağı teması.
- `scripts/body_language.gd`: top takibi, pas öncesi çevre kontrolü, boşluk işaretleri ve fiziksel temasa görsel denge tepkisi.
- `scripts/ball_actions.gd` ve `scripts/first_touch.gd`: topa göre ayak seçimi, vuruş/kontrol hareketleri ve ilk dokunuşun fiziksel sonucu.
- `scripts/heading.gd`: yaklaşan orta için kafa vuruşu komutu, sıçrama zamanlaması, gerçek temas ve yönlü kafa şutu.
- `scripts/impact_motion.gd`: darbe yönüne göre düşüş, el desteği ve ayağa kalkış.
- `scripts/match_reactions.gd` ve `scripts/player_reaction.gd`: maç olaylarından kısa, kesilebilir oyuncu tepkileri.
- `scripts/stadium.gd`: saha, kaleler, tribünler, ışık ve çevre.
- `scripts/stadium_lighting.gd`: bağımsız gündüz/gece seçimi, yönlü güneş, çatılara bağlı projektörler ve yağmurla birlikte aydınlatma.
- `scripts/stadium_architecture.gd`: üst tribünler, çatı makasları, dış cephe, tünel ve canlı skor tabelaları.
- `scripts/stadium_district.gd` ve `scripts/district_geometry.gd`: sokak düzeni, detaylı şehir binaları, çevre donatıları, trafik ve yerel birleşik çevre geometrisi.
- `scripts/sidelines.gd` ve `scripts/sideline_actor.gd`: kulübeler, teknik ekip ve maç olaylarına bağlı eklem animasyonları.
- `scripts/crowd.gd`: verimli toplu çizimle farklı pozlarda seyirci ve koltuk modelleri.
- `scripts/hud.gd`: menüler, skor, radar ve oyuncu göstergeleri.
- `scripts/audio.gd`: ses sentezi.
- `shaders/`: çim ve ağ malzemeleri.

Referanslar: [NSS 3 maç ekranı](https://www.gamewatcher.com/games/new-star-soccer-3/screens), [Godot RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html).

Antrenman düğmesi üç mod açar: **Serbest antrenman** mevcut tek oyuncu/kaleci düzenidir; **Orta & kafa** çalışmasında kanattaki takım arkadaşı iki taraftan sırayla gerçek fiziksel orta açar, pas tuşuyla daha erken orta istenebilir ve şut tuşuyla kafa vurulur; **Serbest vuruş** kaleci ve dört kişilik barajla üç farklı noktadan tekrarlanır. Gol, dışarı çıkan top, kalecinin tuttuğu top veya biten pozisyon sonrasında yeni çalışma kurulur; seken topa devam edilebilir. **R** yeni deneme, **T** (kolda **View / dokunmatik yüzey**) mod seçimi açar. Kontrolcüyle yeni deneme mola menüsündedir. Menü fare, klavye, Xbox ve PlayStation ile kullanılabilir. Antrenman partnerinin otomatik ortası yalnızca bu modda etkindir; maçta kendi takımının pas/şut kontrolü oyuncuda kalır.

Antrenman seçimi, fiziksel orta + kafa vuruşu, baraj hazırlığı, kontrolcü serbest vuruşu, tekrarlar, duraklatma ve mod temizliği: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/training_modes_check.gd`. `-- --visual` ile seçim, orta ve serbest vuruş görüntüleri kaydedilir.

Kulüp armaları ve forma baskıları `scripts/kit_graphics.gd` ile üretilir: sekiz farklı arma, kumaşa oturan desenler ve sırt numaraları aynı UV dokusundadır. Göğüste ayrı kutu/decal, sırtta havada duran yazı yoktur. Menü ve formalar aynı armaları kullanır; deplasman ve kaleci formalarında kulüp arması kendi renklerini korur. 512×192 mipmap dokular önbelleğe alınır; çamur için yeniden üretilmez.

144 oyuncunun boy/kilo profilleri kulüp ve oyuncu kimliğine bağlıdır (`scripts/player_physique.gd`). Mevcut kadrolar 168–198 cm aralığındadır; kilo boya uygun sınırlarda üretilir. Boy, omuz/gövde genişliği, derinlik ve çarpışma kapsülü bu ölçülere uyar; yüzler aşırı esnetilmez. Kadro değişimi, yedekten giriş ve maç sıfırlama aynı oyuncunun ölçülerini korur. Kadro karşılaştırmasında cm/kg gösterilir. Kontrol: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/kit_physique_check.gd`; `-- --visual` ile forma ön/arka, eğilme, kulüp armaları ve menü görüntüleri kaydedilir.

Stadyum ambiyansı, olay alkışları, öncelik, mola, ses kapatma ve yeni maç temizliği: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/stadium_audio_check.gd`.

Tribün davulu ilk kez 12–22 saniyelik aktif oyun sonrasında, ardından her kısa ritmin bitişinden 24–42 saniye sonra rastgele aralıklarla duyulur. Şut/gol alkışlarına öncelik verir; devre arasında yeni ritim başlamaz, mola duraklatır, M susturur. Kaydın sonundaki sessizlik tekrar çalınmaz.

Xbox A/B/X girişleri, analog ölü bölge/hız/yön, şut/pas bas-bırak, topsuz pas isteği, duran toplar, menü geçişleri ve kontrolcü bağlantısının kesilmesi: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/gamepad_check.gd`. Bu test Godot joystick olayları üretir; fiziksel cihaz testi ayrıca yapılmalıdır.

PlayStation algılama, gerçek simge dokuları, rehber/ayarlar/HUD, yeniden atama, kol değişimi ve klavyeye dönüş: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/controller_prompts_check.gd`. Görsel kontrol için `godot --path . --script res://tests/controller_prompts_check.gd -- --visual`. Oynanış testini PlayStation profiliyle çalıştırmak için `gamepad_check.gd` komutuna `-- --playstation` eklenir. Bunlar sanal Godot girişleri kullanır; USB/Bluetooth fiziksel kol testi yerine geçmez.

Topun son konumuna göre toplayıcı değişimi, uzaktan fiziksel teslim, uzun taşıma koşusunun kaldırılması ve stamina: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/restart_relay_check.gd`.

Oyuncu değişikliğinde çıkan oyuncu yorgun olsa da kenara hızlı koşar; bu çıkış stamina harcamaz. Y ile çağrılan kaleci fiziksel olarak topa koşar, tuş bırakılınca kaleye döner. Ceza sahası dışında topu ayağıyla uzaklaştırır. Takım topu kazanınca, düdükte, molada ve kontrolcü bağlantısı kesilince çıkış komutu iptal edilir.

Güce ve zemine bağlı gerçek durma mesafesi, 30/60/120 Hz tutarlılığı, çamur geçişi ve ortanın yere indikten sonra yavaşlaması: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/ball_resistance_check.gd`. Yağmurlu tam maç denemesi: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/simulation_check.gd -- --rain`.

Tüm menülerde kontrolcü gezinmesi, analog tekrar/ölü bölge, seçenekler, kayan tuş listesi, yeniden atama, ekran geçişleri ve bağlantı kesilmesi: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/menu_controller_check.gd`. `-- --visual` ile seçim çerçevelerinin ekran görüntüleri alınır.

Verkaç (LB + A), aşırtma (LB + X) ve çift B ortası; Xbox olayları, sınırlı fiziksel koşu/stamina, tek ve çift basış ayrımı, iptaller, alıcı kontrolü ve gerçek top fiziği: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/attacking_combos_check.gd`. `-- --visual` ile görsel kayıt alınır.

LB + Y havadan pas; basış/bırakış sırası, mesafe seçimi, yardım/ofsayt, iptal ve kuru/yağmurlu zeminde fiziksel uçuş: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/lofted_switch_check.gd`.

Kadro ekranı; gerçek fare tıklamaları, iki yönlü sürükle-bırak, Xbox seçimi/geri alma, üç dizilişte kart yerleşimi, enerji/kart gösterimi, bekleyen değişiklikler ve sınırlar: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/squad_management_check.gd`. İki testte de `-- --visual` ile görsel kayıt alınır.

Gündüz/gece seçimi, fare/Xbox, hava bağımsızlığı, seremoni ve devre arası: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/match_lighting_check.gd`. Headless olmadan `-- --visual` eklemek ekran görüntülerini alır ve gerçek gölgeleri açık/kapalı görüntüler üzerinden, gece saha parlaklığını da piksel ölçümüyle kontrol eder.

Çevrede binaların yolları kapatmaması, kesintisiz araç rotaları, çizim bütçesi, gündüz/gece geçişi ve maç sırasında trafik güncellemesinin kapanması: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/district_check.gd`. Görseller ve canlı ana menü performansı için `godot --path . --script res://tests/district_check.gd -- --visual --measure`; ölçümler `/tmp/football-district-performance.json` dosyasına yazılır. Apple M4 Pro / Metal / 1440×900 yerel ölçümünde gündüz yaklaşık 119, gece 107 FPS görüldü; değerler cihaz ve sahne yüküne göre değişir.


İkili mücadelede hafif yan temas artık otomatik faul değildir. Ayakta müdahale topa yetişirse topu söker; boşa uzanma veya hafif sürtüşme oyunu durdurmaz. Arkadan bacak arasına uzanma, geç hamle ve yüksek hızla sert giriş faul olarak kalır. Kaymada temas alanı gerçek bacak hattına daraltılmıştır; topa ilk dokunuş için küçük bir tolerans vardır. Yapay zekâ kapalı topa arkadan dalmak yerine pozisyon alır, yalnızca açık topa uygun açıdan kayar. Kontrol: `godot --headless --path . --script res://tests/duel_balance_check.gd`.

Top toplayıcıların bekleme noktaları yan hakem koridorunun dışındadır. `sideline_spacing.gd` kişiler arasında açıklık bırakır; top almaya giderken hakemin çevresinden dolaşılır, top tam hakemin yanındaysa hakem ofsayt hizasını koruyarak yana açılır. Top ve oyuncular için yeni bir fiziksel engel eklenmez. Kontrol: `godot --headless --path . --script res://tests/sideline_spacing_check.gd`.

Kadro ekranı portreli oyuncu kartları, kaleci/defans/orta saha/forvet grupları, mevkisine göre renkli etiketler, gerçek enerji/kart bilgisi ve karşılaştırma paneli kullanır. Yedeklerin de mevkileri gösterilir. `squad_portraits.gd`, mevcut oyuncu modellerini tek bir küçük stüdyoda sırayla fotoğraflayıp önbelleğe alır; stüdyo tamamlanınca silinir, maç sırasında portre çizimi yapılmaz. Üç diziliş, portre kimliği, değişiklik ve geri alma kontrolü: `godot --path . --script res://tests/tactics_portrait_check.gd` (grafik arayüz gerektirir). Mevcut fare, sürükle-bırak ve kontrolcü kontrolleri `squad_management_check.gd` ile doğrulanır.

### Kenardan talimat ve hızlı değişiklik

RT/R2 basılıyken yön düğmeleri oyun planını seçer: sol savunmacı, yukarı dengeli, sağ hücumcu. Teknik direktör ilgili el ve beden hareketiyle talimat verir; oyun durmaz. Sol analogla hareket sürer. RT/R2 bu özelliğe ayrılmıştır; topsuz ayakta müdahale X/□ ile yapılır.

Enerjisi azalan oyuncuya, sahadaki mevkisine uygun kullanılmamış bir yedek önerilir. RT+A (R2+×) kabul eder, RT+B (R2+○) öneriyi geçer; klavyede F8/F9, fareyle kart düğmeleri de kullanılabilir. Kabul edilen değişiklik ilk duraklamada uygulanır. Çıkan oyuncu stamina harcamadan kenara koşar; yedek girdikten sonra sayılır. Her iki takımın da maç başına üç hakkı vardır; bekleyen ve hâlen sahaya giren değişiklikler bu sınırda yer tutar.

Rakip hücumları boşluk, baskı, ofsayt çizgisi ve kalecinin konumuna göre kısa pas, verkaç ve dönüş pası, ara pas, havadan kanat değiştirme, yüksek veya yerden sert orta, aşırtma/falsolu şut, çalım ve topu ileri açmayı seçebilir. Havadan gelen topa aynı gerçek temas sistemiyle kafa şutu, kafa pası veya uzaklaştırma yapar. Kullanıcının takımı kendiliğinden pas ve şut atmaz; topsuz koşu ve savunma desteği sürer.

### Maçın gidişine göre atmosfer ve futbol

Tribün desteği skor ve kalan zamana bağlıdır: son bölümde beraberlik arayan takımın taraftarı hareketlenir, deplasman golünde ana tribün kısa süre durulur, kaçan fırsatta tepki söner. Yakın skorlu maçın sonundaki goller daha güçlü sıçrama ve kulübe tepkisi üretir. Mevcut stadyum ve alkış kayıtlarının seviyesi bu akışa uyar; yeni saha sesi, anons veya ses dosyası eklenmemiştir.

Geç dakikada attığı gole rağmen hâlâ geride olan takımın golcüsü kutlama yerine gerçek topu ağdan alıp santraya taşır. Topa yaklaşırken frenler, eğilip alır, kaldırır ve orta noktaya bırakır; stamina harcamaz. Takım arkadaşları yerlerine döner. Son bölümde öne geçiren golün grup kutlaması daha büyüktür; mevcut kutlama geçme tuşu kullanılabilir.

Oyuncuların kulüp ve kimliğine bağlı hız, ivme, ilk kontrol, denge, kafa ve şut değerleri ile güçlü/zayıf ayak bilgisi vardır. Kanat oyuncusu daha çabuk hızlanır, güçlü stoper hava topunda avantajlıdır; baskı altındaki kontrol ve ters ayakla şut gerçek top hızını etkiler. Değerler kadro karşılaştırmasında görülür ve oyuncu değişikliğinde kimlikle birlikte taşınır. Şut çizgisi, vuruşla aynı hesabı kullanır.

Savunma birlikte kayar: tek oyuncu baskıya çıkar, biri arkasını kapatır, diğerleri ortak derinliği ve pas yollarını korur. Kullanıcının pres ve savunma çizgisi ayarları ayrı ayrı geçerlidir. Rakip son bölümde gerideyse daha ileri çıkar ve riskli paslara yönelir; öndeyse daha temkinli oynar. Bu görevler kullanıcının seçili oyuncusunun yön kontrolünü devralmaz.

Yakın omuz mücadelesinde iki oyuncu birbirine yaslanır; sınırlı karşılıklı itiş kilo farkını dikkate alır ve tek başına faul üretmez. Hava topunda yer tutma, dengeye bağlı kontrol ve inişte kısa diz/gövde esnemesi vardır. Kurtarış ve gerçek yön değiştiren şut sekmeleri sonrası her iki takım en uygun oyuncuyu topa yollar; ikinci oyuncu bitiricilik veya kale koruması için yer alır. Kullanıcı takımında otomatik pas/şut eklenmez.

Duraklamalarda kaçan fırsat, kenardan talimat ve oyuncu değişikliği için en fazla iki saniyelik yakın kamera görüntüleri kullanılır. Oyun hazırlığı arkada sürer; duran top hazırsa kamera hemen döner. **Space/Enter**, Xbox **A/B** veya PlayStation **×/○** ile geçilir; diğer oyun tuşları da görüntüyü kapatır. Oyuncu değişikliğinde yedek kulübeden kenara gelir, çıkan oyuncuyla kısa selamlaşır ve sahaya girer. Üç değişiklik sınırı korunur.

Yeni davranış kontrolleri: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/realism_check.gd`. İki kale yönünde gerçek top taşıma, selamlaşma, stamina ve iniş testi: aynı komutla `res://tests/realism_flow_check.gd`; görüntüler için `--headless --disable-render-loop` kaldırılıp `-- --visual` eklenir.
