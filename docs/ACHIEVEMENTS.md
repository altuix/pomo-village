# NEFES — Achievement Tasarımı (H3, Faz F)

18 achievement; hepsi CEZASIZ (kayıp/kaçırma achievement'ı YOK — cozy anayasa).
Kod kancaları world.gd'nin zaten TEK SEFERLİK olan milestone/unlock noktalarında
(`SteamBridge.unlock` — Steam yoksa no-op). API adı = tablodaki kimlik.

| Kimlik | Ad (EN) | Ad (TR) | Tetik (koddaki nokta) |
|---|---|---|---|
| ACH_FIRST_SESSION | First Breath | İlk Nefes | sessions == 1 (finish_focus_reward) |
| ACH_STREAK_3 | Warming Up | Isınıyoruz | streak >= 3 (atölye kilidi) |
| ACH_STREAK_5 | In the Flow | Akışta | streak >= 5 (kütüphane kilidi) |
| ACH_SESSIONS_10 | Stargazer | Gökyüzüne Bakan | sessions >= 10 (rasathane) |
| ACH_SESSIONS_20 | Green Thumb | Yeşil Parmak | sessions >= 20 (sera) |
| ACH_SESSIONS_35 | Deep Rest | Derin Dinlenme | sessions >= 35 (hamam) |
| ACH_SESSIONS_50 | To Labor | Emeğe | ses50 anıtı (heykel) |
| ACH_SESSIONS_100 | Century Oak | Yüzyıl Meşesi | ses100 anıtı |
| ACH_SESSIONS_200 | Gilded | Yaldızlı | ses200 (kule yaldızı) |
| ACH_SESSIONS_500 | Eternal Flame | Ebedi Alev | ses500 anıtı |
| ACH_TIER_VILLAGE | A Real Village | Artık Bir Köy | tier_koy milestone |
| ACH_TIER_TOWN | Town Charter | Kasaba Beratı | tier_kasaba milestone |
| ACH_TIER_CITY | City Lights | Şehir Işıkları | tier_sehir milestone |
| ACH_FIRST_REPLY | Pen Pal | Mektup Arkadaşı | ilk reply_letter (bond 0→1) |
| ACH_BOND_10 | Kindred Town | Gönüldaş Kasaba | bond >= 10 (reply/konser sonrası) |
| ACH_MELODY | Composer | Besteci | melody_saved ilk kez (teach_tower) |
| ACH_CONCERT | Town Concert | Meydan Konseri | concert_done (iyi beste ödülü) |
| ACH_COMPLETE | The Town Breathes | Kasaba Nefes Alıyor | butunlendi milestone |

Steamworks panelinde: tümü görünür (hidden yok), ikonlar palet-içi (ikon üreticinin
varyantları kullanılabilir). İstatistik (stat) API'si launch sonrası (odak dakikası) —
şimdilik yalnız achievement.
