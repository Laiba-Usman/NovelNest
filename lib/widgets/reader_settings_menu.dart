import 'package:flutter/material.dart';

enum ReaderFontSize {
  small(14.0, 'Small'),
  medium(17.0, 'Medium'),
  large(21.0, 'Large'),
  extraLarge(26.0, 'Extra Large');

  final double size;
  final String label;
  const ReaderFontSize(this.size, this.label);
}

enum ReaderTheme {
  light(Color(0xFFFFFFFF), Color(0xFF2B2B2B)),
  sepia(Color(0xFFFBF7EE), Color(0xFF3A3226)),
  dark(Color(0xFF1A1A1A), Color(0xFFE8E4DA));

  final Color backgroundColor;
  final Color textColor;
  const ReaderTheme(this.backgroundColor, this.textColor);
}

class ReaderSettingsMenu extends StatelessWidget {
  final ReaderFontSize currentFontSize;
  final ReaderTheme currentTheme;
  final double currentLineHeight;
  final ValueChanged<ReaderFontSize> onFontSizeChanged;
  final ValueChanged<ReaderTheme> onThemeChanged;
  final ValueChanged<double> onLineHeightChanged;

  const ReaderSettingsMenu({
    super.key,
    required this.currentFontSize,
    required this.currentTheme,
    required this.currentLineHeight,
    required this.onFontSizeChanged,
    required this.onThemeChanged,
    required this.onLineHeightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      decoration: BoxDecoration(
        color: currentTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: currentTheme.textColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Reader Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: currentTheme.textColor,
              ),
            ),
            const SizedBox(height: 20),

            // Font Size Stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Font Size',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: currentTheme.textColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: currentTheme.textColor,
                      onPressed: currentFontSize.index > 0
                          ? () => onFontSizeChanged(ReaderFontSize.values[currentFontSize.index - 1])
                          : null,
                    ),
                    Container(
                      constraints: const BoxConstraints(minWidth: 80),
                      alignment: Alignment.center,
                      child: Text(
                        currentFontSize.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: currentTheme.textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: currentTheme.textColor,
                      onPressed: currentFontSize.index < ReaderFontSize.values.length - 1
                          ? () => onFontSizeChanged(ReaderFontSize.values[currentFontSize.index + 1])
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Line Height Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Spacing',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: currentTheme.textColor,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: currentLineHeight,
                    min: 1.5,
                    max: 2.2,
                    divisions: 7,
                    activeColor: currentTheme.textColor,
                    inactiveColor: currentTheme.textColor.withValues(alpha: 0.2),
                    onChanged: onLineHeightChanged,
                  ),
                ),
                Text(
                  currentLineHeight.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 14,
                    color: currentTheme.textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Theme Options
            Text(
              'Theme',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: currentTheme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ReaderTheme.values.map((theme) {
                final isSelected = currentTheme == theme;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onThemeChanged(theme),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6.0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFD35400) // Warm coral/rust border
                              : theme.textColor.withValues(alpha: 0.3),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          theme.name[0].toUpperCase() + theme.name.substring(1),
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
