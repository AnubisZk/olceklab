"""Faz 2 uçtan uca akışı, gerçek Firefox ile (Playwright tarayıcısı indirilemeyen ortamda yerine kullanıldı).
Kullanım: python3 browser_flow.py <ekran_görüntüsü_klasörü> <firefox> <geckodriver>
Arayüzde görünen metinleri JSON olarak yazdırır; browser_crosscheck.R bunları bağımsız R hesabıyla karşılaştırır.
Akış: HolzingerSwineford1939 → roller → temizleme → AFA (3 faktör) → DFA (ML, Wishart, Bollen–Stine B = 200)
→ karşılaştırma (üç faktör / tek faktör) → güvenirlik.
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
def nav(text):
    d.find_element(By.XPATH, f"//nav//a[contains(., '{text}')]").click()
def field(label):
    return w.until(EC.presence_of_element_located((By.XPATH, f"//label[span[normalize-space()=\"{label}\"]]/*[self::input or self::select or self::textarea]")))
def table_rows(tid, scope=None):
    root = scope or d
    return [[c.text for c in r.find_elements(By.XPATH, "./th|./td")] for r in root.find_elements(By.CSS_SELECTOR, f"[data-table-id={tid}] tbody tr")]
try:
    d.set_window_size(1280, 1100)
    d.get("http://127.0.0.1:5173/")
    d.execute_script("localStorage.setItem('olceklab.theme','dark')"); d.get("http://127.0.0.1:5173/")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Çalışıyor"))
    nav("Veri")
    click_text("button", "Örnek: HolzingerSwineford1939 (lavaan)")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=n-rows]")))
    click_text("button", "Rolleri kaydet")
    w.until(EC.text_to_be_present_in_element((By.TAG_NAME, "body"), "Kaydedildi"))
    click_text("button", "Temizlemeyi çalıştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=clean-summary]")))

    # AFA
    nav("AFA")
    nf = field("Faktör sayısı"); nf.clear(); nf.send_keys("3")
    click_text("button", "AFA'yı çalıştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T1] tbody tr")))
    out["efa_header"] = [th.text for th in d.find_elements(By.CSS_SELECTOR, "[data-table-id=T1] thead th")]
    out["efa_rows"] = table_rows("T1")
    out["efa_fit"] = table_rows("T5")
    d.save_screenshot(f"{shots}/f2_efa_dark.png")

    # DFA
    nav("DFA")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-testid=model-syntax]")))
    out["model_syntax"] = d.find_element(By.CSS_SELECTOR, "[data-testid=model-syntax]").text
    Select(field("Olabilirlik")).select_by_value("wishart")
    d.find_element(By.XPATH, "//label[span[normalize-space()='Bollen–Stine bootstrap']]/input").click()
    b = field("Bootstrap sayısı (B)"); b.clear(); b.send_keys("200")
    t0 = time.time(); click_text("button", "DFA'yı çalıştır")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T6]")))
    out["cfa_seconds"] = round(time.time() - t0, 1)
    out["cfa_fit"] = table_rows("T1")
    out["cfa_loadings"] = table_rows("T2")
    out["cfa_bs"] = table_rows("T6")
    out["path_label_visual_x2"] = d.find_element(By.CSS_SELECTOR, "[data-testid='load-visual-x2']").text
    d.execute_script("document.querySelector('[data-testid=path-diagram]').scrollIntoView()")
    time.sleep(0.4); d.save_screenshot(f"{shots}/f2_cfa_path_dark.png")
    d.execute_script("window.scrollTo(0, 0)")
    # Karşılaştırma: üç faktör ve tek faktör
    nm = field("Karşılaştırma için model adı"); nm.clear(); nm.send_keys("Üç faktör")
    click_text("button", "Modeli karşılaştırmaya ekle")
    click_text("button", "lavaan sözdizimi")
    ta = w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "textarea.syntax-input")))
    ta.clear(); ta.send_keys("g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9")
    nm = field("Karşılaştırma için model adı"); nm.click(); nm.clear(); nm.send_keys("Tek faktör")
    w.until(EC.text_to_be_present_in_element((By.CSS_SELECTOR, "[data-testid=model-syntax]"), "g =~"))
    click_text("button", "Modeli karşılaştırmaya ekle")
    click_text("button", "Modelleri karşılaştır")
    sec = w.until(EC.presence_of_element_located((By.XPATH, "//section[h2[normalize-space()='Rakip model karşılaştırması']]")))
    w.until(lambda _: sec.find_elements(By.CSS_SELECTOR, "[data-table-id=T2] tbody tr"))
    out["cmp_fit"] = table_rows("T1", sec)
    out["cmp_tests"] = table_rows("T2", sec)
    sec.location_once_scrolled_into_view; time.sleep(0.3)
    d.save_screenshot(f"{shots}/f2_compare_dark.png")

    # Güvenirlik: model DFA ile ortak; sözdizimi alanına üç faktörlü modeli yaz
    ta = d.find_element(By.CSS_SELECTOR, "textarea.syntax-input")
    ta.clear(); ta.send_keys("visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9")
    nm = field("Karşılaştırma için model adı"); nm.click()
    w.until(EC.text_to_be_present_in_element((By.CSS_SELECTOR, "[data-testid=model-syntax]"), "speed =~"))
    nav("Güvenirlik")
    click_text("button", "Güvenirlik ve geçerliği hesapla")
    w.until(EC.presence_of_element_located((By.CSS_SELECTOR, "[data-table-id=T1] tbody tr")))
    out["rel_t1"] = table_rows("T1")
    out["rel_htmt"] = table_rows("T2")
    d.save_screenshot(f"{shots}/f2_reliability_dark.png")
    out["horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")

    # Açık tema ve dar ekran
    nav("DFA")
    d.find_element(By.XPATH, "//button[contains(., 'Açık')]").click()
    time.sleep(0.5)
    d.execute_script("document.querySelector('[data-testid=path-diagram]').scrollIntoView()")
    time.sleep(0.4); d.save_screenshot(f"{shots}/f2_cfa_path_light.png")
    out["path_ellipse_stroke_light"] = d.execute_script("return document.querySelector('[data-testid=path-diagram] ellipse').getAttribute('stroke')")
    d.set_window_size(390, 844); time.sleep(0.5)
    out["mobile_horizontal_scroll"] = d.execute_script("return document.documentElement.scrollWidth > document.documentElement.clientWidth")
    d.save_screenshot(f"{shots}/f2_cfa_mobile.png")
finally:
    d.quit()
print(json.dumps(out, ensure_ascii=False))
