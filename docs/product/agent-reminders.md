# Agent reminders

In **Settings → Notifications**, **Agent completion** and **Needs your input**
are independent. Turn completion off and needs-input on to be interrupted only
when the Agent requests your help. Each type has its own sound, tray style and
color. Existing completion color preferences are preserved.

On macOS the menu-bar badge uses a check for completion and a bell for attention.
On Windows the notification-area marker uses a check or exclamation mark. Hover
text identifies the reminder type and unread count. An unread needs-input event
takes priority over subsequent completion events until acknowledged.

**Static marker** keeps a steady badge. **Soft pulse** alternates two close color
shades; it does not hide the icon. System reduced-animation preferences suppress
the pulse. Completion defaults to static; needs-input defaults to soft pulse and
amber. Color presets are reinforced by different glyphs, so color is not the only
way to tell the types apart. Gradient styling is not offered for the small tray
marker.

Tell the Agent, for example: “When you need a decision or action from me, call
DingDong to remind me.” The Agent must explicitly send an `attention` event using
the configured integration. Turning this setting on does not make DingDong read
every conversation, schedule independent AI work or infer that an Agent is
blocked. Completion hooks and explicit attention calls remain distinct sources.

These styles apply to DingDong's tray/menu-bar surface. Operating-system banners
and phone notifications keep their own platform presentation and delivery rules.
