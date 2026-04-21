package com.fluxhome.app.chip

/**
 * Encodes a Matter commissioning window setup payload as an "MT:…" QR code string.
 *
 * Implements Matter Core Specification §5.1.4.1:
 *   1. Bit-pack the payload fields LSB-first into 11 bytes (88 bits total)
 *   2. Base38-encode the byte array — 3-byte chunks → 5 chars, 2-byte tail → 4 chars
 *   3. Prepend "MT:"
 *
 * Bit layout:
 *   Version             [0:2]    3 bits  (0)
 *   VendorID            [3:18]  16 bits
 *   ProductID          [19:34]  16 bits
 *   CustomFlow         [35:36]   2 bits  (0 = standard)
 *   DiscoveryCapab     [37:44]   8 bits  (0x04 = ON_NETWORK)
 *   Discriminator      [45:56]  12 bits
 *   Passcode           [57:83]  27 bits
 *   Padding            [84:87]   4 bits  (0)
 *   ──────────────────────────  ───────
 *   Total                       88 bits = 11 bytes
 *
 * Base38 alphabet: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-."
 */
object MatterQrCode {

    private const val BASE38_CHARS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-."

    /**
     * Generates the QR code payload string for an Enhanced Commissioning Mode
     * window (discovery capability = ON_NETWORK).
     *
     * @param discriminator  12-bit discriminator (0–4095)
     * @param setupPinCode   27-bit passcode (1–99999998, not in the invalid set)
     * @param vendorId       16-bit Vendor ID  (0 if unknown — still scannable)
     * @param productId      16-bit Product ID (0 if unknown — still scannable)
     */
    fun generate(
        discriminator: Int,
        setupPinCode: Long,
        vendorId: Int = 0,
        productId: Int = 0,
    ): String {
        val bytes = ByteArray(11) // 88 bits, zero-initialised
        var bitPos = 0

        fun writeBits(value: Long, numBits: Int) {
            for (i in 0 until numBits) {
                if ((value ushr i) and 1L == 1L) {
                    bytes[bitPos ushr 3] =
                        (bytes[bitPos ushr 3].toInt() or (1 shl (bitPos and 7))).toByte()
                }
                bitPos++
            }
        }

        writeBits(0L, 3)                      // version           (3 bits)
        writeBits(vendorId.toLong(), 16)      // VendorID         (16 bits)
        writeBits(productId.toLong(), 16)     // ProductID        (16 bits)
        writeBits(0L, 2)                      // CustomFlow        (2 bits)
        writeBits(0x04L, 8)                   // DiscoveryCapab    (8 bits, ON_NETWORK)
        writeBits(discriminator.toLong(), 12) // Discriminator    (12 bits)
        writeBits(setupPinCode, 27)           // Passcode         (27 bits)
        writeBits(0L, 4)                      // Padding           (4 bits)
        // Total: 88 bits = 11 bytes ✓

        return "MT:" + base38Encode(bytes)
    }

    // ── Base38 encoding ───────────────────────────────────────────────────────

    private fun base38Encode(data: ByteArray): String {
        val sb = StringBuilder()
        var i = 0
        while (i < data.size) {
            when (val remaining = data.size - i) {
                1 -> {
                    val v = data[i].toLong() and 0xFF
                    appendBase38Chars(sb, v, 2)
                    i += 1
                }
                2 -> {
                    val v = (data[i].toLong() and 0xFF) or
                            ((data[i + 1].toLong() and 0xFF) shl 8)
                    appendBase38Chars(sb, v, 4)
                    i += 2
                }
                else -> { // 3+ bytes remaining — take 3
                    val v = (data[i].toLong() and 0xFF) or
                            ((data[i + 1].toLong() and 0xFF) shl 8) or
                            ((data[i + 2].toLong() and 0xFF) shl 16)
                    appendBase38Chars(sb, v, 5)
                    i += 3
                }
            }
        }
        return sb.toString()
    }

    private fun appendBase38Chars(sb: StringBuilder, value: Long, count: Int) {
        var v = value
        repeat(count) {
            sb.append(BASE38_CHARS[(v % 38).toInt()])
            v /= 38
        }
    }
}
