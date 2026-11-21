.section .text
.global _start

_start:
    # Base SPI
    lui x2, 0x80010

    # Buffer circular
    addi x7, x0, 1024
    addi x10, x0, 1280

    # Suma lenta y contador
    addi x8, x0, 0
    addi x9, x0, 0
    addi x13, x0, 64

    # Estado de posicion
    addi x15, x0, 0

    # Base de variables RAM
    addi x12, x0, 1536

    # Inicializar variables
    sw x0, 0(x12)
    sw x0, 4(x12)
    sw x0, 8(x12)
    sw x0, 12(x12)
    sw x0, 16(x12)
    sw x0, 20(x12)
    sw x0, 24(x12)
    sw x0, 28(x12)

    # Decision inicial HOLD
    sw x0, 8(x2)

wait_price:
    lw x3, 0(x2)
    andi x4, x3, 1
    beq x4, x0, wait_price

    lw x5, 4(x2)

    # Compra pendiente
    addi x4, x0, 1
    bne x15, x4, check_sell_pending

    addi x15, x0, 2

    # Guardar precio efectivo de entrada
    sw x5, 12(x12)
    sw x5, 16(x12)

    jal x0, update_window

check_sell_pending:
    addi x4, x0, 3
    beq x15, x4, sell_executed

    addi x4, x0, 4
    bge x15, x4, cooldown_check

    jal x0, update_window

sell_executed:
    addi x15, x0, 4
    jal x0, update_window

cooldown_check:
    addi x4, x0, 15
    bge x15, x4, cooldown_done

    addi x15, x15, 1
    jal x0, update_window

cooldown_done:
    addi x15, x0, 0

update_window:
    # Actualizar suma rapida S16
    lw x1, 4(x12)

    addi x4, x0, 16
    bge x9, x4, blt_skip_1
    jal x0, fast_add
blt_skip_1:

    # Recuperar precio de hace 16 ticks
    addi x6, x7, 192
    bge x6, x10, blt_skip_2
    jal x0, fast_read
blt_skip_2:

    addi x6, x6, -256

fast_read:
    lw x11, 0(x6)
    sub x1, x1, x11

fast_add:
    add x1, x1, x5
    sw x1, 4(x12)

    # Actualizar suma lenta S64
    bge x9, x13, full_window

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

    addi x7, x0, 1024

evaluate:
    # Guardar suma lenta
    sw x8, 0(x12)

    # Esperar ventana completa
    bne x9, x13, mantener

    # T = 4*S16 - S64
    lw x1, 4(x12)
    add x14, x1, x1
    add x14, x14, x14
    sub x14, x14, x8

    # Clasificar mercado
    # 1 = alcista
    # 0 = lateral
    # -1 = bajista

    addi x4, x0, 384
    bge x14, x4, mercado_alcista

    addi x4, x0, -384
    bge x4, x14, mercado_bajista

mercado_lateral:
    addi x4, x0, 0
    jal x0, confirmar_estado

mercado_alcista:
    addi x4, x0, 1
    jal x0, confirmar_estado

mercado_bajista:
    addi x4, x0, -1

confirmar_estado:
    lw x11, 24(x12)
    beq x11, x4, mismo_estado

    sw x4, 24(x12)
    addi x6, x0, 1
    sw x6, 28(x12)
    jal x0, evaluar_posicion

mismo_estado:
    lw x6, 28(x12)
    addi x11, x0, 8
    bge x6, x11, estado_confirmado

    addi x6, x6, 1
    sw x6, 28(x12)
    bge x6, x11, estado_confirmado
    jal x0, evaluar_posicion

estado_confirmado:
    sw x4, 20(x12)
    jal x0, evaluar_posicion

evaluar_posicion:
    addi x4, x0, 2
    beq x15, x4, evaluar_venta

    # Comprar solo sin posicion
    bne x15, x0, mantener

    # Exigir 8 ticks de confirmacion
    lw x6, 28(x12)
    addi x4, x0, 8
    bge x6, x4, mercado_estable
    jal x0, mantener

mercado_estable:
    lw x14, 20(x12)

    # Mercado bajista: no comprar
    bge x14, x0, blt_skip_3
    jal x0, mantener
blt_skip_3:

    # Mercado alcista
    bne x14, x0, comprar_alcista

comprar_lateral:
    # Precio <= MA64 - 8
    lui x6, 0x80000
    sw x8, 16(x6)
    sw x5, 20(x6)
    lw x14, 24(x6)
    andi x14, x14, 1
    beq x14, x0, mantener

    jal x0, confirmar_recuperacion

comprar_alcista:
    # Precio <= MA16 - 2
    addi x14, x5, 2

    add x14, x14, x14
    add x14, x14, x14
    add x14, x14, x14
    add x14, x14, x14

    lw x1, 4(x12)
    bge x1, x14, confirmar_recuperacion
    jal x0, mantener

confirmar_recuperacion:
    # Leer precio de hace 4 ticks
    addi x6, x7, 236
    bge x6, x10, recuperacion_wrap
    jal x0, recuperacion_read

recuperacion_wrap:
    addi x6, x6, -256

recuperacion_read:
    lw x11, 0(x6)

    # Momentum de 4 ticks >= 3
    sub x14, x5, x11
    addi x4, x0, 3
    bge x14, x4, comprar

    jal x0, mantener

evaluar_venta:
    # Actualizar precio maximo
    lw x11, 16(x12)

    bge x11, x5, check_stop

    sw x5, 16(x12)

check_stop:
    # Stop-loss general de 8 puntos
    lw x1, 12(x12)

    sub x14, x1, x5
    addi x4, x0, 8

    bge x14, x4, vender

    # Mercado bajista: liquidar
    lw x14, 20(x12)
    bge x14, x0, blt_skip_5
    jal x0, vender
blt_skip_5:

    # Mercado alcista?
    bne x14, x0, vender_alcista

vender_lateral:
    # Take-profit de 12 puntos
    sub x14, x5, x1

    addi x4, x0, 12
    bge x14, x4, vender

    jal x0, mantener

vender_alcista:
    # Take-profit de 18 puntos
    sub x14, x5, x1

    addi x4, x0, 18
    bge x14, x4, vender

    # Trailing stop de 8 puntos
    lw x11, 16(x12)

    sub x14, x11, x5
    addi x4, x0, 8

    bge x14, x4, vender

    jal x0, mantener

mantener:
    sw x5, 8(x12)

    sw x0, 8(x2)

    jal x0, wait_price

comprar:
    sw x5, 8(x12)

    lw x14, 20(x12)
    beq x14, x0, cantidad_lateral

    # Comprar 16 acciones
    addi x6, x0, 80
    jal x0, enviar_compra

cantidad_lateral:
    # Comprar 8 acciones
    addi x6, x0, 72

enviar_compra:
    sw x6, 8(x2)
    addi x15, x0, 1
    jal x0, wait_price

vender:
    sw x5, 8(x12)

    # Vender 16 acciones
    addi x6, x0, 144
    sw x6, 8(x2)

    addi x15, x0, 3

    jal x0, wait_price
