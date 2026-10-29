/// Validates a single filename at the vault and WebDAV boundaries.
String checkedFileName(String name) {
  if (name.isEmpty ||
      name == '.' ||
      name == '..' ||
      name.contains(RegExp(r'[/\\\x00]'))) {
    throw const FormatException('Expected a filename without path separators');
  }
  return name;
}
