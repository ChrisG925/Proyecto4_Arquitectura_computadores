import csv

with open("trade_ref_decisiones.csv", newline="") as f:
    ref = list(csv.DictReader(f))

with open("decisiones.csv", newline="") as f:
    fpga = list(csv.DictReader(f))

errores = 0

for i, fila in enumerate(fpga):
    tick = int(fila["tick"])
    ejecutada_fpga = int(fila["decision"], 16)

    # La orden ejecutada en este tick fue decidida
    # por Python en el tick anterior.
    esperada = (
        int(ref[i - 1]["decision_siguiente"], 16)
        if i > 0 else 0
    )

    caja_fpga = int(fila["caja"])
    caja_ref = int(ref[i]["caja"])

    acciones_fpga = int(fila["acciones"])
    acciones_ref = int(ref[i]["acciones"])

    patrimonio_fpga = int(fila["patrimonio"])
    patrimonio_ref = int(ref[i]["patrimonio"])

    if (
        tick != int(ref[i]["tick"])
        or ejecutada_fpga != esperada
        or caja_fpga != caja_ref
        or acciones_fpga != acciones_ref
        or patrimonio_fpga != patrimonio_ref
    ):
        errores += 1
        if errores <= 10:
            print(f"Diferencia en tick {tick}")
            print(
                f"  Decision FPGA: {ejecutada_fpga:02x}"
                f" | Python: {esperada:02x}"
            )
            print(
                f"  Caja FPGA: {caja_fpga}"
                f" | Python: {caja_ref}"
            )
            print(
                f"  Acciones FPGA: {acciones_fpga}"
                f" | Python: {acciones_ref}"
            )
            print(
                f"  Patrimonio FPGA: {patrimonio_fpga}"
                f" | Python: {patrimonio_ref}"
            )

print()
print(f"Ticks comparados: {len(fpga)}")
print(f"Ticks con diferencias: {errores}")

if errores == 0 and len(fpga) == len(ref):
    print("PASS: Espino coincide con Python en todos los ticks")
else:
    print("FAIL: hay diferencias o distinta cantidad de ticks")
