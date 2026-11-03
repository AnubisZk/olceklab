"""Faz 4 uçtan uca akışı, gerçek Firefox ile: popülasyon JSON'u dosyadan yüklenir → koşullar girilir → süre tahmini →
iş başlatılır → ilk parçadan sonra iptal → sürdür → sonuç tabloları, grafikler, bağımsız paket. Görünen metinler
browser_crosscheck.R ile belgelenen algoritmanın bağımsız bir yeniden yazımıyla denetlenir.
Kullanım: python3 browser_flow.py <ekran_görüntüsü_klasörü> <firefox> <geckodriver> <popülasyon.json>
"""
import base64, io, json, sys, time, zipfile
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

shots, ff, gd, popfile = sys.argv[1:5]
o = Options(); o.add_argument("-headless"); o.binary_location = ff
d = webdriver.Firefox(options=o, service=Service(gd))
w = WebDriverWait(d, 600)
out = {}
def click_text(tag, text):
    w.until(EC.element_to_be_clickable((By.XPATH, f"//{tag}[normalize-space()=\"{text}\"]"))).click()
def field(label):
    return w.until(EC.presence_of_element_located((By.XPATH, f"//label[span[normalize-space()=\"{label}\"]]/*[self::input or self::select or self::textarea]")))
def set_field(label, value):
    el = field(label); el.clear(); el.send_keys(value)
def rows(tid):
    return [[c.text for c in r.find_elements(By.XPATH, "./th|./td")] for r in d.find_elements(By.CSS_SELECTOR, f"[data-table-id={tid}] tbody tr")]
def status():
    return d.find_element(By.CSS_SELECTOR, "[data-testid=job-panel]").get_attribute("data-status")
try:
    d.set_window_size(1280, 1100)
    d.get("http://127.0.0.1:5173/")
    d.execute_script("localStorage.setItem('olceklab.theme','dark')"); d.get("http://127.0.0.1:5173/")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Çalışıyor"))
    d.find_element(By.XPATH, "//nav//a[contains(., 'Simülasyon')]").click()
    out["banner"] = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[role=note]"))).text
    d.find_element(By.XPATH, "//label[contains(., 'JSON yükle')]/input[@type='file']").send_keys(popfile)
    w.until(lambda _: "kesişim DIF" in field("Popülasyon tanımı (JSON)").get_attribute("value"))
    set_field("Toplam N listesi", "200, 400")
    set_field("Grup oranları (ör. 50/50; 70/30)", "50/50")
    set_field("Tekrar sayısı", "100")
    set_field("Tohum", "4242")
    set_field("Parça büyüklüğü (tekrar)", "20")
    click_text("button", "Süreyi tahmin et")
    out["estimate"] = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=sim-estimate]"))).text
    click_text("button", "Simülasyonu başlat")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=job-panel]")))
    out["job_id"] = d.find_element(By.CSS_SELECTOR, "[data-testid=job-panel]").get_attribute("data-job-id")
    w.until(lambda _: not d.find_element(By.CSS_SELECTOR, "[data-testid=job-progress]").text.startswith("0 /"))
    d.save_screenshot(f"{shots}/f4_running_dark.png")
    click_text("button", "İptal et")
    w.until(lambda _: status() == "cancelled")
    time.sleep(4)  # işçide süren parçalar biter; yeni parça başlamaz
    out["after_cancel"] = d.find_element(By.CSS_SELECTOR, "[data-testid=job-progress]").text
    out["after_cancel_later"] = (time.sleep(2), d.find_element(By.CSS_SELECTOR, "[data-testid=job-progress]").text)[1]
    click_text("button", "Sürdür")
    w.until(lambda _: status() == "done")
    out["done_progress"] = d.find_element(By.CSS_SELECTOR, "[data-testid=job-progress]").text
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T7] tbody tr")))
    for t in ["T1", "T3", "T4", "T5", "T7"]:
        out[t] = rows(t)
    out["charts"] = len(d.find_elements(By.CSS_SELECTOR, ".chart-figure svg"))
    out["result_notes"] = len(d.find_elements(By.CSS_SELECTOR, "[role=note]"))
    d.execute_script("document.getElementById('simres-title').scrollIntoView()"); time.sleep(0.5)
    d.save_screenshot(f"{shots}/f4_results_dark.png")
    pk = d.execute_async_script("""const done = arguments[arguments.length - 1];
      fetch('http://127.0.0.1:8000/simulations/' + arguments[0] + '/package').then(r => r.arrayBuffer()).then(b => {
        let s = ''; const u = new Uint8Array(b); for (let i = 0; i < u.length; i++) s += String.fromCharCode(u[i]); done(btoa(s)); });""", out["job_id"])
    z = zipfile.ZipFile(io.BytesIO(base64.b64decode(pk)))
    out["package_files"] = sorted(z.namelist())
    open(f"{shots}/../olceklab_simulasyon.zip", "wb").write(base64.b64decode(pk))
    d.find_element(By.XPATH, "//button[contains(., 'Açık')]").click(); time.sleep(0.5)
    d.save_screenshot(f"{shots}/f4_results_light.png")
    d.set_window_size(390, 844); time.sleep(0.5)
    out["mobile_horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")
finally:
    d.quit()
print(json.dumps(out, ensure_ascii=False))
