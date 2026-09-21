# TOUCHLINE

Godot ile üstten bakışlı, NSS 3'ün saha odaklı maç görünümünden esinlenen 11'e 11 futbol oyunu. İlk 2D çizim sürümü yerine 3D saha, animasyonlu oyuncular ve bağımsız bir fizik topuyla yeniden kuruldu. Bütün modeller, malzemeler ve sesler proje içinde üretilir; harici indirme veya eklenti gerekmez.

## Başlat

Godot 4.3+ ile `project.godot` dosyasını aç ve **F5** tuşuna bas. Godot 4.7.2 / macOS üzerinde doğrulandı.

```sh
godot --path .
```

Açılışta **Enter** ile maç; **T** ile kaleciye karşı şut antrenmanı başlar. Fareyle iki düğme de kullanılabilir. Maçlar 4 dakika sürer; gösterge 90 maç dakikasına ölçeklenir.

Normal maçlar tünel çıkışıyla açılır: üç hakemin arkasında iki sıra hâlindeki 22 oyuncu sahaya yürür, takımlar tribüne dönüp selam verir ve santra dizilişine koşar. Kamera çıkış, takım sunumu ve saha görünümü arasında geçer; maç saati ilk düdükte başlar. **Space** veya **Enter** ile herhangi bir aşamayı tek tuşta atlayabilirsin; ekrandaki “Seremoniyi geç” düğmesi de çalışır. **Esc** töreni duraklatır. Antrenman ve F2 serbest vuruş denemesi doğrudan başlar.

Golde golcü tribüne doğru koşar; en yakın beş takım arkadaşı etrafında toplanıp kollarını açarak ve fiziksel olarak zıplayarak kutlar. Diğer takım arkadaşları alkışlar, rakipler üzülerek geri döner. Kamera kutlamaya yaklaşır; küçük gol bandı sahanın altındadır. Golü atan takımın taraftarları 12 saniyelik tepki boyunca ayağa kalkıp belirgin biçimde zıplar; kulübeler de kutlamaya katılır. Ev sahibi golünde tribün dalgası devam eder.

Kutlamadan sonra golü yiyen takımın en yakın uygun oyuncusu aynı fiziksel topu alıp merkeze taşır. İki takım kendi yarı sahasına döner; rakipler santra çemberinin dışında bekler. Top merkezde durup diziliş tamamlanınca düdük gelir. Santra Kıyı Spor'daysa **S'ye basıp bırakarak** başlat; rakipteyse rakip pasla başlar. Gol sonrası oyuncular ve top ışınlanmaz, maç saati kutlama/hazırlık sırasında ilerlemez. Antrenman doğrudan yeni şut denemesine döner.

## Kontroller

| Tuş | İşlev |
| --- | --- |
| Yön tuşları | Hareket; son hareket yönü şut yönüdür |
| W + yön tuşu | Stamina harcayarak sprint; yorulunca W'yi bırakıp toparlan |
| S basılı tut → bırak | Top sendeyken pas gücü ve hedef → vuruş; kısa dokunuş yakın pas. Topsuzken pas iste |
| A | Top sendeyken orta; topsuzken havadan pas iste |
| D basılı tut → bırak | Şut gücü → vuruş |
| Sol fare basılı tut → bırak | Fareye nişan alarak şut |
| Sağ fare basılı | Fare yönünde nişan |
| D basılıyken sol / sağ yön tuşu | Şut nişanını yavaşça ayarla; hafif falso |
| X | Kayarak müdahale |
| F | Ayakta top alma; boşa uzanırsan kısa toparlanma, önce rakibe temas edersen faul |
| E basılı | Top sendeyken vücuduyla koru; topsuzken topa dönük yavaş savunma adımları |
| Z | Kısa vücut çalımı ve yana top dokunuşu; stamina ve bekleme süresi kullanır |
| V | Topu ileri aç, ardından yön tuşları/W ile yetiş |
| Q | Topun gidişini ve savunma konumunu gözeterek oyuncu değiştir; yön tuşu seçim yönünü etkiler |
| Tab | Tek oyuncuda kalma / takım kontrolü |
| Fare tekeri | Kamerayı yakınlaştır / uzaklaştır |
| F2 (ana menü) | Baraja karşı serbest vuruşla maça başla |
| C | Taktik saha görünümü / takip kamerası |
| F11 | Tam ekran / pencere |
| Esc | Duraklat / devam et |
| R | Antrenmanda topu yenile; molada yeni maç |
| M | Ses aç / kapat |
| H | Açık → yağmurlu → sağanak; menüde hava düğmesi de kullanılabilir |
| Space / Enter (seremonide) | Seremoniyi atlayıp santraya geç |

