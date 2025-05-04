import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// Extension methods for File class
extension FileExtensions on File {
  /// Get file extension (without dot)
  String get extension => path.extension(this.path).toLowerCase().replaceFirst('.', '');
  
  /// Check if file is an image
  bool get isImage {
    final ext = extension;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }
  
  /// Check if file is a specific type
  bool isType(String extension) {
    return this.extension == extension.toLowerCase().replaceFirst('.', '');
  }
  
  /// Get file name without path
  String get fileName => path.basename(this.path);
  
  /// Get file name without extension
  String get fileNameWithoutExtension => path.basenameWithoutExtension(this.path);
  
  /// Get file directory
  String get directory => path.dirname(this.path);
  
  /// Get file size in bytes
  Future<int> get size async => await this.length();
  
  /// Get readable file size
  Future<String> readableSize({int decimals = 1}) async {
    final bytes = await this.length();
    
    if (bytes <= 0) return "0 B";
    
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (math.log(bytes) / math.log(1024)).floor();
    
    return '${(bytes / math.pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

/// Extension methods for String class to work with file paths
extension StringFileExtensions on String {
  /// Get file extension from path (without dot)
  String get fileExtension => path.extension(this).toLowerCase().replaceFirst('.', '');
  
  /// Check if path is an image
  bool get isImagePath {
    final ext = fileExtension;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }
  
  /// Get file name without path
  String get fileName => path.basename(this);
  
  /// Get file name without extension
  String get fileNameWithoutExtension => path.basenameWithoutExtension(this);
  
  /// Get directory from path
  String get directory => path.dirname(this);
  
  /// Convert to File object
  File toFile() => File(this);
  
  /// Check if file exists
  Future<bool> fileExists() async {
    return await File(this).exists();
  }
}