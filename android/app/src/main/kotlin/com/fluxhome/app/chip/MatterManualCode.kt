package com.fluxhome.app.chip

/**
 * Generates an 11-digit Matter manual pairing code.
 *
 * Standard commissioning flow (no VID/PID), per Matter Core Specification §5.1.4.
 *
 * Bit layout (encoded into 10 decimal digits + 1 Verhoeff check digit):
 *
 *   DIGIT[1]    = (VID_PID_PRESENT=0 << 2) | DISCRIMINATOR[11:10]   (0..3)
 *   DIGIT[2..6] = (DISCRIMINATOR[9:8] << 14) | PASSCODE[13:0]       (0..65535)
 *   DIGIT[7..10]= PASSCODE[26:14]                                    (0..8191)
 *   DIGIT[11]   = Verhoeff check digit over DIGIT[1..10]
 *
 * The check digit uses the Verhoeff algorithm as specified in §5.1.4.1.5.
 */
object MatterManualCode {

    fun generate(discriminator: Int, setupPINCode: Long): String {
        val chunk1 = (discriminator shr 10) and 0x3
        val chunk2 = (((discriminator shr 8) and 0x3).toLong() shl 14) or (setupPINCode and 0x3FFF)
        val chunk3 = setupPINCode shr 14

        val digits = "%01d%05d%04d".format(chunk1, chunk2, chunk3)
        val check  = verhoeffCheckDigit(digits)
        return digits + check.toString()
    }

    // ── Verhoeff check digit (Matter spec §5.1.4.1.5) ────────────────────────
    //
    // Same tables and iteration order as the CHIP SDK:
    //   src/setup_payload/ManualSetupPayloadGenerator.cpp
    //
    // Iterate the input string right-to-left.  The permutation row for position
    // i (1-indexed from the right) is P[(i) % 8].

    private val D = arrayOf(
        intArrayOf(0,1,2,3,4,5,6,7,8,9),
        intArrayOf(1,2,3,4,0,6,7,8,9,5),
        intArrayOf(2,3,4,0,1,7,8,9,5,6),
        intArrayOf(3,4,0,1,2,8,9,5,6,7),
        intArrayOf(4,0,1,2,3,9,5,6,7,8),
        intArrayOf(5,9,8,7,6,0,4,3,2,1),
        intArrayOf(6,5,9,8,7,1,0,4,3,2),
        intArrayOf(7,6,5,9,8,2,1,0,4,3),
        intArrayOf(8,7,6,5,9,3,2,1,0,4),
        intArrayOf(9,8,7,6,5,4,3,2,1,0),
    )

    private val P = arrayOf(
        intArrayOf(0,1,2,3,4,5,6,7,8,9),
        intArrayOf(1,5,7,6,2,8,3,0,9,4),
        intArrayOf(5,8,0,3,7,9,6,1,4,2),
        intArrayOf(8,9,1,6,0,4,3,5,2,7),
        intArrayOf(9,4,5,3,1,2,6,8,7,0),
        intArrayOf(4,2,8,6,5,7,3,9,0,1),
        intArrayOf(2,7,9,3,8,0,6,4,1,5),
        intArrayOf(7,0,4,6,9,1,3,2,5,8),
    )

    private val INV = intArrayOf(0,4,3,2,1,9,8,7,6,5)

    private fun verhoeffCheckDigit(s: String): Int {
        var c = 0
        val n = s.length
        // Iterate right-to-left; position index is 1-based from the right.
        for (i in n downTo 1) {
            val v = s[i - 1] - '0'
            c = D[c][P[((n - i) + 1) % 8][v]]
        }
        return INV[c]
    }
}
