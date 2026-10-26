# Reminders and recent Agents

Available in DingDong 1.10.0.

A saved reminder defines its color, sound, delivery settings and a short condition
hint. The Agent decides when the condition applies; DingDong does not monitor
an Agent's work for these conditions.

## A reminder for the next use only

When a user asks for a particular color or sound for one occasion, first reuse a
suitable saved reminder if one fits. Otherwise create a temporary reminder with
a unique ID using `dingdong_upsert_reminder`:

```json
{
  "id": "review-once",
  "name": "Review request",
  "description": "Ask for the remaining review input",
  "temporary": true,
  "color": "green",
  "sound": "dingDeep"
}
```

Then call `dingdong_notify` with `reminderId: "review-once"` when the user is
needed. Use `dingdong_list_reminders` to inspect pending reminders and sounds.
Custom sounds must be imported before selecting their returned path.

Temporary reminders appear as colored circles with a white dashed border. They
are consumed by one eligible notification and removed from the saved list;
notifications filtered by the voice or subagent preference leave them pending.
Concurrent notifications cannot claim the same temporary reminder twice.

Recent Agent records and unread tray indicators retain the captured reminder
definition after it is consumed or edited. Hover over the dot to inspect its
name, condition and sound. Older records without a saved definition use a
neutral dot rather than guessing the original color.

## Recent Agents

Both the popup and resource manager load 21 records per page by default. Edit
Page size and press Enter or leave the field to save it. Scrolling near the end
loads another local page; the list builds visible rows on demand. Pin an item
to keep it above other records, or use Back to top after scrolling.

Sources are selected from those present in local history. Date filters are
Yesterday, Last 3 days, This week, This month, Last month, Last 3 months, This
year and Custom range. Recent Agents also supports All time. Weeks begin on
Monday; Last 3 days includes today; Last 3 months begins on the first day of the
month two months ago. Boundaries use local calendar dates and include the whole
end date. Token usage uses the same date filters and desktop range calendar.

A custom range can be selected across the two calendar panels or entered as
`yyyy-MM-dd`. Cancel leaves the applied range unchanged. The notification count
appears to the left of its reminder dot in both recent Agent views.
