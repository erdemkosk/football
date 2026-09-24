# STARTING ELEVEN FC — SEFC

Godot ile üstten bakışlı, NSS 3'ün saha odaklı maç görünümünden esinlenen 11'e 11 futbol oyunu. İlk 2D çizim sürümü yerine 3D saha, animasyonlu oyuncular ve bağımsız bir fizik topuyla yeniden kuruldu. Modeller ve malzemeler proje içinde üretilir; stadyum ve alkış için kullanıcı tarafından sağlanan üç MP3 projeye dahildir. Ek indirme veya eklenti gerekmez.

SEFC arması ana menüde, açılış ekranında, ayar/takım/kadro başlıklarında ve maçın yayın bandında kullanılır. Koyu yeşil, krem ve altın renkli armanın ana dosyası `assets/branding/sefc-crest.png`; macOS Dock/Finder simgesi `sefc.icns`, Windows görev çubuğu/EXE simgesi `sefc.ico` dosyalarıdır. Proje adı, pencere başlığı ve uygulama paketleri **STARTING ELEVEN FC** adını kullanır. Yeni isimle henüz ayar kaydı yoksa eski sürümün ses ve tuş tercihleri okunur; sonraki kaydetme yeni oyunun kullanıcı klasörüne yapılır.

Oyuncuların omuz/bel ayrımı, kaleci eldivenleri ve kaptan pazubandı uzak kamerada kimliği belirginleştirir. İsim ve kontrastlı numara aynı forma dokusuna işlenir. Takım ve kaleci renkleri birlikte seçilir; benzer formalarda diğer takımın alternatif veya kontrast forması kullanılır. Tribün blokları kulüp renklerini, deplasman köşesi rakip renklerini taşır. Ayak altındaki kısa gölgeler ve yüksekliğe göre yumuşayan top gölgesi zemindeki konumu gösterir; ıslak çimde hafif bacak yansımaları, yerdeki vuruşlarda kısa çim/çamur sıçraması görünür. Kir diz, çorap ve forma eteğinde maç boyunca birikir; yeni maç ve oyuna giren yedek temiz başlar. Altıpas aşınması, gölgeli file ipleri, yavaş kayan LED bantları ve dördüncü hakemin kırmızı/yeşil numaralı değişiklik panosu yayın görünümünü tamamlar. Değişiklik yayın şeridi 5,5 saniye görünür. Görsel ve canlı maç kontrolü: `godot --path . --script tests/match_presentation_check.gd -- --visual`.

