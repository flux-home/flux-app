package chip.devicecontroller

/**
 * Mirrors the real chip.devicecontroller.ClusterIDMapping generated class.
 * Only the clusters used by ClusterClient are stubbed here.
 */
object ClusterIDMapping {

    object OnOff {
        const val ID: Long = 0x00000006L

        object Attribute {
            object OnOff { const val id: Long = 0x00000000L }
        }

        object Command {
            object Off    { const val id: Long = 0x00000000L }
            object On     { const val id: Long = 0x00000001L }
            object Toggle { const val id: Long = 0x00000002L }
        }
    }

    object LevelControl {
        const val ID: Long = 0x00000008L

        object Attribute {
            object CurrentLevel { const val id: Long = 0x00000000L }
        }

        object Command {
            object MoveToLevel  { const val id: Long = 0x00000000L }
            object StepWithOnOff { const val id: Long = 0x00000006L }
        }

        object MoveToLevelCommandField {
            object Level           { const val id: Int = 0 }
            object TransitionTime  { const val id: Int = 1 }
            object OptionsMask     { const val id: Int = 3 }
            object OptionsOverride { const val id: Int = 4 }
        }

        object StepWithOnOffCommandField {
            object StepMode        { const val id: Int = 0 }  // 0 = Up, 1 = Down
            object StepSize        { const val id: Int = 1 }  // 0–254
            object TransitionTime  { const val id: Int = 2 }
            object OptionsMask     { const val id: Int = 3 }
            object OptionsOverride { const val id: Int = 4 }
        }
    }

    object BasicInformation {
        const val ID: Long = 0x00000028L

        object Attribute {
            object VendorName            { const val id: Long = 0x00000001L }
            object VendorID              { const val id: Long = 0x00000002L }
            object ProductName           { const val id: Long = 0x00000003L }
            object ProductID             { const val id: Long = 0x00000004L }
            object NodeLabel             { const val id: Long = 0x00000005L }
            object HardwareVersionString { const val id: Long = 0x00000008L }
            object SoftwareVersionString { const val id: Long = 0x0000000AL }
            object ManufacturingDate     { const val id: Long = 0x0000000BL }
            object PartNumber            { const val id: Long = 0x0000000CL }
            object ProductURL            { const val id: Long = 0x0000000DL }
            object ProductLabel          { const val id: Long = 0x0000000EL }  // Note: 0x0E overlaps SerialNumber in older specs; see below
            object SerialNumber          { const val id: Long = 0x0000000FL }
            object UniqueID              { const val id: Long = 0x00000012L }
        }
    }

    object Descriptor {
        const val ID: Long = 0x0000001DL

        object Attribute {
            object DeviceTypeList { const val id: Long = 0x00000000L }
        }
    }

    object Thermostat {
        const val ID: Long = 0x00000201L

        object Attribute {
            object LocalTemperature            { const val id: Long = 0x00000000L }
            object AbsMinHeatSetpointLimit     { const val id: Long = 0x00000003L }
            object AbsMaxHeatSetpointLimit     { const val id: Long = 0x00000004L }
            object AbsMinCoolSetpointLimit     { const val id: Long = 0x00000005L }
            object AbsMaxCoolSetpointLimit     { const val id: Long = 0x00000006L }
            object OccupiedCoolingSetpoint     { const val id: Long = 0x00000011L }
            object OccupiedHeatingSetpoint     { const val id: Long = 0x00000012L }
            object MinHeatSetpointLimit        { const val id: Long = 0x00000015L }
            object MaxHeatSetpointLimit        { const val id: Long = 0x00000016L }
            object MinCoolSetpointLimit        { const val id: Long = 0x00000017L }
            object MaxCoolSetpointLimit        { const val id: Long = 0x00000018L }
            object SystemMode                  { const val id: Long = 0x0000001CL }
            object ControlSequenceOfOperation  { const val id: Long = 0x0000001BL }
        }

