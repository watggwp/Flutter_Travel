import 'package:flutter/material.dart';
import '../l10n/app_translations.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppTranslations.currentLanguage,
      builder: (context, lang, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButton<String>(
            value: lang,
            underline: const SizedBox(),
            icon: const Icon(Icons.language, color: Colors.grey),
            items: const [
              DropdownMenuItem(value: 'en', child: Text('EN', style: TextStyle(fontWeight: FontWeight.bold))),
              DropdownMenuItem(value: 'th', child: Text('TH', style: TextStyle(fontWeight: FontWeight.bold))),
              DropdownMenuItem(value: 'ja', child: Text('JA', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            onChanged: (String? newValue) {
              if (newValue != null) {
                AppTranslations.changeLanguage(newValue);
              }
            },
          ),
        );
      }
    );
  }
}
