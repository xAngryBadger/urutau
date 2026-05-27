class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<int> length() async => 0;
}