        object Command {
            object SetpointRaiseLower { const val id: Long = 0x00000000L }
        }
    }

    object RelativeHumidityMeasurement {
        const val ID: Long = 0x00000405L

        object Attribute {
            object MeasuredValue    { const val id: Long = 0x00000000L }
            object MinMeasuredValue { const val id: Long = 0x00000001L }
            object MaxMeasuredValue { const val id: Long = 0x00000002L }
        }
    }

    object PowerSource {
        const val ID: Long = 0x0000002FL

        object Attribute {
            object BatVoltage          { const val id: Long = 0x0000000BL }
            object BatPercentRemaining { const val id: Long = 0x0000000CL }
            object BatChargeLevel      { const val id: Long = 0x0000000EL }
        }
    }

    object ThreadNetworkDiagnostics {
        const val ID: Long = 0x00000035L

        object Attribute {
            object Channel            { const val id: Long = 0x00000000L }
            object RoutingRole        { const val id: Long = 0x00000001L }
            object NetworkName        { const val id: Long = 0x00000002L }
            object PanId              { const val id: Long = 0x00000003L }
            object ExtendedPanId      { const val id: Long = 0x00000004L }
            object MeshLocalPrefix    { const val id: Long = 0x00000005L }
            object NeighborTable      { const val id: Long = 0x00000007L }
            object RouteTable         { const val id: Long = 0x00000008L }
            object PartitionId        { const val id: Long = 0x00000009L }
            object Weighting          { const val id: Long = 0x0000000AL }
            object LeaderRouterId     { const val id: Long = 0x0000000DL }
        }
    }

    object TemperatureMeasurement {
        const val ID: Long = 0x00000402L
        object Attribute {
            object MeasuredValue { const val id: Long = 0x00000000L }
        }
    }

    object OccupancySensing {
        const val ID: Long = 0x00000406L
        object Attribute {
            object Occupancy { const val id: Long = 0x00000000L }
        }
    }

    object BooleanState {
        const val ID: Long = 0x00000045L
        object Attribute {
            object StateValue { const val id: Long = 0x00000000L }
        }
    }

    object AirQuality {
        const val ID: Long = 0x0000005BL
        object Attribute {
            // AirQualityEnum: 0=Unknown 1=Good 2=Fair 3=Moderate 4=Poor 5=VeryPoor 6=ExtremelyPoor
            object AirQuality { const val id: Long = 0x00000000L }
        }
    }

    object WindowCovering {
        const val ID: Long = 0x00000102L
        object Attribute {
            object CurrentPositionLiftPercent100ths { const val id: Long = 0x0000000EL }
            object OperationalStatus               { const val id: Long = 0x0000000AL }
        }
        object Command {
            object UpOrOpen              { const val id: Long = 0x00000000L }
            object DownOrClose           { const val id: Long = 0x00000001L }
            object StopMotion            { const val id: Long = 0x00000002L }
            object GoToLiftPercentage    { const val id: Long = 0x00000005L }
        }
        object GoToLiftPercentageCommandField {
            object LiftPercent100thsValue { const val id: Int = 0 }
        }
    }

    object FanControl {
        const val ID: Long = 0x00000202L
        object Attribute {
            object FanMode        { const val id: Long = 0x00000000L }
            object PercentSetting { const val id: Long = 0x00000002L }
            object PercentCurrent { const val id: Long = 0x00000003L }
        }
    }

    object ColorControl {
        const val ID: Long = 0x00000300L
        object Attribute {
            object ColorTemperatureMireds      { const val id: Long = 0x00000007L }
            object ColorTempPhysicalMinMireds  { const val id: Long = 0x0000400BL }
            object ColorTempPhysicalMaxMireds  { const val id: Long = 0x0000400CL }
        }
        object Command {
            object MoveToColorTemperature { const val id: Long = 0x0000000AL }
        }
        object MoveToColorTemperatureCommandField {
            object ColorTemperatureMireds { const val id: Int = 0 }
            object TransitionTime         { const val id: Int = 1 }
            object OptionsMask            { const val id: Int = 2 }
            object OptionsOverride        { const val id: Int = 3 }
        }
    }