Kıyı Spor beyaz-yeşil formayla **yukarıdaki kaleye** hücum eder. Top sendeyken S/A ile verdiğin pas sonrası alıcı oyuncuya geçilir. Tab ile tek oyuncuda kalma açıldığında pas sonrası kontrol değiştirilmez; pas verip boşa koşarak yeniden isteyebilirsin. Topsuzken S/A oyuncu değiştirmez: el kaldırıp pas istersin. Takım arkadaşın yaklaşık üç saniye içinde uygun pas yolunu arar; koşuna göre topu önüne bırakır, gerekirse havadan oynar. Markajdaysan boşa çıkmalısın. Rakip pası kesebilir; gelen top fiziksel olarak kontrol edilir.

Yerden pas için S'ye kısa dokunarak yakındaki oyuncuya oyna; daha uzaktaki hedef için kısa süre basılı tut. Güç 0,65 saniyede dolar ve sabit kalır. S basılıyken yön tuşları hedefi çevirir. Dar bir açı içindeki takım arkadaşına hedef yardımı vardır; arkandaki oyuncuya otomatik dönmez. Çizgi, alıcı ve kısa/orta/uzun güç göstergesi pası önceden gösterir; turuncu çizgi araya girebilecek rakibi belirtir. S'yi bırakınca gösterilen pas çıkar. Topu kaybetmek, oyuncu değiştirmek, şuta geçmek veya duraklatmak hazırlanan pası iptal eder.

Şut gücü doldurulurken yön sabitlenir; sol/sağ tuşlarına kısa dokunuşlarla nişan ince ayarlanır. D bırakılınca top gösterilen yönde çıkar. Fareyle şut nişanı da yumuşak döner.

Top sürme sıkı ayak kontrolü kullanır: kontrol edilen top koşu, sprint ve ani yön değişiminde ayağın hemen önünde tutulur; durunca oyuncuyla birlikte durur. Top dönüş sırasında gövdenin çevresinden alınır. Pas/şut, düşme ve düdük bu kontrolü bırakır; rakip topa ulaşarak kapabilir. İki takım aynı kontrolü kullanır.

**Z** ile kısa bir vücut çalımı yapıp topu yana alabilirsin; **V** topu birkaç metre ileri açar ve kontrolü bırakarak sprint yarışına dönüştürür. **E** basılıyken top yakın rakibin uzağındaki ayağa alınır, oyuncu kollarını açıp gövdesiyle korur ve yavaşlar. Rakip top tarafına geçerse yine alabilir. Topsuz E, topa dönük yan adımlarla karşılamayı sağlar. **F** ayakta ayağını uzatarak topu dürter; topa ulaşamayan müdahale otomatik top kazandırmaz, rakibe önce temas faul doğurabilir. **X** kayma olarak kalır.

Takım arkadaşları pas yolundaki rakipleri ve boş alanı değerlendiren destek noktalarına koşar. Kanatta aynı taraftaki bek bindirir; ceza sahasında yakın direk, uzak direk, geriye çıkarılan pas ve ceza sahası yayı için ayrı koşular yapılır. Pas veren oyuncu ileri verkaç koşusuna çıkar; yapay zekâ alıcısı uygun ve ofsaytsız dönüş pasını değerlendirebilir. Kontrol ettiğin oyuncunun koşusunu sen yönetirsin. Koşular stamina kullanır, top kaybında iptal olur ve iki hücum yönünde de aynı mantık uygulanır.

