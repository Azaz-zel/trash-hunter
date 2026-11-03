# TRASH HUNTER

## Game Design Document & Technical Development Plan

**Platform:** Roblox\
**Genre:** Open-world Scavenging Simulator\
**Perspective:** Third-person\
**Visual direction:** Semi-realistic American urban environments\
**Core themes:** Exploration, randomized loot, risk versus reward,
progression\
**Development tools:** Claude Code + Roblox Studio + official Roblox
Studio MCP

------------------------------------------------------------------------

# 1. Game Overview

## High concept

TRASH HUNTER adalah game simulator eksplorasi di mana pemain menjelajahi
kota untuk mencari barang bekas dari dumpster, tempat sampah komersial,
gang belakang gedung, dan area industri.

Barang yang ditemukan memiliki nilai dan kondisi berbeda. Pemain dapat
menemukan barang biasa, elektronik bekas, barang koleksi langka, hingga
jackpot bernilai tinggi.

Namun, beberapa area memiliki risiko tinggi. Polisi berpatroli dan dapat
mendeteksi pemain yang melakukan scavenging di area terlarang. Pemain
harus memilih antara melanjutkan pencarian untuk mendapatkan loot lebih
banyak atau kembali ke safe zone untuk mengamankan hasil temuannya.

## Core player fantasy

"Setiap dumpster mungkin menyimpan sesuatu yang berharga, tetapi semakin
besar risikonya, semakin sulit membawa hasil temuan pulang."

## Design pillars

1.  **Discovery:** Setiap pencarian memberikan kemungkinan penemuan yang
    berbeda.
2.  **Risk versus reward:** Loot yang lebih berharga sering ditemukan di
    area yang lebih berbahaya.
3.  **Progression:** Pemain berkembang dari scavenger pemula menjadi
    pemburu barang berharga.
4.  **Exploration:** Dunia menyimpan area tersembunyi, loot eksklusif,
    dan tempat baru untuk dijelajahi.
5.  **Social moments:** Penemuan jackpot, pengejaran polisi, dan
    eksplorasi multiplayer menciptakan momen yang bisa dibagikan.

# 2. Core Gameplay Loop

1.  Spawn di safe zone.
2.  Ambil perlengkapan dan tentukan tujuan.
3.  Jelajahi kota untuk menemukan dumpster dan lokasi scavenging.
4.  Periksa atau bongkar dumpster untuk mendapatkan loot acak.
5.  Kelola kapasitas backpack dan wanted level.
6.  Kabur dari polisi jika terdeteksi.
7.  Kembali ke safe zone untuk menyimpan dan menjual barang.
8.  Gunakan uang untuk upgrade perlengkapan dan membuka area baru.
9.  Ulangi dengan target loot yang lebih bernilai.

**Core loop harus terasa menyenangkan sebelum map diperluas.**

# 3. Loot and Jackpot System

Setiap dumpster memiliki tabel loot berdasarkan jenis lokasi, tingkat
risiko, dan level area.

  -----------------------------------------------------------------------
  Rarity                  Contoh loot             Tujuan
  ----------------------- ----------------------- -----------------------
  Common                  Kardus, botol, besi tua Pendapatan dasar

  Uncommon                Perkakas, pakaian,      Progresi awal
                          perangkat kecil         

  Rare                    Monitor, keyboard,      Loot bernilai tinggi
                          konsol lama             

  Epic                    Komponen PC, elektronik Target eksplorasi
                          premium                 

  Legendary               Barang koleksi dan      Penemuan spesial
                          elektronik langka       

  Jackpot                 PC gaming langka,       Momen kejutan utama
                          konsol mahal, loot      
                          bundle                  
  -----------------------------------------------------------------------

Rarity dan nilai jual adalah dua hal berbeda. Barang yang langka tidak
harus selalu menjadi barang dengan harga tertinggi; kondisi, jenis, dan
potensi perbaikan juga memengaruhi nilainya.

## Dumpster interactions

Setiap dumpster memiliki:

-   Jenis dan loot table.
-   Waktu pencarian.
-   Durasi respawn atau sistem replenishment.
-   Tingkat risiko.
-   Kemungkinan menemukan loot spesial.
-   Interaksi yang sesuai dengan kondisi dan jenis dumpster.

