import 'dart:io';
void main() {
  var fixes = [
    {'file': 'lib/features/auth/sign_in_screen.dart', 'lines': [428, 492, 509, 618, 691]},
    {'file': 'lib/features/dashboard/dashboard_screen.dart', 'lines': [139]},
    {'file': 'lib/features/pass/pass_screen.dart', 'lines': [377, 416]},
    {'file': 'lib/features/train/train_screen.dart', 'lines': [275, 289, 314]},
  ];
  for (var fix in fixes) {
    var file = File(fix['file'] as String);
    var lines = file.readAsLinesSync();
    for (var lineNum in fix['lines'] as List<int>) {
      var i = lineNum - 1; // 0-based
      lines[i] = lines[i].replaceAll('const ', '');
    }
    file.writeAsStringSync(lines.join('\n') + '\n');
  }
}
