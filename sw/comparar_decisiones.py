#!/usr/bin/env python3

import csv
import sys

if len(sys.argv) != 3:
    sys.exit(
        "Uso: python3 sw/comparar_decisiones.py "
        "referencia.csv decisiones.csv"
    )

def cargar(ruta):
    with open(ruta, newline="") as archivo:
        return list(csv.DictReader(archivo))

try:
    referencia = cargar(sys.argv[1])
    fpga = cargar(sys.argv[2])
except (OSError, csv.Error) as error:
    sys.exit(f"FAIL: {error}")

if not referencia or not fpga:
    sys.exit("FAIL: alguno de los CSV está vacío")

if len(referencia) != len(fpga):
    sys.exit(
        f"FAIL: diferentes cantidades de ticks: "
        f"{len(referencia)} vs {len(fpga)}"
    )

columnas = (
    "tick", "precio", "caja",
    "acciones", "patrimonio"
)

errores = 0

for indice, (ref, real) in enumerate(zip(referencia, fpga)):
    try:
        diferencia = any(
            int(ref[c]) != int(real[c])
            for c in columnas
        )

        if "decision_siguiente" in ref:
            esperado = (
                int(referencia[indice - 1]["decision_siguiente"], 16)
                if indice > 0 else 0
            )
            diferencia |= int(real["decision"], 16) != esperado
        elif "decision" in ref:
            diferencia |= (
                int(ref["decision"], 16) !=
                int(real["decision"], 16)
            )
        else:
            sys.exit("FAIL: referencia sin columna de decisión")

    except (ValueError, KeyError) as error:
        sys.exit(f"FAIL: dato inválido en tick {indice}: {error}")

    if diferencia:
        errores += 1
        if errores <= 10:
            print(f"Diferencia en tick {indice}")

print(f"Ticks comparados: {len(fpga)}")
print(f"Diferencias: {errores}")

if errores:
    sys.exit(1)

print("PASS: decisiones y contabilidad coinciden")