Gökyüzü öğlen, akşam ve gece paletleriyle ince bir gradyan ve farklı hızlarda kayan iki bulut katmanı kullanır; yağmur bulut örtüsünü artırır. Gece projektörlerinde sınırlı HDR parlama, ıslak çimde kameraya göre seçilen tek bir ışık yansıması vardır. İki tribün tabelası ortak maç saati hesabıyla normal süreyi, ilave süreyi ve uzatmayı gösterir; gol tekrarında kaydedilen skor ve saate döner, tekrar bittiğinde canlı veriyi geri getirir. Kulübelerde havlu, yelek ve matara taşıyıcıları; kenarda mevcut top ölçeğinde altı yedek top bulunur. Eşyalar fizik engeli oluşturmaz. Gol tekrarı ekranın tamamına uyan ince üst/alt bantlar ve hafif gren kullanır; duraklatma ve menülerde efekt kapanır. Görsel, saat ve tekrar yaşam döngüsü kontrolü: `godot --path . --rendering-method mobile --script tests/stadium_atmosphere_check.gd -- --visual`. Gökyüzü ve parlama uygulaması için [Godot gökyüzü shader belgeleri](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/sky_shader.html) ve [ortam efektleri belgeleri](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html#glow) esas alındı.

## Başlat

**Bire bir atölyesi ve temel çalımlar:** Antrenman menüsündeki dördüncü seçenek sabit rakip, müdahale eden rakip ve serbest savunmacı aşamalarını açar. İki başarılı geçiş bir sonraki aşamaya götürür; `F3` / `LT + R3` aşamayı değiştirir, `R` / `R3` denemeyi yeniler. `2 + yön` / sağ analog yana: **yana çek**; `9` / sprint tuşu + sağ analog geri: **dur–kalk**; `0 + yön` / sprint tuşu + sağ analog yana: **aç ve dolaş**. Son harekette top seçilen yana, oyuncu diğer yana gider; rakip fiziksel topu kazanabilir. Bu üç hareket topu yalnızca ölçülen ayak temasında yönlendirir. Hazırlıkta pasla vazgeçilebilir; temas başladıktan sonra hareketin bitmesi beklenir. Enerji, toparlanma ve top erişimi nedeniyle reddedilen girişler oyuncu kartının üstünde açıklanır. AI da aynı hareketleri kullanır; hareketlenen pas seçeneği varken topu saklayıp baskıyı çekebilir, en fazla 0,65 saniye sonra veya ikinci baskı geldiğinde yeniden karar verir. Doğrulama: `tests/ground_skills_check.gd` ve `tests/ai_hold_play_check.gd`.

Maç hissi güncellemesi: koşu adımları çarpışma sonrası gerçek yer değiştirmeyi izler; frenlemede kısa denge adımı ve temas şiddetine göre gövde tepkisi vardır. Yavaş yer toplarında taban, sert paslarda ayak içi kontrol kullanılır; kaçan ilk kontrolün sebebi oyuncu kartında kısa süre görünür. Falsolu vuruşlarda iç ayak hareketi, vuruş gücü ve dönüş açısına göre kısa hazırlık uygulanır; top yine gerçek ayak temasında çıkar. Kalecinin alçak kurtarıştan kalkışı tek diz üzerinden ilerler. Oyuncu değişiminde kısa seçim halkası ve kontrastlı isim etiketi vardır. Kamera hızlı hücumlarda sınırlı ileri bakış ve genişleme kullanır. Kaçan şut tepkisi tribünün şut beklentisini sonlandırır. Maç sonu şut/isabet, pas, kurtarış ve topa sahip olma verilerini gösterir; **Tekrar oyna** aynı takımlarla doğrudan yeni maç başlatır. İsabet, gol olan veya kalecinin durdurduğu kale yönündeki kayıtlı şutlardan sayılır; tutulan ortalar dahil edilmez. Kontrol: `godot --headless --path . --script tests/match_feel_check.gd`.

Godot 4.3+ ile `project.godot` dosyasını aç ve **F5** tuşuna bas. Godot 4.7.2 / macOS üzerinde doğrulandı.

FPS incelemesi, uygulanan CPU optimizasyonları ve tekrarlanabilir ölçüm komutları
[performans notlarında](tests/performance_results.md) bulunur. Grafik benchmark'ı
gerçek kare süresini ölçer; fizik hızı 120 Hz olarak korunur.

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

Hızlı Maç, büyük kulüp kartları, forma önizlemeleri ve hücum/orta saha/defans güç çubuklarıyla seçim sırasını gösterir. İki takım onaylandıktan sonra taktik ekranı sağ alttaki **Maça Başla** düğmesine odaklanır; tek A / × ile devam edilir. Maç içindeki kadro ekranı ise seçili oyuncuya açılır. Skor, oyuncu kartı, mini harita ve köşe düğmeleri gerçek ekran kenarlarını izler; menüler ortalanmış kalır.

Gol tekrarı sabit kamera tarafı, yatay ufuk, sınırlı kamera hızı ve kısa kararma geçişleri kullanır; gol çizgisi geçişi kamera kesmesine denk getirilmez. Golcülerin beş farklı sevinci vardır, takım arkadaşları farklı jestlerle katılır. Oyuncular ve yedekler ilk kareden canlı duruşla başlar; giriş, selamlaşma ve koşu geçişleri mevcut pozdan karışır. Top korurken arkadaki baskıya göre dirsek bükülür. Koşu adımları yeni model boyuna göre ayarlanır, vuruş sonrası ayak gövdenin gerisinde takılı kalmaz.

Pas ve şut nişanı kısa, saydam yön göstergesi ve ayrı güç çubuğuyla okunur. Ara pas yarışında AI topun ve rakibin hareketine göre, enerjisi izin verdiğinde sprint yapar. Ulaşılabilir havadan toplarda şut isteği kısa yaklaşma desteği alır; top erişim dışına saparsa boş vuruş iptal edilir ve hareket sürer. Kaleciler göğüs hizasındaki uygun topları iki elle karşılar. Ayakta müdahalede topun görünür ayağa yaklaşması gerekir; yalnızca oyuncunun yakınından geçmek topu uzaktan kapmaya yetmez.

Ana menüde mevcut uzak stadyum açısının arkasında iki yapay zekâ takımı canlı maç oynar. Gerçek top fiziği, paslar, şutlar, hakemler, tribün tepkileri, gol sevinci ve duran toplar çalışır; kamera maç sırasında yakın plana geçmez. Maç bitince yenisi başlar. Ayarlar bu gösteri maçını duraklatır; Hızlı Maç ise skor, süre, kondisyon ve kartları temizleyerek kendi maçına hazırlanmanı sağlar.

Stadyumun çevresinde 52 detaylı bina, balkonlar, dükkân vitrinleri ve tenteler, çatı klima üniteleri, paneller ve su depoları bulunur. Kesintisiz yollar, kavşaklar, yaya geçitleri ve kaldırımlar mahalleyi birbirine bağlar. Otoparklarda ve yol kenarında takım otobüsleri dahil 92 araç; yollarda iki yönde dolaşan 28 araç vardır. Giriş meydanları, gişeler, duraklar, banklar, 58 ağaç ve 126 taraftar çevreyi doldurur. Gece pencereler, farlar ve sokak lambalarının zemindeki aydınlığı açılır. Dış çevre için ek gölgeli ışık kullanılmaz; 35 binden fazla sabit parça 145 yerel çizim grubunda birleştirilir. Hareketli trafik yalnızca uzak menü/hazırlık görünümünde güncellenir, molada durur. Saha kamerası ve arka plandaki maç korunur.

Maç iki adet iki dakikalık yarıdan oluşur. İlk yarının ve varsa uzatmasının sonunda 20 saniyelik devre arası vardır; Enter veya ekrandaki düğmeyle geçilebilir. İkinci yarıda takımlar kaleleri değiştirir, seçtiğin rakip santrayla başlar. Devrede oyuncular 20 yüzde puan enerji kazanır; skor, kartlar ve istatistikler korunur. Antrenmanda devre arası yoktur.

Normal maçlar tünel çıkışıyla açılır: üç hakemin arkasında iki sıra hâlindeki 22 oyuncu sahaya yürür, takımlar tribüne dönüp selam verir ve santra dizilişine koşar. Kamera çıkış, takım sunumu ve saha görünümü arasında geçer; maç saati ilk düdükte başlar. **Space** veya **Enter** ile herhangi bir aşamayı tek tuşta atlayabilirsin; ekrandaki “Seremoniyi geç” düğmesi de çalışır. **Esc** töreni duraklatır. Antrenman ve F2 serbest vuruş denemesi doğrudan başlar. Antrenmanda top dışarı çıktığında yeni top beklenirken oyuncuların hareketleri durmaz; koşu ve vuruş pozları doğal biçimde beklemeye döner.

Golde golcü tribüne doğru koşar; diğer dokuz saha oyuncusu etrafında toplanıp kollarını açarak ve fiziksel olarak zıplayarak kutlar. Diğer takım arkadaşları alkışlar, rakipler üzülerek geri döner. Kamera kutlamaya yaklaşır; küçük gol bandı sahanın altındadır. Golü atan takımın taraftarları 19 saniyelik tepki boyunca ayağa kalkıp belirgin biçimde zıplar; kulübeler de kutlamaya katılır. Ev sahibi golünde tribün dalgası devam eder.

Kutlamadan sonra topun durduğu son konuma en yakın oyuncu aynı fiziksel topu alır; kendisi santrayı kullanmayacaksa merkezde bekleyen oyuncuya atar. Santrayı golü yiyen takım kullanır. İki takım kendi yarı sahasına döner; rakipler santra çemberinin dışında bekler. Top merkezde durup diziliş tamamlanınca düdük gelir. Santra Kıyı Spor'daysa **S'ye basıp bırakarak** başlat; rakipteyse rakip pasla başlar. Gol sonrası oyuncular ve top ışınlanmaz, maç saati kutlama/hazırlık sırasında ilerlemez. Antrenman doğrudan yeni şut denemesine döner.

## Hızlı maç, kadro ve ayarlar

Hızlı Maç sırası: **Takım ve rakip seçimi → İlk 11 ve taktik → Seremoni → Maç**. Sekiz kurgusal kulübün ayrı isimleri, kadroları, armaları ve iki forma seçeneği bulunur: Kıyı Spor, Atlas FC, Demirspor, Güneş FK, Orman Birliği, Kuzey Yıldızı, Liman Athletic ve Kapadokya SK. Formayı 3D oyuncu üzerinde görürsün; isimler, formalar, yayın grafikleri ve stadyum tabelaları seçime göre güncellenir.

Kadro ekranında ilk 11, kulübün formalarını taşıyan kartlarla saha üzerine yerleşir; yedi yedek altta birlikte görünür. Analog/D-pad veya yön tuşlarıyla gezdiğin kart **turkuaz çerçeveyle** gösterilir; sağ panel o oyuncuyu izler. **A / PlayStation çarpı / Enter** ile çıkacak oyuncuyu seç: kartı altın renkte sabitlenir ve odak uygun yedeğe gider. Yedeği seçtikten sonra karşılaştırmayı kontrol edip **Değişikliği onayla** düğmesine bas. Yalnızca gezinmek oyuncu veya taktik değiştirmez. **B / daire / Esc** önce onay adımından, sonra oyuncu seçiminden geri döner. **LB/RB** kadro ile oyun planı arasında son odağı korur; plan seçenekleri yalnızca onaylayınca uygulanır. Fareyle de aynı seçim/onay akışı kullanılır; formaları saha ile kulübe arasında sürükleyerek doğrudan değiştirebilirsin. **Xbox X / klavye Z** son değişikliği geri alır; bekleyen değişikliği sağdaki düğmeden tek tek iptal edebilirsin. Maç öncesindeki ilk 11 düzenlemesi maç içindeki üç değişiklik hakkını tüketmez. Diziliş, pres, oyun anlayışı ve savunma çizgisi ayrı taktik bölümündedir.

**K / Xbox View** maç sırasında kadro ve taktik ekranını açar. **P** veya ana menüdeki **Ayarlar** düğmesi yalnızca ses, kontrolcü, tuş atama ve görüntü/oyun tercihlerini açar. Kadro ayarlarda bulunmaz. İki ekran da maç saatini ve fiziği duraklatır; fare, Tab/yön tuşları ve Xbox sol analog/D-pad ile kullanılır. **A** seçer, **B/Esc** geri döner. Ana menü, antrenman, hava seçimi, takım/forma seçimi, kadro/taktik, mola, devre arası ve maç sonu ekranları da tamamen kontrolcüyle kullanılabilir. Seçili düğme belirgin bir çerçeveyle gösterilir; geri dönünce seçim korunur.

Ayarlarda **sol/sağ** ses ve analog çubuklarını veya seçenekleri değiştirir; **yukarı/aşağı** satır değiştirir. **LB/RB** ayar bölümleri arasında, kadro ekranında ilk 11 ve taktik planı arasında geçer. **View** hazırlık ekranından ayarları açar. Uzun tuş listesi seçili satıra kayar. Xbox tuş ataması sırasında **View/Start** iptal eder (B oyuna atanabilir); klavye atamasını **B** ile de iptal edebilirsin. Analog menülerde kontrollü tekrar yapar; ekran geçişinde yeniden merkezlenene kadar seçimi kaydırmaz. Menü A/B işlevleri oyun içindeki özel tuş atamalarından bağımsızdır.

- **Kadro:** Yedi yedek, maç başına üç değişiklik. Kaleci kaleciyle değiştirilir; ihraç edilen oyuncu değiştirilemez. Değişiklikler ilk duraklamada gerçekleşir. Oyuncu kenara hızlı koşar; yeni isim ve forma numarasıyla yedek sahaya girer. Bu çıkışlarda kondisyon harcanmaz. Rakip de yorgun oyuncularını değiştirebilir.
- **Taktik:** 4-4-2, 4-3-3 veya 3-5-2; savunmacı/dengeli/hücumcu anlayış, pres yoğunluğu ve savunma çizgisi. Zorluk rakibin karar süresini, pas isabetini ve baskısını değiştirir.
- **Ses ve kontrol:** Stadyum, alkış ve davul seviyeleri bağımsızdır. Analog hassasiyeti, ölü bölge, titreşim ve gol tekrarı ayarlanabilir.
- **Tuş atama:** Oyun hareketleri klavyede ve Xbox tuşlarında yeniden atanabilir; çakışmalar yer değiştirir. Yön tuşları, sol analog ve menü kısayolları sabittir. Ayarlar Godot kullanıcı klasöründeki `match_settings.cfg` dosyasına kaydedilir.

Gol sonrası son beş saniye 0.8× hızla gösterilir. **Space / Enter / A** geçer; canlı maçın konumları geri yüklenip takım kutlaması devam eder. Tekrar fizik kararlarını veya skoru yeniden çalıştırmaz.

Top fileye gerçekten değdiğinde kısa bir top/örgü sesi, vuruş hızına göre kol titreşimi ve hafif kamera darbesi oluşur. File darbeyi çevreye yayıp geri salınır; bağlantıları sabit kalır. Yavaş gol ile sert şut farklı tepki verir. Golün ilk anında kamera topu ağın içinde takip eder; tribün alkışı ayrı kanalda devam eder. Mola file fiziğini ve sesi birlikte durdurur, tekrar kaydedilmiş ağ hareketini gösterir.

Hakem, avantajlı bir takım arkadaşı topu aldığında oyunu üç saniye sürdürür; avantaj kaybolursa ilk faul noktasına döner. Gereken sarı kart sonraki duraklamada gösterilir. Yüksek hızlı ve topa ulaşmayan ağır arkadan müdahaleler doğrudan kırmızıyla cezalandırılır. Duran top ve kutlama süreleri, dört dakikalık maç temposuna uyarlanmış en fazla altı gösterge dakikası ilave süre üretir; mola ve tekrar ilave süre kazandırmaz.

## Kariyer modu

Ana menüde **Kariyer** düğmesine gir, üç kayıt yuvasından birini seç ve kulübünü belirle. SEFC Premier Lig ve SEFC Birinci Lig, farklı güçlere ve formalara sahip toplam **36 kurgusal kulüp** içerir. Her ligde 18 takım, çift devreli 34 haftalık sezon vardır. İlk üç alt lig takımı yükselir, üst ligin son üçü düşer; sezon ödülleri, yeni fikstür ve sezon arşivi bir sonraki yıla taşınır.

**Lig & Kupalar** ekranından on ligi ve üç kupayı takip edebilirsin. Lig tablosunda yükselme, düşme ve Şampiyonlar Kupası bölgeleri işaretlidir. Kupa maçları ligle aynı kariyer takviminde oynanır; maçlar arasında en az üç gün bırakılır. Her turnuvanın kendi gol krallığı, sonuçları, ödülü ve şampiyon arşivi vardır; kupa sonuçları lig puanını değiştirmez.

Lig tamamlandığında kulüpler bitirdikleri sıraya göre para kazanır. Şampiyonluk ödülleri oyun ekonomisindeki lig değerine bağlıdır: İngiltere €18 M, İspanya €14 M, Almanya €13 M, İtalya €12 M, Fransa €10 M, SEFC Premier €8 M, Türkiye €6 M, Portekiz €5 M, Hollanda €4 M, SEFC Birinci Lig €2 M. Diğer sıralar daha düşük ödül alır. Para hemen kasaya, %80'i de transfer harcama yetkisine eklenir; yeni sezonu beklemez. Kupa şampiyonluğu ödülünün tamamı hem kasaya hem transfer bütçesine eklenir. Seçim ve puan durumu ekranları ödülü, haberler ve gelir/gider ekranı gerçekleşen ödemeyi gösterir. Kayıt yüklemek veya yeni sezona geçmek ödülü tekrar vermez; eski kupa arşivindeki tutarlar korunur.

- **Ülke Kupası:** İki ligden 36 kulüp. Sekiz takım ön eleme oynar, 28 takım sonraki tura doğrudan geçer. Son 32'den finale kadar tek maçlı eleme; şampiyona €1,8 milyon.
- **Şampiyonlar Kupası:** Üst ligin önceki sezon ilk dördü ve 12 yabancı kulüp. Dört grupta altışar maç; ilk ikiler çıkar. Çeyrek ve yarı final iki maç, final tek maçtır. Toplam skor kullanılır, deplasman golü kuralı yoktur. Grup eşitliğinde puan, averaj, atılan gol ve sabit kulüp sırası uygulanır. Finali kazanana hemen €25 milyon; uzatma ve penaltıyla kazanmak da aynı ödülü verir.
- **Süper Kupa:** Lig şampiyonu ile ülke kupası şampiyonu karşılaşır. Aynı kulüp ikisini kazanırsa lig ikincisi katılır; kazanana €650 bin. İlk kariyer sezonunda önceki sezon bulunmadığı için Avrupa katılımı ve Süper Kupa, başlangıç kulüp güç sıralamasından belirlenir.

Eleme maçında veya rövanşın toplam skorunda eşitlik varsa **oynanabilir 2 × 15 dakika uzatma** vardır; yorgunluk, kartlar ve oyuncu değişiklikleri korunur. Eşitlik sürerse **seri penaltılarını sen oynarsın**: yön tuşları / sol analog ile hedefi ayarla, D / Xbox X / PlayStation kareyi basılı tutup bırakarak vur. Rakip kullanırken yön + şut tuşuyla kaleciyi yatır. Beşer atış, erken bitiş ve eşitlikte tekli eleme uygulanır. ESC / Start duraklatır. Ayrı penaltı skoru kaydedilir; simüle edilen maçların seri penaltıları otomatik hesaplanır. Penaltı serisi golleri maç skoruna veya gol krallığına eklenmez. Elensen bile takvim diğer kulüplerin finallerine kadar ilerler; tüm kupalar tamamlanmadan yeni sezon başlamaz.

İspanya, Portekiz, İtalya, Almanya, Fransa, İngiltere ve Hollanda'nın her birinde sekiz kurgusal kulüp ve çift devreli 14 maçlık sezon vardır. Ayrı **Türkiye Süper Ligi** ile toplam **10 lig, 110 kulüp, 2.640 başlangıç oyuncusu** bulunur. Bu liglerden birinde kariyere başlayabilir veya teknik direktör merkezinden kulüp değiştirebilirsin. İspanya, Portekiz, İtalya ve Almanya’dan ilk iki; Fransa, İngiltere, Hollanda ve Türkiye’den şampiyon sonraki Şampiyonlar Kupası’na katılır. SEFC Premier Lig’in dört temsilcisiyle birlikte turnuva 16 takım olarak kalır. Yerel iki ligdeki 18 takım / 34 hafta ve yükselme-düşme sistemi korunur; yabancı liglerde henüz ikinci kademe yoktur. Oyuncular 13 farklı milliyetten gelir. Transfer ekranında **Yabancı** veya belirli ülkeyi seçebilirsin. Milliyet transfer, kiralama ve kayıt yüklemede korunur; özellik bonusu veya yabancı kotası uygulamaz.

Önceki kariyer kayıtları otomatik güncellenir. Eski kayıt 1 Ağustos'u geçmişse mevcut lig sonuçları korunur ve yeni kupalar **sonraki sezon** başlar; yabancı oyuncu pazarı hemen açılır. Eski kayıtlara yabancı lig fikstürleri eklenir; geçmiş tarihli yabancı maçlar takvim ilk ilerletildiğinde tamamlanır.

**Merkez → Takvimi ilerlet** en fazla bir hafta veya sıradaki olaya gider. Günler kayan takvim kartlarıyla ilerler; varılan tarih, geçen gün sayısı ve yeni teklif/maç günü bildirimi belirgin görünür. Enter/Space, Xbox A/B veya PlayStation çarpı/daire geçişi atlar. Animasyonu atlamak takvimi ikinci kez ilerletmez; sonuç ana ekranda da kalır. Maç gününde **Kadroyu hazırla & maça çık** mevcut 11'e 11 fizik maçını açar; **Maçı simüle et** güç, kondisyon, taktik ve ev sahibi etkisiyle sonucu hesaplar. Diğer kulüplerin maçları takvimle ilerler. Gerçek maçın skoru, golcüleri, oyuncu değişiklikleri, yorgunluğu ve kartları aynı lig kaydına işlenir. Maçtan ayrılmak tamamlanmamış karşılaşmayı oynanmamış bırakır; kayıttan dönüşte karşılaşmaya yeniden başlanır.

- **Kadro:** Kalıcı oyuncu kimliği, mevki, yaş, boy/kilo, OVR, kondisyon, form, sözleşme ve aylık maaş. İlk 11 değiştirilebilir veya en hazır kadro seçilebilir. Yeni transferin adı, görünüşü ve yetenekleri sahada da aynıdır. Gençler gelişir, yaşlılar geriler; biten sözleşmeler serbest oyuncu oluşturur. Emeklilik ve eksilen kadrolar için altyapı oyuncuları vardır.
- **Transfer:** Temmuz–ağustos ve ocak dönemleri. İsim, mevki, bütçe, satış listesi ve serbest oyuncu filtreleri. Bonservis veya oyuncu + para takası için kulüple, maaş/süre/rol için oyuncuyla 3B ofiste ayrı görüşmeler yapılır. Karşı teklifler ve imza öncesi özet vardır. Satış listesi, gelen teklif kabul/ret ve kendi oyuncunla yıl boyunca sözleşme yenileme kullanılabilir. Rakip kulüpler de kadro ihtiyaçlarına göre transfer yapar.
- **Kiralık oyuncular:** Transfer ekranında **Kiralık listesi → Kiralık teklif** ile ofiste kiralama bedeli, süre, maaşın %50/%75/%100 paylaşımı ve isteğe bağlı satın alma opsiyonu görüşülür. Yazın yarım sezonluk anlaşma 31 Ocak'ta, sezonluk anlaşma 30 Haziran'da, iki sezonluk anlaşma sonraki sezonun 30 Haziran'ında biter. Ocakta yarım sezon seçimi de o sezonun haziranına kadardır. Bonservis asıl kulüpte kalır; oyuncu aynı kimliği ve özellikleriyle kiralayan kulübün maçlarına çıkar. Süre bitince kendiliğinden döner ve maaşın tamamı asıl kulübüne geçer. Kiralık süre oyuncunun mevcut sözleşmesini aşamaz; kulüp başına altışar gelen/giden kiralık sınırı vardır. Kiradan dönecekler dahil kadro sınırı 30'dur.
- **Kiraya verme / opsiyon:** Kadroda **Kiralık listesine koy**, gelen tekliflerde **Kabul et / Reddet** kullanılır. Rakip kulüpler de oyuncu kiralar. Kadro filtresindeki **Kiralık gelenler / gidenler** görünümünde asıl kulüp, bitiş tarihi ve maaş payı takip edilir. Opsiyon varsa transfer döneminde belirtilen bedelle aynı maaş üzerinden üç yıllık kalıcı sözleşme yapılabilir. Kiraya verdiğin oyuncuyu transfer döneminde kiralama bedelinin %25'i (en az €5.000) tazminatla geri çağırabilirsin. Bu iki işlem bedel gösterildikten sonra ikinci seçimle onaylanır. Kiralık oyuncu yeniden satılamaz, takas edilemez, başkasına kiralanamaz veya kiralayan kulüpte sözleşme yenileyemez.
- **Emeklilik:** Oyuncuya göre saha oyuncuları 34–38, kaleciler 36–40 yaş arasında bırakır. Karar son sezonun başında açıklanır ve haberler ile **Emeklilik kararı** filtresinde görünür. Oyuncu sezon sonuna kadar oynar ama satılamaz, takas edilemez, kiralanamaz ve sözleşmesi yenilenemez; eski teklifler de kapanır. 30 Haziran'dan sonra kadrodan çıkar, maaşı sona erer ve kimliği arşivde korunur. Yeni sezon eksik kadrolar altyapıdan tamamlanır. Önceki kariyer kayıtları bu alanları otomatik edinir.
- **Kulüp:** Kasa, transfer bütçesi, aylık maaş yükü, sponsor ve maç günü gelirleri, sezon ödülleri, işlem dökümü, haberler ve sezon arşivi. Transfer sonrası en az iki aylık maaş rezervi gerekir. Maaşlar sezon arasında da hesaplanır.
- **Taktik:** Formasyon, savunma çizgisi, pres, genişlik, tempo, topsuz koşu, bek bindirmesi ve ön liberonun geride kalması. Üç oyun planı kaydedilebilir; maç içinde mevcut RT + yön/F5–F7 komutları bu planları uygular. **Kadro → Detaylı oyun planı** canlı maçı durdurup ayrıntıları değiştirir. Rakip kendi kulüp planıyla başlar ve önceki adaptif yapay zekâ sistemiyle maçın gidişine tepki verir.

Hız, şut, pas, teknik, savunma ve fizik değerleri gösterge olarak kalmaz: koşu hızı, şut gücü, pas hatası, kontrol, müdahale erişimi, temas gücü ve dayanıklılığı etkiler. Kalecilerde refleks, tutuş ve pozisyon alma ayrıca kullanılır. İki takım da aynı özellik kurallarını kullanır.

**Merkez → Teknik direktör merkezi** beş yeni ekran açar:

- **Gelişim:** Altı özellik planı ve üç antrenman yükü. Dakika, form ve antrenman deneyim üretir; 100 puan bir plan özelliğini artırır. Gençler daha hızlı gelişir, potansiyel sınırı uygulanır, 32 yaş sonrası yaşlanma sürer. Yoğun eğitim kondisyon maliyeti taşır. Akademi oyuncularına da plan verilebilir.
- **Akademi:** 13 ülkeye mevki seçerek 30/60/90 günlük ücretli görev; aynı anda üç gözlemci. Rapor başına üç aday, 12 kişilik akademi ve haftalık gelişim. Uzun görev daha yüksek potansiyel getirir. Adayı bırakabilir veya maaş rezervi ve kadro kapasitesi uygunsa A takıma yükseltebilirsin.
- **Oyuncu ilişkileri:** 3B odada övgü, süre sözü, rol görüşmesi ve ayrılık kararı. Altı maçlık dakika geçmişi ile söz verilen rol karşılaştırılır. 60 günde 180 dakika sözü tutulmazsa moral düşer; ciddi memnuniyetsizlik transfer talebine dönüşebilir. Görüşme aralığı 14 gündür. Moral saha kontrolü, pas, şut ve pozisyon alma üzerinde küçük bir etki yapar.
- **Yönetim:** Kulüp gücüne göre lig hedefi, 450 akademi dakikası ve pozitif kasa. İlk 60 günden sonra aylık rapor; güven 25'in altına düşerse işten çıkarılma. Sezon başarısı transfer harcama yetkisini artırır veya azaltır.
- **Teknik direktör:** İtibarına uygun kulüplerden ülke ve takım seçerek yeni göreve geç. İlk 30 günde kulüp değiştirilemez. Kadro ve bütçe yeni kulüpten gelir; aynı dünya, takvim ve kayıt devam eder. İşsizken kulüp maçlarını yönetemezsin, takvim devam eder.

**Görüşme → Primler & sözleşme detayları:** İmza parası, maç/gol/kupa primleri, serbest kalma bedeli ve %0–30 sonraki satış payı. Primler maaş pazarlığını, satış payı bonservis talebini etkiler. İmza parası hemen; diğer primler olay gerçekleştiğinde ödenir. Sonraki satış payı nakit bonservisten eski kulübe gider. Serbest kalma bedeli satıcının bonservis talebini sınırlar; kadro derinliği ve dönem kontrolleri sürer. Genç, güçlü oyunculara rakip kulüpler süreli teklif verebilir; teklif ve son tarihi kayıt/yüklemeden etkilenmez.

Oynanan kupa finali sonrasında **madalya, sahada kupa kaldırma ve konfetiyle takım kutlaması** vardır. Lig sezonunun son kullanıcı maçında kesinleşmiş şampiyonluk için de tören açılır. Space / Enter veya koldaki onay tuşuyla geçilebilir; ödül yalnızca bir defa yazılır.

Kariyer ekranları fare, klavye ve Xbox/PlayStation kontrolcüsüyle çalışır. **LB/RB / L1/R1** sekme değiştirir; seçim değiştiğinde odak korunur. Kaydetme otomatik yapılır ve **Kariyeri kaydet** düğmesi de vardır. Godot kullanıcı klasöründeki `sefc_career_1.save`–`sefc_career_3.save` dosyaları önce geçici dosyaya yazılır; önceki tam kayıt `.bak` olarak tutulur. Hızlı maç takımları ve ayarları kariyerden çıkarken geri yüklenir.

Kariyer doğrulaması:

```sh
godot --headless --path . --log-file /tmp/sefc-career.log --script tests/career_check.gd
godot --headless --path . --fixed-fps 120 --log-file /tmp/sefc-career-flow.log --script tests/career_flow_check.gd
godot --headless --path . --log-file /tmp/sefc-contracts.log --script tests/career_contracts_check.gd
godot --headless --path . --fixed-fps 120 --log-file /tmp/sefc-loans-flow.log --script tests/career_loans_flow_check.gd
godot --headless --path . --log-file /tmp/sefc-cups.log --script tests/career_cups_check.gd
godot --headless --path . --fixed-fps 120 --log-file /tmp/sefc-cups-flow.log --script tests/career_cups_flow_check.gd
godot --headless --path . --log-file /tmp/sefc-director.log --script tests/career_director_check.gd
godot --headless --path . --fixed-fps 120 --log-file /tmp/sefc-director-flow.log --script tests/career_director_flow_check.gd
```

İlk test transfer/takas/sözleşme, maaşlar, yedekten kayıt kurtarma ve iki tam sezonu; ikincisi gerçek kol olaylarıyla menü erişimi, transfer imzası, fizik maçına giriş, canlı taktikler, gerçek oyuncu değişikliği ve kariyere dönüşü kontrol eder. Sözleşme testi emeklilik, kayıt göçü, kiralık sahipliği, maaş paylaşımı, otomatik dönüş, opsiyon, geri çağırma ve kadro sınırlarını; kiralık akış testi yeni ekranları gerçek kol olayları ve 3B maç kadrosuyla doğrular. Akış testlerinin grafik ekran görüntüleri için `--headless` yerine normal Godot çalıştırıp komut sonuna `-- --visual` eklenebilir. Testler kişisel kariyer kayıtlarını değiştirmez.

Kupa testleri tüm sezonda 97 kupa maçı, ligden ayrı puan/gol tabloları, grup dengesi, tur eşleşmeleri, rövanş toplamları, penaltı sonuçları, ödüllerin bir kez ödenmesi, sezon katılım hakları, yükselme/düşme ve eski kayıt göçünü kontrol eder. Kupa akış testi kol ile turnuva/ülke filtrelerini, yabancı transferini ve gerçek 3B maçta 90/105/120 dakika geçişlerini doğrular.

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
| Yerden sert orta | R1 + ○ tut → bırak | RB + B tut → bırak |
| Mola | Options | Start |
| Kadro / taktik | Share / Create | View |

Sol analog hareket eder; sağ analog veya yön düğmeleri koşudan bağımsız şut nişanı verir. Menülerde **×** seçer, **○** geri döner. İki kol türü aynı fiziksel düğme yerleşimini ve mevcut pas/şut fiziğini kullanır.

| Tuş | İşlev |
| --- | --- |
| Yön tuşları | Hareket; son hareket yönü şut yönüdür |
| W + yön tuşu | Stamina harcayarak sprint; yorulunca W'yi bırakıp toparlan |
| S basılı tut → bırak | Top sendeyken pas gücü ve hedef → vuruş; kısa dokunuş yakın pas. Topsuzken pas iste |
| A basılı tut → bırak | Orta gücünü ve yönünü ayarla, bırakınca vur; W + A yerden sert orta. Topsuzken havadan pas iste |
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
| Q | Topa yakın uygun oyuncuya geç; sonraki hedef içi boş okla gösterilir |
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

**B / ○ basılı tut → bırak — orta:** Basılı tutarken gücü ve sol analogla yönü ayarla; tam güce ulaşsa bile bıraktığın ana kadar vurmaz. **RB + B / R1 + ○** aynı kontrolle yerden sert orta açar. Klavyede **A**, yerden orta için **W + A** kullanılır. Mola, top kaybı veya bağlantı kesilmesi hazırlığı iptal eder. Topsuz B / ○ kayarak müdahale olarak kalır.


İlk yarı, seremoni tamamlandığında veya atlandığında **santra vuruşuyla** başlar. Top orta noktada bekler; takımlar kendi yarısında, rakipler merkez çemberinin dışında yerleşir. **S / Xbox A / PlayStation çarpı** ile ilk pası verene kadar maç saati ilerlemez. Seremoniyi geçme tuşu aynı anda pas vermez. İkinci yarıya rakip santrasıyla devam edilir.

Kıyı Spor beyaz-yeşil formayla ilk yarıda **yukarıdaki**, ikinci yarıda **aşağıdaki kaleye** hücum eder. Takım kontrolü varsayılan olarak açıktır: S/A/Y pasından sonra alıcıya, topu kazanan takım arkadaşına ve savunmada belirgin biçimde daha uygun oyuncuya geçilir. LB/Q ile yaptığın seçim kısa süre korunur; kontrol işareti yakın oyuncular arasında sürekli atlamaz. Gelen pasta analog/yön girişi yoksa alıcı topu karşılar; yön verdiğinde hareket kontrolü tamamen sendedir. Tab ile tek oyuncuda kalma açıldığında pas sonrası kontrol değiştirilmez; pas verip boşa koşarak yeniden isteyebilirsin. Topsuzken S/A oyuncu değiştirmez: el kaldırıp pas istersin. Takım arkadaşın yaklaşık üç saniye içinde uygun pas yolunu arar; koşuna göre topu önüne bırakır, gerekirse havadan oynar. Markajdaysan boşa çıkmalısın. Rakip pası kesebilir; gelen top fiziksel olarak kontrol edilir.

Otomatik seçim pasın gerçek hızı, yüksekliği, falso ve zemin direncine göre topu karşılayabilecek oyuncuya uçuş sırasında geçer. Top başka bir takım arkadaşına değerse, kontrolü tam sağlayamasa bile seçim hemen ona aktarılır; ilk kontrol animasyonu, müdahale sonrası bekleme ve önceki LB seçimi bunu geciktirmez. Yakın oyuncular arasında kararsız geçişler önlenir; gerçek temas olmadığı sürece manuel seçim ve hazırlanmış kafa/vole korunur. `tests/auto_selection_check.gd` uçuş tahmini, yerden/göğüs kontrolü, seken top ve gerçek fizik çarpışmasını doğrular.

Top rakipteyken veya boşta yavaş ilerlerken otomatik seçim, topa yakın ve müdahale edebilecek oyuncuyu önceler; 8 metre uzaklaşma / 5 metre avantaj şartı yoktur. Yakınlıkla birlikte topun kısa süre sonraki konumu, oyuncunun hareket yönü ve kondisyonu değerlendirilir. Küçük mesafe farkları seçim değiştirmez; belirgin bir müdahale fırsatında beklenmez. Yerde kalan veya ihraç edilen oyuncu atlanır, yakın mesafede başlamış müdahale tamamlanır. **LB / L1 / Q** aynı yakın oyuncu sıralamasını kullanır; sol analog ve yön tuşları bu seçimi saptırmaz. Belirli bir oyuncuya yönlü geçiş **sağ analogla** yapılır. Manuel seçim bir saniye korunur; gerçek top teması her zaman önceliklidir. `tests/defensive_selection_check.gd`, iki yarıda canlı top sürüşü, yakın savunma, kararlılık, klavye ve Xbox/PlayStation geçişlerini doğrular.

Gerçek temas, önceki oyuncunun top sahipliğini ve taşıma kuvvetini de bitirir; eski sahip bilgisi kontrolü geri alamaz. Normal hızda öne veya yana gelen paslar iki takımda da güvenilir biçimde kontrol edilir. Yorgunluk, teknik ve yakın baskı dokunuş mesafesini değiştirir; tek başına kolay pası sektirmez. Pası verenin vuruş kilidi alıcıya taşınmaz. Alçak sekmeler ayakla karşılanır; göğüs/uyluk kontrolü top ayağa inene kadar kesintisiz sürer. Arkada kalan, çok sert gelen veya zor uzanılan toplarda sekme korunur. Top gerçek fizik gövdesi olarak kalır ve rakip araya girebilir. `tests/reliable_reception_check.gd` iki takımda koşarak/ayakta karşılama, yakın pas, alçak sekme, yağmur, yorgunluk ve zor top sınırlarını gerçek fizik akışıyla doğrular.

Rakip, baskıya gelen oyuncunun görünen hızını ve yaklaşma yönünü hesaba katar. Açık kaçışta normal stamina harcayarak hızlanır, karşıdan baskıda yana döner ve güvenli pası daha erken değerlendirir. Zorluk seviyesi öngörü süresini etkiler. `tests/pressure_reception_check.gd` hızlı baskı, pasla çıkış, iki takımda fiziksel karşılama ve top sahipliği devrini doğrular.

Savunmada bir oyuncu topa çıkar; diğerleri pas yollarını ve gerideki alanı kapatır. Dengeli veya geride bekleyen kulüp, yalnızca sen topu birkaç saniye tuttun diye sürekli yoğun prese geçmez. Yüksek preste çizgiye sıkışma, açılan top ve top kaybı sonrası kısa baskı korunur; ikinci baskıcı zor seviyede yaklaşık 1,45 saniye destek verip 3,8 saniye dinlenir. Ceza alanında savunma daha sıkıdır. Yakındaki savunmacı kontrollü topa yan adımlarla yaklaşır; koşarken ters yöne dönmesi gerçek hızlanma ve ayak basma süresine bağlıdır. Zorluk, hız veya müdahale mesafesi için gizli bir avantaj vermez.

Ball roll, roulette, elastico ve scoop sırasında gövdenin çıkış adımı topun yönüyle birlikte çalışır. Bitince alçak top normal kontrole döner; rakip topu kazandığında hareketin kontrol kuvveti kesilir. Sadece top sahibinin bacaklarını temsil eden kaba gövde çarpıştırıcısı geçici olarak dışarıda tutulur; rakiplerle temas devam eder. Hareketin başarısı zamanlama, çıkış alanı, teknik, kondisyon ve savunmacının mevcut hareketine bağlıdır. AI tek rakibe karşı açık çıkışı değerlendirir, iki oyuncu arasında zorla çalım denemez; zor seviyede aynı oyuncu en az 6 saniye, takım 3,6 saniye bekler. Pas ve şut seçenekleri yine birlikte değerlendirilir. Esin kaynağı [EA FC 26'nın savunma geçişlerinde alan açma yaklaşımıdır](https://www.ea.com/games/ea-sports-fc/fc-26/news/pitch-notes-fc26-title-update-1-4-0); uygulama bu oyunun ortak top ve oyuncu fiziğine dayanır. Takım yerleşimi, sınırlı ikili pres, gerçek çalım düelloları ve başarısız denemeler: `godot --headless --path . --fixed-fps 120 --script tests/space_skill_balance_check.gd`.

Bizim takımda pas, şut ve orta kararı kullanıcıya aittir. Seçili olmayan takım arkadaşları destek koşusu, bindirme, markaj ve müdahale yapabilir; top kendilerine gelince kendiliğinden pas veya şut atmazlar. S/A ile açıkça pas istemek yine takım arkadaşına pas komutu verir. Kalecimiz topu tuttuğunda kontrol ona geçer ve dağıtım komutunu bekler. Rakip ve ana menüdeki gösteri maçının iki takımı normal yapay zekâyla oynar.

AI pasları ve kaleci dağıtımları, topun yoluna koşabilecek rakipleri ve alıcının hedefe önce ulaşıp ulaşamayacağını birlikte değerlendirir. Pas hazırlığı sırasında yol kapanırsa ayak vuruşu iptal edilir; kaleci henüz elindeyken güvenli olmayan dağıtımı bırakır. Kaleci kısa çıkış bulamazsa en fazla yaklaşık üç saniyelik beklemenin ardından iki kanattaki uzun top seçeneklerini karşılaştırır; degajın hızı seçilen mesafeye göre hesaplanır. Geri pasta da sabit yöne vurmak yerine pas/uzaklaştırma seçer. Kale vuruşu, taç, korner ve pasla kullanılan frikikler gerçek bir alıcıya göre hazırlanır; kendi yarı sahasındaki frikik şut sanılmaz. Planlı verkaçta dönüş kararı top kontrolünden sonra kısa sürede verilir; hedef, koşucunun duracağı noktayı aşmaz. Vuruştan sonra top hedefe yönlendirilmez; rakip hâlâ pası kesebilir. Kaleci el/ayak dağıtımı, kapanan pas yolu, duran top hedefleri ve kuru/yağmurlu zeminde fiziksel karşılama kontrolleri: `godot --headless --path . --fixed-fps 120 --script tests/ai_delivery_check.gd`.

Yerden pas için S'ye kısa dokunarak yakındaki oyuncuya oyna; daha uzaktaki hedef için kısa süre basılı tut. Güç 0,65 saniyede dolar ve sabit kalır. S basılıyken yön tuşları hedefi yavaşça çevirir. Varsayılan yarı yardımlı pas, yönündeki takım arkadaşına nişanı ve gerekli pas hızını dengeler; kısa basış yakını, uzun basış uzağı tercih eder. Arkandaki oyuncuya otomatik dönmez. Ayarlar → Görüntü & Oyun → Pas yardımı ile Manuel / Yarı yardımlı / Yardımlı seçilebilir. Y ile top koşan arkadaşının önündeki boşluğa bırakılır; uzun basış daha ileriyi hedefler. Ofsayttaki oyuncu otomatik ara pas hedefi olmaz. Top vuruştan sonra fiziksel yolunda gider, havada hedef takip etmez. Oyuncunun önündeki kısa ok yönü, okun doluluğu ve parçalı güç göstergesi vuruş şiddetini gösterir; pas yolundaki rakip ayrı bir uyarıyla belirtilir. S'yi bırakınca gösterilen pas çıkar. Topu kaybetmek, oyuncu değiştirmek, şuta geçmek veya duraklatmak hazırlanan pası iptal eder.

Pas, şut, orta ve duran toplar ortak bir kısa ok ve parçalı güç göstergesi kullanır. Ok zemine oturur, güçle dolar ve kameraya göre okunur bir boyutta kalır; yerden pas mint, şut altın, havadan vuruşlar açık mavidir. Uzun uçuş çizgisi, zemin izdüşümü ve vuruş öncesi kesin hedef halkası gösterilmez. Alt ortadaki küçük kart vuruş türünü, gücünü ve varsa kapalı pas yolu/yüksek şut uyarısını taşır. Gösterge yalnızca hazırlıkta görünür ve tuş bırakılınca kaybolur. Top havadayken gerçek uçuşun düşüş işareti korunur. Bu gösterimler top fiziğini, nişan yardımını veya vuruş zamanını değiştirmez. Görsel kontrol: `godot --path . --script tests/aim_indicator_preview.gd`.

Klavyede şut gücü doldurulurken sol/sağ tuşlarına kısa dokunuşlarla nişan ince ayarlanır. D bırakılınca top gösterilen yönde çıkar. Fareyle şut nişanı da yumuşak döner. Xbox'ta X basılıyken sol analog şut yönünü seçer; başlangıç yönünün çevresindeki 14 derece sınırı kontrolcü için uygulanmaz. Sol analogda tam eğimle nişan dönüşü yaklaşık %38 yavaşlatılmıştır; hafif eğim daha küçük düzeltmeler yapar. Yerden/ara/havadan pas, frikik, korner, taç ve penaltı hedeflemesi aynı hassas analog eğrisini kullanır. Analogu merkeze bırakınca hedef hemen sabit kalır; hareket hassasiyeti ayarı nişanı hızlandırmaz. Oyuncunun koşu tepkisi korunur. **D-pad veya sağ analog**, koşu yönünden bağımsız nişan verir: sol analogla sola koşarken sağa şut çekebilirsin. Bu ayrı nişanı bırakmak seçilen yönü korur; koşu yönüne geri atlamaz. X bırakıldığında top ekrandaki okun yönünde çıkar. D-pad duran toplarda da sağ/sol nişan düzeltmesi yapar. Xbox/PlayStation, 30/60/120 Hz, duran toplar ve penaltı serisi kontrolü: `godot --headless --path . --fixed-fps 120 --script tests/aim_precision_check.gd`.

Top sürme, hareketli krampon temasları ve yakın kontrol yardımıyla çalışır. Top sendeyken sönümlü bir yer kuvveti onu ayağın önünde yaklaşık yarım metre mesafede tutar; koşu adımlarında hafifçe açılıp geri alınır. Oyuncunun tekniği kontrol kuvvetini etkiler. Sprintte mesafe yaklaşık 80–90 cm’ye açılır ve kontrol yardımı azalır. Top ışınlanmaz, havaya yapıştırılmaz; rakip müdahalesi, pas/şut ve ileri açış kontrol yardımını keser. Koşuda kısa itişler, sprintte biraz daha uzun açılış, ani dönüşte iç/dış ayak veya tabanla çevirme görülür. Oyuncu topun tarafına uygun ayağı uzatır, diğer bacağa yük verir ve kollarıyla dengesini korur. Sprint bırakıldığında ve dururken ayrı yumuşatma dokunuşları topu kontrol mesafesinde tutar. Rakip **G / Xbox X** ile açılan topa müdahale edebilir. Pas/şut, düşme, uzaklaşan top ve düdük kontrolü bırakır; iki takım aynı fizik ve erişim sınırlarını kullanır.

Topla koşarken adımlar kısalır; dokunuş mevcut koşu adımından çıkar ve aynı adıma yumuşakça döner. Dönüş ve sprint değişimlerinde de dokunuş hareketi yarıda yeniden başlamaz. Destek adımı ile topa uzanan bacağın son ayak konumları kısa bir geçişle birleştirilir; oyuncunun yön ve hız tepkisi anında kalır. Ayak hareketi, gövde yüksekliği ve top hızındaki süreklilik: `tests/dribble_flow_check.gd`; `-- --visual` ile `/tmp/sefc-dribble-flow-*.png` kare dizileri kaydedilir.

Kontrol edilen top, power shot, alçak sert, dış ayak ve zamanlamalı şutun hazırlığında oyuncuyla birlikte yavaşlar. Kısa normal şut hazırlığı da bu kontrolü korur. Yardım gerçek krampon temasında biter; vuruşun hızı ve sesi o anda oluşur. Rakip topu alırsa, oyuncu darbe alırsa, top uzaklaşırsa veya hazırlık iptal edilirse yardım hemen kesilir. Koşudan ve sprintten şut, dönüşlerde bacak sürekliliği ve iptaller: `tests/carry_finish_check.gd`.

**W / RB / R1** basılı tutulunca sprint yapılır; hareket hâlinde hızlıca iki basış topu gerçek bir ayak vuruşuyla ileri açıp yakın kontrolü bırakır. Tuş atamaları değiştirildiğinde çift basış yeni sprint tuşunda da çalışır. Tek basış veya yavaş aralıklı basışlar topu bırakmaz.

**Z** ile kısa bir vücut çalımı yapıp topu yana alabilirsin; **V** topu birkaç metre ileri açar ve kontrolü bırakarak sprint yarışına dönüştürür. **E** basılıyken top yakın rakibin uzağındaki ayağa alınır, oyuncu kollarını açıp gövdesiyle korur ve yavaşlar. Rakip top tarafına geçerse yine alabilir. Topsuz E, topa dönük yan adımlarla karşılamayı sağlar. **G / Xbox X** ayakta ayağını uzatarak topu dürter; sprintte öne açılmış topa daha kolay ulaşır, ayağın dibindeki topa uzanamayan müdahale otomatik kazandırmaz ve rakibe önce temas faul doğurabilir. **X** kayma olarak kalır.

Takım arkadaşları pas yolundaki rakipleri ve boş alanı değerlendiren destek noktalarına koşar. Kanatta aynı taraftaki bek bindirir; ceza sahasında yakın direk, uzak direk, geriye çıkarılan pas ve ceza sahası yayı için ayrı koşular yapılır. Pas veren oyuncu ileri verkaç koşusuna çıkar; yapay zekâ alıcısı uygun ve ofsaytsız dönüş pasını değerlendirebilir. Kontrol ettiğin oyuncunun koşusunu sen yönetirsin. Koşular stamina kullanır, top kaybında iptal olur ve iki hücum yönünde de aynı mantık uygulanır.

Takım kimliği hızlı maçta da sahaya yansır. Kanat takımları geniş çıkış ve ortayı, pas takımları kısa bağlantı ve verkaçı, geçiş takımları ileri pası daha yüksek değerlendirir; kapalı veya ulaşılamayan pas yolları bu tercihler uğruna kullanılmaz. Rakipler kendi 4-4-2, 4-3-3 veya 3-5-2 planlarıyla başlar. Genişlik, tempo, koşu ve bek talimatları kariyer dışında da uygulanır; bindiren oyuncu ve hücum hattı dizilişteki gerçek role göre belirlenir. Kullanıcının değiştirdiği plan maç başında geri alınmaz, kayıtlı kariyer taktikleri kulüp tarzından önceliklidir.

Yerel hızlı maç kadrolarının görünen güçleri artık ayrı seviyelerdedir: varsayılan ilk on birlerde Atlas 82, Liman 66 genel güce sahiptir. Karar süresi, sonraki pası görme, destek oyuncusu seçimi, savunma hatları arasındaki mesafe ve AI vuruş hassasiyeti sahadaki oyuncuların gerçek özelliklerini kullanır. Hız ve bitirişin etkisi hızlı maçta ayrıca azaltılmaz; kalecilerde refleks, tutuş ve yerleşme değerleri bulunur. Yorgunluk karar hızını azaltır, oyuna giren yedek canlı takım kalitesini değiştirir. Zorluk oyunculara gizli koşu hızı veya garantili sonuç vermez. Aynı pozisyonda farklı tarz/kalite, iki devrede üç diziliş, yedek etkisi ve pas güvenliği: `tests/team_identity_check.gd`; aynı zorluk ve rastgelelik tohumu ile güçlü/zayıf rakiplerin fiziksel maç akışı: `tests/team_identity_flow_check.gd`.

Kaleciler top-kale açısına yerleşir, ceza sahasında ulaşabilecekleri boş topa veya yalnız kalan hücumcuya çıkar. Şuta tepki vermeleri zaman alır; yön ve yükseklik tahminleri kusursuz değildir. Sert köşe şutları ve yakın mesafeli bitirişler kaleciyi geçebilir; kurtarış için topun eldivene veya gövdeye gerçekten yaklaşması gerekir. Yorgunluk, yağmur ve görüşü kapatan oyuncular hata olasılığını artırır. Ortanın düşüşünü hesaplayıp erişilebilir topa fiziksel olarak sıçrarlar. Eldivene gelen yavaş rakip topunu tutup pas/puntla dağıtabilirler; sert topları genellikle güvenli yana çelerken bazen önlerine sektirip ikinci vuruş fırsatı bırakırlar. Rakip kalecinin tepki ve tahmin becerisi zorluk ayarına bağlıdır. Takım arkadaşının geri pası elle yakalanmaz.

Şut gücü doldurulurken koşu adımları devam eder; dururken iki ayak yerde kalır, gövde hazırlanır ve kollar denge sağlar. Tuş bırakılınca mevcut adımdan kısa vuruşa geçilir: destek ayağı yere basar, şut bacağı ileri savrulur, gövde ve kollar birlikte döner; diz toparlanıp koşuya yumuşakça döner. Güçlü şutun savuruşu daha belirgindir. Top tuş bırakıldığı anda çıkar. Vuruş gücü tok temas sesini ve kısa kamera tepkisini değiştirir. Bu geri bildirim topun hızını/yönünü değiştirmez veya zamanı durdurmaz; normal pas ayrı ve daha hafif kalır.

Kayarak müdahalede topa temiz temasla oyuncuya çarpmanın sesi farklıdır. Gövde temasında iki oyuncunun göreli hızına bağlı itme, sendeleme veya düşüp toparlanma uygulanır. Yerde toparlanırken oyuncu topu kontrol edemez; kontrol ettiğin oyuncuya darbe geldiğinde şut/pas hazırlığı kesilir ve kısa bir ekran kenarı tepkisi görülür. Temas sesleri düdükle aynı ses kanalını paylaşmaz. Faul ve kart kararı mevcut topa önce temas kurallarıyla verilir; iki takım aynı tepkileri kullanır.

Sprint normal koşudan belirgin biçimde hızlıdır. Tam enerji ve ortalama kondisyonla kesintisiz sprint yaklaşık 35 saniyede oyuncuyu yorar. Sprint tüketimi saniyede %2,6, normal koşu tüketimi %0,27’dir; normal koşuyla 120 saniyelik bir devrenin sonunda yaklaşık %68 enerji kalır. Oyuncunun kondisyon özelliği bu süreleri etkiler; enerji azaldıkça hız ve hızlanma düşer. Yorulan oyuncu yürüyüş temposuna geçer. Sprinti yeniden açmak için W'yi bırakmak ve en az %32 stamina toplamak gerekir. Durmak, yürümekten daha hızlı toparlar; göstergedeki çizgi geri dönüş eşiğini gösterir. Gol sonrası stamina dolmaz. Yeni maç ve yeni antrenman denemesi tam enerjiyle başlar; yapay zekâ da aynı kurallara tabidir.

Saha 72 × 100 metredir; önceki 64 metrelik genişliğe göre kanatlarda toplam 8 metre daha fazla alan vardır. Formasyonlar, destek koşuları, pas hedefleri, taç/korner sınırları ve saha kenarı yerleşimi bu genişliği kullanır.

Oyuncu modelleri %24 küçültülerek metre ölçeğine yaklaştırıldı: 180 cm boyundaki oyuncu sahada yaklaşık 1,80 m görünür. Kramponların yere basışı, destek ayağı, kaleci uzanışı ve oyuncu işaretleri yeni ölçüye uyar. Varsayılan kenar kamera 22 m yükseklik ve 42° görüş açısıyla daha geniş alan gösterir; menü modelleri ve portrelerin kadrajı korunur. Boy, kale oranı, ayak teması ve kamera kontrolü: `godot --headless --path . --script tests/player_scale_check.gd`. Görüntü almak için headless yerine `-- --visual` kullanılır.

## Hava ve saha

Takım seçim ekranındaki **Maç: ÖĞLEN / AKŞAM / GECE** düğmesiyle saati seç. Fareyle tıklanır; kontrolcüde analog/D-pad ile üzerine gelip **A** ile değiştirilir. Hava durumu bağımsızdır: açık, yağmurlu veya sağanak gece maçı oynanabilir. Öğlen yüksek güneş ve kısa, belirgin gölgeler; akşam daha alçak güneş, altın tonlar ve uzayan gölgeler kullanır. Gece güneş kapanır, tribün çatısındaki dört projektör grubu sahayı aydınlatır. Oyuncunun konumuna ve animasyonuna göre birden fazla gerçek gölge oluşur; tribünler ve dış çevre daha karanlık kalır. Maç saati seremonide, molada, gol tekrarında ve ikinci yarıda korunur. `godot --path . -- --night` gece seçili olarak açar; `--rain` ile birlikte kullanılabilir.

Menüde **H** ile açık hava, yağmur veya sağanak seç. Maç sırasında da H kullanılabilir: yağış birkaç saniyede değişir, zemin kademeli ıslanır ve yağmur kesilince yavaş kurur. Yeni maç seçilen havayla ve temiz iz katmanıyla başlar. `godot --path . -- --rain` sağanak seçili olarak açar.

Yağmurun sesi, rüzgâr yönünde düşen damlalar, yumuşayan ışık, ıslak çim ve birikintilerde halkalar bulunur. Kale ağızları ve aşınan bölgeler çamurlaşır. Islak sağlam çimde top daha fazla kayar; çamur topu yavaşlatır ve sekme yüksekliğini düşürür. Oyuncuların hızlanması ve yön değiştirmesi tutuşa bağlıdır; çamurda koşu hızı da biraz azalır. Bu etkiler iki takıma aynı biçimde uygulanır. Top, her fizik adımında bulunduğu zeminin yuvarlanma direnci ve hıza bağlı enerji kaybıyla yavaşlar; güç ilk hızı belirler. Düşük hızda sonlu sürede durur, kendi kendine yeniden hızlanmaz. Ortalar havada hava direnciyle, indikten sonra sekme ve yer direnciyle enerji kaybeder. Pas, orta ve duran top tahminleri aynı hava/zemin hesabını kullanır; top vuruştan sonra hedefe göre hızlandırılmaz veya frenlenmez.

Yere basan oyuncular ayak izi; kayarak müdahale ve kaleci dalışı geniş sürüklenme izi bırakır. Top çamur üzerinde ince bir iz açar; koşarken, kayarken ve top yuvarlanırken küçük su/çamur parçaları sıçrar. İzler 180 saniyede yavaşça silinir; çizim havuzu 3072 izle sınırlıdır ve dolunca en eski izi değiştirir. Düdük, gol veya yağmurun kesilmesi izleri silmez. M yağmur sesini de kapatır; mola yağmur hareketini ve izlerin yaşlanmasını durdurur. Gol tekrarında yağmur düşmeye ve sesi devam etmeye devam eder. Yağış parçacıkları görsel efekt, top ve oyuncu tepkileri yerel yüzey katsayılarıyla fizik simülasyonudur.

## Bu sürümde

- Kariyer **TAKTİK** ekranında ilk 11 solda saha üzerindedir; sağda portreli yedek kadro, güç, mevki ve kondisyon bilgileri görünür. İki oyuncuyu sırayla seçerek veya sürükleyerek değiştir; **X / Z** son kadro değişikliğini geri alır. **Y / üçgen / T** taktik ayarlarını açıp kapatır; **LT/RT / L2/R2 / Page Up–Down** kalan yedekleri gösterir. Maç içindeki **Detaylı oyun planı** da bu düzeni kullanır. Canlı değişiklikler duraklamayı bekler ve üç değişiklik sınırına uyar; bekleyen oyuncuyu seçip **X / kare / Z** ile iptal edebilirsin.
- Oyuncular için 18 saç modeli ve 7 saç rengi: kısa/dokulu kesimler, yana ayrık, geriye taralı, dalgalı, kıvırcık, afro, örgü, kısa/uzun burgu, mohawk, topuz ve at kuyruğu. Saç oyuncu kimliğine bağlıdır; forma numarası ve kadro değişikliklerinde korunur. Maç modeliyle portre aynı saçı kullanır; saç geometrileri tek yüzeyli ve ortak önbellektedir.
- Oyuncu görünümünde **10 ten tonu, 5 göz şekli ve 12 krampon renk kombinasyonu** bulunur. Göz açıklığı ve dış köşe eğimi doğal sınırlar içinde değişir; ten, göz ve krampon seçimi milliyet etiketinden bağımsız, kalıcı oyuncu kimliğine bağlıdır. Portre, transfer görüşmesi, maç modeli, oyuncu değişikliği ve kayıt yükleme aynı görünümü kullanır; altyapıdan çıkan oyuncular da bu çeşitliliği alır. Kramponların koyu tabanı ve yan renkleri tek modelde çizilir; boyutları ve topa temas noktaları değişmez.

- Düdükten sonra top düşmeye, sekmeye ve yuvarlanmaya devam eder. Taç, korner, faul, penaltı, kale vuruşu ve santrada topun son konumuna en yakın oyuncu seçilir; düdük anında yakında olan oyuncu uzaklaşan topun peşinden gönderilmez. Topu alan kişi farklıysa vuruş noktasında bekleyen oyuncuya fiziksel bir yay çizerek atar ve yerine döner. Alıcı topu elleriyle karşılar; taçta başının üzerine kaldırır, yerdeki vuruşta yere yerleştirir. Topu alma, atma ve toplayıcının yerine dönüşü stamina tüketmez; normal oyunda tüketim tekrar başlar. Yerdeki vuruşta topun durması beklenir. Oyuncular dizilişlerine yürüyerek/koşarak gider, kamera topun alınmasını takip eder. Duran top hazırlığında top veya oyuncular ışınlanmaz.
- Duran toplarda hazırlık, yerleşim, düdük ve vuruş aşamaları. Serbest vuruşta mesafeye göre 3–5 kişilik baraj, rakipler için en az 9,15 m ve hücumcularla baraj arasında en az 1 m açıklık; yakın endirekt vuruşta kale çizgisi istisnası. Kaleci barajın açık tarafını kapatır; baraj şutta fiziksel gövdesiyle sıçrar. Uzaktaki serbest vuruşlarda pas yerleşimi kullanılır.
- Korner ve serbest vuruşta sol analog yönü seçer, şut/orta gücü yüksekliği belirler, sağ analog falsoyu yavaş yavaş ekler. Hafif eğim küçük ayar, uzun tutuş gözle görülen güçlü kıvrımdır; analogu bırakınca değer kilitlenir, karşı tarafa çekmek azaltır. Falso nişanı yana kaydırmaz; ok seçilen çıkış yönünü gösterir; falso topun gerçek uçuşunu kıvırır. Klavyede yön tuşları nişan, Q/E falso, D/A basılı tutmak güçtür. Şut tuşu pas başlatmaz. Oyuncu vuruşu seçmeden top yeniden oyuna girmez; rakip takım da hazırlık aşamasından geçer.
- Kornerde yakın/uzak direk koşu yerleri ve adam paylaşımı; kale vuruşunda kale alanı içinden kullanım ve rakiplerin ceza sahası dışında beklemesi; taçta çizgi üzerinde, iki elle baş üstünden fiziksel atış ve 2 m rakip mesafesi. Penaltıda 11 m noktası, çizgide kaleci, ceza sahası/yay dışında ve topun gerisinde oyuncular.
- Pas/vuruş anına göre ofsayt konumu, topa katılınca endirekt vuruş; taç, korner ve kale vuruşundan doğrudan alışta ofsayt istisnası. Savunmacıdan tesadüfi sekme veya kaleci kurtarışı önceki ofsaytı kaldırmaz. Yeniden başlatan oyuncunun çift dokunuşu endirekt vuruştur; taç/endirekt vuruştan doğrudan gol sayılmaz, doğrudan kendi kalesine duran top korner olur.
- Kayarak müdahalede temas sırası: topa önce dokunmak ile rakibe önce çarpmak ayrılır. Ceza sahasında rakibe faul penaltıdır. Yapay zekâ da müdahale yapabilir. Kontrolsüz arkadan müdahale sarı kart; basitleştirilmiş tekrarlı faul eşiği her üçüncü faulde sarı karttır. İkinci sarıda oyuncu oyundan çıkar, takım eksik kalır; yediden az oyuncuda maç bitirilir.

- Kamera ekranı kaplayan dikey sahada topu ve oyuncuyu yumuşakça takip eder. Kenar kamerada korner ve serbest vuruş, vuruş hazırken oyuncunun arkasından ceza sahasına / kaleye bakacak şekilde yavaşça içeri girer; taç yakın çizgide topu kadrajda tutmak için geri yaslanır.
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
- Yakın kontrol için normal koşu ve sprint dokunuşları kısadır; ani yön değişiminde oyuncu eski koşu yönünü daha hızlı frenler. Pas karşılama ile sürüş arasındaki kısa geçişte kendi gövde kapsülü topu yeniden sektirmez. Art arda dönüşlerde ayağı yukarı çeviren diz dönüşü düzeltilmiştir. Rakip müdahalesi, pas, şut ve bilinçli ileri açış topu serbest bırakır.
- Fiziksel kale direkleri ve üst direk; arka, yan ve üst filelerde sabit kenarlı yay ağı. Topun temas noktası esner; yatay, dikey ve çapraz ip gerilimi darbeyi çevreye yayar. File geri salınır ve zamanla durulur; sert vuruş daha büyük cep oluşturur. Çizilen file, ışık normalleri ve top teması aynı deformasyonu kullanır. Gol tekrarından önce 1,15 saniye canlı fizik devam eder; topun fileye girişi ve ağın hareketi tekrara da kaydedilir. Tekrar bitince ağın gerçek konumu ve hızı geri yüklenir. Hareketsiz file fizik hesabı yapmaz.
- Gol için topun tamamı kale çizgisini, direklerin arasından ve üst direğin altından geçmelidir.
- Her iki takımda topsuz pozisyon alma, kaleci atlayışları ve çelmeler; bizim takımda kullanıcı komutuyla pas/şut, rakipte bağımsız hücum kararları.
- Taç, korner, kale vuruşu, müdahaleden doğan serbest vuruş ve gol sonrası yeniden başlama.
- Şut, pas, kurtarış ve topa sahip olma sayacı; sonuç, duraklatma ve tekrar oynama ekranları.
- Antrenman modu, top hızı göstergesi, radar, enerji ve şut gücü göstergesi.
- Kullanıcının sağladığı gerçek stadyum ambiyansı maç boyunca döner. İkinci alkış kaydı şut, kurtarış, gol, yakın kaçan fırsat ve müdahalelerde ayrı kanalda, yumuşak giriş/çıkışla çalar. Gol daha uzun ve güçlüdür; tekrarlanan olaylar sesleri üst üste bindirmez. M tüm sesleri kapatır, mola iki kaydı da duraklatır. Topa vuruş ve düdük ayrı kanallarda kalır.
- Seremoniden maç sonuna kadar görev yapan siyah formalı orta hakem ve iki bayraklı yardımcı. Orta hakem oyunu takip eder; düdük, yön, penaltı, endirekt vuruş ve kart işaretlerini gösterir. Kart gösterimi bitmeden duran top kullanılamaz; ikinci sarıdan sonra kırmızı kart gösterilir. Endirekt vuruşta kol, başka bir oyuncunun topa temasına kadar havada kalır.
- Yardımcı hakemler kendi taç çizgilerinde top ve ikinci son savunmacının oluşturduğu ofsayt çizgisini izler. Ofsayttaki oyuncu topa müdahale ettiğinde bayrağı kaldırıp ihlalin yakın/orta/uzak bölgesini gösterirler; taç, korner ve kale vuruşunda ilgili işareti verirler. Hakemler topa ve oyunculara fiziksel engel olmaz; antrenmanda görünmezler.

Çevrimiçi çok oyunculu mod bu sürümde bulunmuyor. Elle oynama henüz modellenmiyor. Ofsayt gövde konumu ve topa temas üzerinden değerlendirilir; kalecinin görüşünü kapatma gibi temassız müdahaleler ayrıca modellenmez. Kaleci ve top sürme yardımları oynanabilirlik için ayarlanmış oyun davranışlarıdır.

Duran top kuralları için [IFAB serbest vuruş](https://www.theifab.com/laws/latest/free-kicks/), [penaltı](https://www.theifab.com/laws/latest/the-penalty-kick/), [taç](https://www.theifab.com/laws/latest/the-throw-in/), [kale vuruşu](https://www.theifab.com/laws/latest/the-goal-kick/) ve [ofsayt](https://www.theifab.com/laws/latest/offside/) esas alındı. Mesafeler oyun sahasının metre ölçeğindedir.

## Doğrulama

Kontrol rehberi, fare/F1/Xbox açma-kapama, sekmeler, gerçek tuş atamaları, pas/şut girdilerinin panelden oyuna sızmaması, duraklatma ve önceki ekrana dönüş: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/controls_help_check.gd`. Görsel kontrol için headless olmadan `-- --visual` ekle.

Hızlı maç akışı, bağımsız kulüp seçimi, gerçek forma/isim değişimi, ilk 11, maç başlangıcına taşıma ve ayrı ayarlar: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/prematch_check.gd`. Görsel kayıt için headless olmadan `-- --visual` ekle.

Canlı ana menü maçı, iki takımın pas/şutları, sabit stadyum kadrajı, gol/santra/taç devamlılığı, ayarlarda duraklama ve temiz maç başlangıcı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/menu_match_check.gd`. Gündüz/gece görüntüsü için headless olmadan `-- --visual` ekle.

Kadro, fiziksel değişiklik, kondisyon, taktik, zorluk, avantaj/kartlar, ilave süre, tekrar, Xbox ek tuşları ve kalıcı ayarlar: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/match_expansion_check.gd`. Görsel kayıt için headless olmadan `-- --visual` ekle.

FPS tuşu ve kare ölçümü, devre arası/atlama/dinlenme, ikinci yarı kaleleri/ofsayt/kaleciler/duran toplar ve tribün olayları: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/match_day_check.gd`. Görsel kontrol için headless olmadan `-- --visual` ekle.

İki takımdan en yakın toplayıcı, rakipten doğru takımın oyuncusuna teslim, stamina muafiyetinin görevle sınırlı olması ve yedi duran top senaryosu: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/nearest_collector_check.gd`.

Destek koşuları ve iki yönlü bindirme, verkaç tetikleme, gerçek Z/V/E/G/Q girdileri, top koruma/çalma, sprintte açılan topa ayakta müdahale, faul, kaleci açı/çıkış/orta/tutma/dağıtım ve güvenli çelme: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/gameplay_depth_check.gd`. Animasyon görüntüleri için headless olmadan `-- --visual` ekle.

Top sürme mesafesi, sprintte açılış, 90°/180° dönüş, duruş, şutta bırakma, sert topu yakalamama ve rakibin topu kazanması: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/close_control_check.gd`. Aralıklı gerçek krampon teması, kontrollü yuvarlanma, yağmur, farklı fizik hızları ve kontrol bitince çarpışmaların geri gelmesi: aynı komutta `res://tests/dribble_control_check.gd`. Yakın plan görüntüler için `--headless --disable-render-loop` kaldırılıp `-- --visual` eklenir.

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

Antrenman düğmesi üç mod açar: **Serbest antrenman** mevcut tek oyuncu/kaleci düzenidir; **Orta & kafa** çalışmasında kanattaki takım arkadaşı iki taraftan sırayla gerçek fiziksel orta açar, pas tuşuyla daha erken orta istenebilir ve şut tuşuyla kafa vurulur; **Serbest vuruş**ta üst kamerada yalnızca topu gezdirerek noktayı sen seçersin, **A** ile o noktadan serbest vuruş kamerası ve baraj gelir; uzak noktada da baraj kurulur. Gol, dışarı çıkan top, baraja çarpma veya kaleci kurtarışı yine yer seçimine döner. **R** yeni deneme, **T** (kolda **View / dokunmatik yüzey**) mod seçimi açar. Kontrolcüyle yeni deneme mola menüsündedir. Menü fare, klavye, Xbox ve PlayStation ile kullanılabilir. Antrenman partnerinin otomatik ortası yalnızca bu modda etkindir; maçta kendi takımının pas/şut kontrolü oyuncuda kalır.

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

Verkaç (LB + A), aşırtma (LB + X) ve basılı tutup bırakılan ortalar; Xbox olayları, fiziksel koşu/stamina, güç/yön ayarı, RB + B yerden orta, iptaller ve alıcı kontrolü: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/attacking_combos_check.gd`. `-- --visual` ile görsel kayıt alınır.

Hızlı maç ve tek tuşla devam akışı: `tests/quick_match_polish_check.gd`. Tekrar geçişleri ve gol anı: `tests/replay_comfort_check.gd`. Farklı ekran oranlarında HUD, orta, top koruma, AI sprinti ve sevinç çeşitleri: `tests/match_polish_check.gd`. İlk kare duruşu, boş vole iptali ve iki takım kalecisinin el teması: `tests/animation_continuity_check.gd`. Bu testler `godot --headless --path . --script <dosya>` ile çalışır; ilk üçü `-- --visual` ile normal pencerede görüntü de kaydeder.

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

Uygun hücum seçenekleri ortak bir puanla karşılaştırılır: gol fırsatı, pasın kesilme riski, baskıdan çıkış, alıcının topa yetişmesi, kondisyon ve oyuncu özellikleri kararı etkiler. Açık gol fırsatı sırf verkaç hazır diye kaçırılmaz; baskı yokken boş alana sürmek gereksiz geri pastan daha değerli olabilir. Normal ve Zor seviyeleri alıcının ardından açılabilecek bir sonraki pas yolunu da değerlendirir. Bu, önceden belirlenmiş bir pas zinciri değildir; bir sonraki karar sahadaki yeni duruma göre verilir.

Topsuz destekte birbirinden ayrı kısa pas, ileri kanal koşusu ve geniş kanat görevleri paylaşılır. Görevler kısa süre korunarak oyuncuların sürekli fikir değiştirmesi önlenir; hedefler boşluk ve pas yollarına göre güncellenir. Mevcut bindirmeler, ceza sahası koşuları, açık verkaç komutu ve pası almaya giden oyuncunun önceliği korunur. Koşular canlı ofsayt çizgisinde durur, gerçek hız ve kondisyonla yapılır; top kaybı ve düdükte plan temizlenir. Karar sırası bağımsızlığı, açık/kapalı pas yolu, iki hücum yönü, ayrı koşu koridorları ve kullanıcı komut yetkisi: `godot --headless --path . --fixed-fps 120 --script tests/attack_decisions_check.gd`.

Rakip pası hazırlarken topun hareketini takip eder; pas sayacı, alıcı görevi ve pas sonrası koşu gerçek ayak temasında başlar. Yarıda kesilen vuruş bunları tetiklemez. Alıcı, zeminde yavaşlayan topun ulaşabileceği noktasına gider ve yaklaşırken frenler; kolay pası gereksiz uzanarak sektirmek yerine ayağına alır. İlk kontrol tamamlanmadan yeni vuruşa geçmez. İleri açılan topun peşine koşu, destek göreviyle iptal edilmez. Sert düz pasın gücü mesafeye göre ayarlanır; sıradan destek koşusu otomatik geri pas zorunluluğu yaratmaz. Rakip arkadaki baskıcıyı her pas yolunu kapatıyor saymaz, şutta bir köşe kapalıysa diğer köşeyi de değerlendirir. Bu akış normal/yağmurlu zemin, iki hücum yönü, gerçek pas–kontrol–şut zinciri ve 22 oyunculu maçlarla sınanır: `godot --headless --path . --fixed-fps 120 --script tests/ai_match_flow_check.gd`.

Rakip teknik direktörü maç içindeki gerçek hareketleri izler: kullanılan kanat, yapılmış dikine paslar ve kendi pas çıkışına uygulanan baskı zaman içinde değerlendirilir. Eski gözlemler etkisini kaybeder; taraf veya oyun biçimi değişince rakip tekrar uyum sağlar. Kolay seviyede değerlendirme daha yavaş ve sınırlı, Normal'de daha erken, Zor'da daha sık ve belirgindir. Kullanıcının tuşları, hazırladığı nişan veya sonraki komutu okunmaz; hız, stamina ve top fiziğine zorluk kaynaklı bonus eklenmez.

Rakip top kaybından sonra kısa süreli karşı pres, çizgi kenarında ikinci oyuncuyla sıkıştırma, arkada kademe, koşucuyu kaleye yakın tarafından takip ve pas arası kullanır. Yoğun pres aralarında dinlenir; yorgun takım baskıyı azaltır. Ceza sahasında veya sarı kartı varken arkadan/kapalı topa müdahaleden kaçınır, kontrollü yaklaşır; açık topa temiz müdahale yapabilir. Şut yolu kapalıysa başka çözüm, daha iyi konumdaki arkadaşına gol pası, uygun koşuya havadan ara pas, sert düz pas, teknik oyuncuyla ball roll/roulette/elastico/scoop/rainbow ve boşluğa sürüş seçebilir. Alçak sert, power ve dış ayak şutları aynı fiziksel ayak temasıyla çıkar. Rakip kaleci güvenli yere elle dağıtır, baskıda uzun atışı veya ayaktan açışı kullanır.

Savunmacı topa yakınlığı topu kazanmakla karıştırmaz. Görünen koşu hızından yaklaşma noktasını hesaplar, sprint yapan hücumcuyla birlikte hızlanır ve geçilince kaleye daha yakın arkadaşına baskı görevini devreder. Kademe, eski savunmacının bulunduğu yere değil yeni koşu yolunun arkasına gelir. Ayakta müdahale için topun 120 ms sonraki temas alanında kalması beklenir; boşa ayak uzatmak yerine koşmaya devam edilebilir. Kolay/Normal/Zor seviyelerinde gözlem aralığı ve öngörü değişir; hız, fiziksel erişim ve kondisyon kuralları ortaktır. Ani yön değişikliği, boş kanat ve yorgun savunmacıya karşı hız avantajı hâlâ işe yarar. Gerçek fizik adımlarıyla kontrol: `godot --headless --path . --fixed-fps 120 --script tests/defensive_pressure_check.gd`.

Son bölümde gerideki rakip 4-3-3'e geçebilir; yoğun baskıdan çıkışta Zor seviye 3-5-2'yi kullanabilir. Öndeyken daha fazla oyuncuyu geride tutar. Oyuncu değişiklikleri kondisyon, mevki, kart ve skor ihtiyacına göre ilk duraklamada gerçekleşir; üç değişiklik sınırı ve gerçek çıkış/giriş animasyonları geçerlidir. Bu mantık `scripts/opponent_coach.gd`, `scripts/team_tactics.gd` ve `scripts/ai_attack.gd` içindedir. Kontrol: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/opponent_intelligence_check.gd`.

### Maçın gidişine göre atmosfer ve futbol

Tribün desteği skor ve kalan zamana bağlıdır: son bölümde beraberlik arayan takımın taraftarı hareketlenir, deplasman golünde ana tribün kısa süre durulur, kaçan fırsatta tepki söner. Yakın skorlu maçın sonundaki goller daha güçlü sıçrama ve kulübe tepkisi üretir. Mevcut stadyum ve alkış kayıtlarının seviyesi bu akışa uyar; yeni saha sesi, anons veya ses dosyası eklenmemiştir.

Geç dakikada attığı gole rağmen hâlâ geride olan takımın golcüsü kutlama yerine gerçek topu ağdan alıp santraya taşır. Topa yaklaşırken frenler, eğilip alır, kaldırır ve orta noktaya bırakır; stamina harcamaz. Takım arkadaşları yerlerine döner. Son bölümde öne geçiren golün grup kutlaması daha büyüktür; mevcut kutlama geçme tuşu kullanılabilir.

Oyuncuların kulüp ve kimliğine bağlı hız, ivme, ilk kontrol, denge, kafa ve şut değerleri ile güçlü/zayıf ayak bilgisi vardır. Kanat oyuncusu daha çabuk hızlanır, güçlü stoper hava topunda avantajlıdır; baskı altındaki kontrol ve ters ayakla şut gerçek top hızını etkiler. Değerler kadro karşılaştırmasında görülür ve oyuncu değişikliğinde kimlikle birlikte taşınır. Şut çizgisi, vuruşla aynı hesabı kullanır.

Savunma birlikte kayar: tek oyuncu baskıya çıkar, biri arkasını kapatır, diğerleri ortak derinliği ve pas yollarını korur. Kullanıcının pres ve savunma çizgisi ayarları ayrı ayrı geçerlidir. Rakip son bölümde gerideyse daha ileri çıkar ve riskli paslara yönelir; öndeyse daha temkinli oynar. Bu görevler kullanıcının seçili oyuncusunun yön kontrolünü devralmaz.

Yakın omuz mücadelesinde iki oyuncu birbirine yaslanır; sınırlı karşılıklı itiş kilo farkını dikkate alır ve tek başına faul üretmez. Hava topunda yer tutma, dengeye bağlı kontrol ve inişte kısa diz/gövde esnemesi vardır. Kurtarış ve gerçek yön değiştiren şut sekmeleri sonrası her iki takım en uygun oyuncuyu topa yollar; ikinci oyuncu bitiricilik veya kale koruması için yer alır. Kullanıcı takımında otomatik pas/şut eklenmez.

Duraklamalarda kaçan fırsat, kenardan talimat ve oyuncu değişikliği için en fazla iki saniyelik yakın kamera görüntüleri kullanılır. Oyun hazırlığı arkada sürer; duran top hazırsa kamera hemen döner. **Space/Enter**, Xbox **A/B** veya PlayStation **×/○** ile geçilir; diğer oyun tuşları da görüntüyü kapatır. Oyuncu değişikliğinde yedek kulübeden kenara gelir, çıkan oyuncuyla kısa selamlaşır ve sahaya girer. Üç değişiklik sınırı korunur.

Yeni davranış kontrolleri: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/realism_check.gd`. İki kale yönünde gerçek top taşıma, selamlaşma, stamina ve iniş testi: aynı komutla `res://tests/realism_flow_check.gd`; görüntüler için `--headless --disable-render-loop` kaldırılıp `-- --visual` eklenir.

Havadaki topun tahmini ilk yere temas noktası geçici açık renkli bir halkayla gösterilir. Dış halka top yaklaştıkça küçülür. Yalnızca düşeceği yer işaretlenir; kafa/vole yazısı veya ayrı bir kafa noktası gösterilmez. İşaret mevcut top hızı, falso ve hava direncinden hesaplanır; gerçek sekme, kurtarış veya vuruştan sonra güncellenir. Top yerdeyken, tutulduğunda veya oyun durduğunda kaybolur. Antrenmanda da çalışır; oyuncuyu veya topu hareket ettirmez. Tahmin saniyede yaklaşık 12 kez yenilenir, yeni bir çarpışmada hemen hesaplanır; yeni ışık/gölge çizimi eklenmez.

İniş tahminini kuru/yağmurlu zeminde gerçek top uçuşuyla karşılaştırma ve sekme sonrası güncelleme: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/ball_landing_check.gd`. Görsel sürümü `godot --path . --fixed-fps 120 --script res://tests/ball_landing_check.gd -- --visual` gündüz, yağmurlu gece ve yayın kamerası görüntülerini kaydeder.

Gelen topa aynı şut tuşuyla (**D / Xbox X / PlayStation □**) vurulur: oyuncu yetişebileceği yüksek topa kafa, ayakla ulaşabileceği havadaki topa vole, zeminden yeni sekmiş alçak topa yarım vole seçer. Yerdeki top normal şut olarak kalır. Kısa süre önce basılan şut komutu teması bekler; nişan ve güç kullanıcıda kalır, basılı tutarken top yükselirse hazırlık da uyarlanır. Şut simgesinin yanında seçilen vuruş gösterilir; F1 kontrol rehberinde açıklaması bulunur.

Top gelmeden şuta basıp bırakmak artık kısa bir hazırlanma komutu da verir. Seçili oyuncu, yaklaşık 0,9 saniye içinde yetişebileceği topa en fazla 3 metrelik bir yaklaşımla yerleşir; geliş yüksekliğine göre vole, yarım vole veya kafa seçilir. Ayak seviyesinin biraz üstündeki top için küçük bir sıçrama yapabilir. Yaklaşma normal hızlanma, kondisyon, zemin ve çarpışmalarla çalışır; vuruş yine gerçek kafa/krampon temasını bekler. Nişan ve güç kullanıcıdadır. Başka aksiyon, manuel oyuncu seçimi, mola veya uzaklaşan top komutu iptal eder; takım arkadaşları kendiliğinden şut çekmez. Erken komut, yaklaşma, fiziksel temas, iptal ve kontrolcü kontrolleri: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/aerial_assist_check.gd`.

Volede topun tarafına uygun ayak uzanır, diğer ayak yere basar; gövde ve kollar dengeyi sağlar, hareket mevcut adımdan başlayıp kısa bir devam hareketiyle koşuya döner. Gerçek top ile hareketli kramponun kesişmesi olmadan vuruş yapılmaz. Yaklaşan top kaçarsa komut sona erer. Topun yüksekliği, geliş hızı, güçlü/zayıf ayak, baskı ve yorgunluk vuruş hızını/yükselişini etkiler. Rakip aynı sistemi şut pozisyonlarında kullanabilir; kullanıcının seçmediği takım arkadaşı kendiliğinden şut çekmez. Mola, oyuncu seçimi, başka aksiyon ve yeni antrenman bekleyen komutu temizler.

Vole/yarım vole temasları, iki ayak, gerçek sekme ve gol, yön/güç, klavye ve iki kontrolcü ailesi, ofsayt, iptal, normal şut/kafa seçimi ve rakip kullanımı: `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/volley_check.gd`. Yakın plan görüntüler için `--headless --disable-render-loop` yerine `-- --visual` kullanılır. Mantık `scripts/volleys.gd`, vuruş pozu `scripts/volley_pose.gd` içindedir.

### Çalım, savunma, bitiricilik ve kaleci komutları

F1 kontrol rehberi artık sekiz sekmelidir. **Çalımlar**, **Bitiricilik**, **Özel Pas** ve **Kaleci** sayfaları yeni hareketleri klavye veya algılanan Xbox/PlayStation simgeleriyle açıklar. Rehber açıldığında maç durur. Önceki pas, orta, verkaç, aşırtma ve falso kontrolleri korunur.

| Hareket | Klavye | Xbox (PlayStation simgeleri otomatik görünür) |
|---|---|---|
| Roulette / ball roll / elastico / scoop turn | 1 / 2 / 3 / 4; yön ile taraf seç | Sağ analog: geri / yan / hızlı karşılıklı yan / ileri |
| Rainbow / heel flick / flick up | 6 / 7 / 8 | LT + sağ analog: geri / ileri / yan |
| İkinci adam baskısı | Space basılı | Rakipteyken A basılı |
| Omuz / pas arası | J / L | Rakipteyken L3 / LT + X |
| Yönlü oyuncu seçimi | Kontrolcüde sağ analog; Q yakın oyuncuya geçer | Topsuzken sağ analog; LB yakın oyuncuya geçer |
| Alçak sert / power / dış ayak şutu | Ctrl + D / Shift + D / Alt + D | RB + X / LB + RT + X / LB + LT + X |
| Sonraki normal şutta zamanlama | 5, ardından D | Top ayağındayken L3, ardından X |
| Timed finishing | Özel şutu bırak; yeşil aralıkta D'ye tekrar bas | Özel şutu bırak; yeşil aralıkta X'e tekrar bas |
| Sert düz pas / sert yerden ara pas | Ctrl + S / Ctrl + Y | RB + A / RB + Y |
| Dummy / bırak geç | U | Takım arkadaşının pası gelirken L3 |
| Kaleci: elle yerden pas / uzun el atışı | S / Y | A / Y |
| Kaleci: ayaktan açış / yere bırak | D / V | X / R3 |

Sağ analog yönleri çalımda oyuncunun baktığı yöne göredir. Şut hazırlanırken sağ analog nişan işlevini sürdürür. Top ayağındayken sağ analogla ball roll için yana dokunulur; 0,18 saniye içinde karşı yana çevrilirse elastico olur. **LT** basılıyken sağ analog ekstra flick’leri açar: geri rainbow, ileri heel flick, yana flick up. Yedi çalım farklı gerçek top darbeleri, ayak/gövde hareketleri, kondisyon maliyeti ve kısa toparlanma süresi kullanır; rakipten bağışıklık vermez. Scoop küçük bir kaldırma, rainbow topu oyuncunun üzerinden atar, flick up vole için havaya bırakır. Yeni pas/şut komutu devam eden çalımı kesebilir.

Sonraki LB/L1/Q hedefi sahada açık mavi, içi boş okla; baskıya çağrılan oyuncu yeşil PRES yazısıyla gösterilir. Sağ analogla yönlü seçim belirtilen doğrultuyu önceler. İkinci adam baskısı en fazla dört saniye sürer, enerji tüketir ve kısa dinlenme ister; seçili oyuncunun kontrolünü devralmaz. Omuz müdahalesi kütleye bağlı sınırlı itiş üretir; arkadan veya toptan uzaktaki itiş fauldür. Pas arası uzanan gerçek ayağa temas gerektirir. Dummy yalnızca kısa süreli alçak gelen pası bırakır, topun hızını/yönünü değiştirmez; bitince veya iptal edilince normal çarpışma geri gelir.

Normal, plase, aşırtma, alçak sert, power ve dış ayak şutlarında basılı tutma süresi hazırlıktır; tuş bırakıldığı anda top çıkar ve vuruşun devam animasyonu oynar. Power shot daha sert, alçak sert şut düşük yükselişli, dış ayak şutu fiziksel kavisli gider. Hazırlık sırasında top kaybedilmişse veya oyuncu düşmüşse şut oluşmaz. İkinci basış yalnızca 5/L3 ile seçilen zamanlamalı şutta kullanılır: yeşil pencerede kalite artar, erken basış kaliteyi düşürür. İkinci basış yapılmazsa standart kalitede vurulur; gol garanti edilmez.

Kaleci elde tuttuğu gerçek topu elle yerden gönderir, omuz üzerinden uzun fırlatır, düşürüp ayakla açar veya sahaya bırakır. Yön ve güç kullanıcıdadır; güvenli bir takım arkadaşına zorunlu otomatik pas verilmez. Ayaktan açış ayak temasını bekler ve şut istatistiğine değil dağıtıma sayılır. Mola, rehber, yeni maç ve kontrolcü kopması bekleyen yeni komutları temizler.

Bu davranışlar için `godot --headless --path . --fixed-fps 120 --disable-render-loop --script res://tests/advanced_play_check.gd`; görüntüler için başsız seçenekleri kaldırıp `-- --visual` ekleyin. Test; 7 çalım, gerçek sekme/kaldırma, yönlü seçim, baskı, omuz, pas arası, dummy temizliği, sert paslar, 4 özel şut modu, iki kontrolcü ailesi, kalecinin 4 dağıtımı ve komut listesini kapsar.

## Top teması ve hareket akışı

Normal pas, orta ve yapay zekâ vuruşlarında yaklaşık 45–65 ms süren ayak hazırlığı vardır. Kullanıcının hazırladığı yerden şutta tuş bırakıldıktan sonra ek bekleme yoktur; topun çıkışı, vuruş sesi, titreşim ve tribün tepkisi birlikte tetiklenir. Havadan vuruşlar ve özellikle seçilen zamanlamalı şut temas pencerelerini korur.

Top yeni oyuncu ölçeğine göre küçültülmüştür; model, çarpışma, yere yerleştirme, pas/şut tahminleri ve kale çizgisi kontrolleri aynı yarıçapı kullanır. İki takımın normal koşusu, sprinti ve yorgun yürüyüşü %12 yavaşlatılmıştır; şut gücü, topun akışı ve kontrol tepkisi bundan etkilenmez.

Destek ayağı şut, orta ve ilk kontrolde kısa süreyle sahadaki basma noktasını korur. Koşu hızı ve bacağın erişimi gerektirdiğinde destek çözülür. Boy, kilo, çeviklik ve teknik; adım ritmini, genişliğini, gövde salınımını ve vuruş dönüşünü değiştirir. İlk kontrol → çalım → pas ve müdahale → koşu geçişleri mevcut adımdan yumuşakça devam eder.

Pas gelirken **hareket yönünü** tutarak ilk kontrolü o tarafa açabilirsin. Top saklamada rakipten uzak taraf kullanılır; sprint daha uzun, yüksek teknik daha kısa ve temiz dokunuş sağlar. Rakipler de boşluğa açılan aynı kontrolü kullanır. Topa tek, sınırlı fiziksel darbe uygulanır; top oyuncuya bağlanmaz.

İki takımın alıcıları havadan pas ve ortayı gerçek hava direnci/falso hesabıyla, topun karşılanabilir yüksekliğe indiği noktada bekler. Yaklaşırken topa döner; yakındaki takım arkadaşı aynı topa koşmak yerine destek alanını korur. Orta sahadaki rutin hava pası kontrol edilerek yere indirilir, ceza sahasındaki uygun orta kafayla bitirilir. Kafa vuruşunda gövde kapsülünün erken sekmesi önlenir; temas gerçek kafa konumunda gerçekleşir. Hedeflenen sert yerden paslarda kontrol yardımı artar; rakip müdahalesi ve sert şutlar normal şekilde karşılık bulur. Kullanıcı alıcısında yön girişi yoksa aynı karşılama/frenleme yardımı çalışır, şut kararı kullanıcıda kalır. Taç hazırlığı gerçek el konumunu kontrol eder; kısa boylu oyuncular sabit yükseklik eşiğinde beklemez. İki takım, iki yön, yağmur, koşan alıcı, sert pas, kafa teması, kullanıcı kontrolü ve farklı boylarda taç hazırlığı: `godot --headless --path . --fixed-fps 120 --script tests/reception_flow_check.gd`.

Kaleci alçak topa ayağını uzatabilir, karşı karşıyada vücudunu açabilir, yere kapanarak topu koruyabilir ve toparlandıktan sonra dizlerinden ileri uzanıp ikinci hamleyi yapabilir. İkinci kurtarış ilk hamleye göre 0,34–0,72 saniyelik fiziksel toparlanmayı bekler. Kendi elle dağıtımı veya ayaktan açışı seken top sayılmaz. Karşılıklı omuz mücadeleleri durağan top saklamada da çalışır; kalça araya girer, adımlar temastan etkilenir ve ayakta müdahale topun yanındaki ayağı seçer.

Yeni kontroller: `godot --headless --path . --fixed-fps 120 --script tests/motion_contact_check.gd`. 30/60/120 adımda temas, canlı koşu şutu, yönlendirilmiş kontrol, destek ayağı, komut geçişleri ve gerçek yere kapanma/ikinci kurtarış senaryolarını çalıştırır. Yakın plan kayıtları için `--headless` kaldırılıp `-- --visual` eklenir.

### Türkiye Süper Ligi

Kariyer başlangıcındaki lig seçiminde **Türkiye Süper Ligi**, SEFC Premier Lig ve SEFC Birinci Lig’den ayrı görünür. Boğaziçi Yıldız, İstanbul Hilal, Karaköy Kartalları, Trabzon Fırtına, Bursa İpek ve diğer özgün isimlerden oluşan **18 kurgusal kulübün** kendi formaları, armaları, bütçeleri ve oyuncuları vardır. Takımlar her rakiple evinde ve deplasmanda oynar: 34 hafta, 17 iç saha maçı, ocak ayında ikinci devre. Türkiye liginde ikinci kademe bulunmaz; SEFC’nin iki ligli yükselme/düşme sistemi ayrıdır.

24 kişilik başlangıç kadrolarında Türk oyuncularla birlikte **10–14 yabancı oyuncu** bulunur. Yabancılar ilk 11 ve yedeklere dağılır; milliyet kartlarda ve oyuncu detayında görünür. Bu dağılım bir kadro üretim tercihi; transfer veya kiralamaya getirilen bir yabancı sınırı değildir. Türkiye şampiyonu sonraki sezon Şampiyonlar Kupası’na katılır; mevcut SEFC ülke ve süper kupaları SEFC kulüplerine aittir.

Eski kariyer kayıtları otomatik güncellenir. Oynanmış sonuçlar, mevcut kupa kuraları, oyuncu kimlikleri, transferler, bütçeler ve altyapı oyuncuları korunur. Yeni ligin fikstürü eklenir; geçmiş tarihli yeni lig maçları takvim ilerletilince simüle edilir. Tekrar yükleme kulüp veya oyuncu çoğaltmaz.

Kontroller: `tests/career_turkey_check.gd` lig/milliyet/fikstür/kayıt geçişini, `tests/career_turkey_flow_check.gd` kontrolcüyle lig seçimi ve gerçek maç kadrosunu doğrular.

### Görsel kariyer menüsü

Kariyer merkezi kulübün gerçek formasıyla üç boyutlu oyuncu sahnesi, maç kartı, kulüp armaları ve görsel işlem kartları kullanır. Kadro ve transfer listeleri dokuz oyunculuk portre kartlarına ayrılır; taktik sahası ilk 11'in gerçek portrelerini gösterir. Yönetim güveni, sezon hedefleri, gelişim ve bütçe daha kısa metinlerle görsel göstergeler üzerinden okunur. Menü sahnesi sadece merkez açıkken render edilir; tribün koltukları tek MultiMesh ile çizilir, portreler önbellekten kullanılır.

Kariyerde sol analog / yön tuşları ile gezinilir; Xbox A / PlayStation çarpı seçer, B / daire geri döner. LB/RB veya L1/R1 bölümleri; LT/RT veya L2/R2 kadro ve transfer sayfalarını değiştirir. Klavyede Page Up / Page Down da sayfa değiştirir. Bölümler arasında dönüldüğünde oyuncu seçimi, sayfa ve odak korunur. Tetik tuşları açık seçim menüsünü kapatmaz ve basılı tutulduklarında sayfaları art arda atlamaz.

Arayüz doğrulaması: `godot --headless --path . --script tests/career_visual_check.gd`. Gerçek ekran görüntüleri için `--headless` kaldırılıp sonuna `-- --visual` eklenir. Kariyer, kiralama, kupa ve teknik direktör akış testleri mevcut kayıt ve maç işlemlerini ayrıca doğrular.

Kamera ayarları **P → Görüntü & Oyun** bölümündedir: başlangıç kamerası, %70–150 uzaklık ve %65–160 yükseklik/açı. Klavye, fare ve kol ile ayarlanır; sonraki maçlarda korunur. Fare tekerleği perspektif kameraları da yakınlaştırır. Duran top yakın planları kendi kadrajını korur. Sıfırla düğmesi kenar kamerayı ve %100 değerlerini geri getirir. Yeni kontrol ve kayıt testleri: `tests/sticky_control_check.gd`, `tests/camera_settings_check.gd`.

### Maç sunumu ve hareket güncellemesi

Hızlı maçta kulüp armaları, canlı forma modelleri ve üç güç göstergesi; taktiklerde sahaya yerleşmiş oyuncu portreleri kullanılır. Antrenmandaki üç kart aynı ayakta duran modeli tekrarlamaz: koniler ve takım arkadaşlarıyla top sürme, kaleye orta/kafa ve baraja karşı serbest vuruş için ayrı hareketli 3B sahneler gösterir. Bu sahneler menü kapalıyken çizilmez. Kariyer, antrenman ve mola menüsü ortak koyu yüzeyler, açık yeşil vurgu ve belirgin kol odağı kullanır.

Canlı oyuncu değişikliği önerisi View / touchpad ile açılır; yön tuşları seçim, A / çarpı onay, B / daire kapatma yapar. Tetikle açma da korunur. Kabul edilen değişiklikte çıkan oyuncu kenara koşar; yeni oyuncunun girişi sırasında eski oyuncunun modeli kaybolmak yerine kulübeye yürür.

Yakın ikili mücadelelerde iki rakip temas tarafına doğru gövdesini yükler; paralel koşuda omuzla, yüz yüze temasta bükülü kolla mesafe korur. Yakınlık ve göreli hız hareketin ağırlığını değiştirir. Ayrılınca normal koşuya yumuşakça döner; vuruş ve özel aksiyonlar önceliklidir. Bu görsel katman top sahipliği veya fiziksel itme kuvvetini değiştirmez.

Top sürme ve sprintte ayrı basma/salınım döngüsü, alçak ayak yayı ve yumuşatılmış krampon yolları kullanılır. Topa gerçek temas korunur. Hızlı top için fizik örnekleri arasındaki görüntü enterpole edilir; fizik 120 Hz kalır. Büyük lastik esnemesi azaltılmış, hayalet top kopyaları kaldırılmıştır. Yeniden başlatmada eski görüntü yolu temizlenir.

Gelen topun yüksekliği, geliş yönü, son sekmesi ve oyuncunun duruşu yarım vole, yan vole veya uygun durumda röveşata seçimini etkiler. Röveşata yeterli enerji, bitiricilik ve çevrede boşluk ister; temas gerçek krampon mesafesinde gerçekleşir. Yapay zekâ da uygun pozisyonda kullanabilir. Normal/zor AI, açık alan ve yeterli enerjide power shot; öne çıkan kaleciye karşı aşırtma değerlendirebilir. Gol tekrarında çizgi geçişi çevresinde hız yumuşakça 0,38× olur; diğer kısımlar 0,8× kalır. Kısa kamera geçişleri gol anını kapatmaz.

Yeni doğrulamalar: `tests/contextual_finish_check.gd`, `tests/carry_gait_check.gd`, `tests/duel_animation_check.gd`, `tests/presentation_refresh_check.gd`. Grafik ortamında `tests/ball_render_check.gd` hızlı yer/hava topunun gerçek ara karelerini kontrol eder. `tests/performance_safety_check.gd` birleşen model parçalarının köşe ve UV verilerini, malzemelerini ve mevcut fizik davranışını doğrular. Rijit baş, diz ve önkol parçalarını birleştirmek oyuncu başına beş çizim nesnesini kaldırır; geometri, forma ve gölge ayrıntısı azaltılmaz.

24 Eylül FPS düzeltmesi: destek ve hücum yerleşimi aynı konum/pas koridoru
hesaplarını tekrar kullanır; top uçuşu yalnızca aynı fizik girdilerinde önbelleğe
alınır. Uzak normal koşu pozları çizim karesinde, vuruşlar ve fiziksel temaslar
120 Hz fizik adımında hazırlanır. Fren/dönüş ayak basışı ve tekrar kaydı korunur.
Doğrulama: `tests/fps_regression_check.gd`, `tests/render_pose_check.gd`.
Grafik karşılaştırması: `tests/fps_compare_benchmark.gd` (diğer ağır testlerle
aynı anda çalıştırılmamalı). [Ölçüm ve ayrıntılar](tests/fps_results_2026_09_24.md).
