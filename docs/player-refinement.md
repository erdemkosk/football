# Oyuncu modeli düzenlemeleri

Gövde, boyun, kollar ve bacaklar tek bağlı anatomik yüzey ve ortak 15 kemikli
görsel iskelet kullanıyor. Dirsek ve dizlerdeki ara kemikler bükülürken hacmi
koruyor. Forma da aynı iskelete bağlı; omuz ve bel ağırlıkları vücutla eşleşiyor.
Forma altında kalan ten yüzeyi, yukarı uzanışlarda kumaştan taşmaması için
maskeleniyor. Şort ve çorap sınırları aynı kemik ağırlıklarını paylaşıyor.

Yüzde burun köprüsü ve uç kısmı ana yüz yüzeyinin parçası. Çene, yanak, burun,
kaş ve göz biçimi oyuncu kimliğine göre değişiyor. Daha küçük gözlere yüzü
izleyen kapaklar eşlik ediyor. Saç çizgisi kafaya oturuyor; asimetrik çizgi,
geniş tutamlar ve filtrelenen ince yüzey ayrıntıları kullanılıyor.

Eller daralan avuç ve kesintisiz parmak yüzeylerinden oluşuyor. Parmaklar
dinlenmede hafif kıvrık; koşu, korunma, top tutma ve kaleci uzanışında kıvrılma
ve açılma değişiyor. Bu hareketler bilek ve top temas düğümlerini taşımıyor.

Forma belde biraz gevşiyor. Düzenli tekrarlanan kırışıklıklar yerine gövdenin
dönüşünü izleyen üç geniş kıvrım ve kısa çapraz katlar var. Ten, kumaş, saç ve
krampon farklı pürüzlülük ve yansıma değerleri kullanıyor. Yüz ve vücut ıslaklık
tepkisini paylaşıyor.

## Görseller

- [Yüz, saç ve eller](../artifacts/player-refinement/closeups.png)
- [Önden, yandan ve arkadan vücut](../artifacts/player-refinement/body.png)
- [Koşu, şut ve kaleci uzanışı](../artifacts/player-refinement/motion.png)
- [18 saç biçimi](../artifacts/player-refinement/hair-and-faces.png)

## Doğrulama

Godot 4.7.2 / Mobile üzerinde 13 test grubu geçti: 352 adlandırılmış kontrol
ve rigid batch testindeki 115.380 köşe karşılaştırması. Kayıtlar
`artifacts/player-refinement/validation/` altında.

Kontroller bağlı vücut yüzeyi, normalize ağırlıklar, malzeme sınırlarının
ayrılmaması, el yüzeylerinin dışa bakması, farklı fiziklerde 540 animasyon pozu,
parmakların tekrar oynatılması, forma UV yönü, oyuncu değişikliği, şut ve kaleci
temaslarını kapsıyor. Görseller gerçek Godot çıktılarıdır.

Vücut 13.440, forma 8.419 köşe içeriyor; kaynaklar ve üretilen LOD'lar oyuncular
arasında paylaşılıyor. Görünüm oyunun stilize çizgisini koruyor. Kumaş hareketi
iskelet ve shader ile oluşturuluyor.

Üretim ve kontrol komutları: [Model kaynakları](../assets/models/README.md).

Son sürüm ayrıca Apple M4 Pro, Metal Mobile, 3024 × 1898 çözünürlükte tek Godot
oturumunda ölçüldü. Canlı gece stadyumu sahnesi ortalama 86,8 FPS, canlı yağmurlu
maç sahnesi 144,6 FPS verdi. Farklı kamera senaryolarıdır; önce/sonra hızlanma
karşılaştırması değildir. Ham ölçümler: [performance.json](../artifacts/player-refinement/performance.json).
