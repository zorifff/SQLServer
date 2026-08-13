# SQL Server (MySQL) — Dokumentasi Internal

Server MySQL untuk penyimpanan data bersama tim, berjalan di atas Docker pada mini PC Windows yang menyala 24/7.

Pengguna mengakses database secara langsung dari tools masing-masing (DBeaver, MySQL Workbench). Tabel dan data diisi sendiri oleh pengguna; repositori ini hanya menyediakan infrastrukturnya.

> **Mini PC ini juga menjalankan server web dan server bot.** Restart berdampak pada layanan tersebut — koordinasikan sebelum menjadwalkan restart.

---

## Parameter koneksi

| Keterangan | Isi |
|---|---|
| Host | `172.24.7.70` |
| Port | `3306` |
| Database | `SQLserver` |
| Username | NIK masing-masing |
| Jaringan | WiFi kantor **ACTION** |

Tidak dapat diakses dari luar jaringan kantor.

⚠️ **IP masih diberikan otomatis oleh DHCP dan dapat berubah sewaktu-waktu.** Setiap perubahan mengharuskan aturan firewall diperbarui *dan* seluruh pengguna mengganti host di koneksi mereka. DHCP reservation ke IT belum diajukan — lihat bagian Rencana.

---

## Status

| Komponen | Status |
|---|---|
| MySQL 8.4 di Docker (mini PC) | Berjalan |
| Akses dari LAN kantor | Berfungsi |
| 13 akun per orang (berbasis NIK) | Dibuat, sebagian sudah diuji |
| Backup terjadwal harian 00:00 | Aktif, sudah diuji |
| Restore | Sudah diuji di mini PC |
| Zona waktu WIB | Sudah diatur |
| Uji pemulihan setelah restart | **Belum** |
| IP tetap (DHCP reservation) | **Belum** |
| Akun bersama `user@%` dihapus | Belum — masih dipakai pengelola |
| Akses dari luar kantor | Belum |

---

## Struktur

```
docker-compose.yml   Definisi container MySQL
backup.ps1           Script backup (dump + rotasi 14 hari)
users.sql            13 akun beserta hak akses — TIDAK masuk Git
.env                 Kredensial — TIDAK masuk Git
.env.example         Daftar variabel yang harus diisi
docs/                Runbook migrasi, panduan koneksi
```

Lokasi di mini PC: `C:\Project\SQLServer`

`.env` dan `users.sql` harus disalin manual saat setup di mesin baru, karena keduanya tidak ada di repositori.

---

## Setup dari nol

1. Install Docker Desktop, aktifkan **Start Docker Desktop when you sign in**.
2. Clone repositori, lalu salin `.env` dan `users.sql` secara manual.
3. Jalankan:

   ```powershell
   docker compose up -d
   docker compose ps          # tunggu sampai (healthy)
   ```

4. Hapus akun root yang dapat diakses dari jaringan:

   ```powershell
   docker compose exec mysql mysql -u root -p -e "DROP USER 'root'@'%'; FLUSH PRIVILEGES;"
   ```

   **Wajib diulang setiap kali volume dibuat ulang** — image MySQL membuat akun tersebut secara otomatis.

5. Buat akun pengguna:

   ```powershell
   $env:MYSQL_PWD = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').ToString().Split('=',2)[1].Trim()
   Get-Content .\users.sql -Raw | docker compose exec -T -e MYSQL_PWD="$env:MYSQL_PWD" mysql mysql -u root
   Remove-Item Env:\MYSQL_PWD
   ```

6. Buka port di Windows Firewall (jalankan sebagai Administrator), sesuaikan subnet dengan jaringan setempat:

   ```powershell
   New-NetFirewallRule -DisplayName "MySQL LAN" -Direction Inbound `
       -Protocol TCP -LocalPort 3306 -RemoteAddress 172.24.4.0/22 -Action Allow
   ```

7. Daftarkan backup terjadwal — lihat bagian Backup.

---

## Operasional

**Backup manual:**

```powershell
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

