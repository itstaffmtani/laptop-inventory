# MTani — Inventarisasi Laptop · Setup Guide

## File yang ada
```
cek_laptop.bat   ← yang dikasih ke karyawan (double-click)
cek_laptop.ps1   ← script PowerShell (harus 1 folder sama .bat)
form.html        ← halaman form (host di mana saja)
apps_script.gs   ← Google Apps Script (copy-paste ke script.google.com)
```

---

## Setup (urutan)

### 1. Buat Google Spreadsheet
- Buka sheets.google.com → buat spreadsheet baru
- Ambil ID dari URL:
  `https://docs.google.com/spreadsheets/d/**AMBIL_INI**/edit`

### 2. Setup Google Apps Script
- Buka script.google.com → New project
- Hapus isi default, paste isi `apps_script.gs`
- Ganti `GANTI_DENGAN_ID_SPREADSHEET` dengan ID dari langkah 1
- Klik **Deploy → New deployment**
  - Type: Web App
  - Execute as: **Me**
  - Who has access: **Anyone**
- Klik Deploy → **Copy the Web App URL**

### 3. Setup form.html
- Buka `form.html`, cari baris:
  ```js
  const APPS_SCRIPT_URL = 'GANTI_DENGAN_URL_APPS_SCRIPT';
  ```
- Ganti dengan URL dari langkah 2
- Host file ini — pilih salah satu:
  - **GitHub Pages** (gratis, paling gampang)
  - **Google Drive** → upload → Get shareable link → buka sebagai HTML
  - Server internal perusahaan

### 4. Setup script PowerShell
- Buka `cek_laptop.ps1`, cari baris:
  ```powershell
  $FORM_URL = "GANTI_DENGAN_URL_FORM_KAMU"
  ```
- Ganti dengan URL form.html yang sudah dihost

### 5. Distribusi ke karyawan
- Kirim 2 file: `cek_laptop.bat` + `cek_laptop.ps1` (harus 1 folder)
- Instruksi ke karyawan: **"Double-click file cek_laptop.bat"**
- Selesai — mereka tinggal isi nama + status + kerusakan → Kirim

---

## Alur karyawan
1. Double-click `cek_laptop.bat`
2. Jendela hitam muncul sebentar (deteksi spek otomatis)
3. Browser terbuka, form sudah terisi spesifikasi
4. Karyawan isi: Nama · Status laptop · Kerusakan
5. Klik **Kirim data**
6. Selesai — data masuk ke Google Sheets kamu

---

## Troubleshooting

**"Windows protected your PC" muncul**
→ Klik "More info" → "Run anyway"

**Browser tidak terbuka otomatis**
→ Karyawan buka manual URL form dari chat/email

**Data tidak masuk Sheets**
→ Buka URL Apps Script di browser, pastikan ada tulisan "aktif ✓"
→ Pastikan deployment: Execute as = Me, Access = Anyone
