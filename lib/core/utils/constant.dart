import 'package:flutter/material.dart';

// Colors
//
// The legacy slots, now filled from the Xpedia Partners design system
// (assets/stitch_xpedia_seller_project/design.md_1.md §1) so that every screen
// still written against them picks up the new palette. New screens should read
// the full token set in `xpedia_tokens.dart` instead.
const Color kLightPrimaryColor = Color(0xff0056FE); // brand-primary
const Color kDarkPrimaryColor = Color(0xff4682FF); // brand-primary, dark
const Color kLightSecondColor = Color(0xff111827); // text-primary
const Color kDarkSecondColor = Color(0xffF7F8FA); // text-primary, dark
const Color kLightThirdColor = Color(0xff4B5563); // text-secondary
const Color kDarkThirdColor = Color(0xff9CA3AF); // text-secondary, dark
const Color kBorderColor = Color(0xffE5E7EB); // border-subtle
const Color kSuccessColor = Color(0xff109553); // success
// The legacy slot is mostly read as a text and icon colour on a 12% tint, where
// the raw warning amber (#F59E0B) is unreadable on white — so it takes the
// "Processing" status foreground, which is the same hue at a legible depth.
const Color kWarningColor = Color(0xff8C5002);
const Color kErrorColor = Color(0xffFB132D); // danger
const Color kDeleteColor = Color(0xffFB132D); // danger
const Color kWhiteColor = Colors.white; // bg-surface
const Color kBlackColor = Color(0xff0B1220); // bg-canvas, dark
const Color kDarkColor = Color(0xff111827); // bg-surface, dark

// Font — the only typeface the design system allows.
const String kFontFamily = 'Inter';

// General
const String kAccessToken = 'accessToken';
const String kRefreshToken = 'refreshToken';
const String kUserId = 'userId';
const String kAppLanguage = 'appLanguage';
const String kAppTheme = 'appTheme';
const String kDark = 'dark';
const String kLight = 'light';

// Seller session (Markas API)
const String kActiveStoreId = 'activeStoreId';
const String kUserRole = 'userRole';
const String kUserEmail = 'userEmail';
const String kUserFullName = 'userFullName';
const String kUserPhone = 'userPhone';

/// Locally recorded KYC doc types, so the upload screen can show what has
/// already been sent. The backend exposes no endpoint that lists KYC documents
/// back, so this is a client-side note only — never treat it as server truth.
const String kKycSubmittedDocTypes = 'kycSubmittedDocTypes';
