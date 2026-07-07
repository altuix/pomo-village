# NEFES — JUICE & GELİŞTİRME YAPILACAKLAR (Claude Code için)
Kaynak: bu oturumdaki juice araştırması (anticipation/easing/partikül/ikincil hareket/ses)
+ v10-v15 devir teslim. İLK GÖREV: derin juice araştırması — "Juice it or Lose it" (GDC),
Vlambeer "art of screenshake", easings.net; bulgularla bu listeyi güncelle.

## A. JUICE (öncelik sırasıyla)
1. İnşaat: Tween easeOutBack scale.y + GPUParticles2D toz + bitişte mote patlaması + squash
2. Lamba kaskadı: PointLight2D enerji tween'i + kıvılcım + minik 'tık' (AudioStreamPlayer)
3. Pencere yanışı: tek tek 'flık' — parlak flaş→sönme overshoot (Tween)
4. WorldEnvironment glow (bloom GPU'ya) + CanvasModulate gün eğrisi (evening() hazır)
5. Veda: yıldız Path2D yükselişi + stardust trail + anı ağacı elastic doğuş
6. Doğum taç yaprakları; saat başı kule nabzı + kuş ürkmesi; mevsim yaprak/kar partikülü
7. Kamera: konser/ödülde 1-2px yumuşak zoom-in (screenshake DEĞİL — cozy)
8. UI juice: mektup zarfı sallanır, olay satırı kayarak gelir, buton hover ısınması
## B. SİSTEM PORTLARI (devir teslim v11-v15'ten)
9. Hane+yaşam döngüsü (doğum/veda/göç kuralları) 10. Işık bütçesi (lightCurve+uyku)
11. Odak seansı GERÇEK 25/50dk Timer + ×1.5 + seri ödülleri 12. Dilekler+mektup+cevap UI
13. Ses motoru: AudioStreamGenerator ya da numpy→ogg stem'ler; mikser slider'ları
14. Kule melodisi ızgarası + konser ödülü + melodi paylaşım kodu (8 harf)
## C. PAZAR EKSİKLERİ (kritik sırayla)
15. SAVE + offline "sen yokken" özet kartı (retention #1) 16. Ekran-altı borderless şerit modu
17. Albüm (sakin/anı/mektup koleksiyonu) 18. UI sadeleştirme (tek sakin menü)
19. Dikey mod 20. Kartpostal modu 21. Gerçek tempolar (gün=30dk) 22. Sakin gündüz rutini

## GODOT PORT DURUMU (Faz0 + A0-A7 + B1-B4 tamamlandı — DEVIR_TESLIM.md'ye bak)
✅ Madde 0 pipeline (verify.sh check/sim/visual, tek binary) ✅ 1-3 juice çekirdeği (_draw partikül/
   kaskad/veda-yıldızı; native PointLight2D/glow = opsiyonel) ✅ 4 CanvasModulate yok (gün eğrisi _draw'da)
✅ 5 veda yıldızı+anı ağacı ✅ 6 doğum taçyaprağı+saatbaşı kuş ✅ 7 kamera mikro-zoom (konser/ödül)
✅ 9 hane+yaşam döngüsü ✅ 10 ışık bütçesi ✅ 11 odak Pomodoro/Derin+seri ✅ 12 dilek+mektup+cevap
✅ 13 ses motoru (AudioStreamGenerator 4 kanal+6 olay) ✅ 14 kule melodisi+konser+paylaşım kodu
✅ 15 SAVE+offline kart ✅ 16 borderless şerit ✅ 21 gün=30dk (tick=0.75s) ✅ 22 gündüz rutini
⏳ ERTELENEN (opsiyonel): 8 UI juice, native PointLight2D/glow, 17 albüm, 18 tek menü, 19 gerçek dikey render, 20 kartpostal
