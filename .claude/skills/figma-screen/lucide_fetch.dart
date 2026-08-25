// Fetches named icons from the Lucide repo straight into the design system.
//
// Most glyphs in FT Design are stock Lucide, so they do not need exporting from
// Figma at all — pulling them from source is faster, needs no Figma token, and
// sidesteps the `/v1/images` render cap that blocks `figma_fetch.dart` (see the
// warning in SKILL.md). Icons land in `assets/design_system/icon/<name>.svg`.
//
// Usage:
//
//   dart run .claude/skills/figma-screen/lucide_fetch.dart list-checks user-plus
//   dart run .claude/skills/figma-screen/lucide_fetch.dart trash-2=trash square-pen=edit
//   dart run .claude/skills/figma-screen/lucide_fetch.dart --out-dir assets/x circle-user
//
// `<lucide-name>=<our-name>` saves under a different filename. Use it whenever
// Lucide's name carries variant numbering or wording the design does not share:
// upstream `trash-2` is just "the trash icon" to us, and `square-pen` is what
// Figma calls `edit`. Asset names should read in the design's vocabulary, not
// upstream's — the left-hand side keeps the provenance so a re-fetch is exact.
//
// Figma's layer name is usually the Lucide name, so read it off the node tree.
// Two caveats:
//
//  * Lucide has renamed glyphs over time and Figma may carry the old name —
//    `user-circle` is now `circle-user`, `edit` is now `square-pen`. If a name
//    404s, check https://lucide.dev/icons for the current one.
//  * **Not every icon in the design is Lucide.** This one screen also uses
//    `tabler-icon-fish-hook` (Tabler) and `marker-pin-01` (Untitled UI). Those,
//    and anything genuinely custom like the FT wordmark, come from
//    `figma_fetch.dart images` instead.
//
// Lucide is MIT licensed: https://github.com/lucide-icons/lucide/blob/main/LICENSE
import 'dart:io';

const String baseUrl = 'https://raw.githubusercontent.com/lucide-icons/lucide/main/icons';
const String defaultOutDir = 'assets/design_system/icon';

Future<void> main(List<String> args) async {
  final outDir = _flag(args, '--out-dir') ?? defaultOutDir;
  final names = <String>[
    for (var i = 0; i < args.length; i++)
      if (!args[i].startsWith('--') && (i == 0 || args[i - 1] != '--out-dir')) args[i],
  ];

  if (names.isEmpty) {
    stderr.writeln(_usage);
    exit(64);
  }

  final client = HttpClient();
  var failed = 0;
  try {
    for (final entry in names) {
      final parts = entry.split('=');
      if (parts.length > 2 || parts.any((part) => part.trim().isEmpty)) {
        stderr.writeln('Malformed argument "$entry". Expected `<lucide-name>` or `<lucide-name>=<our-name>`.');
        failed++;
        continue;
      }
      final lucideName = parts.first.trim();
      final outName = parts.last.trim();

      final request = await client.getUrl(Uri.parse('$baseUrl/$lucideName.svg'));
      final response = await request.close();

      if (response.statusCode != 200) {
        await response.drain<void>();
        stderr.writeln(
          'Lucide ${response.statusCode} for "$lucideName". '
          'Check the current name at https://lucide.dev/icons — it may have been renamed.',
        );
        failed++;
        continue;
      }

      final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      final file = await (await File('$outDir/$outName.svg').create(recursive: true)).writeAsBytes(bytes);
      final provenance = outName == lucideName ? '' : '  (lucide: $lucideName)';
      stdout.writeln('Wrote ${file.path}  —  ${bytes.length} bytes$provenance');
    }
  } finally {
    client.close();
  }

  if (failed > 0) {
    exit(65);
  }
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf(name);
  return index != -1 && index + 1 < args.length ? args[index + 1] : null;
}

const String _usage =
    '''
Usage:
  dart run .claude/skills/figma-screen/lucide_fetch.dart <name>[=<our-name>]... [--out-dir path]

Names on the left are Lucide's own, as listed at https://lucide.dev/icons, and
are usually the Figma layer name too. Add `=<our-name>` to save under a name in
the design's vocabulary instead — e.g. `trash-2=trash`, `square-pen=edit`.

Files are written to $defaultOutDir.
''';
