package matter.onboardingpayload

import chip.ChipSdkStubException

data class OnboardingPayload(
    val version: Int = 0,
    val vendorId: Int = 0,
    val productId: Int = 0,
    val commissioningFlow: Int = 0,
    val discoveryCapabilities: MutableSet<DiscoveryCapability> = mutableSetOf(),
    val discriminator: Int = 0,
    val hasShortDiscriminator: Boolean = false,
    val setupPinCode: Long = 0L,
)

enum class DiscoveryCapability { SOFT_AP, BLE, ON_NETWORK, WIFI_PAF, NFC }

enum class CommissioningFlow(val value: Int) {
    STANDARD(0), USER_ACTION_REQUIRED(1), CUSTOM(2)
}

class OnboardingPayloadParser {
    fun parseQrCode(code: String): OnboardingPayload = throw ChipSdkStubException()
    fun parseManualPairingCode(code: String): OnboardingPayload = throw ChipSdkStubException()
}

class QRCodeOnboardingPayloadGenerator(private val payload: OnboardingPayload) {
    fun payloadBase38Representation(): String = throw ChipSdkStubException()
}

class ManualOnboardingPayloadGenerator(private val payload: OnboardingPayload) {
    fun payloadDecimalStringRepresentation(): String = throw ChipSdkStubException()
}
