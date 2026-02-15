import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors - Primary Palette
  static const Color brandPrimary = Color(0xFF023047);       // Deep Space Blue - professional, core foundation
  static const Color brandSecondary = Color(0xFF219EBC);     // Blue Green - supportive brand color
  static const Color brandAccent = Color(0xFFFB8500);        // Princeton Orange - high visibility action
  static const Color brandAccentLight = Color(0xFFFFB703);   // Amber Flame - secondary energy/highlight
  static const Color brandNeutral = Color(0xFF8ECAE6);       // Sky Blue Light - soft background/surface base
  
  // Monochrome Base Colors
  static const Color primary = Color(0xFF023047);            // Deep Space Blue as base black
  static const Color secondary = Color(0xFFFFFFFF);          // Pure White
  
  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);            // White
  static const Color surfaceVariant = Color(0xFFF1F8FB);     // Very light blue-tinted gray
  static const Color surfaceDim = brandNeutral;              // Sky Blue Light used for depth
  static const Color surfaceTint = Color(0x1A8ECAE6);        // 10% Sky Blue tint
  
  // Background Colors
  static const Color background = Color(0xFFFFFFFF);         // White
  static const Color backgroundSecondary = Color(0xFFF8FCFE); // Subtle sky-tinted white
  static const Color backgroundTertiary = brandNeutral;      // Sky Blue Light
  
  // Text Colors
  static const Color textPrimary = Color(0xFF023047);        // Deep Space Blue (High contrast)
  static const Color textSecondary = Color(0xFF219EBC);      // Blue Green
  static const Color textTertiary = Color(0xFF5A7E90);       // Muted Deep Blue
  static const Color textOnPrimary = Color(0xFFFFFFFF);      // White on deep blue
  static const Color textOnBrand = Color(0xFFFFFFFF);        // White on brand colors
  static const Color textBrand = brandPrimary;               // Brand color text
  
  // Border & Divider Colors
  static const Color border = brandNeutral;                  // Soft sky blue border
  static const Color borderMedium = Color(0xFF219EBC);       // Blue Green border
  static const Color borderStrong = brandPrimary;            // Deep Space Blue border
  static const Color divider = Color(0xFFE0EEF5);            // Very light divider
  
  // State Colors
  static const Color success = Color(0xFF065F46);            // Deep Emerald
  static const Color successLight = Color(0xFFD1E7DD);       
  static const Color warning = brandAccentLight;             // Amber Flame
  static const Color warningLight = Color(0xFFFFF3CD);       
  static const Color error = Color(0xFFB91C1C);              // Deep Red
  static const Color errorLight = Color(0xFFFEE2E2);         
  static const Color info = brandSecondary;                  // Blue Green
  static const Color infoLight = Color(0xFFE0F2F1);          
  
  // Interactive Elements
  static const Color buttonPrimary = brandPrimary;           // Deep Space Blue
  static const Color buttonSecondary = brandSecondary;       // Blue Green
  static const Color buttonAccent = brandAccent;             // Princeton Orange
  static const Color buttonDisabled = Color(0xFFB0C4CE);     // Desaturated sky blue
  static const Color buttonText = Color(0xFFFFFFFF);         
  static const Color buttonTextSecondary = Color(0xFFFFFFFF); 
  
  // Hover & Focus States
  static const Color hoverLight = Color(0xFFE1F5FE);         
  static const Color hoverBrand = Color(0xFF03415F);         // Slightly lighter than deep space
  static const Color hoverAccent = Color(0xFFE67A00);        // Darker Princeton Orange
  static const Color focus = brandAccent;                    
  static const Color focusRing = Color(0x4DFB8500);          // Semi-transparent Orange
  
  // Shadows
  static const Color shadowLight = Color(0x1A023047);        // 10% Deep Blue
  static const Color shadowMedium = Color(0x33023047);       // 20% Deep Blue
  static const Color shadowDark = Color(0x4D023047);         // 30% Deep Blue
  static const Color shadowBrand = Color(0x33219EBC);        // Blue-Green shadow
  
  // Freight-specific Functional Colors
  static const Color truckActive = brandAccent;              // Active - Princeton Orange
  static const Color truckInactive = brandNeutral;           // Inactive - Sky Blue
  static const Color truckMaintenance = brandAccentLight;    // Maintenance - Amber Flame
  
  static const Color routePlanned = brandNeutral;            // Planned - Sky Blue
  static const Color routeActive = brandSecondary;           // Active - Blue Green
  static const Color routeCompleted = brandPrimary;          // Completed - Deep Space Blue
  static const Color routeDelayed = error;                   // Delayed - Red
  
  static const Color loadAvailable = brandAccentLight;       // Available - Amber
  static const Color loadAssigned = brandSecondary;          // Assigned - Blue Green
  static const Color loadInTransit = brandPrimary;           // In-transit - Deep Blue
  static const Color loadDelivered = Color(0xFF065F46);      // Delivered - Emerald
  
  // Priority Levels
  static const Color priorityHigh = error;                   
  static const Color priorityMedium = brandAccent;           // Orange
  static const Color priorityLow = brandSecondary;           // Blue Green
  static const Color priorityUrgent = brandAccentLight;      // Amber Flame
  
  // Status Indicators
  static const Color statusOnline = Color(0xFF065F46);       
  static const Color statusOffline = Color(0xFF64748B);      
  static const Color statusPending = brandAccentLight;       
  static const Color statusProcessing = brandSecondary;      
  
  // Data Visualization Colors
  static const Color chartPrimary = brandPrimary;
  static const Color chartSecondary = brandSecondary;
  static const Color chartTertiary = brandAccent;
  static const Color chartQuaternary = brandAccentLight;
  static const Color chartQuinary = brandNeutral;
  
  // Gradient Colors
  static const List<Color> gradientPrimary = [
    brandPrimary,
    brandSecondary,
  ];
  
  static const List<Color> gradientAccent = [
    brandAccentLight,
    brandAccent,
  ];
  
  static const List<Color> gradientSky = [
    brandNeutral,
    brandSecondary,
  ];
}