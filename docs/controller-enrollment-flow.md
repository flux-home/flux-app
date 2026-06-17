# Controller enrollment flow (joining the app to a controller's fabric)

> **Superseded — phone fabric enrollment was removed.** Device control is now
> fully controller-proxied (`POST /command` / `/write` / `/read` + `GET /events`),
> authenticated by the CoAP/DTLS PSK — the phone never needs Matter fabric
> membership to control a device, so `FabricSyncService` and this flow were
> deleted. See `docs/controller-only-control.md` for the current model. Kept
> below for history.

Sequence of calls when the app joins (enrolls onto) a Flux Controller's Matter
fabric. Driven by `FabricSyncService.ensureInSync()`
(`lib/services/fabric_sync_service.dart`), called on app startup (`main.dart`)
and from the controller settings screen.

```mermaid
sequenceDiagram
    autonumber
    participant App as App UI<br/>(main.dart / SettingsScreen)
    participant FS as FabricSyncService
    participant AC as CHIP (app)<br/>(MatterChannel)
    participant Ctrl as Flux Controller<br/>(CoAP)

    App->>FS: ensureInSync()
    FS->>Ctrl: GET /info
    Ctrl-->>FS: ControllerInfo { fabric_id }

    alt fabric_id == 0
        FS-->>App: controllerNotReady
    end

    FS->>AC: getRawFabricId()
    AC-->>FS: app's raw fabric id (or null)

    alt app fabric id == controller fabric id
        FS-->>App: inSync ✅
    else not on controller's fabric
        Note over FS,Ctrl: ━━ ADOPT — enroll onto the controller's fabric ━━
        FS->>AC: generateOperationalCsr()
        AC->>AC: gen P-256 keypair<br/>build PKCS#10 CSR
        AC-->>FS: CSR (DER)

        alt CSR unavailable
            FS-->>App: adoptRequired
        end

        FS->>Ctrl: POST /fabric/enroll { csr }
        Ctrl->>Ctrl: sign CSR with controller's RCAC<br/>(NewICAX509Cert + NewNodeOperationalX509Cert)
        Ctrl-->>FS: FabricEnrollResponse<br/>{ root_ca, icac, noc, ipk, fabric_id, node_id }

        alt enroll failed
            FS-->>App: failed (error)
        end

        FS->>AC: importControllerFabric(rootCa, icac, noc, ipk, fabricId, nodeId)
        AC->>AC: persist adopted identity<br/>(AppFabricManager)
        AC-->>FS: ok

        alt import failed
            FS-->>App: failed
        end

        FS->>App: saveProvisionedFlag(hostname)
        AC->>AC: relaunch process (AppRestart)
        Note over AC: on restart → ChipClient.init()<br/>operationalKeyConfig = adopted identity<br/>CHIP now on the controller's fabric
        FS-->>App: adopted ✅
    end
```

## Notes

- The **controller owns the fabric** and acts as the CA. The app never seeds a
  fabric — it always enrolls (sends a CSR, the controller signs it) and
  imports the issued operational identity. See `multi-phone-fabric.md`.
- Membership is decided by comparing **raw** fabric ids (`getRawFabricId()`
  vs. `/info.fabric_id`), not the compressed fabric id.
- If the controller-issued chain fails to load, `ChipClient.init` clears the
  adopted identity and the app reverts to its local fabric — this path never
  bricks the app's CHIP identity.