**Backup terjadwal:** task `MySQL Backup Harian` di Task Scheduler, berjalan setiap pukul 00:00. Berjalan hanya saat ada user yang login — sama seperti Docker Desktop.

Task tidak memberi notifikasi bila gagal. **Periksa folder `backups` secara berkala:**

```powershell
Get-ChildItem .\backups | Sort-Object LastWriteTime -Descending | Select-Object -First 5 Name, Length, LastWriteTime
```

Yang diperiksa: ada file dari hari sebelumnya, dan ukurannya wajar (tidak nol, bertambah seiring data masuk).

**Restore dari backup terbaru:**

```powershell
$env:MYSQL_PWD = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').ToString().Split('=',2)[1].Trim()
$file = (Get-ChildItem .\backups\*.sql | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
Get-Content $file -Raw | docker compose exec -T -e MYSQL_PWD="$env:MYSQL_PWD" mysql mysql -u root
Remove-Item Env:\MYSQL_PWD
```

Restore yang berhasil tidak menghasilkan output apa pun.

**Restore menimpa seluruh database**, bukan menambahkan. Memulihkan backup lama berarti membuang seluruh perubahan setelah tanggal tersebut. Buat backup dari kondisi terkini lebih dulu sebelum melakukan restore apa pun.

---

## Catatan penting

**Windows Firewall adalah satu-satunya penyaring asal koneksi.** Docker melakukan NAT, sehingga MySQL melihat seluruh koneksi berasal dari gateway internal Docker (`172.18.0.1`), bukan IP asli pengirim. Pembatasan berbasis IP di level MySQL karena itu tidak dapat diterapkan — pembatasan `'user'@'192.168.x.%'` akan memblokir semua koneksi sah, sementara `'user'@'172.18.0.%'` terlihat seperti kontrol padahal tidak menyaring apa pun. Aturan firewall tidak boleh dihapus atau diubah menjadi terbuka untuk semua sumber.

**Aktivitas tidak dapat dilacak lewat kolom host** karena alasan yang sama. Identifikasi hanya mungkin lewat kolom `user` — inilah alasan utama memakai akun terpisah per orang.

**Seluruh akun memiliki hak penuh** di database `SQLserver`, termasuk menghapus tabel milik orang lain. Pemulihan bergantung sepenuhnya pada backup harian.

**Kehilangan data maksimal 24 jam.** Backup berjalan tengah malam; data yang hilang siang hari hanya dapat dipulihkan sampai kondisi tengah malam sebelumnya. Kesalahan penghapusan harus dilaporkan secepatnya.

**Akun MySQL tidak ikut dalam backup.** `backup.ps1` hanya membackup database `SQLserver`, bukan database sistem. `users.sql` adalah satu-satunya catatan akun — harus dijalankan ulang saat volume dibuat ulang.

**DBeaver tidak memperbarui tampilan secara otomatis.** Tabel yang dibuat pengguna lain baru terlihat setelah menekan F5 pada database.

**Docker Desktop membutuhkan sesi login aktif.** Jika mini PC restart dan berhenti di layar login, MySQL tidak akan berjalan sampai ada yang login secara manual. Perilaku ini belum diuji.

---

## Rencana selanjutnya

Berurutan berdasarkan tingkat kepentingan:

1. **DHCP reservation ke IT** — MAC address WiFi mini PC: `80:E4:BA:28:24:31`. Selama IP masih dapat berubah, server belum dapat diandalkan untuk dipakai bersama.
2. **Uji pemulihan setelah restart** — restart mini PC, tunggu 5 menit, coba connect dari perangkat lain tanpa menyentuh mini PC. Perlu koordinasi karena mesin ini juga melayani server web dan bot.
3. **Bagikan kredensial** ke 13 pengguna beserta panduan koneksi di `docs/`.
4. **Hapus akun bersama `user@%`** setelah seluruh pengguna terbukti dapat terhubung dengan akun masing-masing.
5. **Akses dari luar kantor** — memerlukan keputusan antara SSH tunnel atau mesh VPN, serta izin IT. Perhatikan bahwa mini PC terkelola IT (terpasang GlobalProtect).