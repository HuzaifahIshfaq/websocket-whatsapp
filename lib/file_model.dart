class FileModel {
  final String type;
  final String name;
  final String data;

  FileModel({
    required this.data,
    required this.name,
    required this.type,
  });

  factory FileModel.fromJson(Map<String, dynamic> json) {
    return FileModel(
      data: json['data'],
      name: json['name'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'name': name,
      'type': type,
    };
  }
}
