class Category {
  const Category({required this.id, required this.name, required this.type});

  final int id;
  final String name;
  final String type;

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}