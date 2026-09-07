import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_widgets/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class AddressLocationScreen extends StatefulWidget {
  const AddressLocationScreen({super.key});

  @override
  State<AddressLocationScreen> createState() => _AddressLocationScreenState();
}

class _AddressLocationScreenState extends State<AddressLocationScreen> {
  static const String _googleApiKey = "AIzaSyDUSy4tm9GTFNOCZZ5UXjGnEnPnFl1u2hI";

  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  LatLng _currentPosition = const LatLng(6.4281, 3.4219); // Default: Lagos
  bool _isLoadingMap = true;
  bool _isSavingAddress = false;

  final _addressController = TextEditingController();
  final _labelController = TextEditingController();
  String _selectedCategory = 'Home'; // 'Home', 'Work / Office', 'Other'
  bool _isDefault = true;
  bool _isFetchingSuggestions = false;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Autocomplete suggestions
  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _labelController.dispose();
    _mapController?.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _loadDefaultLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _loadDefaultLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _loadDefaultLocation();
      return;
    }

    try {
      // 1. Get last known location for near-instant rendering
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
          _isLoadingMap = false;
        });
        _reverseGeocode(_currentPosition);
      }

      // 2. Query medium accuracy for fast active GPS lock
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );
      final latLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = latLng;
          _isLoadingMap = false;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        _reverseGeocode(latLng);
      }
    } catch (e) {
      if (_isLoadingMap) {
        _loadDefaultLocation();
      }
    }
  }

  void _loadDefaultLocation() {
    setState(() {
      _isLoadingMap = false;
    });
    _reverseGeocode(_currentPosition);
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=${latLng.latitude},${latLng.longitude}&key=$_googleApiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        if (results.isNotEmpty) {
          final formattedAddress = results[0]['formatted_address'] as String;
          if (mounted) {
            setState(() {
              _addressController.text = formattedAddress;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
  }

  void _onAddressChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Auto expand bottom sheet when user starts typing
    if (val.trim().isNotEmpty && _sheetController.isAttached) {
      _sheetController.animateTo(
        0.85,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

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
      debugPrint('Autocomplete error: $e');
    }

    if (mounted) {
      setState(() {
        _suggestions = [];
        _isFetchingSuggestions = false;
      });
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    final description = (suggestion['description'] ?? '').toString();
    final placeId = (suggestion['place_id'] ?? '').toString();

    setState(() {
      _addressController.text = description;
      _suggestions = [];
    });

    // Auto collapse bottom sheet when suggestion is selected
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.50,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (placeId.isEmpty) return;

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleApiKey',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final loc = data['result']['geometry']['location'];
          final latLng = LatLng(loc['lat'], loc['lng']);
          setState(() {
            _currentPosition = latLng;
          });
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        }
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  Future<void> _setDefaultAddress(String addressId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final addressRef = _firestore
          .collection('customers')
          .doc(user.uid)
          .collection('addresses');

      final batch = _firestore.batch();
      final snap = await addressRef.get();
      for (var doc in snap.docs) {
        if (doc.id == addressId) {
          batch.update(doc.reference, {'isDefault': true});
        } else {
          batch.update(doc.reference, {'isDefault': false});
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error setting default address: $e');
    }
  }

  Future<void> _saveNewAddress() async {
    final address = _addressController.text.trim();
    final label = _labelController.text.trim();
    final title = label.isNotEmpty ? label : _selectedCategory;

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid delivery address.')),
      );
      return;
    }

    setState(() {
      _isSavingAddress = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final addressRef = _firestore
            .collection('customers')
            .doc(user.uid)
            .collection('addresses');

        final countSnap = await addressRef.count().get();
        bool shouldBeDefault = _isDefault || countSnap.count == 0;

        if (shouldBeDefault) {
          final existingDefaults =
              await addressRef.where('isDefault', isEqualTo: true).get();
          for (var doc in existingDefaults.docs) {
            await doc.reference.update({'isDefault': false});
          }
        }

        final newDoc = await addressRef.add({
          'title': title,
          'category': _selectedCategory,
          'address': address,
          'latitude': _currentPosition.latitude,
          'longitude': _currentPosition.longitude,
          'isDefault': shouldBeDefault,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Address saved successfully!')),
          );
          context.pop({
            'id': newDoc.id,
            'title': title,
            'address': address,
            'latitude': _currentPosition.latitude,
            'longitude': _currentPosition.longitude,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save address: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAddress = false;
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
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder;

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
                color: borderColor,
                width: 1,
              ),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back, color: purpleColor, size: 20.sp),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Select Location',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: AppTypography.font(AppFontSizes.displaySmall),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoadingMap
          ? Center(child: CircularProgressIndicator(color: purpleColor))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentPosition,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  zoomControlsEnabled: false,
                  onCameraMove: (position) {
                    _currentPosition = position.target;
                  },
                  onCameraIdle: () {
                    _reverseGeocode(_currentPosition);
                  },
                ),
                // Static Red Central Marker
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 36.h),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Colors.red,
                        size: 46.sp,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 20.w,
                  bottom: 380.h,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_location',
                    backgroundColor:
                        isDark ? AppTheme.darkSurface : Colors.white,
                    foregroundColor: purpleColor,
                    elevation: 0,
                    onPressed: _getUserLocation,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                _buildAddressDetailsBottomSheet(isDark),
              ],
            ),
    );
  }

  Widget _buildAddressDetailsBottomSheet(bool isDark) {
    final user = _auth.currentUser;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final mutedText = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final purple = AppTheme.primaryPurpleFor(isDark);
    final inputBorderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE9D5FF);
    final inactivePillBg = isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6);

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.50,
      minChildSize: 0.35,
      maxChildSize: 0.88,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder,
            ),
          ),
          child: ListView(
            controller: scrollController,
            padding: isTablet
                ? EdgeInsets.symmetric(horizontal: 36.w, vertical: 20.h)
                : EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 28.h),
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
                  fontSize: AppTypography.font(isTablet ? 26 : 24),
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Input the exact location or adjust the map pin so your rider finds you fast.',
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
                        final description = (suggestion['description'] ?? '').toString();
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

              // ── Primary Action Button ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSavingAddress ? null : _saveNewAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    elevation: 0,
                  ),
                  child: _isSavingAddress
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Address & Select',
                          style: TextStyle(
                            fontSize: AppTypography.font(16),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 20.h),
              if (user != null) ...[
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFF0F0F5),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Saved Addresses',
                  style: TextStyle(
                    fontSize: AppTypography.font(18),
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                  ),
                ),
                SizedBox(height: 12.h),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('customers')
                      .doc(user.uid)
                      .collection('addresses')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: CircularProgressIndicator(color: purple),
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Center(
                          child: Text(
                            'No saved addresses yet',
                            style: TextStyle(
                              color: mutedText,
                              fontSize: AppTypography.font(14),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: docs.length,
                      separatorBuilder: (context, index) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final id = docs[index].id;
                        final title = (data['title'] ?? 'Address').toString();
                        final address = (data['address'] ?? '').toString();
                        final isDefaultItem = data['isDefault'] == true;

                        return InkWell(
                          borderRadius: BorderRadius.circular(18.r),
                          onTap: () async {
                            final router = GoRouter.of(context);
                            await _setDefaultAddress(id);
                            router.pop({
                              'id': id,
                              'title': title,
                              'address': address,
                              'latitude': data['latitude'],
                              'longitude': data['longitude'],
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(14.w),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF8F8FC),
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: isDefaultItem
                                    ? purple
                                    : (isDark ? AppTheme.darkBorder : AppTheme.lightInputBorder),
                                width: isDefaultItem ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40.w,
                                  height: 40.w,
                                  decoration: BoxDecoration(
                                    color: purple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  child: Icon(
                                    LucideIcons.mapPin,
                                    color: purple,
                                    size: 20.sp,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: AppTypography.font(15),
                                                color: primaryText,
                                              ),
                                            ),
                                          ),
                                          if (isDefaultItem)
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                                              decoration: BoxDecoration(
                                                color: purple.withValues(alpha: 0.14),
                                                borderRadius: BorderRadius.circular(999.r),
                                              ),
                                              child: Text(
                                                'Default',
                                                style: TextStyle(
                                                  fontSize: AppTypography.font(11),
                                                  fontWeight: FontWeight.w700,
                                                  color: purple,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        address,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: AppTypography.font(13),
                                          color: mutedText,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
              SizedBox(height: 20.h),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFieldLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: AppTypography.font(14),
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildCategoryPill(
    String categoryName,
    Color purple,
    Color inactiveBg,
    Color primaryText,
  ) {
    final bool isSelected = _selectedCategory == categoryName;

    IconData icon;
    if (categoryName == 'Home') {
      icon = LucideIcons.house;
    } else if (categoryName.contains('Work')) {
      icon = LucideIcons.briefcase;
    } else {
      icon = LucideIcons.mapPin;
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = categoryName;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
          decoration: BoxDecoration(
            color: isSelected ? purple.withValues(alpha: 0.14) : inactiveBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: isSelected ? purple : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20.sp,
                color: isSelected ? purple : primaryText.withValues(alpha: 0.7),
              ),
              SizedBox(height: 6.h),
              Text(
                categoryName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.font(12),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? purple : primaryText,
                ),
              ),
            ],
          ),
        ),
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
    final fill = isDark ? AppTheme.darkSurface : Colors.white;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
        fontSize: AppTypography.font(14),
      ),
      filled: true,
      fillColor: fill,
      suffixIcon: suffix,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: borderColor, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: BorderSide(color: purple, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.r),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }
}
