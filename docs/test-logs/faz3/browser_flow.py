"""Faz 3 uçtan uca akışı, gerçek Firefox ile. HS1939 (okul grupları): değişmezlik zinciri → skor testleri →
en büyük kısıtın onaylı serbest bırakılması → kısmi zincir ve gizil ortalamalar. Çıktı browser_crosscheck.R ile denetlenir.
Kullanım: python3 browser_flow.py <ekran_görüntüsü_klasörü> <firefox> <geckodriver>
"""
import json, sys, time
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import Select, WebDriverWait

shots, ff, gd = sys.argv[1], sys.argv[2], sys.argv[3]
o = Options(); o.add_argument("-headless"); o.binary_location = ff
d = webdriver.Firefox(options=o, service=Service(gd))
w = WebDriverWait(d, 300)
out = {}
def click_text(tag, text):
    w.until(EC.element_to_be_clickable((By.XPATH, f"//{tag}[normalize-space()=\"{text}\"]"))).click()
def field(label):
    return w.until(EC.presence_of_element_located((By.XPATH, f"//label[span[normalize-space()=\"{label}\"]]/*[self::input or self::select]")))
def rows(tid):
    return [[c.text for c in r.find_elements(By.XPATH, "./th|./td")] for r in d.find_elements(By.CSS_SELECTOR, f"[data-table-id={tid}] tbody tr")]
try:
    d.set_window_size(1280, 1100)
    d.get("http://127.0.0.1:5173/")
    d.execute_script("localStorage.setItem('olceklab.theme','dark')"); d.get("http://127.0.0.1:5173/")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Çalışıyor"))
    d.find_element(By.XPATH, "//nav//a[contains(., 'Veri')]").click()
    click_text("button", "Örnek: HolzingerSwineford1939 (lavaan)")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=n-rows]")))
    click_text("button", "Rolleri kaydet")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Kaydedildi"))
    click_text("button", "Temizlemeyi çalıştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=clean-summary]")))
    d.find_element(By.XPATH, "//nav//a[contains(., 'Değişmezlik')]").click()
    Select(field("Olabilirlik")).select_by_value("wishart")
    click_text("button", "Değişmezliği sına")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T3] tbody tr")))
    out["full_fit"] = rows("T1"); out["full_cmp"] = rows("T2"); out["full_latent"] = rows("T3")
    d.save_screenshot(f"{shots}/f3_invariance_dark.png")
    Select(field("Skor testi yapılacak adım")).select_by_value("scalar")
    click_text("button", "Skor testlerini hesapla")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=score-tests] tbody tr")))
    out["scores_top"] = rows("score-tests")[:3]
    first = d.find_element(By.CSS_SELECTOR, "[data-table-id=score-tests] tbody tr").get_attribute("data-free")
    out["released"] = first
    d.find_element(By.CSS_SELECTOR, "[data-table-id=score-tests] tbody tr button").click()
    click_text("button", "Onayla")
    w.until(EC.text_to_be_present_in_element((By.CSS_SELECTOR, "[data-table-id=T1] + p, .table-note"), first))
    time.sleep(1.0)
    w.until(lambda _: first in d.find_element(By.CSS_SELECTOR, "[data-table-id=T1] .table-note").text)
    out["partial_fit"] = rows("T1"); out["partial_cmp"] = rows("T2"); out["partial_latent"] = rows("T3")
    d.execute_script("document.querySelector('[data-table-id=score-tests]').scrollIntoView()")
    time.sleep(0.3); d.save_screenshot(f"{shots}/f3_wizard_dark.png")
    d.find_element(By.XPATH, "//button[contains(., 'Açık')]").click(); time.sleep(0.5)
    d.execute_script("window.scrollTo(0, 0)"); time.sleep(0.2)
    d.save_screenshot(f"{shots}/f3_invariance_light.png")
    d.set_window_size(390, 844); time.sleep(0.5)
    out["mobile_horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")
finally:
    d.quit()
print(json.dumps(out, ensure_ascii=False))
