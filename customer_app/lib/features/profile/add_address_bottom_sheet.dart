import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

/// Shows a live, fully-functional Add New Address bottom sheet with Google Places Autocomplete.
Future<bool?> showAddNewAddressBottomSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    elevation: 0,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (ctx) => const _AddNewAddressSheet(),
  );
}

class _AddNewAddressSheet extends StatefulWidget {
  const _AddNewAddressSheet();

  @override
  State<_AddNewAddressSheet> createState() => _AddNewAddressSheetState();
}

class _AddNewAddressSheetState extends State<_AddNewAddressSheet> {
  static const String _googleApiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";

  final _addressController = TextEditingController();
  final _labelController = TextEditingController();
  String _selectedCategory = 'Home'; // 'Home', 'Work / Office', 'Other'
  bool _isDefault = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Google Places Autocomplete
  List<Map<String, dynamic>> _suggestions = [];
  bool _isFetchingSuggestions = false;
  Timer? _debounce;

  @override
  void dispose() {
    _addressController.dispose();
    _labelController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onAddressChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      final input = val.trim();
      if (input.length >= 2) {
        _fetchPlaceSuggestions(input);
      } else {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _isFetchingSuggestions = false;
          });
        }
      }
    });
  }

  Future<void> _fetchPlaceSuggestions(String input) async {
    setState(() {
      _isFetchingSuggestions = true;
    });

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && mounted) {
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

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final description = (suggestion['description'] ?? '').toString();
    setState(() {
      _addressController.text = description;
      _suggestions = [];
      _errorMessage = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _saveAddress() async {
    final addressText = _addressController.text.trim();
    final labelText = _labelController.text.trim();

    if (addressText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid delivery address.';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Please log in to add an address.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final addressRef = FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .collection('addresses');

      // Check if user has any existing addresses
      final countSnap = await addressRef.count().get();
      bool shouldBeDefault = _isDefault || countSnap.count == 0;

      // If set to default, update all existing addresses to isDefault = false
      if (shouldBeDefault) {
        final existingDefaults =
            await addressRef.where('isDefault', isEqualTo: true).get();
        for (var doc in existingDefaults.docs) {
          await doc.reference.update({'isDefault': false});
        }
      }

      final titleToSave = labelText.isNotEmpty ? labelText : _selectedCategory;

      await addressRef.add({
        'title': titleToSave,
        'category': _selectedCategory,
        'address': addressText,
        'isDefault': shouldBeDefault,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to save address: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final mutedText = isDark ? Colors.grey[400]! : const Color(0xFF4A4A4A);
    final purple = AppTheme.primaryPurpleFor(isDark);
    final inputBorderColor = isDark
        ? AppTheme.darkBorder
        : const Color(0xFFE9D5FF); // Subtle purple outline from UI spec
    final inactivePillBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Drag Handle ─────────────────────────────────────────────
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // ── Header Title & Subtitle ──────────────────────────────────────
            Text(
              'Add New Address',
              style: TextStyle(
                fontSize: AppTypography.font(24),
                fontWeight: FontWeight.w800,
                color: primaryText,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Input the exact location so your rider finds you fast.',
              style: TextStyle(
                fontSize: AppTypography.font(14),
                color: mutedText,
                height: 1.35,
              ),
            ),
            SizedBox(height: 24.h),

            // ── Field 1: Address ────────────────────────────────────────────
            _buildFieldLabel('Address', mutedText),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _addressController,
              keyboardType: TextInputType.streetAddress,
              maxLines: 2,
              onChanged: _onAddressChanged,
              style: TextStyle(
                fontSize: AppTypography.font(15),
                color: primaryText,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: '14 Layo Thompson St, Ajah, Lagos',
                isDark: isDark,
                borderColor: inputBorderColor,
                purple: purple,
                suffix: _isFetchingSuggestions
                    ? Padding(
                        padding: EdgeInsets.all(12.w),
                        child: SizedBox(
                          width: 18.w,
                          height: 18.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: purple,
                          ),
                        ),
                      )
                    : Icon(
                        LucideIcons.mapPin,
                        color: purple,
                        size: 20.sp,
                      ),
              ),
            ),

            // ── Google Places Suggestions List ──────────────────────────────
            if (_suggestions.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Material(
                color: isDark ? const Color(0xFF1F1F23) : Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  constraints: BoxConstraints(maxHeight: 220.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: purple.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    itemCount: _suggestions.length,
                    separatorBuilder: (ctx, i) => Divider(
                      height: 1,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      final description =
                          (suggestion['description'] ?? '').toString();
                      final mainText = (suggestion['structured_formatting']?['main_text'] ?? description).toString();
                      final secondaryText = (suggestion['structured_formatting']?['secondary_text'] ?? '').toString();

                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
                        leading: Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: purple.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            LucideIcons.mapPin,
                            size: 16.sp,
                            color: purple,
                          ),
                        ),
                        title: Text(
                          mainText,
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                        ),
                        subtitle: secondaryText.isNotEmpty
                            ? Text(
                                secondaryText,
                                style: TextStyle(
                                  fontSize: AppTypography.font(12),
                                  color: mutedText,
                                ),
                              )
                            : null,
                        onTap: () => _selectSuggestion(suggestion),
                      );
                    },
                  ),
                ),
              ),
            ],
            SizedBox(height: 20.h),

            // ── Field 2: Save address as ────────────────────────────────────
            _buildFieldLabel('Save address as', mutedText),
            SizedBox(height: 10.h),
            Row(
              children: [
                _buildCategoryPill('Home', purple, inactivePillBg, primaryText),
                SizedBox(width: 10.w),
                _buildCategoryPill('Work / Office', purple, inactivePillBg, primaryText),
                SizedBox(width: 10.w),
                _buildCategoryPill('Other', purple, inactivePillBg, primaryText),
              ],
            ),
            SizedBox(height: 20.h),

            // ── Field 3: Label this address ─────────────────────────────────
            _buildFieldLabel('Label this address', mutedText),
            SizedBox(height: 8.h),
            TextFormField(
              controller: _labelController,
              keyboardType: TextInputType.text,
              style: TextStyle(
                fontSize: AppTypography.font(15),
                color: primaryText,
                fontWeight: FontWeight.w500,
              ),
              decoration: _inputDecoration(
                hint: "Ayo's Place",
                isDark: isDark,
                borderColor: inputBorderColor,
                purple: purple,
              ),
            ),
            SizedBox(height: 24.h),

            // ── Thin Divider Line ───────────────────────────────────────────
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F5),
            ),
            SizedBox(height: 18.h),

            // ── Set as default address Toggle Switch ────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set as default address',
                  style: TextStyle(
                    fontSize: AppTypography.font(16),
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                Switch(
                  value: _isDefault,
                  activeThumbColor: Colors.white,
                  activeTrackColor: purple,
                  inactiveThumbColor: isDark ? Colors.grey[400] : Colors.grey[300],
                  inactiveTrackColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  onChanged: (val) {
                    setState(() {
                      _isDefault = val;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),

            // Error Banner if any
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: AppTypography.font(13),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
            ],

            // ── Primary Action Button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: purple.withValues(alpha: 0.5),
                  minimumSize: Size(double.infinity, 56.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r), // Fully rounded stadium button
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Add Address',
                        style: TextStyle(
                          fontSize: AppTypography.font(16),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(
    String category,
    Color purple,
    Color inactiveBg,
    Color primaryText,
  ) {
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? purple : inactiveBg,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Text(
            category,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTypography.font(14),
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : primaryText,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, Color color) {
    return Text(
      label,
      style: TextStyle(
        fontSize: AppTypography.font(14),
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool isDark,
    required Color borderColor,
    required Color purple,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[600] : Colors.grey[400],
        fontSize: AppTypography.font(14),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
      suffixIcon: suffix,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: purple, width: 1.6),
      ),
    );
  }
}
