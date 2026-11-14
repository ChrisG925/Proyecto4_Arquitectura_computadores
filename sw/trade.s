
.section .text
.global _start

_start:
    # Base SPI
    lui x2, 0x80010

    # Buffer circular: 0x400 a 0x4FC
    addi x7, x0, 1024
    addi x10, x0, 1280

    # Suma y cantidad de precios
    addi x8, x0, 0
    addi x9, x0, 0
    addi x13, x0, 64

    # Estado:
    # 0 = sin posicion
    # 1 = compra pendiente
    # 2 = posicion abierta
    # 3 = venta pendiente
    # 4 = primera operacion terminada
    addi x15, x0, 0

    # Maximo de la posicion
    addi x12, x0, 0

    # Decision inicial: mantener
    sw x0, 8(x2)

wait_price:
    lw x3, 0(x2)
    andi x4, x3, 1
    beq x4, x0, wait_price

    # Precio nuevo
    lw x5, 4(x2)

    # Actualizar estado de orden pendiente
    addi x4, x0, 1
    bne x15, x4, check_sell_pending

    # Compra ejecutada en este tick
    addi x15, x0, 2
    add x12, x5, x0
    jal x0, update_window


check_sell_pending:
    # Comprobar venta pendiente
    addi x4, x0, 3
    beq x15, x4, sell_executed

    # Estados de espera despues de vender
    addi x4, x0, 4
    beq x15, x4, cooldown_1

    addi x4, x0, 5
    beq x15, x4, cooldown_2

    addi x4, x0, 6
    beq x15, x4, cooldown_done

    jal x0, update_window

sell_executed:
    # La venta se ejecuta en el tick actual
    addi x15, x0, 4
    jal x0, update_window

cooldown_1:
    addi x15, x0, 5
    jal x0, update_window

cooldown_2:
    addi x15, x0, 6
    jal x0, update_window

cooldown_done:
    # Se permite comprar nuevamente
    addi x15, x0, 0
    jal x0, update_window


update_window:
    # Si ventana llena, quitar el antiguo
    bge x9, x13, full_window

    # Llenar ventana inicial
    add x8, x8, x5
    sw x5, 0(x7)
    addi x9, x9, 1
    jal x0, advance_ptr

full_window:
    lw x11, 0(x7)
    sub x8, x8, x11
    add x8, x8, x5
    sw x5, 0(x7)

advance_ptr:
    addi x7, x7, 4
    bne x7, x10, evaluate

    # Reiniciar puntero circular
    addi x7, x0, 1024


evaluate:
    # Guardar suma movil para depuracion
    addi x6, x0, 1536
    sw x8, 0(x6)

    # Esperar hasta tener 64 precios
    bne x9, x13, mantener

    # Base de perifericos generales
    lui x6, 0x80000

    # Enviar suma movil al acelerador
    sw x8, 16(x6)

    # Enviar precio y calcular comparaciones
    sw x5, 20(x6)

    # Leer resultado del acelerador
    lw x14, 24(x6)

    # Si tenemos posicion, evaluar venta
    addi x4, x0, 2
    beq x15, x4, evaluate_sell

    # Si no estamos libres para comprar, mantener
    bne x15, x0, mantener

    # Bit 0: condicion de compra
    andi x14, x14, 1
    bne x14, x0, comprar

    jal x0, mantener

evaluate_sell:
    # Actualizar precio maximo
    bge x12, x5, check_mean
    add x12, x5, x0

check_mean:
    # Bit 1: condicion de venta por media movil
    andi x14, x14, 2
    bne x14, x0, vender

    # Segunda condicion: retroceso de 15
    sub x14, x12, x5
    addi x4, x0, 15
    bge x14, x4, vender


mantener:
    sw x0, 8(x2)
    jal x0, wait_price

comprar:
    # Comprar 16 acciones
    addi x6, x0, 80
    sw x6, 8(x2)

    # Compra pendiente
    addi x15, x0, 1
    jal x0, wait_price

vender:
    # Vender 16 acciones
    addi x6, x0, 144
    sw x6, 8(x2)

    # Venta pendiente
    addi x15, x0, 3
    jal x0, wait_price
