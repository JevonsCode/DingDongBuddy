# Clipboard history · 剪贴板历史

Available in DingDong 1.10.2.

The quick panel and Resource Manager load clipboard history in pages of 50.
Scrolling near the end loads the next page; virtual rows keep off-screen items
from being built together. The manager shows `50+`, `100+` and so on while more
matching history is available, then shows the loaded total at the end.

Search, content-type filters, source filters and copy-count sorting apply to the
complete saved history. A matching record can appear even if its original page
has not been loaded. Changing a query or filter starts the result list from the
first page; clearing search restores the unfiltered first page. Search retains
the same case-insensitive text matching, including Unicode and literal `%` or `_`.

Keyboard navigation can load the next page. Reload refreshes the current query,
and deleting a history item fills the visible page from the remaining matches.
**Select loaded items** selects the currently loaded results for batch actions.

快捷面板与资源管理中的“历史”均按每批 50 条读取，接近列表底部时继续加载下一批，
屏幕外的行按需构建。有更多匹配记录时，资源管理显示 `50+`、`100+` 等数量。

搜索、内容类型、来源筛选和复制次数排序覆盖完整的本机历史，包括尚未加载的记录。
修改搜索或筛选条件会回到首批结果，清空搜索恢复首批历史；键盘导航也可继续加载。
“选择已加载项”仅选择当前已加载的结果，用于批量操作。

[All user guides](README.md)