Kaleciler top-kale açısına yerleşir, ceza sahasında ulaşabilecekleri boş topa veya yalnız kalan hücumcuya çıkar. Ortanın düşüşünü hesaplayıp erişilebilir topa fiziksel olarak sıçrarlar; uzaktaki top kurtarış sayılmaz. Eldivene gelen yavaş rakip topunu tutup pas/puntla dağıtabilirler; sert topları yakındaki rakiplerin daha az olduğu yana çelerler. Takım arkadaşının geri pası elle yakalanmaz.

Şut sırasında ayak geriye alınır; top çıktığı anda destek bacağı, gövde dönüşü ve güçlü bir savuruş animasyonu devreye girer. Vuruş gücü tok temas sesini ve kısa kamera tepkisini değiştirir. Bu geri bildirim topun hızını/yönünü değiştirmez veya zamanı durdurmaz; normal pas ayrı ve daha hafif kalır.

Kayarak müdahalede topa temiz temasla oyuncuya çarpmanın sesi farklıdır. Gövde temasında iki oyuncunun göreli hızına bağlı itme, sendeleme veya düşüp toparlanma uygulanır. Yerde toparlanırken oyuncu topu kontrol edemez; kontrol ettiğin oyuncuya darbe geldiğinde şut/pas hazırlığı kesilir ve kısa bir ekran kenarı tepkisi görülür. Temas sesleri düdükle aynı ses kanalını paylaşmaz. Faul ve kart kararı mevcut topa önce temas kurallarıyla verilir; iki takım aynı tepkileri kullanır.

Kesintisiz sprint yaklaşık altı saniyede oyuncuyu yorar. Normal koşu daha yavaş stamina tüketir; enerji azaldıkça hız ve hızlanma düşer. Yorulan oyuncu yürüyüş temposuna geçer. Sprinti yeniden açmak için W'yi bırakmak ve en az %32 stamina toplamak gerekir. Durmak, yürümekten daha hızlı toparlar; göstergedeki çizgi geri dönüş eşiğini gösterir. Gol sonrası stamina dolmaz. Yeni maç ve yeni antrenman denemesi tam enerjiyle başlar; yapay zekâ da aynı kurallara tabidir.

## Hava ve saha

Menüde **H** ile açık hava, yağmur veya sağanak seç. Maç sırasında da H kullanılabilir: yağış birkaç saniyede değişir, zemin kademeli ıslanır ve yağmur kesilince yavaş kurur. Yeni maç seçilen havayla ve temiz iz katmanıyla başlar. `godot --path . -- --rain` sağanak seçili olarak açar.

Yağmurun sesi, rüzgâr yönünde düşen damlalar, yumuşayan ışık, ıslak çim ve birikintilerde halkalar bulunur. Kale ağızları ve aşınan bölgeler çamurlaşır. Islak sağlam çimde top daha fazla kayar; çamur topu yavaşlatır ve sekme yüksekliğini düşürür. Oyuncuların hızlanması ve yön değiştirmesi tutuşa bağlıdır; çamurda koşu hızı da biraz azalır. Bu etkiler iki takıma aynı biçimde uygulanır.

Yere basan oyuncular ayak izi; kayarak müdahale ve kaleci dalışı geniş sürüklenme izi bırakır. Top çamur üzerinde ince bir iz açar; koşarken, kayarken ve top yuvarlanırken küçük su/çamur parçaları sıçrar. İzler 180 saniyede yavaşça silinir; çizim havuzu 3072 izle sınırlıdır ve dolunca en eski izi değiştirir. Düdük, gol veya yağmurun kesilmesi izleri silmez. M yağmur sesini de kapatır; mola yağmur hareketini ve izlerin yaşlanmasını durdurur. Yağış parçacıkları görsel efekt, top ve oyuncu tepkileri yerel yüzey katsayılarıyla fizik simülasyonudur.

## Bu sürümde

