import 'dart:async';
import 'package:flutter/material.dart';
import '../core/l10n.dart';
import '../core/utils.dart';
import '../services/download_manager.dart';
import '../services/native_bridge.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import 'files_tab.dart';
import 'history_tab.dart';
import 'home_tab.dart';
import 'settings_tab.dart';

/// الهيكل الرئيسي: شريط تنقل بأربع تبويبات + استقبال الروابط المشاركة + فحص التحديث.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _tab = 0;
  final GlobalKey<HomeTabState> _homeKey = GlobalKey<HomeTabState>();
  StreamSubscription<DownloadEvent>? _eventSub;
  StreamSubscription<String>? _shareSub;

  @override
  void initState() {
    super.initState();
    NativeBridge.instance.init();
    _eventSub = DownloadManager.instance.events.listen(_onDownloadEvent);
    _shareSub = NativeBridge.instance.sharedText.listen(_onShared);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialShare();
      _checkUpdate();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _handleInitialShare() async {
    final t = await NativeBridge.instance.initialText();
    if (t != null) _onShared(t);
  }

  void _onShared(String text) {
    final url = extractUrl(text);
    if (url == null || !mounted) return;
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.setUrl(url, openOptions: true);
    });
  }

  void _onDownloadEvent(DownloadEvent e) {
    if (!mounted) return;
    final msg = e.success
        ? '${context.tr('dl_done')}: ${e.name}'
        : '${context.tr('dl_failed')}: ${e.name}';
    showSnack(context, msg);
  }

  Future<void> _checkUpdate() async {
    final info = await UpdateService.check();
    if (!mounted || info == null || !info.shouldShow) return;
    await showUpdateDialog(context, info);
  }

  void _openUrlOnHome(String url) {
    setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.setUrl(url, openOptions: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeTab(key: _homeKey, onOpenSettings: () => setState(() => _tab = 3)),
          const FilesTab(),
          HistoryTab(onRedownload: _openUrlOnHome),
          const SettingsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded, color: Color(0xFF159EFF)),
            label: context.tr('tab_home'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder_rounded, color: Color(0xFF159EFF)),
            label: context.tr('tab_files'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            selectedIcon: const Icon(Icons.history_rounded, color: Color(0xFF159EFF)),
            label: context.tr('tab_history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded, color: Color(0xFF159EFF)),
            label: context.tr('tab_settings'),
          ),
        ],
      ),
    );
  }
}
