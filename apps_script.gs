// ================================================================
// MTani — Inventarisasi Laptop · Google Apps Script
// Deploy sebagai Web App: Execute as Me · Anyone can access
// ================================================================

const SHEET_ID = "1t-0UZzBzEb_-Mf4dwVNEWHL2RI0YRQqZN-dyvOUNnQg"; // ambil dari URL sheets
const SHEET_NAME = "Data Laptop";

const HEADERS = [
  "Timestamp",
  "Nama",
  "Jabatan",
  "Perusahaan",
  "Penempatan",
  "Status Laptop",
  "Merk",
  "Model",
  "CPU",
  "RAM",
  "Storage",
  "Kerusakan",
  "OS",
  "Serial Number",
];

function doPost(e) {
  try {
    const ss = SpreadsheetApp.openById(SHEET_ID);
    let sheet = ss.getSheetByName(SHEET_NAME);

    // Buat sheet & header kalau belum ada
    if (!sheet) {
      sheet = ss.insertSheet(SHEET_NAME);
      sheet.appendRow(HEADERS);
      sheet
        .getRange(1, 1, 1, HEADERS.length)
        .setFontWeight("bold")
        .setBackground("#1c1917")
        .setFontColor("#ffffff");
      sheet.setFrozenRows(1);
    }

    const data = JSON.parse(e.postData.contents);

    sheet.appendRow([
      data.timestamp || "",
      data.nama || "",
      data.jabatan || "",
      data.perusahaan || "",
      data.penempatan || "",
      data.status || "",
      data.merk || "",
      data.model || "",
      data.cpu || "",
      data.ram || "",
      data.storage || "",
      data.kerusakan || "",
      data.os || "",
      data.serial || "",
    ]);

    // Auto-resize kolom supaya rapi
    sheet.autoResizeColumns(1, HEADERS.length);

    return ContentService.createTextOutput(
      JSON.stringify({ status: "ok" }),
    ).setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(
      JSON.stringify({ status: "error", message: err.toString() }),
    ).setMimeType(ContentService.MimeType.JSON);
  }
}

// Test via GET (buka URL Apps Script di browser untuk cek apakah aktif)
function doGet() {
  return ContentService.createTextOutput(
    "MTani Laptop Inventory — Apps Script aktif ✓",
  );
}
