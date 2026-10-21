import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_style.dart';
import 'l10n.dart';

/// Credits, the source repository and the bundled open source licenses.
///
/// A toggle in the header slides between the two tabs inside the dialog, so
/// the booth visitor never leaves it for a full screen page.
class AboutAppDialog extends StatefulWidget {
  const AboutAppDialog({super.key});
  static const repository = 'https://github.com/K9i-0/flutterkaigi2026';

  /// GitHub handle and the bundled avatar, so the booth works offline.
  static const authors = [
    ('K9i-0', 'assets/images/authors/K9i-0.png'),
    ('karas1910', 'assets/images/authors/karas1910.jpg'),
  ];

  static Future<void> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  State<AboutAppDialog> createState() => _AboutAppDialogState();
}

class _AboutAppDialogState extends State<AboutAppDialog> {
  static const _slide = Duration(milliseconds: 300);
  static const _curve = Curves.easeOutCubic;

  /// About and licenses tabs.
  final _tabs = PageController();

  /// License list and one package's text, inside the licenses tab.
  final _licensePages = PageController();
  var _tab = 0;
  var _reading = false;

  /// Package name to its license entries, sorted by name once loaded.
  late final Future<List<(String, List<LicenseEntry>)>> _licenses =
      _loadLicenses();
  String? _package;
  List<LicenseEntry> _entries = const [];

  static Future<List<(String, List<LicenseEntry>)>> _loadLicenses() async {
    final byPackage = <String, List<LicenseEntry>>{};
    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(entry);
      }
    }
    final names = byPackage.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [for (final name in names) (name, byPackage[name]!)];
  }

  @override
  void dispose() {
    _tabs.dispose();
    _licensePages.dispose();
    super.dispose();
  }

  void _showTab(int tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _tabs.animateToPage(tab, duration: _slide, curve: _curve);
  }

  void _read(String? package, [List<LicenseEntry> entries = const []]) {
    setState(() {
      _reading = package != null;
      if (package != null) {
        _package = package;
        _entries = entries;
      }
    });
    _licensePages.animateToPage(
      _reading ? 1 : 0,
      duration: _slide,
      curve: _curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _reading ? _read(null) : _showTab(0);
      },
      child: Dialog(
        key: const ValueKey('about_dialog'),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: 620,
            // Fixed height so the dialog does not jump between tabs.
            height: math.min(constraints.maxHeight, 340),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(t),
                Expanded(
                  child: PageView(
                    controller: _tabs,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [_about(t), _licenseTab(t)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Strings t) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 14, 10, 8),
    child: Row(
      spacing: 12,
      children: [
        Expanded(
          child: Text(
            t.appTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: brandInk,
            ),
          ),
        ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            selectedBackgroundColor: brandBlue,
            selectedForegroundColor: Colors.white,
            foregroundColor: brandInk,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
          segments: [
            ButtonSegment(
              value: 0,
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              label: Text(t.aboutTab, key: const ValueKey('about_tab_about')),
            ),
            ButtonSegment(
              value: 1,
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(t.licenses, key: const ValueKey('about_licenses')),
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (selection) => _showTab(selection.single),
        ),
        IconButton(
          key: const ValueKey('about_close'),
          tooltip: t.close,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: brandMuted,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    ),
  );

  Widget _link(String key, Widget icon, String text, String url) => InkWell(
    key: ValueKey(key),
    borderRadius: BorderRadius.circular(6),
    onTap: () => AboutAppDialog.open(url),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: brandBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.open_in_new, size: 14, color: brandMuted),
        ],
      ),
    ),
  );

  /// Landscape phones are short: the QR code sits beside the text.
  Widget _about(Strings t) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 24,
      children: [
        // Booth visitors scan it with their own phone.
        Container(
          key: const ValueKey('about_repository_qr'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: brandPale, width: 2),
          ),
          child: QrImageView(
            data: AboutAppDialog.repository,
            size: 150,
            padding: EdgeInsets.zero,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.aboutBody,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),
              _label(t.repository),
              _link(
                'about_repository',
                const Icon(Icons.code_rounded, size: 18, color: brandBlue),
                AboutAppDialog.repository.replaceFirst('https://', ''),
                AboutAppDialog.repository,
              ),
              const SizedBox(height: 12),
              _label(t.authors),
              Wrap(
                spacing: 16,
                children: [
                  for (final (handle, avatar) in AboutAppDialog.authors)
                    _link(
                      'about_author_$handle',
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: brandPale,
                        backgroundImage: AssetImage(avatar),
                      ),
                      '@$handle',
                      'https://github.com/$handle',
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _licenseTab(Strings t) => PageView(
    controller: _licensePages,
    physics: const NeverScrollableScrollPhysics(),
    children: [_licenseList(t), _licenseText()],
  );

  Widget _licenseList(Strings t) => FutureBuilder(
    future: _licenses,
    builder: (context, snapshot) {
      final packages = snapshot.data;
      if (packages == null) {
        return const Center(child: CircularProgressIndicator());
      }
      // One line per package, two columns, so a short screen still shows many.
      return GridView.builder(
        key: const ValueKey('about_license_list'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 44,
          crossAxisSpacing: 8,
        ),
        itemCount: packages.length,
        itemBuilder: (context, i) {
          final (name, entries) = packages[i];
          return InkWell(
            key: ValueKey('about_license_$name'),
            borderRadius: BorderRadius.circular(8),
            onTap: () => _read(name, entries),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: brandInk,
                      ),
                    ),
                  ),
                  Text(
                    t.licenseCount(entries.length),
                    style: const TextStyle(fontSize: 11, color: brandMuted),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: brandMuted,
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  Widget _licenseText() {
    // Entries are separated by a divider, as the stock license page does.
    final paragraphs = <LicenseParagraph?>[
      for (final (i, entry) in _entries.indexed) ...[
        if (i > 0) null,
        ...entry.paragraphs,
      ],
    ];
    const style = TextStyle(fontSize: 11, height: 1.45, color: brandInk);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('about_back'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _read(null),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _package ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: brandInk,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            key: ValueKey('about_license_text_$_package'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            itemCount: paragraphs.length,
            itemBuilder: (context, i) {
              final paragraph = paragraphs[i];
              if (paragraph == null) return const Divider(height: 32);
              if (paragraph.indent == LicenseParagraph.centeredIndent) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    paragraph.text,
                    textAlign: TextAlign.center,
                    style: style.copyWith(fontWeight: FontWeight.w700),
                  ),
                );
              }
              return Padding(
                padding: EdgeInsets.only(top: 8, left: 16.0 * paragraph.indent),
                child: Text(paragraph.text, style: style),
              );
            },
          ),
        ),
      ],
    );
  }
}