- Düdükten sonra top düşmeye, sekmeye ve yuvarlanmaya devam eder. Taç ve kornerde en yakın uygun takım arkadaşı, kale vuruşunda kaleci topa koşar; eğilip aynı topu alır ve kullanacağı noktaya taşır. Taçta topu başının üzerine kaldırır; yerdeki vuruşta topu bırakıp durmasını bekler. Oyuncular dizilişlerine yürüyerek/koşarak gider, kamera topun alınmasını takip eder. Duran top hazırlığında top veya oyuncular ışınlanmaz.
- Duran toplarda hazırlık, yerleşim, düdük ve vuruş aşamaları. Serbest vuruşta mesafeye göre 3–5 kişilik baraj, rakipler için en az 9,15 m ve hücumcularla baraj arasında en az 1 m açıklık; yakın endirekt vuruşta kale çizgisi istisnası. Kaleci barajın açık tarafını kapatır; baraj şutta fiziksel gövdesiyle sıçrar. Uzaktaki serbest vuruşlarda pas yerleşimi kullanılır.
- Duran top hazırken sol/sağ yön tuşları nişanı ayarlar; S pas, A orta, D şut için basılı tutup bırakılır. Serbest vuruşta az güç daha yavaş ve yüksek yay çizen bir şut, fazla güç daha sert bir vuruş üretir. Penaltı D ile kullanılır. Oyuncu vuruşu seçmeden top yeniden oyuna girmez; rakip takım da hazırlık aşamasından geçer.
- Kornerde yakın/uzak direk koşu yerleri ve adam paylaşımı; kale vuruşunda kale alanı içinden kullanım ve rakiplerin ceza sahası dışında beklemesi; taçta çizgi üzerinde, iki elle baş üstünden fiziksel atış ve 2 m rakip mesafesi. Penaltıda 11 m noktası, çizgide kaleci, ceza sahası/yay dışında ve topun gerisinde oyuncular.
- Pas/vuruş anına göre ofsayt konumu, topa katılınca endirekt vuruş; taç, korner ve kale vuruşundan doğrudan alışta ofsayt istisnası. Savunmacıdan tesadüfi sekme veya kaleci kurtarışı önceki ofsaytı kaldırmaz. Yeniden başlatan oyuncunun çift dokunuşu endirekt vuruştur; taç/endirekt vuruştan doğrudan gol sayılmaz, doğrudan kendi kalesine duran top korner olur.
- Kayarak müdahalede temas sırası: topa önce dokunmak ile rakibe önce çarpmak ayrılır. Ceza sahasında rakibe faul penaltıdır. Yapay zekâ da müdahale yapabilir. Kontrolsüz arkadan müdahale sarı kart; basitleştirilmiş tekrarlı faul eşiği her üçüncü faulde sarı karttır. İkinci sarıda oyuncu oyundan çıkar, takım eksik kalır; yediden az oyuncuda maç bitirilir.

