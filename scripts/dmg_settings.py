from pathlib import Path


app_path = defines["app_path"]
background_path = defines["background_path"]
guide_path = defines["guide_path"]
icon_path = defines["icon_path"]

app_name = Path(app_path).name
guide_name = Path(guide_path).name

files = [app_path, guide_path]
symlinks = {"Applications": "/Applications"}

icon = icon_path
background = background_path
icon_locations = {
    app_name: (185, 282),
    "Applications": (575, 282),
    guide_name: (666, 395),
}
hide_extensions = [app_name, guide_name]

window_rect = ((120, 120), (760, 540))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False

arrange_by = None
grid_offset = (0, 0)
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 104

format = "UDRW"
filesystem = "APFS"
