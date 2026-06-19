# MTani — Laptop Inventory · Setup Guide

## Files
```
check_laptop.bat  ← distribute to employees (double-click, self-contained)
check_laptop.ps1  ← PowerShell script reference copy
index.html        ← form page (hosted on GitHub Pages)
apps_script.gs    ← Google Apps Script (copy-paste to script.google.com)
```

---

## Setup (in order)

### 1. Create Google Spreadsheet
- Open sheets.google.com → create new spreadsheet
- Copy the ID from the URL:
  `https://docs.google.com/spreadsheets/d/**COPY_THIS**/edit`

### 2. Setup Google Apps Script
- Open script.google.com → New project
- Delete default content, paste contents of `apps_script.gs`
- Replace `GANTI_DENGAN_ID_SPREADSHEET` with ID from step 1
- Click **Deploy → New deployment**
  - Type: Web App
  - Execute as: **Me**
  - Who has access: **Anyone**
- Click Deploy → **Copy the Web App URL**

### 3. Setup index.html
- Open `index.html`, find:
  ```js
  const APPS_SCRIPT_URL = 'GANTI_DENGAN_URL_APPS_SCRIPT';
  ```
- Replace with the URL from step 2
- Push to GitHub — GitHub Pages will serve it automatically

### 4. Setup PowerShell URL
- Open `check_laptop.ps1`, find:
  ```powershell
  $FORM_URL = "https://itstaffmtani.github.io/laptop-inventory/"
  ```
- Update if the GitHub Pages URL is different

### 5. Distribute to employees
- Send **only `check_laptop.bat`** (self-contained, no extra files needed)
- Instruction: **"Double-click check_laptop.bat"**
- Done — they fill in name + status + damage → Submit

---

## Employee flow
1. Double-click `check_laptop.bat`
2. Black window appears briefly (auto-detecting specs)
3. Browser opens with form pre-filled
4. Employee fills in: Name · Laptop status · Damage/complaints
5. Click **Kirim data**
6. Done — data goes into Google Sheets

---

## Troubleshooting

**"Windows protected your PC" appears**
→ Click "More info" → "Run anyway"

**Browser doesn't open automatically**
→ Employee manually opens the form URL from chat/email

**Data not showing in Sheets**
→ Open Apps Script URL in browser, check for "aktif ✓" message
→ Verify deployment: Execute as = Me, Access = Anyone