- Kamera ekranı kaplayan dikey sahada topu ve oyuncuyu yumuşakça takip eder.
- Göz yormayan, düşük kontrastlı çim şeritleri; mesafeye göre azalan ince doku, mat yüzey ve yumuşatılmış aydınlatma.
- Oturan, ayakta duran ve tezahürat yapan seyirciler; farklı kıyafetler, ten/saç tonları, hafif bağımsız hareketler, koyu koltuklar, merdivenler, korkuluklar ve taraftar pankartları.
- Tehlikeli atakta ayağa kalkmaya başlayan tribünler; şut ve kurtarış tepkileri, golde kolları kaldırıp zıplayarak sevinme. Ev sahibi golünden sonra tribün boyunca sırayla ilerleyen Meksika dalgası; yakın skorlu maçın son bölümündeki baskıda artan destek. Deplasman bölümü kendi takımına sevinir; gol kamerası tribünü göstermek için hafifçe genişler.
- İkinci kat tribünlerle yaklaşık 6.700 seyirci, katlar arasında dolaşım alanı, köşe merdiven blokları ve camlı dış cephe. Köşeleri birleşen çelik makaslı çatı, ışık geçiren ön şerit ve çatı altı projektörleri. İki kulübenin arasında tribünün içine açılan oyuncu tüneli; saha kenarı yayın kameraları, giriş kapıları ve stadyum meydanı.
- Kale arkasında maç skorunu ve saatini takip eden iki tabela. Açılış menüsünde yavaş hareketli stadyum panoraması; maçta yukarıdan takip kamerası.
- Kale ağları, reklam panoları, kulübeler ve dinamik gölgeler.
- İki takım için şeffaf çatılı yedek kulübeleri; yedişer yedek, teknik direktör, yardımcı antrenör ve sağlık görevlisi. Teknik direktör dolaşır ve yön gösterir; yedekler tehlikeli atakta doğrulur, golde öne çıkıp alkışlar veya sevinir, yenilen gol ve kaçan fırsatta başlarını tutar. Tepki bitince yerlerine dönerler. Takım renkli koltuklar, antrenman yelekleri, taktik panosu, su şişeleri ve sağlık çantaları.
- Bel, diz ve dirsek eklemleriyle koşu; hızlanırken öne eğilme, dönüşlerde ağırlık aktarımı, yere basan destek ayağı ve vuruş takibi.
- Kaleciler topa dönük çömelir; şutun yönü/yüksekliğine göre sıçrar, eldivenlerini uzatır, yere iner ve kalkar. Kurtarış erişimi eldiven ve gövde konumuyla sınırlıdır.
- Kayarak müdahale ve çim üzerinde kayma izi.
- 0.43 kg kütleli `RigidBody3D` top; yerçekimi, hava direnci, yer sürtünmesi, falso ve sürekli çarpışma algılama. Top oyuncunun konumuna yapıştırılmaz; ayak dokunuşlarıyla ilerler.
- Yakın ayak temasında sınırlı itkiyle top sürme ve ilk kontrol; topun mevcut momentumu korunur. Pas hızı, uçuş süresi, alıcının koşusu ve rakibin araya girme ihtimali hesaba katılır. Yapay zekâ pası karşılamak için hareket eder ve ilk kontrolden sonra karar verir.
- Fiziksel kale direkleri ve üst direk; arka, yan ve üst filelerde sabit kenarlı yay ağı. Topun temas noktası esner, hareket komşu ağ noktalarına yayılır; sönümleme topun enerjisini azaltır. Çizilen file ve top teması aynı deformasyonu kullanır.
- Gol için topun tamamı kale çizgisini, direklerin arasından ve üst direğin altından geçmelidir.
- Pozisyon alan, paslaşan ve şut çeken iki takım; kaleci atlayışları ve çelmeler.
- Taç, korner, kale vuruşu, müdahaleden doğan serbest vuruş ve gol sonrası yeniden başlama.
- Şut, pas, kurtarış ve topa sahip olma sayacı; sonuç, duraklatma ve tekrar oynama ekranları.
- Antrenman modu, top hızı göstergesi, radar, enerji ve şut gücü göstergesi.
- Prosedürel tribün atmosferi, topa vuruş, düdük ve gol sesleri.
- Seremoniden maç sonuna kadar görev yapan siyah formalı orta hakem ve iki bayraklı yardımcı. Orta hakem oyunu takip eder; düdük, yön, penaltı, endirekt vuruş ve kart işaretlerini gösterir. Kart gösterimi bitmeden duran top kullanılamaz; ikinci sarıdan sonra kırmızı kart gösterilir. Endirekt vuruşta kol, başka bir oyuncunun topa temasına kadar havada kalır.
- Yardımcı hakemler kendi taç çizgilerinde top ve ikinci son savunmacının oluşturduğu ofsayt çizgisini izler. Ofsayttaki oyuncu topa müdahale ettiğinde bayrağı kaldırıp ihlalin yakın/orta/uzak bölgesini gösterirler; taç, korner ve kale vuruşunda ilgili işareti verirler. Hakemler topa ve oyunculara fiziksel engel olmaz; antrenmanda görünmezler.

Kariyer/transfer, devre arasında kale değişimi, çevrimiçi çok oyunculu mod ve gol tekrarı bu sürümde bulunmuyor. Kural sistemi henüz avantaj, elle oynama, doğrudan kırmızı kart ve oyuncu değişikliği içermiyor. Ofsayt gövde konumu ve topa temas üzerinden değerlendirilir; kalecinin görüşünü kapatma gibi temassız müdahaleler ayrıca modellenmez. Kaleci ve top sürme yardımları oynanabilirlik için ayarlanmış oyun davranışlarıdır.

