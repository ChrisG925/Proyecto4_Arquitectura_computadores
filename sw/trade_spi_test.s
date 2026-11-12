
.section .text
.global _start

_start:
    # Direccion base SPI: 0x80010000
    lui x2, 0x80010

    # Inicializar DECISION en MANTENER
    sw x0, 8(x2)

wait_price:
    # Leer STATUS
    lw x3, 0(x2)

    # Comprobar bit NEW_PRICE
    andi x4, x3, 1
    beq x4, x0, wait_price

    # Leer precio recibido
    lw x5, 4(x2)

    # DECISION = MANTENER
    sw x0, 8(x2)

    # Esperar siguiente precio
    jal x0, wait_price

