    # Runbook Migrasi ke Mini PC

Panduan memindahkan MySQL server dari laptop pengembangan ke mini PC Windows yang menyala 24/7.

Kerjakan berurutan. Bagian 1 dan 2 bisa dikerjakan kapan saja sebelum hari-H; bagian 3 ke atas dilakukan saat migrasi.

---

## 1. Persiapan mini PC (sebelum menyentuh Docker)

Bagian ini yang paling sering dilewati, padahal justru penyebab utama server mati sendiri di kemudian hari.

### 1.1 Matikan sleep dan hibernate

Settings → System → Power → Screen and sleep → set **semuanya ke Never**.

Lalu lewat PowerShell (Administrator):

```powershell
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
powercfg /hibernate off
```

### 1.2 Matikan power saving pada adapter WiFi

Wajib, karena mini PC ini memakai WiFi. Tanpa ini, adapter bisa dimatikan Windows saat idle dan koneksi kolega putus tanpa sebab jelas.

Device Manager → Network adapters → klik kanan adapter WiFi → Properties → tab **Power Management** → hilangkan centang *"Allow the computer to turn off this device to save power"*.

### 1.3 Pastikan Docker Desktop jalan tanpa campur tangan

Docker Desktop di Windows **hanya berjalan jika ada user yang login**. Kalau mini PC restart dan berhenti di layar login, server tidak akan hidup.

Dua hal yang harus diatur:

- Docker Desktop → Settings → General → centang **Start Docker Desktop when you sign in**
- Aktifkan auto-login Windows agar mesin masuk ke desktop sendiri setelah restart

Auto-login berarti siapa pun yang menyalakan mini PC langsung masuk ke desktop tanpa password. Karena itu mini PC harus berada di tempat yang aman secara fisik. Kalau tidak memungkinkan, konsekuensinya harus diterima: setiap restart butuh seseorang untuk login manual.

### 1.4 Kendalikan Windows Update

Settings → Windows Update → Advanced options → atur **Active hours** selebar mungkin agar restart otomatis tidak terjadi di jam kerja.

### 1.5 Atur IP statis

IP mini PC tidak boleh berubah, karena akan tersimpan di koneksi DBeaver 8 orang.

Cara paling baik adalah **DHCP reservation di router** — router selalu memberikan IP yang sama ke mini PC berdasarkan MAC address-nya. Ini lebih aman daripada mengatur statis di Windows, yang berisiko bentrok dengan device lain.

Kalau tidak punya akses ke router, atur manual di Windows: Settings → Network → Wi-Fi → Hardware properties → IP assignment → Edit → Manual. Pilih alamat di luar rentang DHCP router agar tidak bentrok.

Catat IP finalnya:

```powershell
ipconfig | findstr "IPv4"
```

---

## 2. Backup data dari laptop

Jalankan di laptop, sesaat sebelum migrasi agar datanya paling baru:

```powershell
cd "D:\Magang\SQL-Server"
powershell -ExecutionPolicy Bypass -File .\backup.ps1
```

Salin file `.sql` hasilnya ke mini PC (flashdisk atau shared folder).

Salin juga file **`.env`** — file ini tidak ada di Git, jadi tidak ikut saat clone.

---

## 3. Setup di mini PC

### 3.1 Install Docker Desktop

Download versi AMD64, install, restart, tunggu status **Engine running**.

### 3.2 Ambil project

```powershell
cd C:\
git clone https://github.com/zorifff/SQLServer.git
cd SQLServer
```

Letakkan `.env` yang tadi disalin ke dalam folder ini.

### 3.3 Jalankan

```powershell
docker compose up -d
docker compose ps
```

Tunggu sampai `(healthy)`.

### 3.4 Hapus root yang bisa diakses jaringan

**Langkah ini wajib.** Volume baru dibuat dari nol, jadi image MySQL membuat ulang akun `root@%`.

```powershell
docker compose exec mysql mysql -u root -p -e "DROP USER 'root'@'%'; FLUSH PRIVILEGES; SELECT user, host FROM mysql.user;"
```

Pastikan `root` hanya tersisa satu baris dengan host `localhost`.

### 3.5 Buka firewall

PowerShell **sebagai Administrator**. Sesuaikan subnet dengan hasil `ipconfig` di langkah 1.5:

```powershell
New-NetFirewallRule -DisplayName "MySQL LAN" -Direction Inbound `
    -Protocol TCP -LocalPort 3306 -RemoteAddress 192.168.8.0/24 -Action Allow
```

Aturan firewall tidak ikut berpindah dari laptop — harus dibuat ulang di sini.

### 3.6 Verifikasi zona waktu

```powershell
docker compose exec mysql mysql -u root -p -e "SELECT NOW(), @@global.time_zone;"
```

Jam harus cocok dengan jam mini PC, `@@global.time_zone` menampilkan `+07:00`.

---

## 4. Restore data

```powershell
$env:MYSQL_PWD = (Get-Content .env | Select-String '^MYSQL_ROOT_PASSWORD=').ToString().Split('=',2)[1].Trim()
Get-Content .\backups\NAMA_FILE.sql -Raw | docker compose exec -T -e MYSQL_PWD="$env:MYSQL_PWD" mysql mysql -u root
Remove-Item Env:\MYSQL_PWD
```

Verifikasi:

```powershell
docker compose exec mysql mysql -u root -p -e "USE SQLserver; SHOW TABLES;"
```

---

## 5. Backup terjadwal

Baru bermakna di sini, karena mesin menyala terus.

1. Buat folder `backups` bila belum ada.
2. Buka **Task Scheduler** → Create Task (bukan Basic Task).
3. Tab **General**: centang *Run whether user is logged on or not* dan *Run with highest privileges*.
4. Tab **Triggers**: New → Daily → pukul 00:00.
5. Tab **Actions**: New → Start a program
   - Program: `powershell.exe`
   - Arguments: `-ExecutionPolicy Bypass -File "C:\SQLServer\backup.ps1"`
   - Start in: `C:\SQLServer`
6. Tab **Settings**: centang *Run task as soon as possible after a scheduled start is missed*.

Uji dengan klik kanan task → **Run**, lalu periksa folder `backups` bertambah isinya. Jangan anggap selesai sebelum diuji — task yang gagal diam-diam adalah kegagalan backup yang paling berbahaya.

Sesuaikan juga variabel `$projectDir` di dalam `backup.ps1` dengan path baru di mini PC.

---

## 6. Uji akhir

| Yang diuji | Cara |
|---|---|
| Koneksi dari laptop lain | DBeaver ke IP mini PC, port 3306 |
| Bertahan setelah restart | Restart mini PC, tunggu 3 menit, coba connect lagi tanpa menyentuh mini PC |
| Backup terjadwal | Cek folder `backups` keesokan harinya |

Uji restart adalah yang terpenting. Kalau server tidak hidup sendiri setelah restart, berarti pengaturan di bagian 1.3 belum benar — dan masalah ini baru akan ketahuan saat Windows Update memaksa restart di tengah malam.

---

## 7. Setelah migrasi

- Bagikan IP baru ke kolega; koneksi DBeaver lama mereka harus diperbarui host-nya.
- Laptop pengembangan bisa dimatikan container-nya (`docker compose down`) agar tidak ada dua server aktif yang membingungkan.
- Perbarui README repo dengan IP dan path baru.

Pekerjaan yang masih tersisa setelah ini: user MySQL per orang, dan akses dari luar kantor.