"""Faz 1 uçtan uca akışı, gerçek Firefox ile (Playwright tarayıcısı indirilemeyen ortamda yerine kullanıldı).
Kullanım: python3 browser_flow.py <ekran_görüntüsü_klasörü> <firefox> <geckodriver>
Arayüzde görünen metinleri JSON olarak yazdırır; browser_crosscheck.R bunları bağımsız R hesabıyla karşılaştırır.
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
    w.until(EC.element_to_be_clickable((By.XPATH, f"//{tag}[normalize-space()='{text}']"))).click()
try:
    d.set_window_size(1280, 1100)
    d.get("http://127.0.0.1:5173/")
    d.execute_script("localStorage.setItem('olceklab.theme','dark')"); d.get("http://127.0.0.1:5173/")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Çalışıyor"))
    d.find_element(By.XPATH, "//nav//a[contains(., 'Veri')]").click()
    click_text("button", "Örnek: bfi (psych)")
    out["n_rows"] = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=n-rows]"))).text
    click_text("button", "Rolleri kaydet")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Kaydedildi"))
    click_text("button", "Temizlemeyi çalıştır")
    out["clean_summary"] = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=clean-summary]"))).text
    d.save_screenshot(f"{shots}/f1_data_clean.png")
    click_text("a", "Madde analizine geç")
    click_text("button", "Madde analizini çalıştır")
    row = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T1] tbody tr")))
    out["item_first_row"] = [td.text for td in row.find_elements(By.TAG_NAME, "td")]
    out["item_heatmap_svg"] = len(d.find_elements(By.CSS_SELECTOR, ".chart svg")) > 0
    d.save_screenshot(f"{shots}/f1_items.png")
    d.find_element(By.XPATH, "//nav//a[contains(., 'Faktör sayısı')]").click()
    it = w.until(EC.presence_of_element_located((By.XPATH, "//label[span[normalize-space()='Yineleme sayısı']]/input")))
    it.clear(); it.send_keys("200")
    t0 = time.time(); click_text("button", "Faktör sayısını belirle")
    out["decision"] = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=decision]"))).text
    out["pa_seconds"] = round(time.time() - t0, 1)
    out["scree_svg"] = len(d.find_elements(By.CSS_SELECTOR, ".chart svg path")) > 0
    t1 = d.find_elements(By.CSS_SELECTOR, "[data-table-id=T1] tbody tr")
    out["pa_table_rows"] = len(t1)
    out["pa_first_row"] = [td.text for td in t1[0].find_elements(By.TAG_NAME, "td")]
    out["horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")
    d.save_screenshot(f"{shots}/f1_factor_number_dark.png")
    d.set_window_size(1100, 1000); time.sleep(0.5)
    d.get_full_page_screenshot_as_file(f"{shots}/f1_factor_number_full.png")
    d.set_window_size(1280, 1100); time.sleep(0.3)
    d.execute_script("document.querySelector('.decision').scrollIntoView()")
    d.execute_script("localStorage.setItem('olceklab.theme','light')")
    d.find_element(By.XPATH, "//button[contains(., 'Açık')]").click()
    time.sleep(0.5); d.save_screenshot(f"{shots}/f1_factor_number_light.png")
    d.set_window_size(390, 844); time.sleep(0.5)
    out["mobile_horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")
    d.save_screenshot(f"{shots}/f1_factor_number_mobile.png")
finally:
    d.quit()
print(json.dumps(out, ensure_ascii=False))
