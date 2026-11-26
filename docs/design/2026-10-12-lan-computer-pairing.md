# Private-network computer pairing

One computer generates a six-digit invitation. The other can enter that code
directly, select a nearby computer, or look up a private IPv4 address. The
discovery service helps the two desktops exchange addresses. Clipboard,
files, and pairing credentials travel over their authenticated TCP connection.
Phone QR pairing retains its separate protocol.

## Implementation

- `LanComputerLink` owns UDP discovery and the local TCP listener in the main
  Flutter engine. Auxiliary windows receive presentation snapshots and invoke the
  same owner through the existing window bridge.
- Discovery uses IPv4 multicast `239.255.68.68:45893`, TTL 1. Announcements contain
  protocol version, device ID/name, TCP port and pairing availability. They never
  contain the code, pair key, or room credentials.
- Directed UDP discovery uses a separate socket for each destination IP. Send
  failures affect only that address. The service recreates a stopped discovery
  listener and rejoins multicast while retaining TCP sessions and pairing state.
- On macOS a physical adapter with a self-assigned `169.254/16` address also
  announces to `169.254.255.255:45893` from a socket bound to that interface.
  Peers reply to the sender's UDP port with the existing discovery protocol.
  This keeps nearby discovery working on direct links that drop multicast.
- Automatic discovery and its TCP sessions use on-link prefixes of physical
  Windows adapters or macOS Ethernet/Wi-Fi interfaces. They use TTL 1 and an
  explicit local source address. IPv6-only LANs and other desktop platforms are
  currently unsupported.
- Code-only discovery uses a five-minute WebSocket reservation. Two public digits
  locate a slot. The other four digits remain secret. A discovery-specific SRP
  exchange proves knowledge of the code before the host discloses its encrypted
  identity and addresses. The host enforces a shared five-attempt limit. A
  successful discovery proof allows the subsequent direct pairing handshake.
  A busy slot triggers a new code. Offline, existing nearby and IP lookup are
  available.
- Already paired devices derive a private discovery slot and a separate
  encryption key from their saved pair secret. Fresh challenges, device IDs
  and directions bind address responses to this exchange. This also applies to
  pairs saved before assisted discovery was introduced. Manually disconnecting
  or forgetting a device closes its discovery channel.
- Directed lookup and authenticated reconnect use TCP on port 45893. A new
  private address received through paired discovery can replace a stale route.
  Each direct connection must prove the existing pair key. Routed connections
  keep the existing size policy for transfers outside a verified physical LAN.
  The computer protocol has no relay fallback for user data.
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
