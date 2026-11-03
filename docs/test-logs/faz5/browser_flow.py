"""Faz 5 uçtan uca akışı, gerçek Firefox ile.
A) HS1939 örnek verisi: temizleme → DFA, güvenirlik, değişmezlik → rapora ekle → önizleme → Word raporu (indirilen .docx)
   → tablo CSV → proje dışa aktarma (örnek veri: veri eklenmez) → Başlangıç'ta içe aktarma → yeniden üretim → oturuma devam.
B) Yüklenen CSV (bfi'den 10 madde): onaysız veri eklenemez; onayla dışa aktarma → içe aktarma → yeniden üretim.
İndirilen .docx python-docx ile okunur; tablo hücreleri ve şablon cümleleri browser_crosscheck.R ile bağımsız R hesabına karşı denetlenir.
Kullanım: python3 browser_flow.py <klasör> <firefox> <geckodriver> <bfi10.csv>
"""
import glob, json, os, sys, time, zipfile
import docx
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select, WebDriverWait

base, ff, gd, csv = sys.argv[1:5]
dl = os.path.join(base, "indirilenler"); shots = os.path.join(base, "screenshots")
os.makedirs(dl, exist_ok=True)
for f in glob.glob(os.path.join(dl, "*")): os.remove(f)
o = Options(); o.add_argument("-headless"); o.binary_location = ff
o.set_preference("browser.download.folderList", 2); o.set_preference("browser.download.dir", dl)
o.set_preference("browser.download.useDownloadDir", True); o.set_preference("browser.download.manager.showWhenStarting", False)
o.set_preference("browser.helperApps.neverAsk.saveToDisk", "application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/zip,text/csv,application/octet-stream")
d = webdriver.Firefox(options=o, service=Service(gd))
w = WebDriverWait(d, 300)
out = {}
def click_text(tag, text):
    el = w.until(EC.element_to_be_clickable((By.XPATH, f"//{tag}[normalize-space()=\"{text}\"]")))
    d.execute_script("arguments[0].scrollIntoView({block:'center'})", el); el.click()
def nav(name): d.find_element(By.XPATH, f"//nav//a[contains(., '{name}')]").click()
def wait_file(pattern, n=1, timeout=60):
    t0 = time.time()
    while time.time() - t0 < timeout:
        fs = [f for f in glob.glob(os.path.join(dl, "*" + pattern)) if not f.endswith(".part")]
        if len(fs) >= n and all(os.path.getsize(f) > 0 for f in fs): time.sleep(0.5); return sorted(fs, key=os.path.getmtime)
        time.sleep(0.3)
    raise RuntimeError("indirme yok: " + pattern)
def rows(tid):
    from selenium.common.exceptions import StaleElementReferenceException
    for _ in range(10):  # sayfa yeniden çizilirken öğe bayatlarsa yeniden oku
        try:
            return [[c.text for c in r.find_elements(By.XPATH, "./th|./td")] for r in d.find_elements(By.CSS_SELECTOR, f"[data-table-id={tid}] tbody tr")]
        except StaleElementReferenceException:
            time.sleep(0.3)
    raise RuntimeError("tablo okunamadı: " + tid)
def add_to_report():
    click_text("button", "Bu sonucu rapora ekle")
    w.until(EC.presence_of_element_located((By.XPATH, "//button[@aria-pressed='true']")))
def clean_flow():
    click_text("button", "Rolleri kaydet")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Kaydedildi"))
    click_text("button", "Temizlemeyi çalıştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=clean-summary]")))
