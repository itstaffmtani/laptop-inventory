// ================================================================
// MTani — Inventarisasi Laptop · Google Apps Script
// Deploy sebagai Web App: Execute as Me · Anyone can access
// ================================================================

const SHEET_ID = "1t-0UZzBzEb_-Mf4dwVNEWHL2RI0YRQqZN-dyvOUNnQg";
const SHEET_NAME = "Data Laptop";

const HEADERS = [
  "Timestamp", "Nama", "Jabatan", "Perusahaan", "Penempatan", "Status Laptop",
  "No. Asset", "Hostname", "MAC Address", "Serial Number",
  "Merk", "Model",
  "CPU", "Core Fisik", "Thread", "Arsitektur",
  "GPU",
  "RAM (GB)", "RAM Tipe", "RAM Speed (MHz)", "RAM Usage (%)", "RAM Usage (GB)",
  "SSD (GB)", "SSD Tipe", "HDD (GB)",
  "Battery (%)", "Battery Wh", "Battery Wh Design",
  "OS", "OS Free (GB)", "OS Total (GB)",
  "Kondisi Fisik", "Kelengkapan", "Tahun Pembelian",
  "Kerusakan / Keluhan",
];

function doPost(e) {
  try {
    const ss = SpreadsheetApp.openById(SHEET_ID);
    let sheet = ss.getSheetByName(SHEET_NAME);

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
      data.timestamp     || "",
      data.nama          || "",
      data.jabatan       || "",
      data.perusahaan    || "",
      data.penempatan    || "",
      data.status        || "",
      data.no_asset      || "",
      data.hostname      || "",
      data.mac           || "",
      data.serial        || "",
      data.merk          || "",
      data.model         || "",
      data.cpu           || "",
      data.cpu_cores     || "",
      data.cpu_threads   || "",
      data.cpu_arch      || "",
      data.gpu           || "",
      data.ram_gb            || "",
      data.ram_type          || "",
      data.ram_speed         || "",
      data.ram_usage_pct     || "",
      data.ram_usage_gb      || "",
      data.ssd_gb            || "",
      data.ssd_tipe          || "",
      data.hdd_gb            || "",
      data.battery_pct       || "",
      data.battery_wh        || "",
      data.battery_wh_design || "",
      data.os                || "",
      data.os_free_gb        || "",
      data.os_total_gb       || "",
      data.kondisi_fisik || "",
      data.kelengkapan   || "",
      data.tahun_beli    || "",
      data.kerusakan     || "",
    ]);

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

function doGet() {
  return ContentService.createTextOutput(
    "MTani Laptop Inventory — Apps Script aktif ✓",
  );
}
