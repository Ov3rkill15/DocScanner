import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/scan_document.dart';

/// Manages document storage, folders, and file operations
class FileService {
  static const String _docsDir = 'DocScanner';
  static const String _metaFile = 'documents.json';

  /// Get the app's document storage directory
  Future<Directory> get _storageDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _docsDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Get path to metadata JSON file
  Future<File> get _metaFilePath async {
    final dir = await _storageDir;
    return File(p.join(dir.path, _metaFile));
  }

  // ─── DOCUMENT OPERATIONS ──────────────────────────────────

  /// Save a list of documents to metadata
  Future<void> saveDocuments(List<ScanDocument> documents) async {
    final file = await _metaFilePath;
    final jsonList = documents.map((d) => d.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }

  /// Load all documents from metadata
  Future<List<ScanDocument>> loadDocuments() async {
    try {
      final file = await _metaFilePath;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final jsonList = jsonDecode(content) as List<dynamic>;
      return jsonList
          .map((j) => ScanDocument.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Create a new folder for a document
  Future<String> createDocumentFolder(String documentId) async {
    final dir = await _storageDir;
    final folder = Directory(p.join(dir.path, documentId));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  /// Save an image file to a document folder
  Future<String> saveImageToDocument(
      String documentId, String sourcePath, String pageId) async {
    final folderPath = await createDocumentFolder(documentId);
    final extension = p.extension(sourcePath);
    final destPath = p.join(folderPath, '$pageId$extension');
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Delete a document and all its files
  Future<void> deleteDocument(String documentId) async {
    final dir = await _storageDir;
    final folder = Directory(p.join(dir.path, documentId));
    if (await folder.exists()) {
      await folder.delete(recursive: true);
    }
  }

  /// Rename a document
  Future<void> renameDocument(
      List<ScanDocument> documents, String documentId, String newName) async {
    final doc = documents.firstWhere((d) => d.id == documentId);
    doc.name = newName;
    doc.updatedAt = DateTime.now();
    await saveDocuments(documents);
  }

  // ─── SEARCH ───────────────────────────────────────────────

  /// Search documents by name
  List<ScanDocument> searchDocuments(
      List<ScanDocument> documents, String query) {
    if (query.isEmpty) return documents;
    final lowerQuery = query.toLowerCase();
    return documents
        .where((d) => d.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  // ─── FOLDER MANAGEMENT ────────────────────────────────────

  /// List all user-created folders (directories inside storage)
  Future<List<String>> listFolders() async {
    final dir = await _storageDir;
    final entities = await dir.list().toList();
    return entities
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
  }

  /// Get storage path for external use
  Future<String> getStoragePath() async {
    final dir = await _storageDir;
    return dir.path;
  }
}
