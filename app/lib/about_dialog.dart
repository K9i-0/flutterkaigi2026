import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_style.dart';
import 'l10n.dart';

/// Credits, the source repository and the bundled open source licenses.
class AboutAppDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final t = L10n.of(context);
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
      onTap: () => open(url),
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
    return AlertDialog(
      key: const ValueKey('about_dialog'),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      title: Text(
        t.appTitle,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      // Landscape phones are short: repository and authors sit side by side.
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                            data: repository,
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
                          repository.replaceFirst('https://', ''),
                          repository,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label(t.authors),
                      for (final (handle, avatar) in authors)
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
      ),
      actions: [
        TextButton(
          key: const ValueKey('about_licenses'),
          onPressed: () => showLicensePage(
            context: context,
            applicationName: t.appTitle,
            applicationLegalese: 'Made by @K9i-0 and @karas1910',
          ),
          child: Text(t.licenses),
        ),
        FilledButton(
          key: const ValueKey('about_close'),
          onPressed: () => Navigator.pop(context),
          child: Text(t.close),
        ),
      ],
    );
  }
}
