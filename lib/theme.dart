import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

//
// Flutter has a color profile issue so colors will look different
// on Apple devices.
// https://github.com/flutter/flutter/issues/55092
// https://github.com/flutter/flutter/issues/39113
//

extension NolColors on Colors {
  static const lkBlue = Color(0xFF5A8BFF);
  static const lkDarkBlue = Color(0xFF00153C);
  static Color nolColor = HexColor.fromHex('#531b28');
  static Color redPink = HexColor.fromHex('#ef4056');
  static Color greenyBlue = HexColor.fromHex('#50bcb6');
  static Color grapPurple = HexColor.fromHex("#5c202e");

}

extension HexColor on Color {

  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class NolTheme {
  //
  final bgColor = NolColors.nolColor;
  final textColor = Colors.white;
  final cardColor = NolColors.grapPurple;
  final accentColor = NolColors.redPink;

  ThemeData buildThemeData(BuildContext ctx) => ThemeData(
        backgroundColor: bgColor,
        // accentColor: accentColor,
        // colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue),
        appBarTheme: AppBarTheme(
          backgroundColor: cardColor,
        ),
        cardColor: cardColor,
        scaffoldBackgroundColor: bgColor,
        canvasColor: bgColor,
        iconTheme: IconThemeData(
          color: textColor,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            primary: NolColors.redPink
          )
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            textStyle:
                MaterialStateProperty.all<TextStyle>(GoogleFonts.montserrat(
              fontSize: 15,
            )),
            padding: MaterialStateProperty.all<EdgeInsets>(
                const EdgeInsets.symmetric(vertical: 20, horizontal: 25)),
            shape: MaterialStateProperty.all<OutlinedBorder>(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
            // backgroundColor: MaterialStateProperty.all<Color>(accentColor),
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.disabled)) {
                return accentColor.withOpacity(0.5);
              }
              return accentColor;
            }),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          checkColor: MaterialStateProperty.all(Colors.white),
          fillColor: MaterialStateProperty.all(accentColor),
        ),
        // switchTheme: SwitchThemeData(
        //   trackColor: MaterialStateProperty.resolveWith((states) {
        //     print('states: $states');
        //     if (states.contains(MaterialState.disabled)) {
        //       return Colors.red;
        //     }
        //     return accentColor;
        //   }),
        // ),
        dialogTheme: DialogTheme(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        textTheme: GoogleFonts.montserratTextTheme(
          Theme.of(ctx).textTheme,
        ).apply(
          displayColor: textColor,
          bodyColor: textColor,
          decorationColor: textColor,
        ),
        hintColor: Colors.red,
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(
            color: Colors.white,
          ),
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(.5),
          ),
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      );
}
