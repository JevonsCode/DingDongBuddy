import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

/// Shares paging and query-reset behavior between the popup and manager.
/// Reads happen after layout, never while a lazy row is being built.
class ClipboardHistoryPagination extends StatefulWidget {
  const ClipboardHistoryPagination({
    required this.viewModel,
    required this.controller,
    required this.child,
    super.key,
  });

  final ClipboardViewModel viewModel;
  final ScrollController controller;
  final Widget child;

  @override
  State<ClipboardHistoryPagination> createState() =>
      _ClipboardHistoryPaginationState();
}

class _ClipboardHistoryPaginationState
    extends State<ClipboardHistoryPagination> {
  late int _revision;
  bool _scheduled = false;
  bool _resetScroll = false;

  @override
  void initState() {
    super.initState();
    _revision = widget.viewModel.paginationRevision;
    widget.viewModel.addListener(_changed);
    widget.controller.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant ClipboardHistoryPagination oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_changed);
      widget.viewModel.addListener(_changed);
      _revision = widget.viewModel.paginationRevision;
      _resetScroll = true;
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_schedule);
      widget.controller.addListener(_schedule);
    }
    _schedule();
  }

  void _changed() {
    final revision = widget.viewModel.paginationRevision;
    if (_revision != revision) {
      _revision = revision;
      _resetScroll = true;
    }
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !widget.controller.hasClients) return;
      if (_resetScroll) {
        _resetScroll = false;
        widget.controller.jumpTo(0);
      }
      if (widget.controller.position.extentAfter <= 300 &&
          widget.viewModel.hasMoreHistory) {
        widget.viewModel.loadNextPage();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_changed);
    widget.controller.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
