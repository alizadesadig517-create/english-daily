import 'dart:convert';

import 'package:http/http.dart' as http;

class GitHubException implements Exception {
  GitHubException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Reads (and with a token, writes) files in the content repository.
///
/// Without a token: public raw URLs (repo must be public).
/// With a fine-grained token: the GitHub REST API (works for private repos
/// and allows writing config/settings.json).
class GitHubClient {
  GitHubClient({
    required this.owner,
    required this.repo,
    required this.branch,
    this.token,
    http.Client? client,
  }) : _http = client ?? http.Client();

  final String owner;
  final String repo;
  final String branch;
  final String? token;
  final http.Client _http;

  static const _timeout = Duration(seconds: 20);

  bool get usesApi => token != null;

  Map<String, String> get _apiHeaders => {
        'Authorization': 'Bearer $token',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'english-daily-app',
      };

  Uri _apiUri(String path) => Uri.https(
      'api.github.com', '/repos/$owner/$repo/contents/$path', {'ref': branch});

  /// File contents as text, or null if the file does not exist (yet).
  Future<String?> getFile(String path) async {
    final http.Response res;
    try {
      if (usesApi) {
        res = await _http
            .get(_apiUri(path), headers: {..._apiHeaders, 'Accept': 'application/vnd.github.raw+json'})
            .timeout(_timeout);
      } else {
        // The query string avoids stale CDN copies right after publishing.
        final uri = Uri.https('raw.githubusercontent.com', '/$owner/$repo/$branch/$path',
            {'t': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}'});
        res = await _http.get(uri).timeout(_timeout);
      }
    } catch (e) {
      throw GitHubException('No connection to GitHub ($e)');
    }
    if (res.statusCode == 200) return utf8.decode(res.bodyBytes);
    if (res.statusCode == 404) return null;
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw GitHubException(
          usesApi ? 'GitHub token was rejected (HTTP ${res.statusCode}). Check it in Settings.' : 'GitHub refused access (HTTP ${res.statusCode}).',
          statusCode: res.statusCode);
    }
    throw GitHubException('GitHub error HTTP ${res.statusCode}', statusCode: res.statusCode);
  }

  /// Creates or updates a text file on [branch]. Needs a token with
  /// "Contents: Read and write" permission.
  Future<void> putFile(String path, String content, String message) async {
    if (!usesApi) throw GitHubException('A GitHub token is needed to save to the repository.');
    String? sha;
    final meta = await _http
        .get(_apiUri(path), headers: {..._apiHeaders, 'Accept': 'application/vnd.github+json'})
        .timeout(_timeout);
    if (meta.statusCode == 200) {
      sha = (jsonDecode(meta.body) as Map<String, dynamic>)['sha'] as String?;
    } else if (meta.statusCode != 404) {
      throw GitHubException('Could not read $path (HTTP ${meta.statusCode})', statusCode: meta.statusCode);
    }
    final res = await _http
        .put(
          Uri.https('api.github.com', '/repos/$owner/$repo/contents/$path'),
          headers: {..._apiHeaders, 'Accept': 'application/vnd.github+json'},
          body: jsonEncode({
            'message': message,
            'content': base64Encode(utf8.encode(content)),
            'branch': branch,
            'sha': ?sha,
          }),
        )
        .timeout(_timeout);
    if (res.statusCode == 200 || res.statusCode == 201) return;
    if (res.statusCode == 403 || res.statusCode == 404) {
      throw GitHubException(
          'Saving failed (HTTP ${res.statusCode}). The token needs "Contents: Read and write" access to $owner/$repo.',
          statusCode: res.statusCode);
    }
    throw GitHubException('Saving failed (HTTP ${res.statusCode})', statusCode: res.statusCode);
  }
}
