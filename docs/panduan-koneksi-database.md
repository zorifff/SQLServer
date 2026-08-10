# Panduan Koneksi ke Server Database

Panduan ini untuk menghubungkan aplikasi SQL Anda (DBeaver atau MySQL Workbench) ke server database tim.

Setup hanya perlu dilakukan **sekali**. Setelah itu, cukup buka aplikasi dan klik koneksi yang sudah tersimpan.

---

## Sebelum mulai

Siapkan informasi berikut (diberikan oleh pengelola server):

| Keterangan | Isi |
|---|---|
| Host / Server | `192.168.8.4` |
| Port | `3306` |
| Database | `SQLserver` |
| Username | `NIK_Masing_masing` |
| Password | `Passwordmasingmasing` |

**Syarat:** laptop Anda harus terhubung ke **WiFi kantor**. Dari jaringan lain (rumah, hotspot HP) koneksi tidak akan berhasil.

---

## A. DBeaver

1. Buka DBeaver.
2. Menu **Database** → **New Database Connection**.
3. Pilih **MySQL**, klik **Next**.
4. Isi formulir:
   - **Server Host** — isi dengan Host di tabel atas
   - **Port** — `3306`
   - **Database** — isi dengan nama Database di tabel atas
   - **Username** dan **Password** — sesuai tabel atas
5. Centang **Save password** agar tidak perlu mengetik ulang setiap kali.
6. Klik **Test Connection** di kiri bawah.
   - Jika muncul permintaan mengunduh driver, klik **Download** (butuh internet, hanya sekali).
   - Jika berhasil, akan muncul informasi versi server.
7. Klik **Finish**.

Koneksi muncul di panel kiri (**Database Navigator**). Klik dua kali untuk membuka.

---

## B. MySQL Workbench

1. Buka MySQL Workbench.
2. Pada layar utama, klik tanda **+** di sebelah *MySQL Connections*.
3. Isi formulir:
   - **Connection Name** — bebas, misalnya `Server Tim`
   - **Hostname** — isi dengan Host di tabel atas
   - **Port** — `3306`
   - **Username** — sesuai tabel atas
   - **Password** — klik **Store in Vault**, masukkan password
   - **Default Schema** — isi dengan nama Database di tabel atas
4. Klik **Test Connection**.
5. Klik **OK**.

Koneksi muncul sebagai kotak di layar utama. Klik untuk membuka.

---

## Cara menjalankan query

Setelah terhubung, buka jendela SQL Editor (DBeaver: **SQL Editor → New SQL script**; Workbench: sudah terbuka otomatis), lalu ketik perintah dan jalankan dengan **Ctrl + Enter**.

Contoh melihat daftar tabel yang ada:

```sql
SHOW TABLES;
```

---

## Hal yang penting diketahui

**Tampilan tidak diperbarui otomatis.** Jika rekan lain membuat tabel baru, tabel itu belum terlihat di layar Anda sampai daftarnya di-refresh. Tekan **F5** pada nama database di panel kiri sebelum menyimpulkan bahwa tabel tidak ada.

**Data tersimpan di server, bukan di laptop Anda.** Perubahan yang Anda buat langsung terlihat oleh semua orang. Sebaliknya, `DROP TABLE` atau `DELETE` juga berlaku untuk semua orang dan **tidak bisa dibatalkan**. Pastikan Anda yakin sebelum menjalankan perintah yang menghapus.

**Jika terjadi kesalahan penghapusan**, segera hubungi pengelola server. Ada backup harian, tetapi semakin cepat dilaporkan semakin sedikit pekerjaan yang hilang.

---

## Jika gagal terhubung

| Pesan error | Kemungkinan penyebab | Yang perlu dilakukan |
|---|---|---|
| *Communications link failure* / *Connection refused* | Tidak terhubung ke WiFi kantor, atau server sedang mati | Periksa koneksi WiFi. Jika sudah benar, hubungi pengelola |
| *Access denied for user* | Username atau password salah | Periksa ulang, perhatikan huruf besar/kecil |
| *Unknown database* | Nama database salah ketik | Periksa ejaan, perhatikan huruf besar/kecil |
| *Public Key Retrieval is not allowed* (DBeaver) | Pengaturan driver | Edit Connection → tab **Driver properties** → `allowPublicKeyRetrieval` diubah menjadi `true` |

Jika masih gagal, sampaikan ke pengelola **pesan error lengkapnya** — itu yang paling membantu untuk menemukan penyebabnya.

---

## Kontak

Pengelola server: `________________`
