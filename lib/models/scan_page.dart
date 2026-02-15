/// Represents a single scanned page within a document
class ScanPage {
  final String id;
  final String imagePath;
  String? processedImagePath;
  String filterApplied;
  int rotation; // 0, 90, 180, 270
  final int orderIndex;
  final DateTime capturedAt;

  ScanPage({
    required this.id,
    required this.imagePath,
    this.processedImagePath,
    this.filterApplied = 'original',
    this.rotation = 0,
    this.orderIndex = 0,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();

  /// The image to display (processed version if available, otherwise original)
  String get displayPath => processedImagePath ?? imagePath;

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imagePath': imagePath,
      'processedImagePath': processedImagePath,
      'filterApplied': filterApplied,
      'rotation': rotation,
      'orderIndex': orderIndex,
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory ScanPage.fromJson(Map<String, dynamic> json) {
    return ScanPage(
      id: json['id'] as String,
      imagePath: json['imagePath'] as String,
      processedImagePath: json['processedImagePath'] as String?,
      filterApplied: json['filterApplied'] as String? ?? 'original',
      rotation: json['rotation'] as int? ?? 0,
      orderIndex: json['orderIndex'] as int? ?? 0,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
    );
  }
}
