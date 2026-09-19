import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/app_models.dart';
import '../services/hive_service.dart';

class ProfileImageCropperDialog extends StatefulWidget {
  const ProfileImageCropperDialog({
    super.key,
    required this.currentSettings,
    required this.onProfileUpdated,
  });

  final AppSettings currentSettings;
  final Function(AppSettings updatedSettings) onProfileUpdated;

  @override
  State<ProfileImageCropperDialog> createState() =>
      _ProfileImageCropperDialogState();
}

class _ProfileImageCropperDialogState extends State<ProfileImageCropperDialog> {
  final GlobalKey _cropAreaKey = GlobalKey();
  final TransformationController _transformController =
      TransformationController();

  File? _selectedFile;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.currentSettings.profileImagePath.isNotEmpty) {
      final existingFile = File(widget.currentSettings.profileImagePath);
      if (existingFile.existsSync()) {
        _selectedFile = existingFile;
      }
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result.isNotEmpty && result.first.path != null) {
        final file = File(result.first.path!);
        if (await file.exists()) {
          setState(() {
            _selectedFile = file;
            _transformController.value = Matrix4.identity();
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load image: $e';
      });
    }
  }

  Future<void> _saveCroppedImage() async {
    if (_selectedFile == null) return;

    setState(() => _isProcessing = true);

    try {
      final boundary = _cropAreaKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Could not capture crop area');
      }

      // Render at pixel ratio 2.5 for crisp avatar while maintaining compact file size (~15-40 KB)
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode image data');
      }

      final pngBytes = byteData.buffer.asUint8List();

      final docsDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory('${docsDir.path}/avatars');
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final savedFile = File('${avatarsDir.path}/profile_avatar_$timestamp.png');
      await savedFile.writeAsBytes(pngBytes);

      // Clean up old avatar files if any
      final oldPath = widget.currentSettings.profileImagePath;
      if (oldPath.isNotEmpty && oldPath != savedFile.path) {
        try {
          final oldFile = File(oldPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {}
      }

      final updated = widget.currentSettings.copyWith(
        profileImagePath: savedFile.path,
      );

      await HiveService.instance.saveSettings(updated);
      widget.onProfileUpdated(updated);

      if (mounted) {
        Navigator.pop(context, savedFile.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Error saving cropped image: $e';
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    setState(() => _isProcessing = true);

    try {
      final oldPath = widget.currentSettings.profileImagePath;
      if (oldPath.isNotEmpty) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      final updated = widget.currentSettings.copyWith(profileImagePath: '');
      await HiveService.instance.saveSettings(updated);
      widget.onProfileUpdated(updated);

      if (mounted) {
        Navigator.pop(context, '');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Failed to remove picture: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userName = widget.currentSettings.userName;
    final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Profile Picture',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Drag & pinch to zoom and reposition within the circular crop frame.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],

            // Crop & Preview Area
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Container with border
                  Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF141A2E)
                          : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF6366F1),
                        width: 3.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: RepaintBoundary(
                        key: _cropAreaKey,
                        child: _selectedFile != null
                            ? InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.5,
                                maxScale: 4.0,
                                boundaryMargin: const EdgeInsets.all(120),
                                child: Image.file(
                                  _selectedFile!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => _fallbackAvatar(userInitial),
                                ),
                              )
                            : _fallbackAvatar(userInitial),
                      ),
                    ),
                  ),

                  // Overlay grid guide for framing
                  if (_selectedFile != null)
                    IgnorePointer(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _pickImage,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(_selectedFile == null ? 'Select Image' : 'Replace Image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (widget.currentSettings.profileImagePath.isNotEmpty || _selectedFile != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _removeProfileImage,
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    label: const Text('Remove', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // Save Profile Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_selectedFile != null && !_isProcessing)
                    ? _saveCroppedImage
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Profile Picture',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar(String initial) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
