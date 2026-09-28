# Türkçe spiker ve yorumcu

Bu pakette 42 olay grubuna ait 171 **yapay ses kaydı** bulunur. İnsan seslendirme veya gerçek bir spikerin taklidi değildir. Spiker `tr-TR-AhmetNeural`, yorumcu `tr-TR-EmelNeural` sesini kullanır. Replikler bu proje için yazılmıştır; hizmete yalnızca `tools/commentary_script.json` içindeki genel cümleler gönderilir. Oyuncu adı, maç kaydı veya kullanıcı verisi gönderilmez.

Sesler Microsoft Edge'in konuşma hizmetinden `edge-tts 7.2.8` ile bir kez üretilmiştir. Oyun bu hizmete bağlanmaz; **171 mono, 24 kHz, 16-bit WAV** dosyasını yerel Godot kaynaklarından çalar. Başlangıç/bitiş sessizliği temizlenmiş, düzeyler −18 LUFS hedefine getirilmiş, tepe düzeyi −2 dB ile sınırlandırılmış ve kısa giriş/çıkış yumuşatmaları uygulanmıştır. Toplam ham paket yaklaşık 20 MB ve 6 dakika 57 saniyedir. Godot'un WAV içe aktarma ayarları paketleme sırasında ayrıca sıkıştırır.

Her spiker kaydının varsa kendi yorumcu cevabı vardır. Cevaplar `AudioStreamPlayer.finished` sonrasında 0,35–0,65 saniye bekler; metin uzunluğundan tahmin edilen zamanla başlatılmaz. Tek ses kanalı üst üste konuşmayı engeller. Skor/devre değişimi, yeni pozisyon, ekran geçişi ve sessize alma bekleyen cevabı iptal eder. Oynatım sırasında kayıtların hızı ve perdesi rastgele değiştirilmez. `Stadium` ses yolu konuşurken yaklaşık 5 dB azalır; saha efektleri ve ses ayarları değişmez.

Kayıtlı replikler özel isim içermez. **Sistem sesi** ayarı önceki Türkçe TTS anlatımını ve dinamik oyuncu adlarını korur. Bir WAV eksikse ilgili çağrı da bu yolu kullanır; Türkçe sistem sesi yoksa yalnızca altyazı kalır. Türkçe metin başka dilin sesiyle okunmaz.

Yeniden üretmek için ayrı bir Python ortamına `edge-tts==7.2.8` kurup `ffmpeg` erişilebilirken proje kökünden çalıştır:

```sh
python tools/build_commentary_audio.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/recorded_commentary_check.gd
```

Üretim internet gerektirir; oyun ve testler gerektirmez. `manifest.json` her dosyanın metnini, sesini, hızını ve kaynak parmak izini saklar. Aynı girdilere ait mevcut kayıtlar tekrar üretilmez; metni veya üretim ayarını değiştirince yalnızca ilgili kayıt yenilenir. `scripts/commentary_voice_bank.gd` bu komutla oluşturulur. Sanatçı kayıtları kullanılacaksa aynı metin/dosya eşlemeleri korunarak WAV'lar değiştirilebilir; replik de değişirse banka ve kaynak metin birlikte güncellenmelidir.

Teknik kaynaklar: [edge-tts projesi](https://github.com/rany2/edge-tts), [Microsoft Türkçe ses listesi](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/language-support?tabs=tts), [Godot AudioStreamPlayer](https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer.html).