try:
    d.set_window_size(1280, 1100)
    d.get("http://127.0.0.1:5173/")
    d.execute_script("localStorage.setItem('olceklab.theme','dark')"); d.get("http://127.0.0.1:5173/")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Çalışıyor"))
    # --- A ---
    nav("Veri"); click_text("button", "Örnek: HolzingerSwineford1939 (lavaan)")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=n-rows]")))
    clean_flow()
    nav("DFA"); w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=model-syntax]")))
    click_text("button", "DFA'yı çalıştır"); w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T1] tbody tr")))
    out["ui_cfa_T1"] = rows("T1"); add_to_report()
    nav("Güvenirlik"); click_text("button", "Güvenirlik ve geçerliği hesapla")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T1] tbody tr"))); add_to_report()
    nav("Değişmezlik"); click_text("button", "Değişmezliği sına")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T3] tbody tr"))); add_to_report()
    # CSV (biçimli ve ham) — değişmezlik T2
    Select(d.find_element(By.XPATH, "//label[span[normalize-space()='Tablo']]/select")).select_by_value("T2")
    click_text("button", "CSV indir"); f1 = wait_file("invariance_T2_bicimli.csv")
    d.find_element(By.XPATH, "//label[span[normalize-space()='ham değerler (17 basamak)']]/input").click()
    click_text("button", "CSV indir"); f2 = wait_file("invariance_T2_ham.csv")
    out["csv_formatted"] = open(f1[0], encoding="utf-8-sig").read(); out["csv_raw"] = open(f2[0], encoding="utf-8-sig").read()
    nav("Rapor"); w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=report-items]")))
    out["report_items"] = [li.get_attribute("data-module") for li in d.find_elements(By.CSS_SELECTOR, "[data-testid=report-items] li")]
    click_text("button", "Metni önizle")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, ".report-preview article")))
    out["preview"] = [a.text for a in d.find_elements(By.CSS_SELECTOR, ".report-preview article")]
    out["preview_em"] = len(d.find_elements(By.CSS_SELECTOR, ".report-preview em"))
    d.execute_script("document.querySelector('.report-preview').scrollIntoView()"); time.sleep(0.3)
    d.save_screenshot(f"{shots}/f5_report_preview_dark.png")
    tt = d.find_element(By.XPATH, "//label[span[normalize-space()='Rapor başlığı']]/input"); tt.send_keys("HS1939 deneme raporu")
    click_text("button", "Word raporu oluştur (.docx)")
    rp = wait_file("olceklab_rapor.docx")[0]
    doc = docx.Document(rp)
    out["docx_paragraphs"] = [p.text for p in doc.paragraphs if p.text.strip()]
    out["docx_tables"] = [[[c.text for c in r.cells] for r in t.rows] for t in doc.tables]
    out["docx_path"] = rp
    # proje dışa aktarma (örnek veri: veri eklenmez)
    click_text("button", "Projeyi dışa aktar"); zA = wait_file("holzinger.olceklab.zip")[0]
    out["zipA"] = sorted(zipfile.ZipFile(zA).namelist())
    # içe aktarma → yeniden üretim
    nav("Başlangıç"); inp = w.until(EC.presence_of_element_located((By.XPATH, "//input[@aria-label='Proje dosyası seç']")))
    inp.send_keys(zA)
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=project-summary]")))
    out["importA_summary"] = d.find_element(By.CSS_SELECTOR, "[data-testid=project-summary]").text
    click_text("button", "Yeniden üret ve karşılaştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=project-result] tbody tr")))
    out["importA_result"] = [[c.text for c in r.find_elements(By.TAG_NAME, "td")] for r in d.find_elements(By.CSS_SELECTOR, "[data-testid=project-result] tbody tr")]
    out["importA_status"] = d.find_element(By.CSS_SELECTOR, "[data-testid=project-result] [role=status]").text
    d.save_screenshot(f"{shots}/f5_import_dark.png")
    click_text("button", "Oturuma devam et")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=clean-summary]")))
    nav("DFA"); w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T1] tbody tr")))
    out["restored_cfa_T1"] = rows("T1")
    # --- B: yüklenen CSV ---
    nav("Başlangıç"); click_text("button", "Yeni proje")
    d.find_element(By.XPATH, "//label[contains(., 'Dosya seç')]/input[@type='file']").send_keys(csv)
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=n-rows]")))
    clean_flow()
    nav("Madde analizi"); click_text("button", "Madde analizini çalıştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T2] tbody tr")))
    nav("Rapor"); w.until(EC.presence_of_element_located((By.XPATH, "//button[normalize-space()='Projeyi dışa aktar']")))
    d.find_element(By.XPATH, "//label[contains(., 'Veri dosyasını da ekle')]/input").click()
    out["export_disabled_without_consent"] = not d.find_element(By.XPATH, "//button[normalize-space()='Projeyi dışa aktar']").is_enabled()
    d.find_element(By.XPATH, "//label[contains(., 'açıkça onay veriyorum')]/input").click()
    click_text("button", "Projeyi dışa aktar"); zB = wait_file("bfi10.olceklab.zip")[0]
    zb = zipfile.ZipFile(zB); out["zipB"] = sorted(zb.namelist())
    out["zipB_data_identical"] = zb.read("data/bfi10.csv") == open(csv, "rb").read()
    d.find_element(By.XPATH, "//button[contains(., 'Açık')]").click(); time.sleep(0.4)
    d.execute_script("window.scrollTo(0, 0)"); d.save_screenshot(f"{shots}/f5_report_light.png")
    nav("Başlangıç"); inp = w.until(EC.presence_of_element_located((By.XPATH, "//input[@aria-label='Proje dosyası seç']")))
    inp.send_keys(zB)
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=project-summary]")))
    out["importB_summary"] = d.find_element(By.CSS_SELECTOR, "[data-testid=project-summary]").text
    click_text("button", "Yeniden üret ve karşılaştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=project-result] tbody tr")))
    out["importB_result"] = [[c.text for c in r.find_elements(By.TAG_NAME, "td")] for r in d.find_elements(By.CSS_SELECTOR, "[data-testid=project-result] tbody tr")]
    out["importB_status"] = d.find_element(By.CSS_SELECTOR, "[data-testid=project-result] [role=status]").text
    d.save_screenshot(f"{shots}/f5_import_light.png")
    d.set_window_size(390, 844); time.sleep(0.5)
    out["mobile_horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")
finally:
    d.quit()
print(json.dumps(out, ensure_ascii=False))
