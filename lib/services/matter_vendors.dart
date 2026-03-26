/// Connectivity Standards Alliance (CSA) — Matter Vendor ID registry.
///
/// Source: CSA public vendor database / connectedhomeip SDK.
/// VIDs 0xFFF1–0xFFF4 are reserved for test / development use.
const kMatterVendors = <int, String>{
  // ── Test / Development ───────────────────────────────────────────────────
  0xFFF1: 'Test Vendor 1',
  0xFFF2: 'Test Vendor 2',
  0xFFF3: 'Test Vendor 3',
  0xFFF4: 'Test Vendor 4',

  // ── A ────────────────────────────────────────────────────────────────────
  0x171A: 'Acer',
  0x1271: 'Acuity Brands',
  0x1615: 'Adeo',
  0x1228: 'Amazon',
  0x1398: 'Amazon Lab126',
  0x1002: 'AMD',
  0x139A: 'A. O. Smith',
  0x15BE: 'ASSA ABLOY',

  // ── B ────────────────────────────────────────────────────────────────────
  0x13A6: 'Belkin International',
  0x130A: 'Bosch',
  0x14D3: 'Bosch Thermotechnology',
  0x1703: 'Robert Bosch',
  0x1378: 'Bose',
  0x1244: 'BUNN-O-Matic',

  // ── C ────────────────────────────────────────────────────────────────────
  0x145F: 'Carrier Global',
  0x120F: 'Centralite',
  0x1010: 'Computime',

  // ── D ────────────────────────────────────────────────────────────────────
  0x15E0: 'Daikin',
  0x12E7: 'Danfoss',
  0x1028: 'Dell',
  0x16CE: 'dormakaba',

  // ── E ────────────────────────────────────────────────────────────────────
  0x14FA: 'Ecobee',
  0x1604: 'Echelon',
  0x11FA: 'Ecolink',
  0x12D6: 'Electrolux',
  0x136E: 'ELKO Group',
  0x135B: 'EM Microelectronic',
  0x1712: 'Enbrighten',
  0x1321: 'Espressif',
  0x1387: 'Eve Systems',

  // ── F ────────────────────────────────────────────────────────────────────
  0x1621: 'Feit Electric',
  0x1642: 'Fibaro',

  // ── G ────────────────────────────────────────────────────────────────────
  0x162C: 'GE Appliances',
  0x137B: 'Gira',
  0x1049: 'Google',

  // ── H ────────────────────────────────────────────────────────────────────
  0x1478: 'Haier',
  0x1773: 'HELLA',
  0x13B9: 'Honeywell',
  0x1706: 'HomeSeer',
  0x163D: 'Hunter Douglas',

  // ── I ────────────────────────────────────────────────────────────────────
  0x143A: 'Legrand',
  0x16A7: 'iDevices',
  0x100B: 'Infineon',
  0x104D: 'Intel',
  0x170C: 'Inovelli',

  // ── J ────────────────────────────────────────────────────────────────────
  0x118A: 'Jabil',
  0x137A: 'JUNG',

  // ── K ────────────────────────────────────────────────────────────────────
  0x166B: 'Kasa Smart (TP-Link)',
  0x167C: 'Kwikset',

  // ── L ────────────────────────────────────────────────────────────────────
  0x155B: 'LEDVANCE',
  0x117C: 'IKEA',
  0x1618: 'Leviton',
  0x160F: 'LIFX',
  0x1659: 'LDS',
  0x110C: 'LG Electronics',
  0x1428: 'LG Electronics (alt)',
  0x1189: 'Aqara',
  0x1555: 'Lutron',

  // ── M ────────────────────────────────────────────────────────────────────
  0x1407: 'Midea',
  0x13D3: 'Microchip Technology',
  0x121B: 'Murata Manufacturing',
  0x15A7: 'Mysa Smart Technologies',

  // ── N ────────────────────────────────────────────────────────────────────
  0x153E: 'Nanoleaf',
  0x131B: 'Nordic Semiconductor',
  0x1135: 'NXP Semiconductors',

  // ── P ────────────────────────────────────────────────────────────────────
  0x1534: 'Panasonic',

  // ── Q ────────────────────────────────────────────────────────────────────
  0x10CB: 'Qualcomm',

  // ── R ────────────────────────────────────────────────────────────────────
  0x16D5: 'Ring',
  0x146F: 'Resideo',
  0x13C9: 'Resideo (Honeywell Home)',

  // ── S ────────────────────────────────────────────────────────────────────
  0x1101: 'Samsung',
  0x1527: 'SmartThings',
  0x1686: 'Schlage',
  0x134A: 'Schneider Electric',
  0x16BE: 'Sense',
  0x1737: 'Shelly',
  0x15F7: 'Siemens',
  0x100F: 'Signify (Philips Hue)',
  0x1037: 'Silicon Laboratories',
  0x10C4: 'Silicon Laboratories (alt)',
  0x1481: 'Somfy',
  0x14F1: 'Sony',
  0x1291: 'STMicroelectronics',

  // ── T ────────────────────────────────────────────────────────────────────
  0x134E: 'tado',
  0x14E7: 'Texas Instruments',
  0x1275: 'Third Reality',
  0x1108: 'Tuya',

  // ── U ────────────────────────────────────────────────────────────────────
  0x15C6: 'UTC Fire & Security',

  // ── V ────────────────────────────────────────────────────────────────────
  0x164E: 'Velux',
  0x13CF: 'Vertiv',

  // ── W ────────────────────────────────────────────────────────────────────
  0x15EF: 'Whirlpool',

  // ── X ────────────────────────────────────────────────────────────────────
  0x158D: 'Xiaomi',

  // ── Y ────────────────────────────────────────────────────────────────────
  0x1498: 'Yeelight',
  0x16C2: 'Yale',
};
