// Fetches design data from the FT Design Figma file over the REST API.
//
// Exists because the Figma MCP server is capped at 6 tool calls per month on a
// View seat, which cannot support a 34-screen migration. The REST API has its
// own, far larger quota.
//
// Usage:
//
//   export FIGMA_TOKEN=figd_...
//   dart run .claude/skills/figma-screen/figma_fetch.dart node 259-4727
//   dart run .claude/skills/figma-screen/figma_fetch.dart image 259-4727 --scale 2
//   dart run .claude/skills/figma-screen/figma_fetch.dart image 261-4798 --format svg --out logo.svg
//
// The token is read from the environment and never written to disk. Do **not**
// put it in `.env` — that file is tracked in git.
//
// Output lands in `docs/redesign/figma/`, pretty-printed so a design change
// arrives as a reviewable diff.
//
// Note: `/v1/files/:key/variables/local` (which would give us variable *names*
// and the DTCG export the drift check wants) is Enterprise-only, so it is not
// implemented here. The node tree still carries resolved fills and typography;
// map those back to `Palette` by value.
import 'dart:convert';
import 'dart:io';

const String fileKey = 'AmUyG0SdHzI74BhYlXQq91';
const String outputDir = 'docs/redesign/figma';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(_usage);
    exit(64);
  }

  final token = Platform.environment['FIGMA_TOKEN'];
  if (token == null || token.isEmpty) {
    stderr.writeln('FIGMA_TOKEN is not set.\n\n$_usage');
    exit(78);
  }

  final command = args[0];
  // Figma accepts `259-4727` in URLs but the API wants `259:4727`.
  final nodeId = args[1].replaceAll('-', ':');
  final slug = nodeId.replaceAll(':', '-');

  switch (command) {
    case 'node':
      await _fetchNode(token: token, nodeId: nodeId, slug: slug);
    case 'image':
      await _fetchImage(
        token: token,
        nodeId: nodeId,
        slug: slug,
        scale: _flag(args, '--scale') ?? '2',
        format: _flag(args, '--format') ?? 'png',
        out: _flag(args, '--out'),
      );
    case 'images':
      await _fetchImages(
        token: token,
        spec: args[1],
        scale: _flag(args, '--scale') ?? '2',
        format: _flag(args, '--format') ?? 'svg',
        outDir: _flag(args, '--out-dir') ?? 'assets/design_system/icon',
      );
    default:
      stderr.writeln('Unknown command "$command".\n\n$_usage');
      exit(64);
  }
}

/// Writes the node subtree to `<outputDir>/<slug>.json`.
Future<void> _fetchNode({required String token, required String nodeId, required String slug}) async {
  final body = await _get(token: token, path: '/v1/files/$fileKey/nodes', query: {'ids': nodeId});
  final document = jsonDecode(body);
  final nodes = document['nodes'];
  if (nodes is! Map || nodes[nodeId] == null) {
    stderr.writeln('Figma returned no node "$nodeId". Check the id and that the token can read this file.');
    exit(65);
  }

  final file = await _write('$slug.json', const JsonEncoder.withIndent('  ').convert(document));
  final name = nodes[nodeId]['document']?['name'] ?? '(unnamed)';
  stdout.writeln('Wrote ${file.path}  —  "$name", ${_readableSize(await file.length())}');
}

/// Renders the node and writes it to `<outputDir>/<slug>.<format>`, or to [out]
/// (a path relative to the repo root) when given — that is how design-system
/// assets land straight in `assets/`.
///
/// Two calls: `/v1/images` returns a short-lived S3 URL rather than the bytes.
Future<void> _fetchImage({
  required String token,
  required String nodeId,
  required String slug,
  required String scale,
  required String format,
  required String? out,
}) async {
  final body = await _get(
    token: token,
    path: '/v1/images/$fileKey',
    query: {'ids': nodeId, 'format': format, if (format != 'svg') 'scale': scale},
  );
  final url = jsonDecode(body)['images']?[nodeId];
  if (url is! String) {
    stderr.writeln('Figma returned no render URL for "$nodeId".');
    exit(65);
  }

  final client = HttpClient();
  try {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    final file = out != null
        ? await (await File(out).create(recursive: true)).writeAsBytes(bytes)
        : await _write('$slug.$format', null, bytes: bytes);
    final size = format == 'svg' ? _readableSize(bytes.length) : '${_readableSize(bytes.length)} at ${scale}x';
    stdout.writeln('Wrote ${file.path}  —  $size');
  } finally {
    client.close();
  }
}

