import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';

import 'auth_error_handler.dart';

class PersonalInfoScreen extends StatefulWidget {
  final String email;
  final String password;

  const PersonalInfoScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final TextEditingController _emailController;
  final _dobController = TextEditingController();

  String _selectedGender = 'Female';
  bool _isLoading = false;
  File? _imageFile;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
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
      if (mounted) {
        AuthErrorHandler.showError(context, 'Failed to pick image: $e');
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1930),
      lastDate: now,
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(primary: AppTheme.primaryPurpleFor(isDark))
                : ColorScheme.light(primary: AppTheme.primaryPurpleFor(isDark)),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final formattedDate =
          "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";
      setState(() {
        _dobController.text = formattedDate;
      });
    }
  }

  Future<void> _finishRegistration() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final phoneNumber = _phoneController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || phoneNumber.isEmpty) {
      AuthErrorHandler.showError(context, 'Please fill all fields');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          )
          .timeout(const Duration(seconds: 5));

      final uid = userCredential.user?.uid;
      if (uid != null) {
        String profilePicUrl = '';

        if (_imageFile != null) {
          final storageRef = FirebaseStorage.instance
              .ref()
              .child('profile_pics')
              .child('$uid.jpg');
          await storageRef
              .putFile(_imageFile!)
              .timeout(const Duration(seconds: 5));
          profilePicUrl = await storageRef
              .getDownloadURL()
              .timeout(const Duration(seconds: 5));
        }

        await FirebaseFirestore.instance
            .collection('customers')
            .doc(uid)
            .set({
          'uid': uid,
          'email': widget.email,
          'fullName': fullName,
          'firstName': firstName,
          'lastName': lastName,
          'phoneNumber': phoneNumber,
          'gender': _selectedGender,
          'dob': _dobController.text.trim(),
          'profilePic': profilePicUrl,
          'balance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 5));
      }

      if (mounted) {
        context.go('/success');
      }
    } catch (e) {
      if (mounted) {
        AuthErrorHandler.showError(context, e);
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
    final backgroundColor =
        isDark ? AppTheme.darkSurface : AppTheme.lightInputFill;
    final purpleColor = AppTheme.primaryPurpleFor(isDark);
    final fieldBg = isDark ? AppTheme.darkSurface : Colors.white;
    final fieldBorder = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: purpleColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Avatar Picker ──────────────────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 54.r,
                        backgroundColor:
                            isDark ? Colors.grey[800] : Colors.grey[200],
                        backgroundImage:
                            _imageFile != null ? FileImage(_imageFile!) : null,
                        child: _imageFile == null
                            ? Icon(
                                Icons.person_outline,
                                size: 48.sp,
                                color: Colors.grey[500],
                              )
                            : null,
                      ),
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: purpleColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 16.sp,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 28.h),

              // ── 2. First Name & Last Name (2-Column Row) ───────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'First name',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(28.r),
                            border: Border.all(color: fieldBorder, width: 1.0),
                          ),
                          child: TextField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: textColor,
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter name',
                              hintStyle: TextStyle(
                                color:
                                    isDark ? Colors.grey[500] : Colors.grey[400],
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 14.h,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Last name',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(28.r),
                            border: Border.all(color: fieldBorder, width: 1.0),
                          ),
                          child: TextField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            style: TextStyle(
                              color: textColor,
                              fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter name',
                              hintStyle: TextStyle(
                                color:
                                    isDark ? Colors.grey[500] : Colors.grey[400],
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 14.h,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // ── 3. Phone Number Field ───────────────────────────────────────
              Text(
                'Phone Number',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter phone number',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // ── 4. Email Field (Read Only) ──────────────────────────────────
              Text(
                'Email',
                style: TextStyle(
                  fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 8.h),
              Container(
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(28.r),
                  border: Border.all(color: fieldBorder, width: 1.0),
                ),
                child: TextField(
                  controller: _emailController,
                  readOnly: true,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Email address',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18.h),

              // ── 5. Date of Birth & Gender (2-Column Row) ───────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date of Birth',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        GestureDetector(
                          onTap: _selectDateOfBirth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: fieldBg,
                              borderRadius: BorderRadius.circular(28.r),
                              border: Border.all(
                                  color: fieldBorder, width: 1.0),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 14.h,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dobController.text.isEmpty
                                        ? 'DD/MM/YYYY'
                                        : _dobController.text,
                                    style: TextStyle(
                                      color: _dobController.text.isEmpty
                                          ? (isDark
                                              ? Colors.grey[500]
                                              : Colors.grey[400])
                                          : textColor,
                                      fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: purpleColor,
                                  size: 20.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          decoration: BoxDecoration(
                            color: fieldBg,
                            borderRadius: BorderRadius.circular(28.r),
                            border: Border.all(color: fieldBorder, width: 1.0),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedGender,
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: purpleColor,
                                size: 20.sp,
                              ),
                              dropdownColor:
                                  isDark ? AppTheme.darkSurface : Colors.white,
                              style: TextStyle(
                                color: textColor,
                                fontSize: AppTypography.font(AppFontSizes.bodyMedium),
                              ),
                              isExpanded: true,
                              onChanged: (newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedGender = newValue;
                                  });
                                }
                              },
                              items: ['Female', 'Male', 'Other'].map((gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),

              // ── 6. Action Button ────────────────────────────────────────────
              _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: purpleColor),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52.h,
                      child: ElevatedButton(
                        onPressed: _finishRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purpleColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Save & Continue',
                          style: TextStyle(
                            fontSize: AppTypography.font(AppFontSizes.titleMedium),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