Pemain mendapatkan hasil pencarian melalui sistem server, bukan dari
perhitungan hadiah yang dikendalikan client.

## Jackpot presentation

Saat jackpot ditemukan:

-   Animasi penemuan khusus.
-   Efek suara yang berbeda.
-   Tampilan nama barang, rarity, dan estimasi nilai.
-   Efek visual yang lebih dramatis untuk Legendary dan Jackpot.
-   Notifikasi global opsional untuk penemuan tertentu.

Peluang jackpot, nilai barang, dan harga jual harus dikonfigurasi dan
diseimbangkan melalui playtesting. Jangan menetapkan peluang permanen
sebelum ekonomi game diuji.

# 4. Police and Wanted System

Polisi adalah sistem tekanan gameplay, bukan sekadar NPC dekoratif.

## Wanted levels

  Level              Perilaku
  ------------------ ---------------------------------------------------
  0 --- Clear        Pemain tidak sedang dicurigai
  1 --- Suspicious   Polisi mulai memperhatikan aktivitas pemain
  2 --- Detected     Polisi mendekati atau mengejar pemain
  3 --- Pursuit      Pengejaran aktif dan risiko penangkapan meningkat

Wanted level dapat meningkat berdasarkan lokasi, durasi scavenging, dan
tindakan pemain. Sistem harus memberi peringatan yang cukup jelas
sebelum pengejaran aktif.

## Police AI

Implementasi bertahap:

1.  Patrol melalui titik rute.
2.  Deteksi berdasarkan jarak dan kondisi yang ditentukan.
3.  Investigasi lokasi mencurigakan.
4.  Mengejar pemain yang terdeteksi.
5.  Menangkap pemain ketika syarat penangkapan terpenuhi.
6.  Kembali ke patroli setelah pengejaran berakhir.

Untuk menghindari NPC yang tidak adil, deteksi tidak boleh selalu
terjadi secara instan. Pemain harus memiliki kesempatan untuk bereaksi
dan kabur.

## Capture consequences

Jika tertangkap:

-   Sebagian loot yang belum diamankan disita.
-   Wanted level direset sesuai aturan game.
-   Pemain dikembalikan ke safe zone atau titik penahanan.
-   Perlengkapan permanen dan progres utama tidak ikut hilang.

Persentase loot yang disita masih menjadi parameter balancing. Safehouse
menjadi tempat untuk mengamankan hasil eksplorasi.

# 5. World and Map Progression

## Zone 1 --- Suburbs

Area awal yang relatif aman:

-   Rumah dan gang perumahan.
-   Dumpster kecil dan barang rumah tangga.
-   Tutorial looting dan penjualan.
-   Polisi dengan patroli sederhana.

## Zone 2 --- Downtown

Area komersial:

-   Belakang restoran dan toko.
-   Dumpster besar dan barang elektronik.
-   Peluang loot lebih baik.
-   Kepadatan patroli lebih tinggi.

## Zone 3 --- Industrial Zone

Area industri:

-   Gudang dan tempat pembuangan elektronik.
-   Dumpster dengan loot khusus.
-   Area luas dengan rute alternatif.
-   Risiko polisi dan nilai loot lebih tinggi.

## Zone 4 --- Rich District

Area premium:

-   Area servis gedung dan lingkungan mewah.
-   Barang koleksi dan elektronik bernilai tinggi.
-   Loot khusus yang tidak ditemukan di area awal.
-   Penjagaan dan risiko tertinggi.

Setiap zona dibuka melalui persyaratan progresi, uang, atau reputasi.
Untuk prototipe pertama, hanya Suburbs yang perlu dibuat.

# 6. Player Progression and Economy

## Player upgrades

-   **Backpack:** meningkatkan kapasitas inventaris.
-   **Search tools:** mengurangi waktu pencarian.
-   **Flashlight:** membantu eksplorasi di area gelap.
-   **Detection tools:** memberi petunjuk tentang barang atau dumpster
    tertentu.