/// Renders **many** nodes in one `/v1/images` call and writes each to
/// `<outDir>/<name>`.
///
/// Prefer this over looping `image` whenever a screen needs more than one
/// asset. `/v1/images` is rate limited far more aggressively than the node
/// endpoint, and it is limited *per request*, not per node — exporting a
/// screen's dozen icons one at a time can exhaust the render quota for the rest
/// of the day, while the same dozen in one call costs a single request.
///
/// [spec] is `id=filename` pairs, comma separated:
///
///   dart run … images '276-883=user-circle.svg,I276:941;276:919=fish-hook.svg'
///
/// Ids may use either `259-4727` or `259:4727`; ids that already contain a
/// colon (instance ids such as `I276:941;276:919`) are passed through as-is.
Future<void> _fetchImages({
  required String token,
  required String spec,
  required String scale,
  required String format,
  required String outDir,
}) async {
  final targets = <String, String>{};
  for (final pair in spec.split(',')) {
    final parts = pair.split('=');
    if (parts.length != 2 || parts.any((part) => part.trim().isEmpty)) {
      stderr.writeln('Malformed pair "$pair". Expected `id=filename`.\n\n$_usage');
      exit(64);
    }
    final rawId = parts[0].trim();
    // Only bare ids use the dashed form; instance ids already carry colons.
    targets[rawId.contains(':') ? rawId : rawId.replaceAll('-', ':')] = parts[1].trim();
  }

  final body = await _get(
    token: token,
    path: '/v1/images/$fileKey',
    query: {'ids': targets.keys.join(','), 'format': format, if (format != 'svg') 'scale': scale},
  );
  final images = jsonDecode(body)['images'];
  if (images is! Map) {
    stderr.writeln('Figma returned no renders for these ids.');
    exit(65);
  }

  final client = HttpClient();
  var failed = 0;
  try {
    for (final entry in targets.entries) {
      final url = images[entry.key];
      if (url is! String) {
        stderr.writeln('No render URL for "${entry.key}" (${entry.value}).');
        failed++;
        continue;
      }
      final response = await (await client.getUrl(Uri.parse(url))).close();
      final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      final file = await (await File('$outDir/${entry.value}').create(recursive: true)).writeAsBytes(bytes);
      stdout.writeln('Wrote ${file.path}  —  ${_readableSize(bytes.length)}');
    }
  } finally {
    client.close();
  }

  if (failed > 0) {
    exit(65);
  }
}

/// A single authenticated GET against the Figma API.
Future<String> _get({required String token, required String path, required Map<String, String> query}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.https('api.figma.com', path, query));
    request.headers.set('X-Figma-Token', token);
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      stderr.writeln('Figma API ${response.statusCode} on $path');
      stderr.writeln(_explain(response.statusCode));
      stderr.writeln(_retryAfter(response));
      stderr.writeln(body);
      exit(response.statusCode == 429 ? 75 : 70);
    }
    return body;
  } finally {
    client.close();
  }
}

/// The failures worth naming, since the raw messages are terse.
String _explain(int status) {
  return switch (status) {
    403 =>
      'Token rejected. Check it has the `file_content:read` scope and that '
          'your account can view this file.',
    404 => 'File or node not found.',
    429 =>
      'REST rate limit (separate from the MCP quota). Not a short cooldown — '
          'retrying in a loop will not clear it; read the retry-after below for '
          'how long it actually is. This can hit `node` as well as `image`: the '
          'budget is per token across the whole REST API, so a blocked render '
          'quota does NOT imply node fetches still work. Use `images` to batch, '
          'and see the Profile entry in docs/redesign/MIGRATION.md for the '
          'hand-export fallback.',
    _ => '',
  };
}

/// Turns the `retry-after` header into a wall-clock time.
///
/// Figma returns it in seconds, and the values are long enough (20h has been
/// observed) that the raw number reads as a typo. Printing the time the budget
/// resets is what makes the difference between waiting and finding another way
/// in — so this is worth surfacing on every failure that carries the header.
String _retryAfter(HttpClientResponse response) {
  final header = response.headers.value('retry-after');
  final seconds = int.tryParse(header ?? '');
  if (seconds == null) {
    return '';
  }
  final resets = DateTime.now().add(Duration(seconds: seconds));
  final hours = (seconds / 3600).toStringAsFixed(1);
  return 'retry-after: ${seconds}s (~$hours h) — resets around ${resets.toLocal()}';
}

String? _flag(List<String> args, String name) {
  final index = args.indexOf(name);
  return index != -1 && index + 1 < args.length ? args[index + 1] : null;
}

Future<File> _write(String name, String? text, {List<int>? bytes}) async {
  await Directory(outputDir).create(recursive: true);
  final file = File('$outputDir/$name');
  return bytes != null ? file.writeAsBytes(bytes) : file.writeAsString(text!);
}

String _readableSize(int bytes) {
  return bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

const String _usage = '''
Usage:
  export FIGMA_TOKEN=figd_...
  dart run .claude/skills/figma-screen/figma_fetch.dart node  <node-id>
  dart run .claude/skills/figma-screen/figma_fetch.dart image <node-id> [--scale 2] [--format png|svg] [--out path]
  dart run .claude/skills/figma-screen/figma_fetch.dart images '<id>=<file>,<id>=<file>' [--format svg|png] [--scale 2] [--out-dir assets/design_system/icon]

Use `images` for more than one asset. /v1/images is rate limited per request,
so a screen's icons in one call cost one request; the same icons looped through
`image` can exhaust the render quota for the day.

Node ids may use either form: 259-4727 or 259:4727.
Create a token at Figma > Settings > Security > Personal access tokens,
with the `file_content:read` scope.
''';
