extension StringExtension on String {
  String formatForUrl() {
    if (trim() == '...') return '-';
    
    // Remove dots
    String result = replaceAll('.', '');
    
    // Replace spaces, colons, slashes with underscores
    result = result.replaceAll(RegExp(r'[ :/]'), '_');
    
    // Keep hyphens as is
    // Remove any other special characters
    result = result.replaceAll(RegExp(r'[^\w\-]'), '');
    
    // Replace double underscores with a single one
    while (result.contains('__')) {
      result = result.replaceAll('__', '_');
    }
    
    return result;
  }
}