// This file is intentionally minimal — it re-exports [FluxControllerEndpoint]
// from [FluxCoapService] so that discovery code in [FluxControllerDiscovery]
// continues to work without modification.
//
// The HTTP methods that used to live here (getInfo, getThreadDataset, etc.)
// have moved to [FluxCoapService].  Any `import flux_controller_service.dart`
// that only used the endpoint type can stay as-is.

export 'package:matter_home/services/flux_coap_service.dart'
    show FluxControllerEndpoint, FluxCoapService, ControllerInfo, Device, DeviceList;
