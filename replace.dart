import 'dart:io';

void main() {
  var dir = Directory('lib');
  var files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  var replacements = {
    'AppColors.lightBackground': 'context.bg',
    'AppColors.lightForeground': 'context.fg',
    'AppColors.lightCard': 'context.card',
    'AppColors.lightPrimaryForeground': 'context.primaryFg',
    'AppColors.lightPrimary': 'context.primaryColor',
    'AppColors.lightMutedForeground': 'context.mutedFg',
    'AppColors.lightMuted': 'context.muted',
    'AppColors.lightBorder': 'context.border',
  };

  for (var file in files) {
    if (!file.path.contains('features') && !file.path.endsWith('main.dart')) continue;
    var content = file.readAsStringSync();
    var newContent = content;

    // Handle specific ternary logic in main.dart
    if (file.path.endsWith('main.dart')) {
      newContent = newContent.replaceAll('isDark ? AppColors.darkCard : AppColors.lightCard', 'context.card');
      newContent = newContent.replaceAll('isDark ? AppColors.darkBorder : AppColors.lightBorder', 'context.border');
    }

    bool changed = false;
    for (var entry in replacements.entries) {
      if (newContent.contains(entry.key)) {
        newContent = newContent.replaceAll(entry.key, entry.value);
        changed = true;
      }
    }

    if (changed || content != newContent) {
      if (!newContent.contains('app_colors.dart')) {
        // Find the last import and insert after it
        var importIndex = newContent.lastIndexOf(RegExp(r'^import .*;', multiLine: true));
        if (importIndex != -1) {
          var endOfImport = newContent.indexOf('\n', importIndex) + 1;
          newContent = newContent.substring(0, endOfImport) + "import 'package:pulse_app/core/theme/app_colors.dart';\n" + newContent.substring(endOfImport);
        } else {
          newContent = "import 'package:pulse_app/core/theme/app_colors.dart';\n" + newContent;
        }
      }
      file.writeAsStringSync(newContent);
      print('Updated ${file.path}');
    }
  }
}
