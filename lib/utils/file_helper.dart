import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

class FileHelper {
  static final FileHelper _instance = FileHelper._internal();
  
  factory FileHelper() {
    return _instance;
  }
  
  FileHelper._internal();
  
  static FileHelper get instance => _instance;
  
  /// Allowed image file extensions
  final Map<String, String> allowedImageTypes = {
    'jpeg': 'jpg',
    'jpg': 'jpg',
    'png': 'png',
    'gif': 'gif',
  };
  
  /// Pick image from gallery with option to compress
  Future<File?> pickImageFromGallery({
    bool compress = true,
    int maxWidth = 1200,
    int maxHeight = 1200,
    int quality = 85,
  }) async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: compress ? quality : null,
      );
      
      if (pickedFile == null) {
        return null;
      }
      
      // Verify file extension is allowed
      final extension = path.extension(pickedFile.path).toLowerCase().replaceFirst('.', '');
      if (!allowedImageTypes.containsKey(extension)) {
        throw Exception('Unsupported file type: $extension. Allowed types: ${allowedImageTypes.keys.join(', ')}');
      }
      
      File imageFile = File(pickedFile.path);
      
      // Compress large images if needed
      if (compress && !extension.contains('gif')) {
        final fileSize = await imageFile.length();
        
        // Only compress if file is larger than 1MB
        if (fileSize > 1024 * 1024) {
          final compressedFile = await _compressImage(
            imageFile,
            quality: quality,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
          );
          
          if (compressedFile != null) {
            imageFile = compressedFile;
          }
        }
      }
      
      return imageFile;
    } catch (e) {
      debugPrint('Error picking image: $e');
      rethrow;
    }
  }
  
  /// Compress image file
  Future<File?> _compressImage(
    File file, {
    int quality = 85,
    int maxWidth = 1200,
    int maxHeight = 1200,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${const Uuid().v4()}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1080,
        minHeight: 1080,
      );
      
      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }
  
  /// Save image to app documents directory with a unique name
  Future<File?> saveImageToAppDirectory(File imageFile, {String prefix = 'image'}) async {
    try {
      // Get app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      
      // Create a unique filename with timestamp and UUID
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String uuid = const Uuid().v4().substring(0, 8);
      final String extension = path.extension(imageFile.path).toLowerCase();
      final String filename = '${prefix}_${timestamp}_$uuid$extension';
      final String savePath = '$appDocPath/$filename';
      
      // Copy the file to app documents directory
      final File savedFile = await imageFile.copy(savePath);
      
      return savedFile;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }
  
  /// Delete file if it exists
  Future<bool> deleteFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return false;
    }
    
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }
  
  /// Check if file exists
  Future<bool> fileExists(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return false;
    }
    
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      debugPrint('Error checking if file exists: $e');
      return false;
    }
  }
  
  /// Get file size in readable format
  Future<String> getFileSize(String filePath, {int decimals = 1}) async {
    try {
      final file = File(filePath);
      final bytes = await file.length();
      
      if (bytes <= 0) return "0 B";
      
      const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
      var i = (math.log(bytes) / math.log(1024)).floor();
      
      return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
    } catch (e) {
      debugPrint('Error getting file size: $e');
      return "Unknown";
    }
  }
}