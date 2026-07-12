import 'package:dingdong/core/models/resource.dart';

bool matchesResource(Resource resource, String needle) {
  return needle.isEmpty ||
      resource.title.toLowerCase().contains(needle) ||
      resource.content.toLowerCase().contains(needle) ||
      resource.group.toLowerCase().contains(needle) ||
      resource.tags.any((String tag) => tag.toLowerCase().contains(needle)) ||
      (resource.updateUrl?.toLowerCase().contains(needle) ?? false);
}

int compareResources(Resource left, Resource right) {
  if (left.type.supportsAgentActivation && right.type.supportsAgentActivation) {
    final int? leftOrder = left.sortOrder;
    final int? rightOrder = right.sortOrder;
    if (leftOrder != null && rightOrder != null && leftOrder != rightOrder) {
      return leftOrder.compareTo(rightOrder);
    }
    if (leftOrder != null && rightOrder == null) {
      return -1;
    }
    if (leftOrder == null && rightOrder != null) {
      return 1;
    }
  }
  if (left.pinned != right.pinned) {
    return left.pinned ? -1 : 1;
  }
  return right.updatedAt.compareTo(left.updatedAt);
}
