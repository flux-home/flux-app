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
            object MoveToLevel { const val id: Long = 0x00000000L }
        }

        object MoveToLevelCommandField {
            object Level          { const val id: Int = 0 }
            object TransitionTime { const val id: Int = 1 }
            object OptionsMask    { const val id: Int = 3 }
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
            object OccupiedHeatingSetpoint     { const val id: Long = 0x00000012L }
            object OccupiedCoolingSetpoint     { const val id: Long = 0x00000011L }
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

    object Identify {
        const val ID: Long = 0x00000003L
        object Command {
            // Identify command: field 0x00 = IdentifyTime (uint16, seconds)
            object Identify { const val id: Long = 0x00000000L }
        }
        object CommandField {
            object IdentifyTime { const val id: Int = 0x00 }
        }
    }
}
