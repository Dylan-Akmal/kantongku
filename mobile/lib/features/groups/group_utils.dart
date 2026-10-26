/// "Dylan Akmal" menjadi "DA".
String initials(String name) {
  final letters = name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  return letters.isEmpty ? '?' : letters;
}