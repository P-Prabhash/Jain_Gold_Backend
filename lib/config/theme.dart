// lib/config/theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ============================================================
  // GOLD
  // ============================================================

  static const Color goldPrimary =
      Color(0xFFD4AF37);

  static const Color goldDark =
      Color(0xFFAA7C11);

  static const Color goldLight =
      Color(0xFFF7E7CE);

  static const Color goldAccent =
      Color(0xFFFFD700);

  // ============================================================
  // SILVER
  // ============================================================

  static const Color silverPrimary =
      Color(0xFF94A3B8);

  static const Color silverLight =
      Color(0xFFF1F5F9);

  static const Color silverDark =
      Color(0xFF64748B);

  static const Color silverBorder =
      Color(0xFFCBD5E1);

  // ============================================================
  // NAVY / DARK
  // ============================================================

  static const Color darkNavy =
      Color(0xFF0F172A);

  static const Color darkNavyLight =
      Color(0xFF1E293B);

  static const Color darkCharcoal =
      Color(0xFF1A1A1A);

  // ============================================================
  // BACKGROUNDS
  // ============================================================

  static const Color backgroundLight =
      Color(0xFFF8FAFC);

  static const Color surfaceWhite =
      Color(0xFFFFFFFF);

  // ============================================================
  // STATUS
  // ============================================================

  static const Color statusActive =
      Color(0xFF0D9488);

  static const Color statusClosed =
      Color(0xFF64748B);

  static const Color statusPending =
      Color(0xFFD97706);

  static const Color statusDanger =
      Color(0xFFDC2626);

  static const Color statusInfo =
      Color(0xFF2563EB);

  // ============================================================
  // GLOBAL LIGHT THEME
  // ============================================================

  static ThemeData get lightTheme {
    final baseTextTheme =
        GoogleFonts.plusJakartaSansTextTheme();

    return ThemeData(
      useMaterial3: true,

      brightness:
          Brightness.light,

      // ========================================================
      // COLORS
      // ========================================================

      primaryColor:
          goldPrimary,

      scaffoldBackgroundColor:
          backgroundLight,

      colorScheme:
          const ColorScheme.light(
        primary:
            goldPrimary,

        onPrimary:
            darkNavy,

        secondary:
            silverDark,

        onSecondary:
            Colors.white,

        surface:
            surfaceWhite,

        onSurface:
            darkNavy,

        surfaceContainerHighest:
            silverLight,

        outline:
            silverBorder,

        error:
            statusDanger,

        onError:
            Colors.white,
      ),

      // ========================================================
      // APP BAR
      // ========================================================

      appBarTheme:
          AppBarTheme(
        backgroundColor:
            darkNavy,

        foregroundColor:
            Colors.white,

        elevation:
            0,

        scrolledUnderElevation:
            0,

        centerTitle:
            false,

        titleTextStyle:
            GoogleFonts.plusJakartaSans(
          fontSize:
              18,

          fontWeight:
              FontWeight.w700,

          color:
              Colors.white,
        ),

        iconTheme:
            const IconThemeData(
          color:
              goldPrimary,
        ),

        actionsIconTheme:
            const IconThemeData(
          color:
              Colors.white,
        ),
      ),

      // ========================================================
      // CARD
      // ========================================================

      cardTheme:
          CardThemeData(
        color:
            surfaceWhite,

        elevation:
            1,

        shadowColor:
            Colors.black.withValues(alpha: 
          0.05,
        ),

        margin:
            EdgeInsets.zero,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),

          side:
              const BorderSide(
            color:
                silverBorder,

            width:
                0.8,
          ),
        ),
      ),

      // ========================================================
      // ELEVATED BUTTON
      // ========================================================

      elevatedButtonTheme:
          ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              goldPrimary,

          foregroundColor:
              darkNavy,

          disabledBackgroundColor:
              silverLight,

          disabledForegroundColor:
              silverDark,

          elevation:
              2,

          minimumSize:
              const Size(
            0,
            46,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                20,

            vertical:
                14,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),
          ),

          textStyle:
              GoogleFonts.plusJakartaSans(
            fontSize:
                13,

            fontWeight:
                FontWeight.w700,

            letterSpacing:
                0.3,
          ),
        ),
      ),

      // ========================================================
      // OUTLINED BUTTON
      // ========================================================

      outlinedButtonTheme:
          OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              darkNavy,

          side:
              const BorderSide(
            color:
                silverBorder,

            width:
                1.2,
          ),

          minimumSize:
              const Size(
            0,
            44,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                18,

            vertical:
                13,
          ),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),
          ),

          textStyle:
              GoogleFonts.plusJakartaSans(
            fontSize:
                13,

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),

      // ========================================================
      // TEXT BUTTON
      // ========================================================

      textButtonTheme:
          TextButtonThemeData(
        style:
            TextButton.styleFrom(
          foregroundColor:
              goldDark,

          minimumSize:
              const Size(
            0,
            40,
          ),

          padding:
              const EdgeInsets.symmetric(
            horizontal:
                10,

            vertical:
                8,
          ),

          textStyle:
              GoogleFonts.plusJakartaSans(
            fontSize:
                12,

            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // INPUT FIELDS
      // ========================================================

      inputDecorationTheme:
          InputDecorationTheme(
        filled:
            true,

        fillColor:
            Colors.white,

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal:
              16,

          vertical:
              14,
        ),

        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),

          borderSide:
              const BorderSide(
            color:
                silverBorder,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),

          borderSide:
              const BorderSide(
            color:
                silverBorder,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),

          borderSide:
              const BorderSide(
            color:
                goldPrimary,

            width:
                1.8,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),

          borderSide:
              const BorderSide(
            color:
                statusDanger,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),

          borderSide:
              const BorderSide(
            color:
                statusDanger,

            width:
                1.8,
          ),
        ),

        labelStyle:
            const TextStyle(
          color:
              silverDark,

          fontSize:
              13,
        ),

        floatingLabelStyle:
            const TextStyle(
          color:
              goldDark,

          fontSize:
              13,

          fontWeight:
              FontWeight.w600,
        ),

        hintStyle:
            TextStyle(
          color:
              silverDark.withValues(alpha: 
            0.7,
          ),

          fontSize:
              13,
        ),

        prefixIconColor:
            silverDark,

        suffixIconColor:
            silverDark,

        errorStyle:
            const TextStyle(
          color:
              statusDanger,

          fontSize:
              11,

          fontWeight:
              FontWeight.w600,
        ),
      ),

      // ========================================================
      // DROPDOWN
      // ========================================================

      dropdownMenuTheme:
          DropdownMenuThemeData(
        textStyle:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontSize:
              13,
        ),

        inputDecorationTheme:
            InputDecorationTheme(
          filled:
              true,

          fillColor:
              Colors.white,

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),

            borderSide:
                const BorderSide(
              color:
                  silverBorder,
            ),
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),

            borderSide:
                const BorderSide(
              color:
                  silverBorder,
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              8,
            ),

            borderSide:
                const BorderSide(
              color:
                  goldPrimary,

              width:
                  1.8,
            ),
          ),
        ),
      ),

      // ========================================================
      // DATA TABLE
      // ========================================================

      dataTableTheme:
          DataTableThemeData(
        headingRowColor:
            WidgetStateProperty.all(
          silverLight,
        ),

        dataRowColor:
            WidgetStateProperty.all(
          Colors.white,
        ),

        headingTextStyle:
            GoogleFonts.plusJakartaSans(
          fontSize:
              12,

          fontWeight:
              FontWeight.w800,

          color:
              darkNavy,
        ),

        dataTextStyle:
            GoogleFonts.plusJakartaSans(
          fontSize:
              12,

          color:
              darkNavy,
        ),

        dividerThickness:
            0.6,

        horizontalMargin:
            14,

        columnSpacing:
            22,
      ),

      // ========================================================
      // LIST TILE
      // ========================================================

      listTileTheme:
          ListTileThemeData(
        tileColor:
            Colors.white,

        iconColor:
            goldDark,

        textColor:
            darkNavy,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal:
              12,

          vertical:
              4,
        ),

        dense:
            false,
      ),

      // ========================================================
      // DIALOG
      // ========================================================

      dialogTheme:
          DialogThemeData(
        backgroundColor:
            Colors.white,

        surfaceTintColor:
            Colors.transparent,

        elevation:
            8,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),

        titleTextStyle:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontSize:
              18,

          fontWeight:
              FontWeight.w800,
        ),

        contentTextStyle:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavyLight,

          fontSize:
              13,
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBarTheme:
          BottomNavigationBarThemeData(
        backgroundColor:
            darkNavy,

        selectedItemColor:
            goldPrimary,

        unselectedItemColor:
            silverDark,

        type:
            BottomNavigationBarType.fixed,

        elevation:
            8,

        selectedLabelStyle:
            GoogleFonts.plusJakartaSans(
          fontWeight:
              FontWeight.w600,

          fontSize:
              11,
        ),

        unselectedLabelStyle:
            GoogleFonts.plusJakartaSans(
          fontSize:
              10,
        ),
      ),

      // ========================================================
      // SNACKBAR
      // ========================================================

      snackBarTheme:
          SnackBarThemeData(
        backgroundColor:
            darkNavy,

        contentTextStyle:
            GoogleFonts.plusJakartaSans(
          color:
              Colors.white,

          fontSize:
              12,

          fontWeight:
              FontWeight.w600,
        ),

        behavior:
            SnackBarBehavior.floating,

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            8,
          ),
        ),
      ),

      // ========================================================
      // PROGRESS INDICATOR
      // ========================================================

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(
        color:
            goldPrimary,

        linearTrackColor:
            silverLight,

        circularTrackColor:
            silverLight,
      ),

      // ========================================================
      // CHECKBOX
      // ========================================================

      checkboxTheme:
          CheckboxThemeData(
        fillColor:
            WidgetStateProperty
                .resolveWith(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return goldPrimary;
            }

            return Colors.white;
          },
        ),

        checkColor:
            WidgetStateProperty.all(
          darkNavy,
        ),

        side:
            const BorderSide(
          color:
              silverBorder,

          width:
              1.2,
        ),

        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            4,
          ),
        ),
      ),

      // ========================================================
      // SWITCH
      // ========================================================

      switchTheme:
          SwitchThemeData(
        thumbColor:
            WidgetStateProperty
                .resolveWith(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return goldPrimary;
            }

            return silverDark;
          },
        ),

        trackColor:
            WidgetStateProperty
                .resolveWith(
          (states) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return goldLight;
            }

            return silverLight;
          },
        ),
      ),

      // ========================================================
      // DIVIDER
      // ========================================================

      dividerTheme:
          const DividerThemeData(
        color:
            silverBorder,

        thickness:
            0.7,

        space:
            1,
      ),

      // ========================================================
      // TYPOGRAPHY
      // ========================================================

      textTheme:
          baseTextTheme.copyWith(
        displayLarge:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.bold,
        ),

        displayMedium:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.bold,
        ),

        headlineLarge:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w800,
        ),

        headlineMedium:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w700,
        ),

        headlineSmall:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w700,
        ),

        titleLarge:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w700,

          fontSize:
              18,
        ),

        titleMedium:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w600,

          fontSize:
              15,
        ),

        titleSmall:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w600,

          fontSize:
              13,
        ),

        bodyLarge:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontSize:
              14,
        ),

        bodyMedium:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavyLight,

          fontSize:
              13,
        ),

        bodySmall:
            GoogleFonts.plusJakartaSans(
          color:
              silverDark,

          fontSize:
              11,
        ),

        labelLarge:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w700,

          fontSize:
              13,
        ),

        labelMedium:
            GoogleFonts.plusJakartaSans(
          color:
              darkNavy,

          fontWeight:
              FontWeight.w600,

          fontSize:
              11,
        ),
      ),
    );
  }

  // ============================================================
  // GOLD GRADIENT
  // ============================================================

  static const LinearGradient goldGradient =
      LinearGradient(
    colors: [
      Color(0xFFE5C058),
      Color(0xFFD4AF37),
      Color(0xFFAA7C11),
    ],

    begin:
        Alignment.topLeft,

    end:
        Alignment.bottomRight,
  );

  // ============================================================
  // DARK NAVY GRADIENT
  // ============================================================

  static const LinearGradient darkNavyGradient =
      LinearGradient(
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E293B),
    ],

    begin:
        Alignment.topLeft,

    end:
        Alignment.bottomRight,
  );

  // ============================================================
  // SILVER GRADIENT
  // ============================================================

  static const LinearGradient silverGradient =
      LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF1F5F9),
      Color(0xFFE2E8F0),
    ],

    begin:
        Alignment.topLeft,

    end:
        Alignment.bottomRight,
  );
}