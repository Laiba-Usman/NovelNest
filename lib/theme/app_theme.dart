import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Color Palette Constants
class AppColors {
  static const Color background = Color(0xFFF9F3E7);
  static const Color primaryNavy = Color(0xFF1B2A4A);
  static const Color secondaryText = Color(0xFF6B6B6B);
  static const Color accentGold = Color(0xFFC9A24B);
  static const Color accentCoral = Color(0xFFDD8B6E);
  static const Color cardBackground = Colors.white;
  static const Color borderLight = Color(0xFFE8E0D0);
}

// Typography Styles
class AppTypography {
  static TextStyle get logo => GoogleFonts.playfairDisplay(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryNavy,
      );

  static TextStyle get heading => GoogleFonts.playfairDisplay(
        fontWeight: FontWeight.bold,
        color: AppColors.primaryNavy,
      );

  static TextStyle get subtitle => GoogleFonts.lora(
        fontStyle: FontStyle.italic,
        color: AppColors.secondaryText,
      );

  static TextStyle get body => GoogleFonts.lora(
        fontWeight: FontWeight.normal,
        color: AppColors.primaryNavy,
      );

  static TextStyle get uiLabel => GoogleFonts.inter(
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
        color: AppColors.secondaryText,
      );
}

// Reusable Components
class GoldPillBadge extends StatelessWidget {
  final String label;

  const GoldPillBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF8A6A23), // Darkened accentGold
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentCoral,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const SecondaryButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _NavBarItem(Icons.home_outlined, Icons.home, 'Home'),
      _NavBarItem(Icons.explore_outlined, Icons.explore, 'Discover'),
      _NavBarItem(Icons.bookmark_border, Icons.bookmark, 'Bookmarks'),
      _NavBarItem(Icons.library_books_outlined, Icons.library_books, 'Library'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(tabs.length, (index) {
              final isSelected = index == currentIndex;
              final tab = tabs[index];

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.accentGold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? tab.activeIcon : tab.inactiveIcon,
                        color: isSelected ? Colors.white : AppColors.secondaryText,
                        size: 22,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          tab.label,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;

  _NavBarItem(this.inactiveIcon, this.activeIcon, this.label);
}
