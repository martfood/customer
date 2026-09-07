import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

enum AddressValidationStatus {
  unverified,
  validating,
  validInCoverage,
  validOutOfCoverage,
  invalid,
}

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  static const String _googleApiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";

  final _titleController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isDefault = false;
  bool _isLoading = false;
  bool _isValidating = false;

  // Google Places Autocomplete Suggestions
  List<Map<String, dynamic>> _suggestions = [];
  bool _isFetchingSuggestions = false;
  Timer? _debounceTimer;

  // Address Validation State
  AddressValidationStatus _validationStatus = AddressValidationStatus.unverified;
  String _validationErrorMessage = '';
  double? _resolvedLat;
  double? _resolvedLng;
  String? _resolvedCity;
  String? _resolvedState;
  String? _lastValidatedAddress;

  @override
  void initState() {
    super.initState();
    _addressController.addListener(_onAddressInputChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _addressController.removeListener(_onAddressInputChanged);
    _titleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _onAddressInputChanged() {
    final input = _addressController.text.trim();

    // Reset validation if user modified previously validated address text
    if (_lastValidatedAddress != null && input != _lastValidatedAddress) {
      setState(() {
        _validationStatus = AddressValidationStatus.unverified;
        _validationErrorMessage = '';
        _resolvedLat = null;
        _resolvedLng = null;
        _resolvedCity = null;
        _resolvedState = null;
        _lastValidatedAddress = null;
      });
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    if (input.length >= 3) {
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _fetchPlaceSuggestions(input);
      });
    } else {
      if (mounted && _suggestions.isNotEmpty) {
        setState(() {
          _suggestions = [];
          _isFetchingSuggestions = false;
        });
      }
    }
  }

  /// Fetches real-time address autocomplete predictions from Google Places API.
  Future<void> _fetchPlaceSuggestions(String input) async {
    if (!mounted) return;
    setState(() {
      _isFetchingSuggestions = true;
    });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['predictions'] is List) {
          setState(() {
            _suggestions = List<Map<String, dynamic>>.from(data['predictions']);
            _isFetchingSuggestions = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Google Autocomplete error: $e');
    }

    if (mounted) {
      setState(() {
        _suggestions = [];
        _isFetchingSuggestions = false;
      });
    }
  }

  /// Handles when customer taps an address prediction suggestion.
  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final description = (suggestion['description'] ?? '').toString();
    final placeId = (suggestion['place_id'] ?? '').toString();

    // Set text without re-triggering autocomplete search
    _addressController.removeListener(_onAddressInputChanged);
    _addressController.text = description;
    _addressController.selection = TextSelection.fromPosition(
      TextPosition(offset: description.length),
    );
    _addressController.addListener(_onAddressInputChanged);

    setState(() {
      _suggestions = [];
      _isFetchingSuggestions = false;
    });

    FocusScope.of(context).unfocus();

    if (placeId.isNotEmpty) {
      await _fetchPlaceDetailsAndValidate(placeId, description);
    } else {
      await _validateAddressWithGeocoding(description);
    }
  }

  /// Fetches Google Place Details (exact lat/lng and components) and checks coverage.
  Future<void> _fetchPlaceDetailsAndValidate(String placeId, String fullAddress) async {
    setState(() {
      _isValidating = true;
      _validationStatus = AddressValidationStatus.validating;
      _validationErrorMessage = '';
    });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&fields=geometry,address_components,formatted_address&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['result'] != null) {
          final result = data['result'];
          final location = result['geometry']?['location'];
          final components = result['address_components'] as List?;

          double? lat;
          double? lng;
          String? city;
          String? state;

          if (location != null) {
            lat = (location['lat'] as num?)?.toDouble();
            lng = (location['lng'] as num?)?.toDouble();
          }

          if (components != null) {
            for (final comp in components) {
              final types = List<String>.from(comp['types'] ?? []);
              if (types.contains('locality') || types.contains('administrative_area_level_2')) {
                city ??= comp['long_name']?.toString();
              }
              if (types.contains('administrative_area_level_1')) {
                state ??= comp['long_name']?.toString();
              }
            }
          }

          final inCoverage = await _checkServiceCoverage(
            fullAddressStr: fullAddress,
            state: state,
            city: city,
          );

          if (mounted) {
            setState(() {
              _resolvedLat = lat;
              _resolvedLng = lng;
              _resolvedCity = city;
              _resolvedState = state;
              _lastValidatedAddress = fullAddress;
              _isValidating = false;
              _validationStatus = inCoverage
                  ? AddressValidationStatus.validInCoverage
                  : AddressValidationStatus.validOutOfCoverage;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Place details validation error: $e');
    }

    // Fallback to geocoding if place details failed
    await _validateAddressWithGeocoding(fullAddress);
  }

  /// Geocodes address text to check if it represents a valid real-world location and checks coverage.
  Future<void> _validateAddressWithGeocoding(String addressStr) async {
    final clean = addressStr.trim();
    if (clean.isEmpty) {
      setState(() {
        _isValidating = false;
        _validationStatus = AddressValidationStatus.invalid;
        _validationErrorMessage = 'Please enter your full delivery address.';
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationStatus = AddressValidationStatus.validating;
      _validationErrorMessage = '';
    });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(clean)}&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;

        if (data['status'] == 'OK' && results != null && results.isNotEmpty) {
          final first = results.first;
          final location = first['geometry']?['location'];
          final components = first['address_components'] as List?;

          double? lat;
          double? lng;
          String? city;
          String? state;

          if (location != null) {
            lat = (location['lat'] as num?)?.toDouble();
            lng = (location['lng'] as num?)?.toDouble();
          }

          if (components != null) {
            for (final comp in components) {
              final types = List<String>.from(comp['types'] ?? []);
              if (types.contains('locality') || types.contains('administrative_area_level_2')) {
                city ??= comp['long_name']?.toString();
              }
              if (types.contains('administrative_area_level_1')) {
                state ??= comp['long_name']?.toString();
              }
            }
          }

          final inCoverage = await _checkServiceCoverage(
            fullAddressStr: clean,
            state: state,
            city: city,
          );

          if (mounted) {
            setState(() {
              _resolvedLat = lat;
              _resolvedLng = lng;
              _resolvedCity = city;
              _resolvedState = state;
              _lastValidatedAddress = clean;
              _isValidating = false;
              _validationStatus = inCoverage
                  ? AddressValidationStatus.validInCoverage
                  : AddressValidationStatus.validOutOfCoverage;
            });
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding validation error: $e');
    }

    if (mounted) {
      setState(() {
        _isValidating = false;
        _validationStatus = AddressValidationStatus.invalid;
        _validationErrorMessage =
            'Could not locate or verify this address. Please choose an address from suggestions or provide complete street, city, and state details.';
      });
    }
  }

  /// Verifies regional service coverage from Firestore settings.
  Future<bool> _checkServiceCoverage({
    required String fullAddressStr,
    String? state,
    String? city,
  }) async {
    List<String> enabledStates = [];
    List<String> enabledLgas = [];
    List<String> enabledTowns = [];

    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('service_availability')
          .get();
      if (docSnap.exists) {
        final data = docSnap.data() ?? {};
        enabledStates.addAll(List<String>.from(data['enabledStates'] ?? []));
        enabledLgas.addAll(List<String>.from(data['enabledLgas'] ?? []));
        enabledTowns.addAll(List<String>.from(data['enabledTowns'] ?? []));
      }
    } catch (_) {}

    try {
      final sysSnap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('system_settings')
          .get();
      if (sysSnap.exists) {
        final data = sysSnap.data() ?? {};
        enabledStates.addAll(List<String>.from(data['enabledStates'] ?? []));
        enabledLgas.addAll(List<String>.from(data['enabledLgas'] ?? []));
      }
    } catch (_) {}

    enabledStates = enabledStates
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    enabledLgas = enabledLgas
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    enabledTowns = enabledTowns
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    // If regions are not configured in Firestore, regional coverage is open
    if (enabledStates.isEmpty && enabledLgas.isEmpty && enabledTowns.isEmpty) {
      return true;
    }

    final addrLower = fullAddressStr.toLowerCase();
    final stateLower = (state ?? '').toLowerCase();
    final cityLower = (city ?? '').toLowerCase();

    for (final town in enabledTowns) {
      final t = town.toLowerCase();
      if (addrLower.contains(t) || cityLower.contains(t)) {
        return true;
      }
    }

    for (final lga in enabledLgas) {
      final l = lga.toLowerCase();
      if (addrLower.contains(l) || cityLower.contains(l)) {
        return true;
      }
    }

    for (final st in enabledStates) {
      final s = st.toLowerCase();
      if (addrLower.contains(s) || stateLower.contains(s)) {
        return true;
      }
    }

    return false;
  }

  /// Displays bottom sheet warning when address is out of coverage, allowing customer to proceed or edit.
  Future<bool> _showOutOfCoverageConfirmationSheet() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : Colors.black87;
    final mutedTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: surfaceColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20.w,
          16.h,
          20.w,
          MediaQuery.of(context).viewInsets.bottom + 28.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),
            Container(
              width: 60.w,
              height: 60.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber.withValues(alpha: 0.12),
              ),
              child: Icon(
                LucideIcons.alertTriangle,
                color: const Color(0xFFD97706),
                size: 30.sp,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'Out of Service Coverage',
              style: TextStyle(
                color: primaryTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodyLarge),
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10.h),
            Text(
              'The delivery address is out of service coverage so change to an address that service coverage covers.',
              style: TextStyle(
                color: mutedTextColor,
                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Change Address',
                  style: TextStyle(
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              child: Text(
                'Save Anyway',
                style: TextStyle(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTypography.font(AppFontSizes.bodySmall),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return result ?? false;
  }

  Future<void> _saveAddress() async {
    final title = _titleController.text.trim();
    final address = _addressController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an address title (e.g. Home, Office).'),
        ),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your full delivery address.'),
        ),
      );
      return;
    }

    // If address has not been validated yet, validate now
    if (_validationStatus == AddressValidationStatus.unverified) {
      await _validateAddressWithGeocoding(address);
    }

    if (!mounted) return;

    if (_validationStatus == AddressValidationStatus.invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(
            _validationErrorMessage.isNotEmpty
                ? _validationErrorMessage
                : 'Please enter a valid address that can be located.',
          ),
        ),
      );
      return;
    }

    if (_validationStatus == AddressValidationStatus.validOutOfCoverage) {
      final shouldSaveAnyway = await _showOutOfCoverageConfirmationSheet();
      if (!shouldSaveAnyway) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final addressRef = FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .collection('addresses');

        // Check if user has any addresses
        final countSnapshot = await addressRef.count().get();
        final shouldBeDefault = _isDefault || countSnapshot.count == 0;

        // If this address is set to default, unset all others
        if (shouldBeDefault) {
          final existingDefaults =
              await addressRef.where('isDefault', isEqualTo: true).get();
          for (var doc in existingDefaults.docs) {
            await doc.reference.update({'isDefault': false});
          }
        }

        final newDoc = await addressRef.add({
          'title': title,
          'address': address,
          'fullAddress': address,
          if (_resolvedLat != null) 'latitude': _resolvedLat,
          if (_resolvedLng != null) 'longitude': _resolvedLng,
          if (_resolvedCity != null) 'city': _resolvedCity,
          if (_resolvedState != null) 'state': _resolvedState,
          'isDefault': shouldBeDefault,
          'isVerified': _validationStatus == AddressValidationStatus.validInCoverage,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF16A34A),
              content: Text('Address saved successfully!'),
            ),
          );
          // Return new address data map to caller (e.g. DeliverToScreen)
          context.pop({
            'id': newDoc.id,
            'title': title,
            'address': address,
            'latitude': _resolvedLat,
            'longitude': _resolvedLng,
            'city': _resolvedCity,
            'state': _resolvedState,
            'isDefault': shouldBeDefault,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('Failed to save address: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final cardBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.all(8.w),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.grey[800]! : const Color(0xFFE9EAF0),
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                LucideIcons.arrowLeft,
                color: isDark ? Colors.white : purpleColor,
                size: 18.sp,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Add New Address',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: purpleColor))
          : SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
                      child: Responsive.maxContainer(
                        context: context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Address details',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: AppTypography.font(
                                  AppFontSizes.headlineSmall,
                                ),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Add a location for faster delivery and smoother checkout.',
                              style: TextStyle(
                                color: mutedTextColor,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 16.h),

                            // Main Input Card
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(18.w),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24.r),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Address Title Field
                                  _buildField(
                                    context: context,
                                    label: 'Address title',
                                    hint: 'Home, Office, Apartment',
                                    controller: _titleController,
                                    icon: LucideIcons.bookmark,
                                  ),
                                  SizedBox(height: 18.h),

                                  // Full Address Field
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Full address',
                                            style: TextStyle(
                                              color: isDark
                                                  ? Colors.grey[400]!
                                                  : const Color(0xFF6E7191),
                                              fontSize: AppTypography.font(
                                                  AppFontSizes.bodySmall),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_isFetchingSuggestions || _isValidating)
                                            Row(
                                              children: [
                                                SizedBox(
                                                  width: 12.w,
                                                  height: 12.w,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: purpleColor,
                                                  ),
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  _isFetchingSuggestions
                                                      ? 'Searching...'
                                                      : 'Validating...',
                                                  style: TextStyle(
                                                    color: purpleColor,
                                                    fontSize: AppTypography.font(
                                                        AppFontSizes.caption),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 8.h),
                                      TextField(
                                        controller: _addressController,
                                        maxLines: 2,
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: AppTypography.font(
                                              AppFontSizes.bodyLarge),
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Start typing street, area, city...',
                                          prefixIcon: Icon(
                                            LucideIcons.mapPin,
                                            color: _validationStatus ==
                                                    AddressValidationStatus
                                                        .validInCoverage
                                                ? const Color(0xFF16A34A)
                                                : (_validationStatus ==
                                                        AddressValidationStatus
                                                            .invalid
                                                    ? const Color(0xFFDC2626)
                                                    : Colors.grey[500]),
                                            size: 20.sp,
                                          ),
                                          suffixIcon: _addressController
                                                  .text.isNotEmpty
                                              ? IconButton(
                                                  icon: Icon(
                                                    LucideIcons.x,
                                                    size: 16.sp,
                                                    color: mutedTextColor,
                                                  ),
                                                  onPressed: () {
                                                    _addressController.clear();
                                                    setState(() {
                                                      _suggestions = [];
                                                      _validationStatus =
                                                          AddressValidationStatus
                                                              .unverified;
                                                    });
                                                  },
                                                )
                                              : null,
                                          hintStyle: TextStyle(
                                            color: isDark
                                                ? Colors.grey[500]
                                                : const Color(0xFF6E7191),
                                          ),
                                          filled: true,
                                          fillColor: isDark
                                              ? const Color(0xFF27272A)
                                              : const Color(0xFFF7F8FC),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18.r),
                                            borderSide: BorderSide(
                                              color: borderColor,
                                              width: 1,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18.r),
                                            borderSide: BorderSide(
                                              color: borderColor,
                                              width: 1,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18.r),
                                            borderSide: BorderSide(
                                              color: purpleColor,
                                              width: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Google Places Suggestions Dropdown List
                                  if (_suggestions.isNotEmpty) ...[
                                    SizedBox(height: 10.h),
                                    _buildSuggestionsContainer(
                                      isDark: isDark,
                                      borderColor: borderColor,
                                      primaryTextColor: primaryTextColor,
                                      mutedTextColor: mutedTextColor,
                                      purpleColor: purpleColor,
                                    ),
                                  ],

                                  // Address Validation Status Banner
                                  _buildValidationStatusBanner(
                                    isDark: isDark,
                                    purpleColor: purpleColor,
                                    primaryTextColor: primaryTextColor,
                                    mutedTextColor: mutedTextColor,
                                  ),

                                  SizedBox(height: 18.h),

                                  // Set as Default Address Switch
                                  Container(
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF27272A)
                                          : const Color(0xFFF7F8FC),
                                      borderRadius: BorderRadius.circular(18.r),
                                      border: Border.all(
                                          color: borderColor, width: 1),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 42.w,
                                          height: 42.w,
                                          decoration: BoxDecoration(
                                            color: purpleColor.withValues(
                                                alpha: 0.10),
                                            borderRadius:
                                                BorderRadius.circular(14.r),
                                          ),
                                          child: Icon(
                                            LucideIcons.pin,
                                            color: purpleColor,
                                            size: 20.sp,
                                          ),
                                        ),
                                        SizedBox(width: 14.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Set as default address',
                                                style: TextStyle(
                                                  color: primaryTextColor,
                                                  fontSize: AppTypography.font(
                                                    AppFontSizes.bodyLarge,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                'Use this address automatically during checkout.',
                                                style: TextStyle(
                                                  color: mutedTextColor,
                                                  fontSize: AppTypography.font(
                                                    AppFontSizes.bodySmall,
                                                  ),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: _isDefault,
                                          activeTrackColor: purpleColor,
                                          onChanged: (val) {
                                            setState(() {
                                              _isDefault = val;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Bar: Save Address
                  Container(
                    padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Responsive.maxContainer(
                        context: context,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveAddress,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purpleColor,
                            foregroundColor: Colors.white,
                            minimumSize: Size(double.infinity, 56.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18.r),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 24.w,
                                  height: 24.w,
                                  child: const CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  'Save Address',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: AppTypography.font(
                                        AppFontSizes.bodyMedium),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Builds the Autocomplete Suggestions List.
  Widget _buildSuggestionsContainer({
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required Color purpleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 6.h),
            child: Row(
              children: [
                Icon(
                  LucideIcons.sparkles,
                  color: purpleColor,
                  size: 14.sp,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Address Suggestions',
                  style: TextStyle(
                    color: purpleColor,
                    fontSize: AppTypography.font(11),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: borderColor, height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suggestions.length > 5 ? 5 : _suggestions.length,
            separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
            itemBuilder: (context, index) {
              final item = _suggestions[index];
              final description = (item['description'] ?? '').toString();
              final structured = item['structured_formatting'] as Map?;
              final mainText = (structured?['main_text'] ?? description).toString();
              final secondaryText = (structured?['secondary_text'] ?? '').toString();

              return InkWell(
                onTap: () => _selectSuggestion(item),
                borderRadius: BorderRadius.circular(8.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.mapPin,
                        color: purpleColor,
                        size: 18.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mainText,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w700,
                                fontSize: AppTypography.font(AppFontSizes.bodySmall),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (secondaryText.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                secondaryText,
                                style: TextStyle(
                                  color: mutedTextColor,
                                  fontSize: AppTypography.font(AppFontSizes.caption),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Builds the Address Validation feedback card.
  Widget _buildValidationStatusBanner({
    required bool isDark,
    required Color purpleColor,
    required Color primaryTextColor,
    required Color mutedTextColor,
  }) {
    if (_validationStatus == AddressValidationStatus.unverified) {
      if (_addressController.text.trim().length >= 4) {
        return Padding(
          padding: EdgeInsets.only(top: 10.h),
          child: Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => _validateAddressWithGeocoding(_addressController.text),
              borderRadius: BorderRadius.circular(8.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.checkCheck,
                      color: purpleColor,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'Verify Address',
                      style: TextStyle(
                        color: purpleColor,
                        fontSize: AppTypography.font(AppFontSizes.caption),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    if (_validationStatus == AddressValidationStatus.validInCoverage) {
      return Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF142E1B) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.checkCircle2,
              color: const Color(0xFF16A34A),
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verified Address (In Service Coverage)',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                      fontWeight: FontWeight.w800,
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'This address was validated and is eligible for MartFood delivery.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFBBF7D0) : const Color(0xFF166534),
                      fontSize: AppTypography.font(AppFontSizes.caption),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_validationStatus == AddressValidationStatus.validOutOfCoverage) {
      return Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D1B11) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? const Color(0xFF854D0E) : const Color(0xFFFCD34D),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              color: const Color(0xFFD97706),
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Out of Service Coverage Area',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
                      fontWeight: FontWeight.w800,
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'The delivery address is out of service coverage so change to an address that service coverage covers.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFEF3C7) : const Color(0xFF92400E),
                      fontSize: AppTypography.font(AppFontSizes.caption),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_validationStatus == AddressValidationStatus.invalid) {
      return Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.alertCircle,
              color: const Color(0xFFDC2626),
              size: 20.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Address Could Not Be Located',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                      fontWeight: FontWeight.w800,
                      fontSize: AppTypography.font(AppFontSizes.bodySmall),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _validationErrorMessage.isNotEmpty
                        ? _validationErrorMessage
                        : 'Please pick an address from suggestions or enter complete street, city, and state details.',
                    style: TextStyle(
                      color: isDark ? const Color(0xFFFECACA) : const Color(0xFFB91C1C),
                      fontSize: AppTypography.font(AppFontSizes.caption),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildField({
    required BuildContext context,
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final labelColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: labelColor,
            fontSize: AppTypography.font(AppFontSizes.bodySmall),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          style: TextStyle(
            color: primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: AppTypography.font(AppFontSizes.bodyLarge),
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.grey[500], size: 20.sp),
            hintStyle: TextStyle(color: labelColor),
            filled: true,
            fillColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8FC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18.r),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18.r),
              borderSide: BorderSide(color: borderColor, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18.r),
              borderSide: BorderSide(
                color: purpleColor,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
