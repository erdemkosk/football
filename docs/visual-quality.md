# Oyuncu, kamera ve stadyum görsel düzenlemesi

28 Eylül 2026 — Godot 4.7.2, Mobile renderer.

## Değişiklikler

- Forma gövdesi ve iki kol tek, kesintisiz bir yüzey oldu. Omuzlar mevcut kol
  eklemlerine dağıtılmış ağırlıklarla hareket ediyor. Yeni avuç, parmak ve
  başparmak biçimleri mevcut kaleci/top temas noktalarını kullanıyor.
- Yüzlerde göz çukuru, elmacık kemiği ve burun köprüsü daha belirgin. Saçlarda
  hafif tel yönü, düzensiz saç çizgisi ve ayrı yüzey malzemesi var.
- Kenar kamerası oyunun bulunduğu kanada yaklaşıyor. Top, aktif oyuncu ve en
  yakın iki pas seçeneği kadraja sınırlı bir görüş açısı düzeltmesiyle alınıyor.
  Kamera mesafesi/yüksekliği ayarları, duran top açıları ve duraklatma korunuyor.
- Çimde ince renk ve yüzey normali farklılıkları mesafeye göre süzülüyor.
  Gölge içindeki detaylar daha görünür; ayak temas gölgeleri biraz daha belirgin.
- Tribün doluluğu küçük komşu gruplarına göre değişiyor. Günlük kıyafet oranı,
  boy, genişlik, baş/saç biçimi ve duruş yönü çeşitliliği artırıldı. Mevcut dört
  poz ve beş malzeme grubu korunarak ek çizim grupları açılmadı.

## Görüntüler

[Oyuncular](../artifacts/visual-quality/players.png) ·
[Yüzler ve saçlar](../artifacts/visual-quality/faces.png) ·
[Maç kamerası](../artifacts/visual-quality/match.png) ·
[Saha yakın planı](../artifacts/visual-quality/pitch-close.png) ·
[Tribün](../artifacts/visual-quality/crowd.png) ·
[Gece](../artifacts/visual-quality/night.png) ·
[Yağmur](../artifacts/visual-quality/rain.png)

## Doğrulama

Aşağıdaki 12 kontrol grubu hatasız tamamlandı:

| Kontrol | Sonuç |
| --- | --- |
| `player_body_check` | 27 anatomik/oran kontrolü |
| `character_detail_check` | 12 yüz, saç, malzeme ve kimlik kontrolü |
| `player_batch_check` | 1.842.840 tepe noktasında dönüşüm eşdeğerliği |
| `visual_quality_check` | 10 bağlantılı forma, animasyon ve kadraj kontrolü |
| `camera_rig_check` | Kamera geçişleri, taç, korner ve serbest vuruş |
| `camera_settings_check` | 22 ayar ve kontrolcü kontrolü |
| `crowd_check` | Doluluk, deplasman, pozlar ve maç tepkileri |
| `match_lighting_check --visual` | 25 kontrol; gerçek gündüz/gece gölgeleri |
| `wet_turf_shader_check` | Sabit görüntü boyutunda kuru/ıslak geçişleri |
| `natural_motion_check` | 121 hareket kontrolü |
| `motion_contact_check` | 76 ayak, top ve el temas kontrolü |
| `action_flow_check` | 42 hareket, pas ve kamera takip kontrolü |

Yeni forma yaklaşık 7.600 tepe noktası içeriyor; ortak kaynak ve otomatik
LOD'lar kullanıyor. Üretim komutu ve bağlama ayrıntıları
[model notunda](../assets/models/README.md).

Yerel performans ölçümü Apple M4 Pro üzerinde gündüz maçında yaklaşık 223,
gece 172, yağmurda 159 FPS verdi. Bunlar kısa test örnekleridir; farklı donanım
ve maç sahneleri için garanti değildir. Ham çıktı:
[`performance-visual-quality.json`](../tests/performance-visual-quality.json).

Kod incelemesinde ortak mesh kullanımı, GPU kaynaklarının serbest bırakılması,
render sinyalinin bağlantısının kaldırılması, mevcut temas düğümlerinin
korunması ve yeni tribün çizim grubu açılmaması kontrol edildi.