-   **Movement upgrades:** meningkatkan kemampuan mobilitas.
-   **Vehicles:** membantu membawa loot dalam jumlah lebih besar.
-   **Safehouse:** tempat menyimpan koleksi dan barang bernilai tinggi.

## Item condition and repair

Loot dapat memiliki kondisi seperti Damaged, Used, Good, dan Excellent.

Pemain dapat menjual barang apa adanya atau memperbaikinya untuk
mendapatkan nilai lebih tinggi. Sistem repair merupakan fitur lanjutan,
bukan bagian wajib dari prototipe pertama.

## Economic rules

-   Loot menghasilkan uang setelah dijual atau diamankan sesuai jenis
    barang.
-   Upgrade memiliki harga dan manfaat yang jelas.
-   Jackpot harus menarik, tetapi tidak membuat ekonomi biasa menjadi
    tidak relevan.
-   Harga jual, drop rates, kapasitas backpack, dan waktu pencarian
    harus dapat diubah melalui konfigurasi.

# 7. User Interface

UI minimum:

-   Cash balance.
-   Backpack capacity.
-   Interaction prompt.
-   Loot discovery panel.
-   Rarity indicator.
-   Wanted meter.
-   Police warning.
-   Inventory panel.
-   Sell interface.
-   Map unlock information.

UI harus mudah dibaca ketika karakter bergerak, berinteraksi dengan
dumpster, atau dikejar polisi.

# 8. Technical Architecture

## Recommended Roblox hierarchy

``` text
Workspace
├── Map
│   └── Suburbs
├── LootContainers
├── PoliceNPCs
└── SafeZone

ReplicatedStorage
├── Remotes
├── Shared
│   ├── LootDefinitions
│   ├── ItemDefinitions
│   └── GameConfig
└── Assets

ServerScriptService
├── Bootstrap.server.lua
└── Services
    ├── LootService
    ├── InventoryService
    ├── EconomyService
    ├── WantedService
    ├── PoliceService
    └── DataService

ServerStorage
├── LootTemplates
└── NPCTemplates

StarterPlayer
└── StarterPlayerScripts
    └── ClientController.client.lua

StarterGui
├── HUD
├── InventoryUI
└── LootDiscoveryUI
```

Struktur ini merupakan target arsitektur, bukan instruksi untuk langsung
membuat semua file. Claude harus terlebih dahulu memeriksa place yang
terbuka dan menyesuaikan struktur dengan project aktual.

## Responsibilities

**Server**

-   Menentukan loot yang diperoleh.
-   Memvalidasi interaksi dumpster.
-   Mengelola uang dan inventaris.
-   Mengontrol wanted level dan penangkapan.
-   Menyimpan progres pemain.

**Client**

-   Menampilkan UI dan animasi.
-   Memproses input pemain.
-   Menampilkan feedback interaksi.
-   Meminta tindakan melalui RemoteEvents atau RemoteFunctions yang
    divalidasi server.

**Shared modules**

-   Definisi barang.
-   Konfigurasi rarity dan harga.
-   Konfigurasi area dan balancing.
-   Data yang aman untuk dibagikan ke client.

## Data persistence

Gunakan DataStoreService untuk menyimpan:

-   Cash.
-   Inventaris dan koleksi.
-   Upgrade.
-   Area yang sudah dibuka.
-   Progres pemain.

DataStore hanya diakses melalui server scripts. Simpan data dengan
penanganan error, validasi, dan strategi penyimpanan yang aman.

# 9. First Playable Prototype

Target pertama bukan game lengkap. Targetnya adalah satu area kecil yang
sudah dapat dimainkan dari awal hingga akhir.

## Required features

1.  Karakter third-person muncul di Suburbs.
2.  Ada minimal 5 dumpster yang bisa diinteraksikan.
3.  Dumpster menghasilkan loot acak.
4.  Loot masuk ke backpack dengan kapasitas terbatas.
5.  Pemain dapat menjual barang di safe zone.
6.  Pemain mendapatkan uang dan membeli satu upgrade backpack.
7.  Satu NPC polisi berpatroli dan dapat mengejar pemain.
8.  Ketika tertangkap, sebagian loot yang belum diamankan hilang.
9.  UI menampilkan uang, kapasitas backpack, loot, dan wanted level.
10. Game dapat dimainkan ulang tanpa error kritis.

