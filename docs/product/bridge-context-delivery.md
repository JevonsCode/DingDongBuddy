# Bridge context delivery

DingDong avoids returning unchanged resource bodies when the caller explicitly
acknowledges that its baseline is still in context. It cannot remove text already
stored in a third-party client's conversation, control native tool enumeration,
or infer model-visible context from a session ID.

## Client protocol

1. Call Bridge with `acceptDelta: true` and `expand: "prompts"` (the POST/MCP
   default). On first load, send no `knownHash`. A full `active` response replaces
   the previous catalog and active Prompt set; retain its hash.
2. On subsequent requests send that hash only while the complete merged snapshot
   remains in context. `unchanged: true` retains it without new bodies.
3. A `mode: "delta"` response must name the retained `baseHash`. For each category
   apply `delta.upsert` by resource ID, remove `delta.remove` IDs, and arrange IDs
   in `delta.order` when supplied. Omitted categories are unchanged. Empty order
   means no active resources in that category. Advance to the new hash only after
   merging successfully. A removed Skill is no longer eligible for application.
4. If any baseline is missing or context was compacted without retaining the
   complete snapshot, omit `knownHash` and request a full snapshot. Do not rely on
   the fact that the same session received something earlier. Lost replies and
   retrying an older acknowledged baseline are safe: the delta is computed from
   the hash actually provided, not from the most recently sent response.
5. For matching Skills, load the body once. Only a version returned by a full
   load whose body remains in context may be sent as `knownVersion`. Catalog
   discovery is not a full load. An unchanged load response omits body/manifest;
   changed content returns a complete replacement. Omit the version to recover
   lost content. Reuse the versioned body's references; package-file reads remain
   explicit on-demand reads, not automatic full-package injection.

Legacy callers receive full `active` on changes unless they opt into deltas.
`expand: "all"` remains a full diagnostic response. Diagnostic, metadata-only
and normal Prompt expansion have separate acknowledgement scopes.

## Boundaries and cost

The server retains only bounded ID/version manifests, not conversation bodies.
Cache eviction or restart can require a full response, and is safe. Usage
counters and timestamps do not invalidate Skill versions. Managed package digest
and SKILL.md content do; changes to external files outside DingDong's package
installation/update flow must be re-imported to update the managed digest.

Scope and activation rules filter resources locally. Snapshot and Skill-version
deduplication make no AI requests. Separately, AI+ offers automatic resource
selection, off by default: when enabled, a bounded model request can narrow the
eligible Skill, task-matched Prompt and MCP catalog before Bridge returns it. Mandatory
and explicitly named eligible resources are preserved; invalid selections fall
back to local rules. Cached decisions avoid repeated selection requests. The
calling Agent still chooses and loads Skill bodies. See [AI+](ai-companion.md) for
the data sent, cache boundaries and separate internal Token accounting.

Reduced response bytes are not a measured token or billing saving. Provider
cache behavior and retained conversation history are separate. Verify both
resource correctness and measured end-to-end use before claiming an advantage
over a native client.
