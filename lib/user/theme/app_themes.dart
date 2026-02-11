import 'package:flutter/material.dart';

class AppTheme {
  final String name;
  final String displayName;
  final ThemeData lightTheme;
  final ThemeData darkTheme;
  final String imagePath;

  const AppTheme({
    required this.name,
    required this.displayName,
    required this.lightTheme,
    required this.darkTheme,
    required this.imagePath,
  });
}

class AppThemes {
  static const String springName = 'spring';
  static const String summerName = 'summer';
  static const String autumnName = 'autumn';
  static const String winterName = 'winter';

  // Spring theme (light greens and pinks)
  static final springTheme = AppTheme(
    name: springName,
    displayName: 'Spring',
    imagePath: 'assets/images/spring.jpg',
    lightTheme: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF76C893),
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF76C893),
        secondary: Color(0xFFFF9AA2),
        surface: Color(0xFFFFFFFF),
        background: Color(0xFFF6F7F9),
        error: Color(0xFFB00020),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFF000000),
        onBackground: Color(0xFF000000),
        onError: Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFF1B4332)),
        bodyLarge: TextStyle(color: Color(0xFF1B4332)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF76C893),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF76C893),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF76C893)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.green,
      primaryColor: const Color(0xFF2D6A4F),
      scaffoldBackgroundColor: const Color(0xFF1B4332),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF2D6A4F),
        secondary: Color(0xFFFF9AA2),
        surface: Color(0xFF2D3B45),
        background: Color(0xFF1B4332),
        error: Color(0xFFCF6679),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onBackground: Color(0xFFFFFFFF),
        onError: Color(0xFF000000),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFFD8F3DC)),
        bodyLarge: TextStyle(color: Color(0xFFD8F3DC)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF2D6A4F),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF2D3B45),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF2D6A4F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF2D6A4F)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
  );

  // Summer theme (blues and yellows)
  static final summerTheme = AppTheme(
    name: summerName,
    displayName: 'Summer',
    imagePath: 'assets/images/summer.jpg',
    lightTheme: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: const Color(0xFF48CAE4),
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF48CAE4),
        secondary: Color(0xFFFFD166),
        surface: Color(0xFFFFFFFF),
        background: Color(0xFFF8F9FA),
        error: Color(0xFFB00020),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFF000000),
        onBackground: Color(0xFF000000),
        onError: Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFF03045E)),
        bodyLarge: TextStyle(color: Color(0xFF03045E)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF48CAE4),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF48CAE4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF48CAE4)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: const Color(0xFF0077B6),
      scaffoldBackgroundColor: const Color(0xFF03045E),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF0077B6),
        secondary: Color(0xFFFFD166),
        surface: Color(0xFF1E293B),
        background: Color(0xFF03045E),
        error: Color(0xFFCF6679),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onBackground: Color(0xFFFFFFFF),
        onError: Color(0xFF000000),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFFCAF0F8)),
        bodyLarge: TextStyle(color: Color(0xFFCAF0F8)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF0077B6),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF0077B6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF0077B6)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
  );

  // Autumn theme (oranges and browns)
  static final autumnTheme = AppTheme(
    name: autumnName,
    displayName: 'Autumn',
    imagePath: 'assets/images/fall.jpg',
    lightTheme: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.orange,
      primaryColor: const Color(0xFFF9A826),
      scaffoldBackgroundColor: const Color(0xFFF9F7F3),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFF9A826),
        secondary: Color(0xFF94414F),
        surface: Color(0xFFFFFFFF),
        background: Color(0xFFF9F7F3),
        error: Color(0xFFB00020),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
        onBackground: Color(0xFF000000),
        onError: Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFF4A4238)),
        bodyLarge: TextStyle(color: Color(0xFF4A4238)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFFF9A826),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFFF9A826),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFFF9A826)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.orange,
      primaryColor: const Color(0xFFCB8A00),
      scaffoldBackgroundColor: const Color(0xFF2F2519),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFCB8A00),
        secondary: Color(0xFF94414F),
        surface: Color(0xFF3C2E23),
        background: Color(0xFF2F2519),
        error: Color(0xFFCF6679),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFFFFFFF),
        onSurface: Color(0xFFFFFFFF),
        onBackground: Color(0xFFFFFFFF),
        onError: Color(0xFF000000),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFFF5DEB3)),
        bodyLarge: TextStyle(color: Color(0xFFF5DEB3)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFFCB8A00),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF3C2E23),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFFCB8A00),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFFCB8A00)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
  );

  // Winter theme (blues and purples)
  static final winterTheme = AppTheme(
    name: winterName,
    displayName: 'Winter',
    imagePath: 'assets/images/winter.jpg',
    lightTheme: ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.indigo,
      primaryColor: const Color(0xFF6B7FD7),
      scaffoldBackgroundColor: const Color(0xFFF0F3FA),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF6B7FD7),
        secondary: Color(0xFFBFDBFE),
        surface: Color(0xFFFFFFFF),
        background: Color(0xFFF0F3FA),
        error: Color(0xFFB00020),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFF000000),
        onBackground: Color(0xFF000000),
        onError: Color(0xFFFFFFFF),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFF1E293B)),
        bodyLarge: TextStyle(color: Color(0xFF1E293B)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF6B7FD7),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF6B7FD7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF6B7FD7)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.indigo,
      primaryColor: const Color(0xFF4C5BA6),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF4C5BA6),
        secondary: Color(0xFF93C5FD),
        surface: Color(0xFF1E293B),
        background: Color(0xFF0F172A),
        error: Color(0xFFCF6679),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
        onBackground: Color(0xFFFFFFFF),
        onError: Color(0xFF000000),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Color(0xFFE2E8F0)),
        bodyLarge: TextStyle(color: Color(0xFFE2E8F0)),
      ),
      appBarTheme: const AppBarTheme(
        color: Color(0xFF4C5BA6),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFF4C5BA6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.all(const Color(0xFF4C5BA6)),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    ),
  );

  // List of all available themes
  static final List<AppTheme> availableThemes = [
    springTheme,
    summerTheme,
    autumnTheme,
    winterTheme,
  ];
}