import 'package:flutter/cupertino.dart';

class MyThemeData {
  // LIGHT MODE COLORS
  static const Color lightPrimary = Color(0xFF0F53B9);
  static const Color lightBackground = Color(0xFFB8E3E9);

  // DARK MODE COLORS
  static const Color darkPrimary = Color(0xFF0F53B9);
  static const Color darkBackground = Color(0xFF0F0E47);

  // Complete Themes
  static final CupertinoThemeData lightTheme = CupertinoThemeData(
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground
  );

  static final CupertinoThemeData darkTheme = CupertinoThemeData(
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground
  );
}