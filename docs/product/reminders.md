# Reminders and recent Agents

Available in DingDong 1.10.2.

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

Temporary reminders use a dashed marker in reminder settings. They
are consumed by one eligible notification and removed from the saved list;
notifications filtered by the voice or subagent preference leave them pending.
Concurrent notifications cannot claim the same temporary reminder twice.

Recent Agent records and unread tray indicators retain the captured reminder
definition after it is consumed or edited. Hover over the leading Agent icon to
inspect its name, condition and sound. Quick-panel cards use the reminder color
for their border and icon, with a dashed border for temporary reminders. Resource
Manager uses the color for the leading icon and title. Older records without a
saved definition keep the neutral styling.

## Recent Agents

The quick panel shows 21 records by default. Change **Settings → Recent Agents →
Quick panel Agent count** to choose its displayed quantity. This setting applies
to the quick panel. Resource Manager browses recent Agent history separately,
loading another local page near the end and building rows on demand.

In Resource Manager, sources are selected from those present in local history. Date filters are
Yesterday, Last 3 days, This week, This month, Last month, Last 3 months, This
year and Custom range. Recent Agents also supports All time. Weeks begin on
Monday; Last 3 days includes today; Last 3 months begins on the first day of the
month two months ago. Boundaries use local calendar dates and include the whole
end date. Token usage uses the same date filters and desktop range calendar.

A custom range can be selected across the two calendar panels or entered as
`yyyy-MM-dd`. Cancel leaves the applied range unchanged. Notification counts
precede the timestamp; earlier local dates show `YYYYMMDD` above the time.

快捷面板默认显示最近 21 条，在“设置 → 最近 Agent → 快捷面板显示条数”修改。
资源管理中的来源和时间筛选独立使用；两处最近 Agent 均不显示置顶按钮或颜色圆点。
悬停前面的图标可查看当时的提醒定义，临时提醒在快捷面板中使用同色虚线边框。