    object SmokeCoAlarm {
        const val ID: Long = 0x0000005CL
        object Attribute {
            object SmokeState    { const val id: Long = 0x00000001L }
            object COState       { const val id: Long = 0x00000002L }
            object BatteryAlert  { const val id: Long = 0x00000003L }
        }
    }

    // Concentration measurement clusters — MeasuredValue (0x0000) is a nullable float.
    object CarbonMonoxideConcentrationMeasurement {
        const val ID: Long = 0x0000040CL
        object Attribute {
            object MeasuredValue { const val id: Long = 0x00000000L }
        }
    }

    object CarbonDioxideConcentrationMeasurement {
        const val ID: Long = 0x0000040DL
        object Attribute {
            object MeasuredValue { const val id: Long = 0x00000000L }
        }
    }

    object Pm25ConcentrationMeasurement {
        const val ID: Long = 0x0000042AL
        object Attribute {
            object MeasuredValue { const val id: Long = 0x00000000L }
        }
    }

    object Switch {
        const val ID: Long = 0x0000003BL
        object Attribute {
            object NumberOfPositions { const val id: Long = 0x00000000L }
            object CurrentPosition   { const val id: Long = 0x00000001L }
            object MultiPressMax     { const val id: Long = 0x00000002L }
        }
        object Event {
            object SwitchLatched      { const val id: Long = 0x00000000L }
            object InitialPress       { const val id: Long = 0x00000001L }
            object LongPress          { const val id: Long = 0x00000002L }
            object ShortRelease       { const val id: Long = 0x00000003L }
            object LongRelease        { const val id: Long = 0x00000004L }
            object MultiPressOngoing  { const val id: Long = 0x00000005L }
            object MultiPressComplete { const val id: Long = 0x00000006L }
        }
    }

    // Matter 1.3 – Electrical Power Measurement cluster (AC and DC).
    // Attribute units: Voltage = mV, ActiveCurrent = mA, ActivePower = mW,
    // RMSVoltage = mV, RMSCurrent = mA, RMSPower = mW (all nullable int64s).
    object ElectricalPowerMeasurement {
        const val ID: Long = 0x00000090L

        object Attribute {
            object Voltage        { const val id: Long = 0x00000002L }
            object ActiveCurrent  { const val id: Long = 0x00000003L }
            object ActivePower    { const val id: Long = 0x00000006L }
            object ApparentPower  { const val id: Long = 0x00000008L }
            object RMSVoltage     { const val id: Long = 0x00000009L }
            object RMSCurrent     { const val id: Long = 0x0000000AL }
            object RMSPower       { const val id: Long = 0x0000000BL }
        }
    }

    // Matter 1.3 – Electrical Energy Measurement cluster.
    // CumulativeEnergyImported / Exported are nullable EnergyMeasurementStructs
    // whose `energy` field carries the value in milliwatt-hours (mWh).
    object ElectricalEnergyMeasurement {
        const val ID: Long = 0x00000091L

        object Attribute {
            object Accuracy                  { const val id: Long = 0x00000000L }
            object CumulativeEnergyImported  { const val id: Long = 0x00000001L }
            object CumulativeEnergyExported  { const val id: Long = 0x00000002L }
            object PeriodicEnergyImported    { const val id: Long = 0x00000003L }
            object PeriodicEnergyExported    { const val id: Long = 0x00000004L }
        }

        object Event {
            object CumulativeEnergyMeasured { const val id: Long = 0x00000000L }
            object PeriodicEnergyMeasured   { const val id: Long = 0x00000001L }
        }
    }

    object Identify {
        const val ID: Long = 0x00000003L
        object Command {
            // Identify command: field 0x00 = IdentifyTime (uint16, seconds)
            object Identify { const val id: Long = 0x00000000L }
        }
    }
}
