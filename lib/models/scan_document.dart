import 'scan_page.dart';

/// Represents a scanned document with multiple pages
class ScanDocument {
  final String id;
  String name;
  final String folderPath;
  final List<ScanPage> pages;
  final DateTime createdAt;
  DateTime updatedAt;
  String? pdfPath;
  String? thumbnailPath;

  ScanDocument({
    required this.id,
    required this.name,
    required this.folderPath,
    List<ScanPage>? pages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.pdfPath,
    this.thumbnailPath,
  })  : pages = pages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Number of pages in this document
  int get pageCount => pages.length;

  /// Get thumbnail: first page image or explicit thumbnail
  String? get displayThumbnail => thumbnailPath ?? pages.firstOrNull?.imagePath;

  /// Add a page to this document
  void addPage(ScanPage page) {
    pages.add(page);
    updatedAt = DateTime.now();
  }

  /// Remove a page by index
  void removePage(int index) {
    if (index >= 0 && index < pages.length) {
      pages.removeAt(index);
      updatedAt = DateTime.now();
    }
  }

  /// Reorder pages
  void reorderPage(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final page = pages.removeAt(oldIndex);
    pages.insert(newIndex, page);
    updatedAt = DateTime.now();
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folderPath': folderPath,
      'pages': pages.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'pdfPath': pdfPath,
      'thumbnailPath': thumbnailPath,
    };
  }

  /// Create from JSON
  factory ScanDocument.fromJson(Map<String, dynamic> json) {
    return ScanDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      folderPath: json['folderPath'] as String,
      pages: (json['pages'] as List<dynamic>?)
              ?.map((p) => ScanPage.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pdfPath: json['pdfPath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
