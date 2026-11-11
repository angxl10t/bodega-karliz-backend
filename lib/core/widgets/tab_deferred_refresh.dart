import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Evita recargas de red y rebuilds en pestañas ocultas dentro de [IndexedStack],
/// consolidando cualquier cambio pendiente en una única recarga cuando la pestaña vuelve a mostrarse.
mixin TabDeferredRefreshMixin<T extends StatefulWidget> on State<T> {
  ValueListenable<int>? get tabVisibilityNotifier;
  int? get assignedTabIndex;

  bool _pendingTabRefresh = false;
  bool _tabListenerAttached = false;

  bool get isTabCurrentlyVisible =>
      tabVisibilityNotifier == null ||
      assignedTabIndex == null ||
      tabVisibilityNotifier!.value == assignedTabIndex;

  void initTabVisibilityListener() {
    if (tabVisibilityNotifier != null && !_tabListenerAttached) {
      tabVisibilityNotifier!.addListener(_handleActiveTabChanged);
      _tabListenerAttached = true;
    }
  }

  void disposeTabVisibilityListener() {
    if (_tabListenerAttached && tabVisibilityNotifier != null) {
      tabVisibilityNotifier!.removeListener(_handleActiveTabChanged);
      _tabListenerAttached = false;
    }
  }

  void runWhenTabVisible(VoidCallback action) {
    if (!mounted) return;
    if (isTabCurrentlyVisible) {
      _pendingTabRefresh = false;
      action();
    } else {
      _pendingTabRefresh = true;
    }
  }

  void _handleActiveTabChanged() {
    if (!mounted || !_pendingTabRefresh || !isTabCurrentlyVisible) return;
    _pendingTabRefresh = false;
    onDeferredTabRefresh();
  }

  void onDeferredTabRefresh();
}