Duran top kuralları için [IFAB serbest vuruş](https://www.theifab.com/laws/latest/free-kicks/), [penaltı](https://www.theifab.com/laws/latest/the-penalty-kick/), [taç](https://www.theifab.com/laws/latest/the-throw-in/), [kale vuruşu](https://www.theifab.com/laws/latest/the-goal-kick/) ve [ofsayt](https://www.theifab.com/laws/latest/offside/) esas alındı. Mesafeler oyun sahasının metre ölçeğindedir.

## Doğrulama

Destek koşuları ve iki yönlü bindirme, verkaç tetikleme, gerçek Z/V/E/F/Q girdileri, top koruma/çalma, faul, kaleci açı/çıkış/orta/tutma/dağıtım ve güvenli çelme: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/gameplay_depth_check.gd`. Animasyon görüntüleri için headless olmadan `-- --visual` ekle.

Sıkı top sürme, sprint, 90°/180° dönüş, duruş, şutta bırakma, sert topu yakalamama ve rakibin topu kazanması: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/close_control_check.gd`.

İki takımda gol kutlaması, fiziksel zıplama/toplanma, mola, kesintisiz top taşıma, yasal santra dizilişi, S ile başlama ve rakibin santrası: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/goal_celebration_check.gd`. Gerçek oyun kamerası, yakın plan kutlama ve santra görüntüleri için headless olmadan `-- --visual` ekle.

Filenin iç arka köşesindeki topa ulaşma ve santraya dönerken karşılaşan oyuncuların birbirinin yanından geçmesi: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/kickoff_corner_check.gd`.

Hakem takibi, iki yardımcıdaki ofsayt çizgisi, gerçek topun hakemden etkilenmeden geçmesi, bayrak/kart sırası, endirekt işareti, mola ve seremoni devamlılığı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/referee_check.gd`. Yakın plan işaretler: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/referee_visual.gd`. İşaretler için [IFAB beden dili, iletişim ve düdük rehberi](https://www.theifab.com/laws/latest/guidelines/body-language-communication-and-whistle/) esas alındı.

Şut hazırlığı/savuruşu, nişanın korunması, kontrollü kamera tepkisi, temiz/kusurlu müdahale ayrımı, fiziksel itme, düşüp toparlanma ve ses kapatma: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/impact_check.gd`. Yakın plan görüntüler: `godot --path . --fixed-fps 120 --disable-render-loop --script res://tests/impact_visual.gd`.

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

File teması, sert/yumuşak şut, yan/üst ağlar, sönümleme ve iki kale: `godot --headless --path . --fixed-fps 120 --script res://tests/net_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Oyuncu eklemleri, kaleci sıçrama/iniş/kalkış ve kurtarış erişimi: `godot --headless --path . --script res://tests/motion_check.gd` (görsel kontrol için headless olmadan `-- --visual`).

Şut hassasiyeti ve nişan/gösterge tutarlılığı: `godot --headless --path . --script res://tests/shot_control_check.gd`

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
- `scripts/passing.gd`: hareketli alıcıya pas yörüngesi ve pas yolundaki rakip riski.
- `scripts/goal_net.gd`: yay ağı simülasyonu, deforme ağ geometrisi ve top ile karşılıklı kuvvet aktarımı.
- `scripts/footballer.gd`: oyuncu modeli, hareket ve animasyon.
- `scripts/stadium.gd`: saha, kaleler, tribünler, ışık ve çevre.
- `scripts/stadium_architecture.gd`: üst tribünler, çatı makasları, dış cephe, tünel ve canlı skor tabelaları.
- `scripts/sidelines.gd` ve `scripts/sideline_actor.gd`: kulübeler, teknik ekip ve maç olaylarına bağlı eklem animasyonları.
- `scripts/crowd.gd`: verimli toplu çizimle farklı pozlarda seyirci ve koltuk modelleri.
- `scripts/hud.gd`: menüler, skor, radar ve oyuncu göstergeleri.
- `scripts/audio.gd`: ses sentezi.
- `shaders/`: çim ve ağ malzemeleri.

Referanslar: [NSS 3 maç ekranı](https://www.gamewatcher.com/games/new-star-soccer-3/screens), [Godot RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html).
