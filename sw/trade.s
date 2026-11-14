
.section .text
.global _start

_start:
    # Base SPI: 0x80010000
    lui x2, 0x80010

    # Inicio del buffer: 0x400
    addi x7, x0, 1024

    # Fin exclusivo del buffer: 0x500
    addi x10, x0, 1280

    # Suma acumulada
    addi x8, x0, 0

    # Cantidad de precios recibidos, maximo 64
    addi x9, x0, 0

    # Tamano de ventana
    addi x13, x0, 64

    # Indicador de primera compra realizada
    addi x15, x0, 0

    # DECISION inicial = MANTENER
    sw x0, 8(x2)

wait_price:
    # Esperar nuevo precio
    lw x3, 0(x2)
    andi x4, x3, 1
    beq x4, x0, wait_price

    # Leer precio actual
    lw x5, 4(x2)

    # Si ventana llena, reemplazar precio antiguo
    bge x9, x13, full_window

    # Ventana aun no llena
    add x8, x8, x5
    sw x5, 0(x7)
    addi x9, x9, 1
    jal x0, advance_ptr

full_window:
    # Recuperar precio mas antiguo
    lw x11, 0(x7)

    # Actualizar suma movil
    sub x8, x8, x11
    add x8, x8, x5

    # Reemplazar precio antiguo
    sw x5, 0(x7)

advance_ptr:
    # Avanzar una posicion
    addi x7, x7, 4

    # Comprobar si llegamos al final
    bne x7, x10, write_decision

    # Volver al comienzo del buffer
    addi x7, x0, 1024



write_decision:
    # Guardar suma movil para depuracion
    addi x12, x0, 1536
    sw x8, 0(x12)

    # Si ya encontramos una compra, mantener
    bne x15, x0, mantener

    # No comprar hasta completar 64 precios
    bne x9, x13, mantener

    # Calcular 64 * (precio + 4)
    # Sin utilizar multiplicacion ni shifts
    addi x14, x5, 4
    add x14, x14, x14
    add x14, x14, x14
    add x14, x14, x14
    add x14, x14, x14
    add x14, x14, x14
    add x14, x14, x14

    # Comprar cuando suma >= 64*(precio+4)
    bge x8, x14, comprar

mantener:
    sw x0, 8(x2)
    jal x0, wait_price

comprar:
    # 0x50 = comprar 16 acciones
    addi x6, x0, 80
    sw x6, 8(x2)

    # Evitar compras repetidas en esta prueba
    addi x15, x0, 1
    jal x0, wait_price
