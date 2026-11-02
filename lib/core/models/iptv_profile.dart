enum ProfileSource { tvlister, xtream, playlist }

class IptvProfile {
  const IptvProfile({required this.id, required this.name, required this.source,
    required this.server, this.username = '', this.password = '', this.playlistText = '', this.allowHttp = false});
  final String id, name, server, username, password, playlistText;
  final ProfileSource source;
  final bool allowHttp;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'source': source.name,
    'server': server, 'username': username, 'password': password, 'playlistText': playlistText, 'allowHttp': allowHttp};
  factory IptvProfile.fromJson(Map<String, dynamic> j) => IptvProfile(id: j['id'] as String,
    name: j['name'] as String, server: j['server'] as String? ?? '',
    source: ProfileSource.values.firstWhere((v) => v.name == j['source'], orElse: () => ProfileSource.xtream),
    username: j['username'] as String? ?? '', password: j['password'] as String? ?? '',
    playlistText: j['playlistText'] as String? ?? '', allowHttp: j['allowHttp'] == true);
}
