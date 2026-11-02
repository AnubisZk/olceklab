# CSV'leri BİDEKÇET dosya düzeninde .xlsx olarak yazar (openpyxl 3.1.5). Sentetik veridir.
import csv
from openpyxl import Workbook

def write(csv_path, xlsx_path, header):
    wb = Workbook()
    ws = wb.active
    ws.append(header)
    with open(csv_path, encoding="utf-8") as f:
        r = csv.reader(f)
        next(r)
        for row in r:
            out = []
            for v in row:
                if v == "":
                    out.append(None)
                else:
                    try:
                        out.append(int(v))
                    except ValueError:
                        out.append(v)
            ws.append(out)
    wb.save(xlsx_path)

write("ortaokul.csv", "ortaokul_sentetik.xlsx", ["cinsiyet", "sınıf"] + [f"M{k}" for k in range(1, 14)])
write("lise.csv", "lise_sentetik.xlsx", ["Cinsiyet", "Sinif"] + [f"Madde{k}" + (" " if k in (1, 7, 13) else "") for k in range(1, 14)])
print("yazıldı")
