import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'change_email_bottom_sheet.dart';

/// Redesigned Edit Profile screen matching the Minimal & Flat registration form styling.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String _profilePicUrl = '';
  File? _imageFile;
  final _picker = ImagePicker();
  String _selectedCountryCode = '+234';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawPhone = (data['phoneNumber'] ?? '').toString();

        String parsedCode = '+234';
        String parsedPhone = rawPhone;

        if (rawPhone.startsWith('+')) {
          for (int len = 4; len >= 2; len--) {
            if (rawPhone.length > len) {
              final potentialCode = rawPhone.substring(0, len);
              if (RegExp(r'^\+[0-9]+$').hasMatch(potentialCode)) {
                parsedCode = potentialCode;
                parsedPhone = rawPhone.substring(len);
                break;
              }
            }
          }
        }

        setState(() {
          _nameController.text = data['fullName'] ?? '';
          _emailController.text = data['email'] ?? '';
          _phoneController.text = parsedPhone;
          _selectedCountryCode = parsedCode;
          _profilePicUrl = data['profilePic'] ?? '';
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Phone Number cannot be empty')),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final sanitizedPhone = cleanPhone.startsWith('0') ? cleanPhone.substring(1) : cleanPhone;
    if (sanitizedPhone.length < 10 || sanitizedPhone.length > 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit phone number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final fullPhoneNumber = '$_selectedCountryCode$sanitizedPhone';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        String uploadedUrl = _profilePicUrl;

        if (_imageFile != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pics')
              .child('${user.uid}.jpg');
          await storageRef.putFile(_imageFile!);
          uploadedUrl = await storageRef.getDownloadURL();
        }

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .update({
          'fullName': name,
          'phoneNumber': fullPhoneNumber,
          'profilePic': uploadedUrl,
        });

        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final purpleColor = AppTheme.primaryPurpleFor(isDark);

          setState(() {
            _isLoading = false;
          });

          await showModalBottomSheet<void>(
            context: context,
            backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
            elevation: 0,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            builder: (ctx) => _buildSuccessBottomSheet(ctx, isDark, purpleColor),
          );

          if (mounted) {
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
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

  Widget _buildSuccessBottomSheet(
      BuildContext context, bool isDark, Color purpleColor) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  LucideIcons.check,
                  color: Color(0xFF10B981),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Profile Updated!',
              style: TextStyle(
                fontSize: AppTypography.font(18),
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your profile details and contact information have been saved successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTypography.font(13),
                color: mutedTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: AppTypography.font(14),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF15161A);
    final fieldBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF7F8FC);
    final fieldBorder =
        isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryTextColor),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Edit Profile',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Responsive.maxContainer(
                  context: context,
                  maxWidth: 600,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Profile Photo Picker ─────────────────────────────
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor: isDark
                                      ? const Color(0xFF27272A)
                                      : const Color(0xFFF2F3F7),
                                  backgroundImage: _imageFile != null
                                      ? FileImage(_imageFile!)
                                      : (_profilePicUrl.isNotEmpty
                                          ? NetworkImage(_profilePicUrl)
                                          : null) as ImageProvider?,
                                  child: _imageFile == null &&
                                          _profilePicUrl.isEmpty
                                      ? Icon(
                                          Icons.person,
                                          size: 44,
                                          color: purpleColor,
                                        )
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: purpleColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.darkSurface
                                          : Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // ── Field 1: Full Name ───────────────────────────────
                        Text(
                          'Full Name',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: fieldBorder, width: 1.0),
                          ),
                          child: TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: primaryTextColor,
                              fontSize: AppTypography.font(14),
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your full name',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: AppTypography.font(14),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Field 2: Email (With Change Action) ─────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Email Address',
                              style: TextStyle(
                                fontSize: AppTypography.font(14),
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final changed = await showChangeEmailBottomSheet(context);
                                if (changed == true) {
                                  _loadProfileData();
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: AppTypography.font(13),
                                    fontWeight: FontWeight.bold,
                                    color: purpleColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E24)
                                : const Color(0xFFEFEFF4),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: fieldBorder, width: 1.0),
                          ),
                          child: TextField(
                            controller: _emailController,
                            readOnly: true,
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: AppTypography.font(14),
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Email address',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: AppTypography.font(14),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Field 3: Phone Number with Country Code Picker ──
                        Text(
                          'Phone Number',
                          style: TextStyle(
                            fontSize: AppTypography.font(14),
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: fieldBorder, width: 1.0),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  showCountryPicker(
                                    context: context,
                                    showPhoneCode: true,
                                    countryListTheme: CountryListThemeData(
                                      backgroundColor: isDark
                                          ? AppTheme.darkSurface
                                          : Colors.white,
                                      bottomSheetHeight: 500,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(28)),
                                    ),
                                    onSelect: (Country country) {
                                      setState(() {
                                        _selectedCountryCode =
                                            '+${country.phoneCode}';
                                      });
                                    },
                                  );
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      _selectedCountryCode,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppTypography.font(14),
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                height: 20,
                                width: 1,
                                color: isDark
                                    ? AppTheme.darkBorder
                                    : Colors.grey[300],
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: AppTypography.font(14),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Enter phone number',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: AppTypography.font(14),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ── Save Changes Button ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purpleColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: AppTypography.font(15),
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }
}
