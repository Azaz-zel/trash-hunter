# TRASH HUNTER

## Game Design Document & Technical Development Plan — v2.0

**Platform:** Roblox (mobile-first, juga PC dan konsol)\
**Genre:** Scavenging simulator dengan tekanan kejar-kejaran\
**Perspective:** Third-person\
**Visual direction:** Stylized, cerah, komedik\
**Tagline:** *Find treasure in trash. Don't get caught.*\
**Development tools:** Claude Code + Roblox Studio + official Roblox
Studio MCP\
**Tanggal revisi:** 2026-11-03

------------------------------------------------------------------------

## Ringkasan perubahan dari v1

Versi lama disimpan di `TRASH_HUNTER_GDD_v1.md`. Perubahan utama:

-   Momen membuka dumpster (reveal) menjadi inti game dan dibangun di
    Phase 1, bukan Phase 3.
-   Art semi-realistic diganti stylized dan komedik, dengan maskot
    raccoon.
-   Item condition dihapus. Variasi nilai sekarang datang dari mutasi
    (Shiny, Golden).
-   Wanted level 0–3 diganti satu suspicion bar yang terlihat.
-   Area terlarang dibuat jelas sebagai zona merah.
-   Saat tertangkap, hanya isi backpack yang hilang. Ada opsi Drop & Run.
-   Loot dibuat per pemain, dengan cooldown per dumpster.
-   Ditambahkan collection book, rak pajangan, dan pilihan "jual atau
    simpan".
-   Ditambahkan pilihan push-your-luck "Dig deeper".
-   Polisi diberi timebox 3 hari dan punya rencana cadangan.
-   Ditambahkan bagian monetisasi, rating konten, posisi pasar, dan
    metrik retensi.
-   Definition of Done sekarang juga mengukur fun, bukan hanya
    stabilitas.

------------------------------------------------------------------------

# 1. Game Overview

## High concept

TRASH HUNTER adalah game scavenging di mana pemain mengorek dumpster di
sebuah kota kartun untuk menemukan harta karun tersembunyi. Setiap
dumpster adalah "unboxing" gratis: tutup terbuka, sampah beterbangan,
dan cahaya warna rarity bocor keluar sebelum barangnya terlihat.

Dumpster terbaik ada di zona merah: lahan pribadi, belakang toko mewah,
dan gudang. Di sana polisi dan satpam berjaga. Pemain memilih sendiri
seberapa besar risiko yang diambil, lalu harus membawa hasilnya pulang
sebelum tertangkap.

## Core player fantasy

"Satu dumpster lagi... siapa tahu ada PC gaming emas di dalamnya. Tapi
senter satpam itu makin dekat."

## Posisi pasar

Tema scavenging sampah sudah terbukti menarik pemain di Roblox:

-   **DUMP** sempat mencapai 143 ribu pemain bersamaan, lalu turun drastis
    karena tidak bisa menahan pemain.
-   **Prospecting!** mencapai 181 ribu pemain bersamaan dengan loop
    gali-jual-upgrade.
