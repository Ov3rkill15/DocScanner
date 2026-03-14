import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/camera/camera_screen.dart';
import '../features/crop/crop_screen.dart';
import '../features/editor/editor_screen.dart';
import '../features/preview/preview_screen.dart';
import '../features/id_card/id_card_screen.dart';
import '../features/signature/signature_screen.dart';
import '../features/signature/signature_gallery_screen.dart';
import '../features/signature/signature_overlay_screen.dart';

/// Named route constants
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String camera = '/camera';
  static const String crop = '/crop';
  static const String editor = '/editor';
  static const String preview = '/preview';
  static const String idCard = '/id-card';
  static const String signature = '/signature';
  static const String signatureGallery = '/signature-gallery';
  static const String signatureOverlay = '/signature-overlay';


  /// Generate route from settings
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _buildRoute(const HomeScreen(), settings);

      case camera:
        final mode = settings.arguments as String? ?? 'document';
        return _buildRoute(CameraScreen(mode: mode), settings);

      case crop:
        final imagePath = settings.arguments as String;
        return _buildRoute(CropScreen(imagePath: imagePath), settings);

      case editor:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(
          EditorScreen(imagePaths: args['imagePaths'] as List<String>),
          settings,
        );

      case preview:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(
          PreviewScreen(
            imagePaths: args['imagePaths'] as List<String>,
            documentName: args['documentName'] as String? ?? 'Untitled',
          ),
          settings,
        );

      case idCard:
        return _buildRoute(const IdCardScreen(), settings);

      case signature:
        final pdfPath = settings.arguments as String?;
        return _buildRoute(SignatureScreen(pdfPath: pdfPath), settings);

      case signatureGallery:
        final docPath = settings.arguments as String?;
        return _buildRoute(
            SignatureGalleryScreen(documentImagePath: docPath), settings);

      case signatureOverlay:
        final args = settings.arguments as Map<String, dynamic>;
        return _buildRoute(
          SignatureOverlayScreen(
            documentImagePath: args['documentImagePath'] as String,
            signaturePath: args['signaturePath'] as String,
          ),
          settings,
        );



      default:
        return _buildRoute(const HomeScreen(), settings);
    }
  }

  /// Smooth page transition
  static Route<dynamic> _buildRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }
}
