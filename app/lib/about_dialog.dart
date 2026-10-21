import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_style.dart';
import 'l10n.dart';

/// Credits, the source repository and the bundled open source licenses.
///
/// The licenses slide in inside the dialog instead of pushing a full page,
/// so the booth visitor never loses where they are.
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
  final _pages = PageController();
  var _page = 0;

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
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    setState(() => _page = page);
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_page - 1);
      },
      child: Dialog(
        key: const ValueKey('about_dialog'),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: 600,
            // Fixed height so the dialog does not jump between pages.
            height: math.min(constraints.maxHeight, 380),
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              children: [_about(t), _licenseList(t), _licenseText(t)],
            ),
          ),
        ),
      ),
    );
  }

  /// Title, scrolling body and actions, laid out like an [AlertDialog].
  Widget _frame({
    required Widget title,
    required Widget body,
    required List<Widget> actions,
    VoidCallback? onBack,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(onBack == null ? 24 : 8, 16, 24, 6),
        child: Row(
          children: [
            if (onBack != null)
              IconButton(
                key: const ValueKey('about_back'),
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            Expanded(
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: brandInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: title,
              ),
            ),
          ],
        ),
      ),
      Expanded(child: body),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 8,
          children: actions,
        ),
      ),
    ],
  );

  Widget _closeButton(Strings t) => FilledButton(
    key: const ValueKey('about_close'),
    onPressed: () => Navigator.pop(context),
    child: Text(t.close),
  );

  Widget _about(Strings t) {
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
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
    Widget link(String key, Widget icon, String text, String url) => InkWell(
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
    return _frame(
      title: Text(t.appTitle),
      // Landscape phones are short: repository and authors sit side by side.
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.aboutBody,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label(t.repository),
                      // Booth visitors scan it with their own phone.
                      Container(
                        key: const ValueKey('about_repository_qr'),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: brandPale),
                        ),
                        child: QrImageView(
                          data: AboutAppDialog.repository,
                          size: 120,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      link(
                        'about_repository',
                        const Icon(
                          Icons.code_rounded,
                          size: 18,
                          color: brandBlue,
                        ),
                        AboutAppDialog.repository.replaceFirst('https://', ''),
                        AboutAppDialog.repository,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    label(t.authors),
                    for (final (handle, avatar) in AboutAppDialog.authors)
                      link(
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
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('about_licenses'),
          onPressed: () => _go(1),
          child: Text(t.licenses),
        ),
        _closeButton(t),
      ],
    );
  }

  Widget _licenseList(Strings t) => _frame(
    onBack: () => _go(0),
    title: Text(t.licenses),
    body: FutureBuilder(
      future: _licenses,
      builder: (context, snapshot) {
        final packages = snapshot.data;
        if (packages == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView.builder(
          key: const ValueKey('about_license_list'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: packages.length,
          itemBuilder: (context, i) {
            final (name, entries) = packages[i];
            return ListTile(
              key: ValueKey('about_license_$name'),
              dense: true,
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(t.licenseCount(entries.length)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                setState(() {
                  _package = name;
                  _entries = entries;
                });
                _go(2);
              },
            );
          },
        );
      },
    ),
    actions: [_closeButton(t)],
  );

  Widget _licenseText(Strings t) {
    // Entries are separated by a divider, as the stock license page does.
    final paragraphs = <LicenseParagraph?>[
      for (final (i, entry) in _entries.indexed) ...[
        if (i > 0) null,
        ...entry.paragraphs,
      ],
    ];
    return _frame(
      onBack: () => _go(1),
      title: Text(_package ?? ''),
      body: ListView.builder(
        key: ValueKey('about_license_text_$_package'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        itemCount: paragraphs.length,
        itemBuilder: (context, i) {
          final paragraph = paragraphs[i];
          if (paragraph == null) return const Divider(height: 32);
          const style = TextStyle(fontSize: 11, height: 1.45, color: brandInk);
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
      actions: [_closeButton(t)],
    );
  }
}
