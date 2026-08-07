# SQL Server (MySQL) — Dokumentasi Internal

Server MySQL untuk penyimpanan data bersama tim. Dijalankan di atas Docker, saat ini di laptop pengembangan, akan dimigrasikan ke mini PC yang menyala 24/7.

Pengguna mengakses database secara langsung dari tools masing-masing (DBeaver, MySQL Workbench). Tabel dan data diisi sendiri oleh pengguna; repositori ini hanya menyediakan infrastrukturnya.

---

## Status

| Komponen | Status |
|---|---|
| MySQL 8.4 di Docker | Berjalan |
| Akses dari LAN kantor | Berfungsi, sudah diuji dari device lain |
| Backup + restore | Script tersedia, restore sudah diuji |
| Backup terjadwal | Belum — direncanakan saat migrasi ke mini PC |
| User per orang | Belum — masih satu akun bersama |
| Akses dari luar kantor | Belum |
| Migrasi ke mini PC | Belum |

**Belum layak untuk data produksi.** Server masih berada di laptop dan backup masih manual.

---

## Struktur

```
docker-compose.yml   Definisi container MySQL
backup.ps1           Script backup (dump + rotasi 14 hari)
.env.example         Daftar variabel yang harus diisi
.gitignore           Mencegah .env dan backup masuk Git
```

File `.env` dan folder `backups/` sengaja tidak masuk repositori.

---

## Setup dari nol

1. Install Docker Desktop.
2. Salin `.env.example` menjadi `.env`, isi seluruh nilainya.
   `MYSQL_ROOT_PASSWORD` dan `MYSQL_PASSWORD` **harus berbeda**.
3. Jalankan:

   ```powershell
   docker compose up -d
   docker compose ps          # tunggu sampai (healthy)
   ```

4. Hapus akun root yang dapat diakses dari jaringan:

   ```sql
   DROP USER 'root'@'%';
   FLUSH PRIVILEGES;
   ```

   Langkah ini **wajib diulang** setiap kali volume dibuat ulang, karena image MySQL membuat akun tersebut secara otomatis.

5. Buka port di Windows Firewall, dibatasi ke subnet lokal saja (jalankan sebagai Administrator):

   ```powershell
   New-NetFirewallRule -DisplayName "MySQL LAN" -Direction Inbound `
       -Protocol TCP -LocalPort 3306 -RemoteAddress 192.168.8.0/24 -Action Allow
   ```

---

## Operasional harian

**Menyalakan:**

```powershell
docker compose up -d
docker compose ps
```

**Backup manual:**

```powershell
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

Hasil tersimpan di `backups/` dengan nama berisi tanggal dan jam. File lebih tua dari 14 hari terhapus otomatis.

**Restore:**

```powershell
$env:MYSQL_PWD = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').ToString().Split('=',2)[1].Trim()
Get-Content .\backups\NAMA_FILE.sql -Raw | docker compose exec -T -e MYSQL_PWD="$env:MYSQL_PWD" mysql mysql -u root
Remove-Item Env:\MYSQL_PWD
```

Restore yang berhasil tidak menghasilkan output apa pun.

---

## Catatan penting

**Windows Firewall adalah satu-satunya penyaring asal koneksi.** Docker melakukan NAT, sehingga MySQL melihat seluruh koneksi berasal dari gateway internal Docker (`172.18.0.1`), bukan IP asli pengirim. Pembatasan berbasis IP di level MySQL karena itu tidak dapat diterapkan — aturan firewall tidak boleh dihapus atau diubah menjadi terbuka untuk semua sumber.

**Konsekuensinya, aktivitas tidak dapat dilacak per orang** selama masih memakai satu akun bersama. Ini alasan utama untuk beralih ke satu user per orang sebelum data sungguhan masuk.

**DBeaver tidak memperbarui tampilan secara otomatis.** Perubahan yang dilakukan dari luar (restore, atau tabel yang dibuat pengguna lain) baru terlihat setelah menekan F5 pada database.

**IP server berpotensi berubah** karena diberikan otomatis oleh router. Di mini PC nanti, IP harus diatur statis agar koneksi tersimpan milik pengguna tidak putus.

---

## Rencana selanjutnya

1. Migrasi ke mini PC — IP statis, ulangi seluruh langkah setup, restore data dari backup terakhir.
2. Backup terjadwal via Task Scheduler (hanya bermakna di mesin yang menyala 24/7).
3. User MySQL per orang, dengan pemisahan hak baca dan tulis.
4. Akses dari luar kantor — memerlukan keputusan antara SSH tunnel atau VPN, dan izin dari IT.
