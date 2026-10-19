import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/app_scope.dart';
import '../core/l10n.dart';
import '../core/theme.dart';
import '../services/settings_store.dart';
import '../services/update_service.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _endpoint = TextEditingController();
  final TextEditingController _key = TextEditingController();
  bool _loadedFields = false;
  bool _obscure = true;
  bool _checking = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (mounted) setState(() => _version = '${p.version} (${p.buildNumber})');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedFields) {
      final s = AppScope.of(context);
      _endpoint.text = s.endpoint;
      _key.text = s.apiKey;
      _loadedFields = true;
    }
  }

  @override
  void dispose() {
    _endpoint.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final info = await UpdateService.check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (info == null) {
      showSnack(context, context.tr('update_check_failed'));
    } else if (info.shouldShow) {
      await showUpdateDialog(context, info);
    } else {
      showSnack(context, context.tr('up_to_date'));
    }
  }

  Widget _card(BuildContext context, {required String title, String? subtitle, required Widget child}) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: context.textColor, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: context.mutedColor, fontSize: 12.5, height: 1.4)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.mutedColor),
        filled: true,
        fillColor: context.bgColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
        children: [
          Text(
            context.tr('tab_settings'),
            style: TextStyle(color: context.textColor, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          SectionTitle(context.tr('prefs')),
          _card(
            context,
            title: context.tr('language'),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              PillOption(
                label: context.tr('arabic'),
                selected: s.lang == 'ar',
                onTap: () => s.setLang('ar'),
              ),
              PillOption(
                label: context.tr('english'),
                selected: s.lang == 'en',
                onTap: () => s.setLang('en'),
              ),
            ]),
          ),
          _card(
            context,
            title: context.tr('theme'),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              PillOption(
                label: context.tr('theme_system'),
                icon: Icons.brightness_auto_rounded,
                selected: s.themeKey == 'system',
                onTap: () => s.setTheme('system'),
              ),
              PillOption(
                label: context.tr('theme_light'),
                icon: Icons.light_mode_rounded,
                selected: s.themeKey == 'light',
                onTap: () => s.setTheme('light'),
              ),
              PillOption(
                label: context.tr('theme_dark'),
                icon: Icons.dark_mode_rounded,
                selected: s.themeKey == 'dark',
                onTap: () => s.setTheme('dark'),
              ),
            ]),
          ),
          _card(
            context,
            title: context.tr('default_quality'),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final q in AppSettings.qualities)
                PillOption(label: q, selected: s.quality == q, onTap: () => s.setQuality(q)),
            ]),
          ),
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('auto_save'),
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.tr('auto_save_sub'),
                        style: TextStyle(color: context.mutedColor, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: s.autoSave,
                  activeColor: AppColors.primary,
                  onChanged: (v) => s.setAutoSave(v),
                ),
              ],
            ),
          ),
          SectionTitle(context.tr('connection')),
          _card(
            context,
            title: context.tr('engine'),
            subtitle: context.tr('engine_sub'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _endpoint,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: context.textColor, fontSize: 14),
                  decoration: _fieldDecoration(context, 'https://your-cobalt-instance/'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _key,
                  obscureText: _obscure,
                  style: TextStyle(color: context.textColor, fontSize: 14),
                  decoration: _fieldDecoration(context, context.tr('api_key')).copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: context.mutedColor,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                GradientButton(
                  label: context.tr('save'),
                  icon: Icons.check_rounded,
                  height: 48,
                  onPressed: () async {
                    await s.setEngine(_endpoint.text, _key.text);
                    _endpoint.text = s.endpoint;
                    if (mounted) showSnack(context, context.tr('saved'));
                  },
                ),
              ],
            ),
          ),
          SectionTitle(context.tr('about')),
          _card(
            context,
            title: 'FlowDrop',
            subtitle: '${context.tr('version')}: $_version',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientButton(
                  label: context.tr('check_update'),
                  icon: Icons.system_update_alt_rounded,
                  height: 46,
                  loading: _checking,
                  onPressed: _checkUpdate,
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr('legal'),
                  style: TextStyle(color: context.mutedColor, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
