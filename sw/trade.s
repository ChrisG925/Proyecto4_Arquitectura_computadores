
.section .text
.global _start

_start:
    # Direccion base del periferico SPI
    lui x2,0x80010

    # Historial circular de 64 precios
    addi x7,x0,1024
    addi x10,x0,1280

    # Suma movil
    addi x8,x0,0

    # Contador de precios recibidos
    addi x9,x0,0
    addi x13,x0,64

    # Estado de trading
    addi x15,x0,0

    # Precio maximo desde la compra
    addi x12,x0,0

    # Decision inicial: HOLD
    sw x0,8(x2)


# ==========================================
# ESPERAR NUEVO PRECIO POR SPI
# ==========================================

wait_price:
    lw x3,0(x2)
    andi x4,x3,1
    beq x4,x0,wait_price

    # Leer precio recibido
    lw x5,4(x2)

    # Comprobar compra pendiente
    addi x4,x0,1
    bne x15,x4,check_sell_pending

    addi x15,x0,2
    add x12,x5,x0
    jal x0,update_window


# ==========================================
# ESTADOS DEL ALGORITMO
# ==========================================

check_sell_pending:
    addi x4,x0,3
    beq x15,x4,sell_executed

    addi x4,x0,4
    beq x15,x4,cooldown_1

    addi x4,x0,5
    beq x15,x4,cooldown_2

    addi x4,x0,6
    beq x15,x4,cooldown_done

    jal x0,update_window


sell_executed:
    addi x15,x0,4
    jal x0,update_window


cooldown_1:
    addi x15,x0,5
    jal x0,update_window


cooldown_2:
    addi x15,x0,6
    jal x0,update_window


cooldown_done:
    addi x15,x0,0
    jal x0,update_window


# ==========================================
# ACELERACION 2: ACTUALIZAR VENTANA
# ==========================================

update_window:
    # Durante los primeros 64 precios
    # guardar sin reemplazar valores anteriores
    bge x9,x13,full_window

    sw x5,0(x7)
    addi x9,x9,1
    jal x0,advance_ptr


full_window:
    # Leer el precio antiguo desde RAM
    lw x11,0(x7)

    # Escribir el nuevo precio
    # El hardware actualiza la suma movil
    sw x5,0(x7)


advance_ptr:
    # Avanzar el puntero circular
    addi x7,x7,4

    bne x7,x10,evaluate

    # Volver al inicio del historial
    addi x7,x0,1024


# ==========================================
# LEER SUMA MOVIL DESDE HARDWARE
# ==========================================

evaluate:
    # Base MMIO de perifericos
    lui x6,0x80000

    # Leer suma movil en 0x80000010
    lw x8,16(x6)

    # Guardar suma para depuracion
    addi x6,x0,1536
    sw x8,0(x6)

    # Esperar hasta llenar 64 precios
    bne x9,x13,mantener

    # Comprobar si tenemos acciones
    addi x4,x0,2
    beq x15,x4,evaluate_sell

    # Si estamos en cooldown, mantener
    bne x15,x0,mantener

    # ======================================
    # CONDICION DE COMPRA
    # 64*(precio+4) <= suma_movil
    # ======================================

    addi x14,x5,4

    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14

    bge x8,x14,comprar
    jal x0,mantener


# ==========================================
# CONDICIONES DE VENTA
# ==========================================

evaluate_sell:
    # Actualizar maximo desde la compra
    bge x12,x5,check_mean
    add x12,x5,x0


check_mean:
    # Condicion 1: precio >= media movil
    add x14,x5,x5
    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14
    add x14,x14,x14

    bge x14,x8,vender

    # Condicion 2: trailing stop de 15
    sub x14,x12,x5
    addi x4,x0,15
    bge x14,x4,vender


# ==========================================
# MANTENER
# ==========================================

mantener:
    sw x0,8(x2)
    jal x0,wait_price


# ==========================================
# COMPRAR 16 ACCIONES
# ==========================================

comprar:
    # BUY = 01 en bits 7:6
    # Cantidad = 16
    # 0x40 + 0x10 = 0x50 = 80
    addi x6,x0,80
    sw x6,8(x2)

    # Compra pendiente
    addi x15,x0,1
    jal x0,wait_price


# ==========================================
# VENDER 16 ACCIONES
# ==========================================

vender:
    # SELL = 10 en bits 7:6
    # Cantidad = 16
    # 0x80 + 0x10 = 0x90 = 144
    addi x6,x0,144
    sw x6,8(x2)

    # Venta pendiente
    addi x15,x0,3
    jal x0,wait_price
