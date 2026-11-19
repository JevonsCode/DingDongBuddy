# Private-network computer pairing

One computer generates a six-digit code. The other selects it from nearby
computers and enters that code. As of 1.11.12, the second computer can also enter
a private IPv4 address to find a peer on a reachable routed subnet. Paired
computers reconnect automatically. Phone QR pairing retains its own protocol.

## Implementation

- `LanComputerLink` owns UDP discovery and the local TCP listener in the main
  Flutter engine. Auxiliary windows receive presentation snapshots and invoke the
  same owner through the existing window bridge.
- Discovery uses IPv4 multicast `239.255.68.68:45893`, TTL 1. Announcements contain
  protocol version, device ID/name, TCP port and pairing availability. They never
  contain the code, pair key, or room credentials.
- Automatic discovery and its TCP sessions use on-link prefixes of physical
  Windows adapters or macOS Ethernet/Wi-Fi interfaces. They use TTL 1 and an
  explicit local source address. IPv6-only LANs and other desktop platforms are
  currently unsupported.
- An explicitly entered RFC 1918 address outside the physical subnet is queried
  through TCP on port 45893. The receiving computer answers lookup only while
  its pairing code is active. After SRP authentication, each computer saves the
  authenticated peer IP for reconnect. Previous pairings keep their existing
  scope. Routed sessions use the operating system route and retain the size
  limit for transfers outside a verified physical LAN. There is no public relay
  for computer-to-computer sessions.
- Discovery keeps multiple addresses per identity. Active connections retain their
  address; reconnect tries alternatives when one adapter cannot accept TCP.
- Pairing uses SRP-6a, the fixed RFC 5054 2048-bit group, SHA-256, random 256-bit
  exponents and AES-256-GCM proofs. A six-digit code is not used as a content key
  or sent in plaintext. It expires after five minutes, permits five attempts,
  and is consumed before a successful pair is persisted. Both endpoint identities
  are included in the encrypted authentication exchange.
- Successful pairing creates a separate random 256-bit pair key. Existing device
  storage retains that key and device identity; IP addresses are rediscovered.
  Reconnect authenticates fresh challenges in both directions. Content frames bind
  direction, connection nonce and sequence number to reject replay/reflection.
- Disconnected sessions retry every two seconds, including failed service startup.
  Adapter inventory refreshes every 30 seconds; discovery expires after eight
  seconds. Explicit disconnect/delete disables reconnection through existing
  controller lifecycle handling.
- All persisted computer links use this transport, including older records that
  contain a relay URL. Changing local or remote transport preferences cannot enable
  a computer relay. Phone QR sessions reject computer hello messages.

## Verification

Use Flutter 3.44.6 (the repository's CI version):

```text
flutter analyze
flutter test test/features/device_link test/contract/desktop_component_contract_test.dart
flutter test --exclude-tags golden
flutter build windows --release --no-pub
```

Tests cover short-code authentication, an independently calculated SHA-256 SRP
vector, malformed public values, code expiration/attempt limit/one-time use,
encrypted socket traffic, oversized frames, restart reconnection, manual close,
unreachable and multiple adapters, startup retry, private subnet boundaries,
controller policy, existing clipboard/file flows and the pairing UI.

Socket tests run two services locally, with an explicitly test-only loopback
constructor. This is not a two-physical-computer Wi-Fi/firewall acceptance test.
Windows/macOS physical-device acceptance must check same-LAN discovery, permission
prompts, pairing, bidirectional clipboard/file delivery, sleep/restart/IP change,
and disconnection after leaving the LAN. No OS firewall or developer-mode settings
are changed by this implementation.

Visual goldens are authoritative on macOS arm64 in the existing CI. Windows CI
intentionally excludes that tag. Local baseline comparison reproduces existing
platform-specific golden differences; do not replace unrelated baselines using
Windows-rendered images.

Protocol reference: https://www.rfc-editor.org/rfc/rfc5054
