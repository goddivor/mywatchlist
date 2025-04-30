import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:mywatchlist/utils/file_helper.dart';

class SidebarBackgroundManager {
  static final SidebarBackgroundManager _instance = SidebarBackgroundManager._internal();
  
  factory SidebarBackgroundManager() {
    return _instance;
  }
  
  SidebarBackgroundManager._internal();
  
  static SidebarBackgroundManager get instance => _instance;
  
  final FileHelper _fileHelper = FileHelper.instance;
  static const String _keyBgImagePath = "bg_image_path";
  
  /// Pick and save a new background image
  Future<String?> setNewBackgroundImage({
    bool compress = true,
    BuildContext? context,
  }) async {
    try {
      // Pick image from gallery
      final File? pickedFile = await _fileHelper.pickImageFromGallery(
        compress: compress,
        maxWidth: 1920,
        maxHeight: 1080,
        quality: 85,
      );
      
      if (pickedFile == null) {
        return null;
      }
      
      // Save the file with 'sidebar_bg' prefix
      final File? savedFile = await _fileHelper.saveImageToAppDirectory(
        pickedFile,
        prefix: 'sidebar_bg',
      );
      
      if (savedFile == null) {
        throw Exception('Failed to save background image');
      }
      
      // Get previous background image path
      final String? previousPath = await _getBackgroundImagePath();
      
      // Delete previous background image if it exists
      if (previousPath != null && previousPath.isNotEmpty) {
        await _fileHelper.deleteFile(previousPath);
      }
      
      // Save the new path to SharedPreferences
      await _saveBackgroundImagePath(savedFile.path);
      
      // Show success message if context is provided
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Background image updated'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      return savedFile.path;
    } catch (e) {
      debugPrint('Error setting new background image: $e');
      
      // Show error message if context is provided
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set background image: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      return null;
    }
  }
  
  /// Remove the current background image
  Future<bool> removeBackgroundImage({BuildContext? context}) async {
    try {
      // Get current background image path
      final String? currentPath = await _getBackgroundImagePath();
      
      if (currentPath == null || currentPath.isEmpty) {
        return false;
      }
      
      // Delete the file
      final deleted = await _fileHelper.deleteFile(currentPath);
      
      if (deleted) {
        // Clear the path in SharedPreferences
        await _saveBackgroundImagePath(null);
        
        // Show success message if context is provided
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Background image removed'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error removing background image: $e');
      
      // Show error message if context is provided
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove background image: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      return false;
    }
  }
  
  /// Get the current background image path, checking if it exists
  Future<String?> getCurrentBackgroundImagePath() async {
    // Get current path from SharedPreferences
    final String? currentPath = await _getBackgroundImagePath();
    
    if (currentPath == null || currentPath.isEmpty) {
      return null;
    }
    
    // Check if the file exists
    final exists = await _fileHelper.fileExists(currentPath);
    
    if (!exists) {
      // Clear the path if file doesn't exist
      await _saveBackgroundImagePath(null);
      return null;
    }
    
    return currentPath;
  }
  
  /// Set a default background image from assets
  Future<String?> setDefaultBackgroundImage(String assetPath, {BuildContext? context}) async {
    try {
      // Get app documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String appDocPath = appDocDir.path;
      
      // Create a unique filename
      final String filename = 'sidebar_bg_default.png';
      final String savePath = '$appDocPath/$filename';
      
      // Copy asset to file
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();
      
      // Write to file
      final File file = File(savePath);
      await file.writeAsBytes(bytes);
      
      // Get previous background image path
      final String? previousPath = await _getBackgroundImagePath();
      
      // Delete previous background image if it exists
      if (previousPath != null && previousPath.isNotEmpty) {
        await _fileHelper.deleteFile(previousPath);
      }
      
      // Save the new path to SharedPreferences
      await _saveBackgroundImagePath(file.path);
      
      // Show success message if context is provided
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Default background applied'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      return file.path;
    } catch (e) {
      debugPrint('Error setting default background image: $e');
      
      // Show error message if context is provided
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set default background: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      return null;
    }
  }
  
  // Private method to get background image path from SharedPreferences
  Future<String?> _getBackgroundImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBgImagePath);
  }
  
  // Private method to save background image path to SharedPreferences
  Future<void> _saveBackgroundImagePath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_keyBgImagePath, path);
    } else {
      await prefs.remove(_keyBgImagePath);
    }
    
    // Also try to update UserMal.instance.pref if it's initialized
    try {
      if (UserMal.instance.pref != null) {
        UserMal.instance.pref.bgImagePath = path;
      }
    } catch (e) {
      // Ignore errors if pref is not initialized
      debugPrint('Note: Could not update UserMal.pref (not initialized yet): $e');
    }
  }
}