## Out of scope for prototype

-   Empat zona lengkap.
-   Kendaraan.
-   Sistem repair.
-   Multiplayer competitions.
-   Trading antarpemain.
-   Jackpot global kompleks.
-   Map tanpa batas.
-   Monetisasi dan game passes.

Fitur tersebut baru dipertimbangkan setelah loop dasar terbukti
menyenangkan dan stabil.

# 10. Development Plan

## Phase 0 --- Connect and inspect

-   Pastikan Roblox Studio MCP tersambung.
-   Identifikasi place dan struktur yang sedang terbuka.
-   Periksa scripts, objek, dan console errors.
-   Simpan backup.
-   Minta Claude mengusulkan rencana implementasi tanpa mengubah game.

**Exit criteria:** Claude dapat membaca place yang benar dan memberikan
laporan struktur project.

## Phase 1 --- Build the scavenging loop

-   Buat satu Suburbs blockout.
-   Tambahkan dumpster interaktif.
-   Implementasikan loot table dan rarity.
-   Tambahkan inventory dan backpack capacity.
-   Implementasikan sell zone dan cash.

**Exit criteria:** pemain dapat mencari barang, mengumpulkan loot, lalu
menjualnya.

## Phase 2 --- Add risk

-   Tambahkan polisi patroli.
-   Implementasikan deteksi dan pengejaran.
-   Tambahkan wanted meter.
-   Implementasikan penangkapan dan kehilangan sebagian loot.

**Exit criteria:** pemain bisa menyelesaikan satu sesi scavenging dengan
risiko nyata.

## Phase 3 --- Add progression

-   Tambahkan upgrade backpack.
-   Konfigurasikan harga dan nilai loot.
-   Tambahkan jackpot.
-   Tambahkan feedback visual dan audio.

**Exit criteria:** pemain mempunyai alasan yang jelas untuk terus
mencari dan meningkatkan perlengkapan.

## Phase 4 --- Stabilization

-   Uji multiplayer dengan server dan client terpisah.
-   Uji validasi remote dan exploit resistance.
-   Uji respawn, penangkapan, dan disconnect.
-   Uji penyimpanan dan pemuatan data.
-   Perbaiki bug dan optimalkan performa.

**Exit criteria:** tidak ada bug kritis yang diketahui dalam alur
gameplay utama.

# 11. Testing Checklist

-   [ ] Loot ditentukan oleh server.
-   [ ] Pemain tidak bisa menjual item yang tidak dimiliki.
-   [ ] Interaksi tidak bisa dilakukan dari jarak yang tidak sah.
-   [ ] Remote requests memiliki validasi dan rate limiting.
-   [ ] Backpack tidak melebihi kapasitas.
-   [ ] Loot yang disita benar-benar dihapus dari inventaris.
-   [ ] Polisi tidak mengejar pemain tanpa syarat yang benar.
-   [ ] Data tidak hilang saat proses penyimpanan berhasil.
-   [ ] UI tidak menampilkan uang atau inventaris yang berbeda dari
    server.
-   [ ] Game bisa dimainkan kembali setelah respawn.
-   [ ] Prototipe diuji dengan lebih dari satu pemain.

# 12. Definition of Done

Prototipe TRASH HUNTER dinyatakan selesai ketika pemain bisa:

1.  Spawn di Suburbs.
2.  Menemukan dan mengorek dumpster.
3.  Mendapatkan loot dengan rarity berbeda.
4.  Mengisi backpack dan menjual barang.
5.  Menggunakan hasil penjualan untuk membeli upgrade.
6.  Dikejar dan ditangkap polisi.
7.  Kehilangan sebagian loot sesuai aturan.
8.  Mengulangi loop gameplay tanpa error kritis.

**Prioritas akhir:** buat satu loop yang seru, mudah dipahami, dan
stabil terlebih dahulu. Luas dunia, variasi jackpot, serta kompleksitas
polisi akan dibangun setelah fondasi tersebut bekerja.