-   **Dumpster Divers!** punya pitch hampir sama ("dumpster, jual,
    upgrade, buka zona") tetapi sepi.

Kesimpulan: loop "cari-jual-upgrade" saja tidak cukup unik.

**Pembeda TRASH HUNTER adalah tekanan polisi dan pelarian.** Elemen ini
tidak dimiliki kompetitor langsung. Pembeda ini harus terlihat di
thumbnail, judul, dan lima menit pertama permainan.

Detail riset ada di Lampiran A.

## Design pillars

1.  **The Reveal:** Setiap dumpster terasa seperti membuka hadiah.
    Dumpster ke-50 harus tetap seru seperti dumpster pertama.
2.  **Risiko pilihan pemain:** Bahaya selalu terlihat dan dipilih
    secara sadar. Pemain tidak boleh merasa dijebak.
3.  **Collect & show off:** Barang temuan bukan sekadar angka uang.
    Pemain mengoleksi, memajang, dan memamerkannya.
4.  **Social moments:** Penemuan besar diumumkan ke server, dan main
    bareng teman memberi bonus.
5.  **Progression yang terasa:** Upgrade jelas manfaatnya dan terasa
    didapat lewat usaha.

# 2. Core Gameplay Loop

1.  Spawn di Hideout (safe zone).
2.  Pilih tujuan: zona hijau (aman) atau zona merah (loot lebih bagus,
    ada polisi).
3.  Cari dumpster dan lakukan search.
4.  Lihat reveal. Ambil barang atau pilih **Dig deeper**.
5.  Kelola kapasitas backpack dan suspicion bar.
6.  Kabur atau gunakan Drop & Run jika dikejar.
7.  Kembali ke Hideout. Pilih **jual** atau **simpan ke koleksi**.
8.  Upgrade perlengkapan, lalu kembali dengan target lebih tinggi.

## Lima menit pertama (FTUE)

Target: pemain mendapat barang Rare dalam 60 detik pertama dan
merasakan pengejaran pertama dalam 5 menit.

1.  Spawn di depan Hideout. Ada satu dumpster tutorial berjarak beberapa
    langkah dengan panah petunjuk.
2.  Search pertama dijamin menghasilkan barang Rare, lengkap dengan
    reveal penuh.
3.  Panduan singkat mengarahkan pemain ke titik jual. Penjualan pertama
    cukup untuk membeli upgrade pertama yang murah.
4.  Panah berikutnya menunjuk ke zona merah terdekat, dengan teks "Loot
    lebih bagus... tapi hati-hati."
5.  Suspicion bar diperkenalkan saat pemain masuk zona merah pertama.

Teks tutorial maksimal satu kalimat per langkah, dan tidak ada dialog
panjang.

# 3. Search and Reveal (mekanik inti)

## Search

-   Pemain mendekati dumpster, lalu menahan tombol interaksi (tombol
    layar besar di mobile, `E` di PC).
-   Waktu search awal 2 detik dan bisa dipercepat lewat upgrade.
-   Selama search, karakter mengorek dan sampah kecil beterbangan.
    Search bukan sekadar progress bar.

## Dig layer (sentuhan skill ringan)

Selama search, sebuah penanda bergerak di bar. Jika pemain menekan tap
saat penanda berada di sweet spot, hasilnya **Perfect Dig**: bobot
rarity naik sedikit untuk roll tersebut.

-   Tidak tap pun tetap mendapat hasil normal. Tidak ada hukuman.
-   Tujuannya memberi pemain sesuatu untuk dikuasai tanpa membuat
    minigame berat.
-   Jika dalam playtest dig layer terasa mengganggu di mobile, hapus
    fitur ini dan pertahankan hold biasa.

## Reveal sequence

Durasi total sekitar 1,5 detik dan bisa dilewati dengan tap.

1.  Tutup dumpster bergetar.
2.  Cahaya warna rarity bocor dari celah. Ini memberi "tease" sebelum
    barang terlihat.
3.  Tutup terbuka dan barang melompat keluar.
4.  Panel menampilkan nama barang, warna rarity, mutasi (jika ada), dan
    nilai.

Efek ditingkatkan per tier:

-   Rare ke atas mendapat suara khusus.
-   Epic ke atas mendapat screen shake ringan.
-   Legendary dan Jackpot mendapat slow-motion singkat, partikel besar,
    dan pengumuman ke server.

## Dig deeper (push-your-luck)

Setelah reveal, pemain memilih:

-   **Ambil & pergi:** barang masuk backpack dan dumpster masuk cooldown.
-   **Dig deeper:** satu search lagi di dumpster yang sama. Waktunya
    +1,5 detik, dan bobot rarity naik satu tingkat. Di zona merah,
    suspicion juga naik lebih cepat. Maksimal dua kali Dig deeper per
    dumpster.

Pilihan ini adalah keputusan risk/reward kecil yang terjadi di setiap
dumpster.

## Dumpster rules

-   **Loot per pemain:** setiap pemain punya cooldown sendiri untuk
    setiap dumpster (awal 90 detik). Pemain yang baru masuk server tidak
    akan menemukan dumpster kosong.
-   Dumpster yang sedang cooldown untuk seorang pemain terlihat tertutup
    dan redup di layar pemain itu.
-   Beberapa pemain boleh mengorek dumpster yang sama secara bersamaan.
    Setiap pemain mendapat roll sendiri.
-   Setiap dumpster memiliki: tipe, loot table, zona (hijau atau merah),
    waktu search, dan cooldown.
-   Semua roll dilakukan di server. Client hanya meminta search dan
    menampilkan hasil.

# 4. Loot, Mutations, and Collection

## Rarity

Warna rarity = tingkat nilai. Pemain harus bisa membaca nilai barang
hanya dari warnanya.

  Rarity      Warna          Contoh loot                          Bobot awal (zona hijau)
  ----------- -------------- ------------------------------------ -------------------------
  Common      Abu-abu        Kardus, kaleng, botol                60
  Uncommon    Hijau          Perkakas, sepatu bekas, mainan       25
  Rare        Biru           Monitor, keyboard, skateboard        10
  Epic        Ungu           Konsol lama, komponen PC             4
  Legendary   Oranye         Barang koleksi langka                0,9
  Jackpot     Emas berkilau  PC gaming emas, konsol edisi khusus  0,1

Zona merah menggeser bobot ke rarity yang lebih tinggi. Semua angka di
atas adalah nilai awal dalam `GameConfig` dan akan disetel lewat
playtest.

Sisipkan juga **barang aneh dan lucu** (misalnya patung bebek
raksasa, toilet emas, atau kaset misterius). Barang lucu lebih sering
dibagikan pemain daripada barang realistis.

## Mutations

Mutasi menggantikan item condition. Setiap barang punya peluang kecil
untuk muncul dengan mutasi:

-   **Shiny:** nilai ×2. Peluang awal 5%. Ditandai efek kilau.
-   **Golden:** nilai ×5. Peluang awal 1%. Ditandai warna emas penuh.

Mutasi lain (misalnya Cursed atau Rainbow) menjadi kandidat konten
update setelah rilis.

## Collection book

-   Berisi daftar semua barang. Barang yang belum ditemukan tampil
    sebagai siluet.
-   Mutasi tercatat terpisah. Contoh: "Monitor ✓, Shiny Monitor ✗".
-   Ada hadiah kelengkapan per set atau kategori, misalnya bonus uang,
    title, atau kosmetik.
-   Datanya disimpan sebagai daftar ID barang yang pernah ditemukan.

## Jual atau simpan

Di Hideout, setiap barang bisa:

-   **Dijual** untuk mendapat uang.
-   **Dipajang** di rak Hideout. Slot rak terbatas dan bisa di-upgrade.

Barang Legendary yang dipajang tidak menghasilkan uang, tetapi terlihat
oleh pemain lain yang lewat atau berkunjung. Ini menjadi keputusan
risk/reward kedua setelah Dig deeper.

# 5. Risk: Red Zones, Suspicion, and Police

## Zona merah

Area terlarang harus terlihat jelas. Contohnya:

-   Lantai atau marka bernuansa merah.
-   Pagar dan papan **PRIVATE PROPERTY**.
-   Lampu sorot.
-   Satpam atau polisi kartun yang berpatroli.

Zona merah selalu memberi loot lebih bagus. Masuk zona merah adalah
pilihan sadar pemain. Zona hijau tidak pernah memicu pengejaran.

## Suspicion bar

Wanted level 0–3 diganti dengan satu bar yang terlihat di layar.

-   Bar mulai terisi saat pemain melakukan search di zona merah.
-   Bar terisi lebih cepat jika:
    -   Pemain berada dalam jangkauan pandang polisi.
    -   Pemain memilih Dig deeper.
-   Bar turun perlahan saat pemain keluar zona merah atau tidak terlihat
    polisi.
-   Peringatan visual dan audio muncul di 50% dan 80%.
-   Saat bar penuh, pengejaran dimulai.

## Police AI (state machine sederhana)

1.  **Patrol:** berjalan melalui titik rute di zona merah.
2.  **Investigate:** mendekati lokasi saat suspicion seorang pemain di
    atas 50%.
3.  **Chase:** mengejar saat suspicion penuh.
4.  **Catch:** menangkap jika berhasil menyentuh pemain selama durasi
    tertentu.
5.  **Return:** kembali ke patroli setelah pemain lolos atau
    tertangkap.

Pengejaran berakhir jika pemain mencapai Hideout atau zona hijau, keluar
dari jangkauan pandang polisi cukup lama, atau memilih Drop & Run.

**Keadilan:**

-   Deteksi tidak pernah instan.
-   Kecepatan polisi sedikit di bawah kecepatan pemain yang sudah
    di-upgrade.
-   Polisi tidak bisa keluar dari zona merah lebih jauh dari batas
    tertentu.

## Drop & Run

Selama dikejar, tombol besar **DROP & RUN** muncul.

-   Jika ditekan, setengah isi backpack (yang bernilai terendah lebih
    dulu) dijatuhkan.
-   Pengejaran langsung berakhir.

Pemain selalu punya jalan keluar yang ia pilih sendiri.

## Konsekuensi tertangkap

-   Seluruh isi backpack yang belum diamankan hilang. Karena backpack
    awal kecil, kerugiannya juga kecil.
-   Pemain dibawa kembali ke Hideout dengan animasi kartun (peluit dan
    "tilang").
-   Uang, koleksi, barang pajangan, dan upgrade tidak pernah hilang.

## Rencana cadangan polisi

Pathfinding NPC di Roblox rawan tersangkut di trotoar dan pintu. Karena
itu, implementasi pengejaran diberi **timebox 3 hari**.

Jika setelah 3 hari pengejaran masih terasa janky, ganti dengan sistem
**vision cone / lampu sorot**: polisi berpatroli di rute tetap, dan
pemain yang tertangkap sorotan cukup lama langsung tertangkap tanpa
pengejaran fisik. Jangan memperpanjang timebox meskipun pengejaran
"hampir jadi".

## Disconnect saat dikejar

Jika pemain keluar game saat status Chase, terapkan konsekuensi
tertangkap saat data disimpan. Keluar game tidak boleh menjadi cara
kabur.

# 6. World and Map Progression

## Zone 1 — Suburbs (prototipe)

-   Hideout di tengah, dengan titik jual dan rak pajangan.
-   Zona hijau: dumpster rumah tangga dan gang perumahan.
-   Zona merah: belakang minimarket dan lahan pribadi yang dipagari.
-   Satu polisi atau satpam yang berpatroli di zona merah.

## Zona berikutnya (setelah ada data retensi)

-   Downtown
-   Industrial Zone
-   Rich District

Desain detail zona-zona ini ditunda sampai metrik prototipe terbaca
(lihat bagian 15). Satu dumpster tipe baru plus event baru sering lebih
murah dan lebih efektif daripada satu distrik baru.

# 7. Player Progression and Economy

## Upgrades

  Upgrade         Efek                                           Prototipe
  --------------- ---------------------------------------------- -----------
  Backpack        Kapasitas slot (awal 8)                        Ya
  Search tool     Search lebih cepat                             Tidak
  Sneakers        Kecepatan lari lebih tinggi                    Tidak
  Flashlight      Melihat dumpster tersembunyi di area gelap     Tidak
  Display shelf   Menambah slot pajangan                         Tidak

## Aturan ekonomi

-   Uang hanya bertambah dari penjualan yang diproses server.
-   Setiap upgrade punya harga dan manfaat yang terlihat jelas sebelum
    dibeli.
-   Jackpot harus terasa besar, tetapi tidak membuat semua upgrade bisa
    dibeli sekaligus.
-   **Money sink:** harga upgrade naik per tingkat. Hadiah set koleksi
    berupa kosmetik, bukan uang dalam jumlah besar.
-   Semua angka (harga, bobot, cooldown, kapasitas, waktu search,
    kecepatan suspicion) disimpan di `GameConfig`.

# 8. Social

Masuk prototipe:

-   **Pengumuman server** untuk Legendary dan Jackpot. Contoh: "Raka
    menemukan GOLDEN GAMING PC!"
-   **Bonus teman:** loot sedikit lebih bagus (misalnya +10% bobot Rare
    ke atas) jika ada teman Roblox di server yang sama. Bonus ini
    mendorong co-play, sinyal yang dinilai algoritma Roblox.
-   Pemain lain bisa melihat rak pajangan saat melewati Hideout.

Setelah rilis:

-   Kunjungan Hideout pemain lain, dengan tombol "like" untuk pajangan.
-   Event server bersama (lihat Garbage Day di bagian 15).

# 9. Art and Audio Direction

-   **Stylized, saturasi tinggi, bentuk tebal.** Tujuannya mudah dibaca
    di layar HP dan thumbnail, murah dibuat oleh dev solo, dan ringan di
    perangkat low-end.
-   Sampah tetap terlihat lucu, bukan kotor. Dumpster boleh bersinar
    sesuai rarity.
-   **Maskot:** raccoon kartun sebagai rival yang kadang terlihat
    mengorek dumpster. Raccoon ini menjadi ikon game dan bahan utama
    thumbnail.
-   Polisi dan satpam bergaya kartun: peluit, senter besar, ekspresi
    berlebihan. Tidak ada senjata, tidak ada kekerasan.
-   **Audio:** setiap rarity punya suara reveal sendiri, dan Jackpot
    punya jingle khas. Ada musik tegang saat suspicion di atas 80% dan
    saat dikejar.
-   **Thumbnail pertama:** karakter memegang PC emas yang bercahaya dari
    dalam dumpster, polisi kartun mengejar di belakang, dan raccoon
    mengintip.

# 10. User Interface (mobile-first)

UI minimum:

-   Uang.
-   Kapasitas backpack.
-   Tombol interaksi besar, dengan bar search dan sweet spot.
-   Panel reveal dengan tombol "Ambil" dan "Dig deeper".
-   Suspicion bar beserta peringatannya.
-   Tombol Drop & Run (muncul hanya saat dikejar).
-   Inventory dengan pilihan jual atau pajang.
-   Collection book.
-   Toko upgrade.

Aturan UI:

-   Semua tombol bisa ditekan dengan ibu jari, dan diuji di emulator
    device Studio sejak hari pertama.
-   Teks singkat dan tidak menutupi karakter saat bergerak.
-   Satu istilah untuk satu hal: "Hideout" untuk tempat aman, "Backpack"
    untuk barang yang belum aman.

# 11. Monetization (dirancang sekarang, dirilis setelah prototipe)

Prinsip: **jual kenyamanan dan kosmetik, bukan kekuatan atau peluang.**

Kandidat:

-   Game pass Backpack+ (slot ekstra).
-   Game pass Auto-sell dari mana saja.
-   Game pass slot pajangan tambahan.
-   Kosmetik karakter dan dekorasi Hideout.
-   Developer product "Bail out": mengambil kembali isi backpack setelah
    tertangkap. Harganya kecil dan sekali pakai.

**Aturan Paid Random Items (diperketat Roblox per 26 Mei 2026):**

-   Loot dumpster yang gratis tidak memerlukan disclosure peluang.
-   Jika nanti ada item berbayar yang memberi hasil acak atau mengubah
    peluang (crate, luck potion, boost Robux), item itu wajib
    menampilkan peluang dalam angka sebelum pembelian dan wajib
    menggunakan `PolicyService` (`ArePaidRandomItemsRestricted`) untuk
    memblokir pengguna yang tidak memenuhi syarat.
-   Pelanggaran bisa berujung penghapusan game.
-   Untuk v1, **jangan jual item acak atau luck boost sama sekali**.

Untuk menghindari pay-to-win, game pass tidak boleh menaikkan rarity
atau mengurangi risiko polisi melebihi apa yang bisa dicapai lewat
upgrade biasa.

# 12. Content Rating and Compliance

-   Isi kuesioner Content Maturity dengan lengkap sebelum rilis. Jika
    tidak, game diberi label "Content May Vary" dan hanya bisa diakses
    pengguna 16+.
-   Target label **Minimal** atau **Mild** supaya game tersedia untuk
    Roblox Kids dan Roblox Select (umur 9–15).
-   Penangkapan bersifat kartun: tanpa pukulan, tanpa senjata, tanpa
    darah.
-   Framing tema: pemain adalah "pemburu harta karun" yang menerobos
    lahan pribadi, bukan pencuri. Barang berasal dari sampah yang
    dibuang.
-   Catatan: kategori kuesioner berfokus pada kekerasan, darah, rasa
    takut, humor kasar, dan perjudian. Ekspektasi label Minimal adalah
    asumsi yang harus dikonfirmasi saat mengisi kuesioner.

# 13. Technical Architecture

## Recommended Roblox hierarchy

``` text
Workspace
├── Map
│   └── Suburbs
│       ├── GreenZone
│       └── RedZones
├── Dumpsters          (tag CollectionService: "Dumpster")
├── PoliceNPCs
└── Hideout
    ├── SellPoint
    └── DisplayShelf

ReplicatedStorage
├── Remotes
├── Shared
│   ├── ItemDefinitions
│   ├── LootTables
│   └── GameConfig
└── Assets

ServerScriptService
├── Bootstrap.server.lua
└── Services
    ├── LootService        (roll, cooldown per pemain, dig deeper)
    ├── InventoryService   (backpack, koleksi, pajangan)
    ├── EconomyService     (jual, upgrade)
    ├── SuspicionService   (bar, zona, status chase)
    ├── PoliceService      (state machine NPC)
    ├── SocialService      (pengumuman, bonus teman)
    └── DataService        (load/save, session lock)

ServerStorage
├── LootTemplates
└── NPCTemplates

StarterPlayer
└── StarterPlayerScripts
    └── ClientController.client.lua

StarterGui
├── HUD
├── RevealUI
├── InventoryUI
└── CollectionUI
```

Struktur ini adalah target arsitektur, bukan instruksi untuk langsung
membuat semua file. Claude harus terlebih dahulu memeriksa place yang
terbuka dan menyesuaikan struktur dengan project aktual.

## Responsibilities

**Server**

-   Melakukan semua roll loot, mutasi, dan Perfect Dig. Hasil tap
    timing hanya dikirim sebagai klaim, lalu divalidasi terhadap waktu
    di server.
-   Memvalidasi jarak pemain ke dumpster dan cooldown per pemain.
-   Mengelola uang, backpack, koleksi, dan pajangan.
-   Mengelola suspicion, chase, dan penangkapan.
-   Menyimpan progres pemain.

**Client**

-   Menampilkan UI, animasi reveal, dan efek.
-   Memproses input dan mengirim permintaan lewat RemoteEvents.
-   Tidak pernah menentukan hadiah, harga, atau status.

## Anti-exploit (masuk Phase 1, bukan Phase 4)

Game collect-carry-sell adalah target utama exploit teleport dan
spam remote. Karena itu, sejak Phase 1:

-   Setiap remote memeriksa jarak pemain ke target (dumpster atau titik
    jual).
-   Ada rate limit per pemain per remote.
-   Cooldown dumpster disimpan di server.
-   Ada pemeriksaan kecepatan pergerakan sederhana. Lompatan posisi yang
    tidak wajar membatalkan search dan penjualan.
-   Penjualan hanya bisa dilakukan untuk barang yang tercatat di
    inventaris server.

## Data persistence

DataStoreService menyimpan:

-   Uang.
-   Upgrade.
-   Koleksi (ID barang yang pernah ditemukan, termasuk mutasi).
-   Barang pajangan.
-   Isi backpack.
-   Flag tutorial.

Aturan:

-   Hanya server yang mengakses DataStore.
-   Gunakan `UpdateAsync` dan session lock supaya data tidak tertimpa
    jika pemain pindah server dengan cepat.
-   Simpan saat pemain keluar, secara berkala, dan di `BindToClose`.
-   Retry dengan backoff jika penyimpanan gagal. Jangan menimpa data
    dengan data kosong jika load gagal.
-   Disconnect saat status Chase diperlakukan sebagai tertangkap (bagian
    5).

# 14. First Playable Prototype

Target: satu area kecil yang bisa dimainkan dari awal sampai akhir dan
diuji ke orang lain.

## Required features

1.  Karakter spawn di Hideout, Suburbs.
2.  Dumpster tutorial dengan Rare yang dijamin.
3.  Minimal 6 dumpster: 4 di zona hijau, 2 di zona merah.
4.  Search dengan reveal penuh (cahaya, suara, warna rarity).
5.  Dig deeper.
6.  Sekitar 20 barang dengan 6 rarity, plus mutasi Shiny dan Golden.
7.  Backpack dengan kapasitas terbatas, beserta satu upgrade backpack.
8.  Jual atau pajang di Hideout.
9.  Collection book sederhana.
10. Suspicion bar, satu polisi, pengejaran (atau vision cone cadangan),
    Drop & Run, dan konsekuensi tertangkap.
11. Pengumuman server untuk Legendary dan Jackpot.
12. Penyimpanan data dan anti-exploit dasar.
13. Bisa dimainkan nyaman di mobile.

## Out of scope for prototype

-   Zona 2–4.
-   Kendaraan.
-   Repair atau flip.
-   Pet.
-   Tim polisi yang dimainkan pemain.
-   Trading.
-   Event Garbage Day.
-   Kunjungan Hideout.
-   Monetisasi.

# 15. Development Plan

## Phase 0 — Connect and inspect

-   Pastikan Roblox Studio MCP tersambung.
-   Identifikasi place dan struktur yang sedang terbuka.
-   Periksa scripts, objek, dan console errors.
-   Simpan backup.

**Exit criteria:** Claude dapat membaca place yang benar dan memberikan
laporan struktur project.

## Phase 1 — The Reveal (satu dumpster)

-   Siapkan baseplate kosong dengan satu dumpster.
-   Buat hold-to-search yang berjalan di emulator mobile.
-   Server melakukan roll dari tabel sekitar 15 barang.
-   Tambahkan reveal lengkap: cahaya, suara, warna rarity, dan mutasi.
-   Tambahkan Dig deeper dan dig layer.
-   Pasang anti-exploit dasar pada remote search.

**Exit criteria:** setelah 50 kali membuka dumpster, developer masih
ingin membuka satu lagi. Jangan membangun map sebelum kriteria ini
terpenuhi.

## Phase 2 — The Loop

-   Buat blockout Suburbs dengan zona hijau, zona merah, dan Hideout.
-   Tambahkan dumpster dengan cooldown per pemain.
-   Tambahkan backpack, jual atau pajang, dan uang.
-   Tambahkan satu upgrade backpack.
-   Tambahkan collection book.
-   Tambahkan DataService.

**Exit criteria:** pemain bisa mencari, mengumpulkan, menjual, dan
upgrade, dan progresnya tersimpan.

## Phase 3 — Risk (timebox polisi 3 hari)

-   Tambahkan suspicion bar dan zona merah.
-   Tambahkan polisi dengan patrol, investigate, chase, dan catch.
-   Jika lewat 3 hari, ganti dengan vision cone.
-   Tambahkan Drop & Run dan konsekuensi tertangkap.

**Exit criteria:** pemain bisa menyelesaikan satu sesi dengan risiko
nyata, dan kalah terasa adil.

## Phase 4 — Polish and Social

-   Tambahkan FTUE lima menit.
-   Tambahkan pengumuman server dan bonus teman.
-   Lengkapi audio dan musik tegang.
-   Buat thumbnail dan ikon.

**Fun gate:** minimal 5 orang yang tidak dikenal (bukan teman dekat)
bermain 15 menit atau lebih tanpa disuruh.

## Phase 5 — Stabilization and Launch

-   Uji multiplayer dengan server dan beberapa client.
-   Uji validasi remote dan exploit.
-   Uji tertangkap, disconnect saat chase, dan rejoin.
-   Uji penyimpanan dan pemuatan data.
-   Isi kuesioner Content Maturity.
-   Publish. Jalankan iklan kecil, lalu baca metrik di Creator Analytics.

**Target waktu:** publish 4–6 minggu setelah Phase 1 dimulai. Ini
estimasi kasar, bukan janji.

## Metrik setelah rilis

Algoritma "Recommended For You" Roblox (diperbarui 15 Juni 2026) menilai
retensi sampai hari ke-28. Pantau:

-   First play bounce rate. Ini sinyal yang paling penting, dan sangat
    dipengaruhi lima menit pertama.
-   Retensi D1, D7, dan D28.
-   Rata-rata waktu bermain per sesi dan jumlah hari bermain.
-   Intentional co-play: main bareng teman.

Gunakan metrik ini untuk menentukan konten berikutnya, bukan urutan di
dokumen ini.

## Roadmap konten (kandidat, pilih berdasarkan data)

-   **Garbage Day:** setiap sekitar 15 menit, truk sampah menjatuhkan
    loot langka di satu area, disertai pengumuman ke seluruh server.
-   **Trash Panda pets:** raccoon yang ditemukan di sampah, dengan perk
    pasif (mengendus Rare, memperlambat polisi).
-   **Mutasi baru:** Cursed, Rainbow, dan mutasi event musiman.
-   **Kunjungan Hideout dan Trash Museum:** pemain lain bisa melihat dan
    me-like pajangan.
-   **Zona baru:** Downtown, Industrial, Rich District.
-   **Repair atau flip:** memperbaiki barang rusak untuk dijual lebih
    mahal. Model ini sudah terbukti di Junk Mechanics.
-   **Tim polisi pemain:** mode asimetris. Hanya masuk akal jika server
    sudah ramai.

Target ritme update: satu update kecil per minggu (barang, mutasi, atau
event) lebih baik daripada satu update besar per bulan.

# 16. Testing Checklist

-   [ ] Loot, mutasi, dan Perfect Dig ditentukan oleh server.
-   [ ] Rare tutorial muncul pada search pertama pemain baru.
-   [ ] Cooldown dumpster berlaku per pemain dan tidak bisa dilewati.
-   [ ] Pemain tidak bisa menjual atau memajang barang yang tidak
    dimiliki.
-   [ ] Interaksi tidak bisa dilakukan dari jarak yang tidak sah.
-   [ ] Remote punya validasi dan rate limit.
-   [ ] Teleport atau speed exploit membatalkan search dan penjualan.
-   [ ] Backpack tidak bisa melebihi kapasitas.
-   [ ] Zona hijau tidak pernah memicu pengejaran.
-   [ ] Drop & Run mengakhiri pengejaran dan membuang barang yang benar.
-   [ ] Barang yang hilang saat tertangkap benar-benar terhapus dari
    inventaris.
-   [ ] Disconnect saat chase menerapkan konsekuensi tertangkap.
-   [ ] Data tidak hilang saat pindah server cepat (session lock).
-   [ ] UI selalu sama dengan data server.
-   [ ] Semua tombol nyaman digunakan di layar HP.
-   [ ] Prototipe diuji dengan lebih dari satu pemain.

# 17. Definition of Done

Prototipe TRASH HUNTER dinyatakan selesai jika pemain bisa:

1.  Spawn di Hideout dan mendapat Rare dalam 60 detik pertama.
2.  Mengorek dumpster dengan reveal penuh dan memilih Dig deeper.
3.  Mendapat barang dengan rarity dan mutasi berbeda.
4.  Mengisi backpack, lalu menjual atau memajang barang.
5.  Membeli upgrade backpack.
6.  Masuk zona merah, dikejar, lalu kabur, Drop & Run, atau tertangkap.
7.  Melihat koleksi bertambah di collection book.
8.  Keluar, masuk lagi, dan menemukan progresnya utuh.
9.  Memainkan semua ini di mobile tanpa error kritis.

Selain itu, **fun gate di Phase 4 harus lulus.** Game yang stabil tetapi
tidak membuat orang ingin "satu dumpster lagi" belum dianggap selesai.

**Prioritas akhir:** buat momen reveal yang seru, lalu loop yang adil
dan mudah dipahami. Luas dunia, variasi jackpot, dan kompleksitas
polisi dibangun setelah fondasi itu terbukti.

------------------------------------------------------------------------

# Lampiran A — Ringkasan Riset Pasar (2026-11-03)

## Kompetitor

  Game              Inti                                             Data
  ----------------- ------------------------------------------------ ----------------------------------------------------------------------------------
  DUMP              Gali sampah, jual, upgrade sekop, rebirth,       Puncak 143.706 CCU (2 Nov 2025), rating 89,6%, rata-rata main 30 menit,
                    raid base, mutasi                                 sekarang sekitar 3–20 pemain
  Prospecting!      Gali mineral, jual, upgrade, stat Luck           Puncak 181.653 CCU (9 Agu 2025), 273 juta visits
  Dumpster Divers!  Dumpster kota, jual, upgrade, buka zona          Tidak ada server berjalan saat dicek
  Trash Game        Robot scavenger, survival, crafting, PvP         Puncak 2.318 CCU, rata-rata main 10 menit, sekarang sekitar 50 pemain
  Junk Mechanics    Beli mobil rongsok, perbaiki, jual lagi          63 juta visits, sekitar 6,7 ribu pemain

## Temuan penting

-   Tema scavenging sampah terbukti bisa ramai. Kompetitor terbesar
    jatuh karena retensi, bukan karena kurang peminat.
-   Tidak ada kompetitor langsung yang memakai tekanan polisi atau
    pelarian. Inilah pembeda utama TRASH HUNTER.
-   Nama "Trash Hunter" belum dipakai oleh game Roblox yang ditemukan.
-   Algoritma Home Roblox (15 Juni 2026) menilai retensi sampai 28 hari.
    First play bounce rate adalah sinyal paling penting. Co-play dan
    jumlah hari bermain juga dinilai.
-   Aturan Paid Random Items diperketat pada 26 Mei 2026: peluang wajib
    ditampilkan dalam angka, dan `PolicyService` wajib dipakai.
-   Label Minimal atau Mild diperlukan agar game tersedia untuk Roblox
    Kids dan Select. Kuesioner yang tidak lengkap menghasilkan label
    16+.
-   Dari pengguna yang sudah verifikasi umur: 36% di bawah 13, 38% umur
    13–17, 26% umur 18+.

## Belum diverifikasi

-   Jumlah pemain terkini DUMP dan Dumpster Divers! (data Rolimons bisa
    tertinggal).
-   Detail mekanik DUMP (dua review gagal diakses).
-   Angka tren genre, yang berasal dari blog sekunder.

## Sumber

-   DUMP — https://www.rolimons.com/game/98868317791094
-   Dumpster Divers! — https://www.roblox.com/games/133904667472313/Dumpster-Divers
-   Prospecting! — https://www.rolimons.com/game/129827112113663
-   Trash Game — https://www.rolimons.com/game/98255728893675
-   Junk Mechanics — https://www.rolimons.com/game/70435795041539
-   RFY Algorithm update — https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575
-   Paid Random Items — https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622
-   Content maturity — https://create.roblox.com/docs/production/promotion/content-maturity
-   Age data — https://about.roblox.com/newsroom/2026/02/moving-beyond-self-reported-age

------------------------------------------------------------------------

# Lampiran B — Catatan Implementasi Prototipe (2026-11-03)

Perbedaan antara prototipe yang dibangun dan teks GDD di atas:

-   **Search dimulai dengan tap, bukan hold.** Pemain menekan prompt
    sekali, lalu karakter menggali otomatis selama 2 detik sambil bar
    dig layer berjalan. Alasannya: di mobile, menahan prompt sambil
    menekan tombol DIG membutuhkan dua jempol.
-   **Dig deeper menukar temuan.** Barang yang sedang ditampilkan dibuang,
    lalu roll baru dilakukan dengan peluang lebih baik. Tanpa aturan ini,
    Dig deeper selalu menjadi pilihan terbaik dan tidak ada keputusan.
-   **Terlihat penjaga tanpa menggali** juga menaikkan suspicion, tetapi
    lebih lambat (10/detik, dibanding 25/detik saat menggali).
-   **Collection book mencatat barang saat reveal**, bukan saat diambil.
    Barang yang ditinggal atau ditukar lewat Dig deeper tetap dihitung
    sudah ditemukan.
-   **Reset karakter saat dikejar** diperlakukan sama dengan tertangkap.
-   **Peta dibangun dari kode** (`World.luau`) saat server mulai, sehingga
    peta ikut tersimpan di git.
-   **Rak pajangan:** Hideout punya 8 rak, satu per pemain. Atur Max
    Players server ke 8.
-   **Audio** memakai aset Creator Store berlisensi dari ProSoundEffects
    dan APM Music. Musik tegang saat dikejar belum ada; yang ada baru
    peluit.

------------------------------------------------------------------------

# Lampiran C — Perubahan Arah Visual: Realistis (2026-11-03)

Atas permintaan pemilik proyek, arah visual diganti dari stylized dan
kartun menjadi **kota kecil Amerika yang realistis, luas, dan ramai**.
Bagian 9 (Art and Audio Direction) digantikan oleh lampiran ini.

## Kota

Peta sekitar 1.300 x 1.100 stud (sekitar 1 stud = 0,3 m). Isinya:

-   **Main St:** deretan toko (laundromat, diner, apotek, toko barang
    bekas, pizza). Gang servis di belakangnya menjadi tempat dumpster.
-   **Strip mall:** parkiran di depan, jalur bongkar muat di belakang.
-   **Pendukung:** pom bensin, motel, apartemen, taman dengan lapangan
    basket.
-   **Pemukiman Maple Ave:** rumah satu dan dua lantai dengan garasi,
    driveway, kotak surat, tong sampah, dan pagar halaman.
-   **Jalan:** marka kuning dan putih, trotoar dengan kanstin, zebra
    cross, lampu lalu lintas yang berganti warna, rambu STOP, lampu
    jalan, hidran, tiang listrik dan kabel.
-   **Hideout:** bengkel tua "Rusty's Salvage & Pawn" dengan scrapyard
    di belakangnya.

## Zona merah: Meridian Logistics

Area pribadi sekarang berupa kompleks gudang berpagar kawat, sekitar
460 x 270 stud, isinya:

-   Dua gudang dengan dock bongkar muat.
-   Trailer truk, tumpukan kontainer, dan forklift.
-   Menara lampu sorot dan kamera keamanan.
-   Gerbang dengan pos jaga dan mobil polisi.
-   Satu celah di pagar barat untuk jalan masuk diam-diam.

## Polisi

Ada tiga petugas keamanan berseragam (pakaian katalog Roblox) dengan
perilaku tidak seragam:

-   **Patroli:** berjalan ke titik acak, lalu berhenti dan menoleh,
    mengecek dumpster, atau lanjut berjalan.
-   **Investigasi:** saat suspicion pemain di atas 50, petugas terdekat
    mendatangi lokasi pemain.
-   **Kejar:** petugas terdekat mengejar, dan petugas dalam radius 140
    stud ikut membantu lewat radio.
-   **Cari:** setelah kehilangan jejak, petugas menyisir lokasi terakhir
    pemain terlihat.
-   **Ucapan:** petugas mengeluarkan kalimat pendek, misalnya "Security!
    Don't move!".

Mobil polisi patroli melintas di Industrial Rd. Lampu rotator menyala
merah-biru selama alarm aktif.

## Kehidupan kota

-   12 pejalan kaki berpakaian kasual menyusuri trotoar dan taman.
-   Lalu lintas mobil di Main St, Maple Ave, dan Industrial Rd.
-   Mobil terparkir di strip mall.
-   Siklus siang-malam, dengan lampu jalan dan lampu sorot yang menyala
    saat malam.

Mobil memakai model "Police Car" resmi milik Roblox (dimuat lewat
InsertService), yang juga diwarnai ulang untuk mobil sipil. Bangunan dan
pohon dibuat dari part dengan material realistis, sehingga seluruh peta
tetap berada di git.

------------------------------------------------------------------------

# Lampiran D — Distrik dan Tier Loot (2026-11-03)

Peta diperluas menjadi sekitar 2.500 x 1.800 stud dengan enam distrik.
Semakin mahal sebuah daerah, semakin bagus isi dumpster-nya. Kolom "Boost"
adalah tambahan peluang rarity di `Config.Districts`.

  Distrik             Tier   Boost   Isi distrik
  ------------------- ------ ------- ------------------------------------------------------------
  Town Center         1      0       Hideout, toko Main St, strip mall, balai kota, gereja,
                                     pemadam kebakaran
  Eastside            1      +0,2    Bungalow tua, taman trailer, toko sudut, apartemen walk-up
  Maple Grove         2      +0,45   Rumah keluarga di Maple Ave, gang belakang
  Hillcrest Estates   3      +0,8    Mansion berpagar dengan kolam renang, country club
  Business District   4      +1,2    Gedung kantor kaca, plaza air mancur, bank, parkir bertingkat
  Industrial Park     5      +1,6    Pabrik, cerobong asap, scrapyard, gudang sewa, rel kereta.
                                     Kompleks Meridian (zona polisi) berada di sini dan
                                     mendapat tambahan +1.

Hasil simulasi 20.000 roll per distrik (tanpa Dig deeper atau Perfect Dig):

  Distrik             Rata-rata nilai per roll   Peluang Rare atau lebih
  ------------------- -------------------------- -------------------------
  Town Center         $27                        15%
  Eastside            $33                        18%
  Maple Grove         $47                        22%
  Hillcrest Estates   $62                        28%
  Business District   $88                        35%
  Industrial Park     $118                       42%
  Kompleks Meridian   $218                       56%

Perubahan pendukung:

-   **Kecepatan jalan pemain** dinaikkan ke 20 karena peta jauh lebih
    besar. Kecepatan kejar polisi disesuaikan menjadi 18,5.
-   **Penanda distrik:** HUD menampilkan nama distrik dan bintang tier,
    dan sebuah banner muncul setiap kali pemain memasuki distrik baru.
    Prompt dumpster menampilkan tier-nya.
-   **Tampilan UI** sekarang minimalis: panel grafit transparan dengan
    garis tipis, font Builder Sans, tombol utama putih, dan aksen amber
    yang hanya dipakai untuk uang.

------------------------------------------------------------------------

# Lampiran E — Rummage, Mobil, Shop, dan Retensi (2026-11-03)

## Mekanik pencarian baru: Rummage

Alurnya diganti dari "tahan tombol, lalu tap timing":

1.  Pemain menggali sebentar, sekitar 1,2 detik.
2.  Muncul 3 kantong sampah. Kalau pemain punya Crowbar, muncul 4.
3.  Setiap kantong menunjukkan beratnya (Light, Medium, atau Heavy).
    Kantong yang lebih berat biasanya berisi barang lebih bagus, tetapi
    tidak selalu. Petunjuk berat ini sengaja diberi noise.
4.  Pemain memilih satu kantong. Kartu hasil menampilkan gambar 3D
    barangnya, ditambah isi kantong lain yang tidak dipilih ("Other
    bags"), supaya pemain tahu nyaris dapat apa.
5.  Pemain memilih Keep, Dig deeper (kantong baru dengan peluang lebih
    baik, tetapi temuan sekarang hilang), atau Leave.

Semua kantong di-roll di server. Client hanya menerima petunjuk berat.

## Alat (dibeli dengan cash di Hideout)

  Alat             Harga    Efek
  ---------------- -------- -----------------------------------------------
  Work Gloves      $80      Menggali 40% lebih cepat
  Running Shoes    $250     Kecepatan jalan +3
  Flashlight       $450     Menunjukkan rarity salah satu kantong
  Crowbar          $900     Membuka kantong ke-4 di setiap pencarian
  Metal Detector   $2.500   Peluang loot lebih bagus di semua dumpster

## Mobil

-   Tombol "Car" memunculkan mobil milik pemain. Di dalam Hideout,
    mobil muncul di apron depan.
-   Mobil bisa dikendarai dengan keyboard, gamepad, atau stik di HP.
-   Bagasi (trunk) adalah penyimpanan tambahan yang aman dari penjaga.
-   Isi bagasi bisa langsung dijual kalau mobil diparkir di Hideout.
-   Pilihan mobil: Old Sedan (gratis, bagasi 8), Station Wagon ($1.200,
    bagasi 16), Work Truck ($4.000, bagasi 30).
-   Hanya pemilik yang bisa mengemudi. Teman bisa ikut menumpang.

## Robux (hanya kenyamanan)

-   **Game pass:** Bigger Pockets (+6 slot) dan Home Run (teleport ke
    Hideout, tidak bisa dipakai saat dikejar).
-   **Developer product:** paket cash.
-   Tidak ada item acak dan tidak ada pembelian luck.
-   ID produk diisi di `Config.Robux`. Selama ID bernilai 0, item tampil
    sebagai "Coming soon".
-   Receipt bersifat idempoten dan disimpan sebelum produk diberikan.

## Retensi (dari LLM Council)

-   **Hot District:** setiap hari satu distrik mendapat loot lebih bagus.
    Distriknya sama di semua server.
-   **Collection milestones:** hadiah cash saat pemain menemukan 5, 10,
    15, dan 20 jenis barang.
-   **Penalti tertangkap dilunakkan:** barang paling berharga tetap
    dibawa pemain.
-   **Funnel analytics:** setiap langkah tutorial tercatat di Creator
    Analytics.
-   **Ditunda sampai ada data pemain:** trading, co-op heist, dan event
    terjadwal tambahan.

## Visual

-   Tas di punggung karakter ikut membesar sesuai level backpack.
-   Item tampil sebagai gambar 3D di Bag, Book, dan kartu reveal. Di Book,
    item yang belum ditemukan tampil sebagai siluet.
-   Tanah memakai lantai rumput yang rapi, bukan terrain. Terrain
    menumbuhkan rumput tinggi yang menembus jalan.

# Lampiran F — Phase 1: Feel, Navigasi, Toko Fisik

Spec: `docs/superpowers/specs/2026-11-04-phase1-feel-navigation-design.md`.

## Loot lebih langka
-   Bobot rarity: Common 62, Uncommon 25, Rare 9, Epic 3.2, Legendary 0.12,
    Jackpot 0.012. `BIAS_STEP` 0.5.
-   Peluang Legendary+ per pencarian (pilih yang terbaik dari 3 kantong):
    Town Center 0.4%, Industrial Park 2.8%, yard Meridian 5.8%. Dicek oleh
    `Loot.selfCheck`.
-   Pity: 30 pencarian tanpa Epic menjamin 1 kantong Epic; 120 tanpa
    Legendary menjamin 1 kantong Legendary. Counter disimpan di profil.

## Dunia
-   Satu hari = 24 menit (`DAY_LENGTH` 1440).
-   Jalan punya trotoar tinggi dan tutup manhole. Rumput punya variasi warna.
-   Ruko dua lantai: pilaster, kanopi bergaris, etalase menyala, papan nama.
-   Tempat sampah ada di gang belakang gedung, di atas pad beton; sebagian
    di dalam pagar bata.
-   Hideout: neon OPEN, pegboard alat, TV, parkiran berpagar, truk derek.

## Toko fisik
-   Belanja hanya di counter toko: Hank's Hardware (alat + tas) di Main St,
    Maple Motors (mobil). Server mengecek jarak ke counter (`Guard.atStore`).
-   Game pass "Shop Anywhere" (R$ 249) membuka tombol Shop dari mana saja.
-   Tombol R$ membuka daftar produk Robux. Robux tidak pernah menjual loot
    atau peluang.

## Navigasi
-   Minimap kanan atas (utara di atas): jalan, distrik, yard merah, Hideout,
    toko, dan titik tempat sampah (redup saat cooldown). Ketuk atau tekan M
    untuk peta penuh.
-   Kartu lokasi muncul saat masuk distrik: nama, bintang loot, "HOT TODAY".
    Kartu merah "PRIVATE PROPERTY" saat masuk yard.

# Lampiran G — Phase 2: Rumah, Quest, Streak, Izin Distrik

## Rumah (Sunset Lane)
-   Kompleks baru di barat daya peta, 10 kavling. Beli dan upgrade di counter
    Maple Realty (toko fisik): Starter Home $6.000 (4 pedestal), Family Home
    $25.000 (8), Collector's Villa $90.000 (12).
-   Saat pemain online, rumahnya muncul di kavling kosong. Item dipajang di
    pedestal sebagai model 3D, dengan jendela besar sehingga terlihat dari jalan.
-   Pajang atau ambil item lewat tab Bag saat berdiri di dalam rumah.
-   Pemain lain bisa Like di kotak surat (sekali per server). Jumlah like
    tersimpan di profil.

## Quest NPC
-   Old Earl (Main St), Rosa (Maple Ave), Vic (Industrial Rd). Masing-masing
    memberi 1 quest harian; isinya sama untuk semua pemain hari itu.
-   Jenis quest: cari N tempat sampah, temukan item Rare+/Epic+, jual senilai $X,
    cari di distrik tertentu, cari di yard Meridian. Hadiah $250–$1.200.
-   Tracker quest ada di kiri atas, di bawah chip Cash/Backpack.

## Login streak
-   Hadiah harian: $100, 150, 200, 300, 400, 500, lalu $1.000 di hari ke-7
    (setelah itu berulang). Kalau bolos sehari, streak kembali ke 1.

## Izin distrik
-   Maple Grove: cari 12 tempat sampah. Hillcrest: temukan 4 item Rare+.
    Business District: total penjualan $5.000.
-   Sebelum izin didapat, tempat sampah di distrik itu terkunci (abu-abu di
    peta). Yard Meridian tidak butuh izin karena sudah dijaga satpam.

## Distrik lebih besar
-   Business District diperluas ke selatan: Corporate Park (4 gedung kantor,
    Corporate Dr) dengan 4 tempat sampah baru.
-   Jalan baru: Sunset Ln dan Corporate Dr.

# Lampiran H — Phase 3: Kota Kedua, Port Haven

-   Satu peta yang tersambung: Main St berlanjut ke timur menjadi Route 9
    (jalan raya lewat hutan, ±600 stud), lalu masuk Port Haven. Peta penuh dan
    minimap menampilkan kedua kota.
-   Distrik: Old Port (tier 3, bebas masuk) dan The Docks (tier 5, izin: 12 item
    Rare+). Total 12 tempat sampah baru.
-   Hideout sendiri: Harbor Lockup (jual barang, zona aman). Jual isi bagasi
    mobil di hideout terdekat.
-   Item khusus kota: 15 item Port Haven (Frayed Rope sampai Pirate Treasure
    Chest $3.800). Tempat sampah hanya menjatuhkan item dari kotanya sendiri.
    Book dibagi per kota.
-   Toko sendiri: Harbor Supply menjual Magnet Kit ($3.000, +1 kantong di
    tempat sampah Port Haven) dan upgrade tas. Bayside Autos menjual Harbor Van
    (bagasi 22) dan Dock Hauler (bagasi 44). Mobil yang sudah dimiliki bisa
    dipilih di dealer mana pun.
-   Harbor Park (monumen jangkar, bangku, pepohonan), dermaga, perahu, crane
    kontainer, mercusuar di ujung pemecah ombak.
-   Quest giver baru: Captain Mae. Quest baru: "Search 4 dumpsters in Port Haven".
