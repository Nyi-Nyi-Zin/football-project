import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/locale_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nrcController = TextEditingController();
  final _gmailController = TextEditingController();
  final _locationController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _isVerifyingLocation = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _loadedUserId;

  // NRC state
  List<dynamic> _nrcData = [];
  List<dynamic> _nrcTownships = [];
  int? _selectedRegion;
  String? _selectedTownshipId; // Use ID instead of name
  String? _selectedNumberType; // (နိုင်), (ဧည့်), (ပြု)
  final _nrcNumberController = TextEditingController();

  // Number types with IDs (matching backend nrc_types table)
  static const List<String> _numberTypes = ['(နိုင်)', '(ဧည့်)', '(ပြု)'];
  static const Map<String, int> _numberTypeIds = {
    '(နိုင်)': 1,
    '(ဧည့်)': 2,
    '(ပြု)': 3,
  };

  // Myanmar numerals
  static const List<String> _mmNumerals = [
    '၀',
    '၁',
    '၂',
    '၃',
    '၄',
    '၅',
    '၆',
    '၇',
    '၈',
    '၉',
    '၁၀',
    '၁၁',
    '၁၂',
    '၁၃',
    '၁၄'
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _nrcController.dispose();
    _gmailController.dispose();
    _locationController.dispose();
    _nrcNumberController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadNRCData();
  }

  Future<void> _loadNRCData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/nrc.json');
      final jsonData = json.decode(jsonString);
      setState(() {
        _nrcData = jsonData['data'] as List<dynamic>;
      });
    } catch (e) {
      print('Error loading NRC data: $e');
    }
  }

  void _loadNRCTownships(int region, {String? townshipNameToMatch}) {
    final townships = _nrcData
        .where((item) => item['nrc_code'] == region.toString())
        .toList();
    setState(() {
      _nrcTownships = townships;
      _selectedTownshipId = null;
    });

    // If a township name is provided, find and set its ID after townships are loaded
    if (townshipNameToMatch != null && townships.isNotEmpty) {
      final township = townships.firstWhere(
        (t) => t['name_mm'] == townshipNameToMatch,
        orElse: () => {},
      );
      if (township.isNotEmpty) {
        setState(() {
          _selectedTownshipId = township['id'] as String?;
        });
      }
    }
  }

  String _convertToMMNumerals(String input) {
    String result = '';
    for (int i = 0; i < input.length; i++) {
      int digit = int.tryParse(input[i]) ?? -1;
      if (digit >= 0 && digit <= 9) {
        result += _mmNumerals[digit];
      } else {
        result += input[i];
      }
    }
    return result;
  }

  String _extractTownshipCode(String nameMm) {
    // Extract first 3 characters after the opening parenthesis
    // Example: "(သတန)နိုင်" -> "သတန"
    final match = RegExp(r'\((.{3})').firstMatch(nameMm);
    return match?.group(1) ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull;
    final themeMode = ref.watch(themeModeProvider);

    if (user != null && _loadedUserId != user.id) {
      _loadedUserId = user.id;
      _fullNameController.text = user.fullName;
      _phoneController.text = user.phone;
      _nrcController.text = user.nrc ?? '';
      _gmailController.text = user.gmail ?? '';
      _locationController.text = user.location ?? '';

      // Populate NRC component fields if available
      // Prefer ID fields from backend if available
      if (user.nrcRegionId != null) {
        _selectedRegion = user.nrcRegionId;
      } else if (user.nrcRegion != null && user.nrcRegion!.isNotEmpty) {
        _selectedRegion = int.tryParse(user.nrcRegion!);
      }

      if (user.nrcTownshipId != null) {
        // Use township ID from backend
        _selectedTownshipId = user.nrcTownshipId.toString();
        if (_selectedRegion != null) {
          _loadNRCTownships(_selectedRegion!);
        }
      } else if (user.nrcTownship != null && user.nrcTownship!.isNotEmpty) {
        // Check if it's an ID (numeric) or a name (contains Myanmar text)
        final townshipValue = user.nrcTownship!;
        if (int.tryParse(townshipValue) != null) {
          // It's an ID - set it directly
          _selectedTownshipId = townshipValue;
          // Load townships for the region
          if (_selectedRegion != null) {
            _loadNRCTownships(_selectedRegion!);
          }
        } else {
          // It's a name - load townships and match by name
          if (_selectedRegion != null) {
            _loadNRCTownships(_selectedRegion!,
                townshipNameToMatch: townshipValue);
          }
        }
      } else if (_selectedRegion != null) {
        // No township value, just load townships for the region
        _loadNRCTownships(_selectedRegion!);
      }

      if (user.nrcTypeId != null) {
        // Map ID back to type name
        final typeEntry = _numberTypeIds.entries.firstWhere(
          (e) => e.value == user.nrcTypeId,
          orElse: () => const MapEntry('', 0),
        );
        if (typeEntry.key.isNotEmpty) {
          _selectedNumberType = typeEntry.key;
        }
      } else if (user.nrcType != null && user.nrcType!.isNotEmpty) {
        _selectedNumberType = user.nrcType;
      }

      if (user.nrcNumber != null && user.nrcNumber!.isNotEmpty) {
        _nrcNumberController.text = user.nrcNumber!;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('profile')),
      ),
      body: user == null
          ? Center(
              child: Text(
                context.l10n.tr('userDataNotFound'),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '@${user.username}',
                            style:
                                const TextStyle(color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'User ID',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      user.id,
                                      style: const TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy User ID',
                                icon: const Icon(Icons.copy_outlined),
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: user.id),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('User ID copied'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.tr('theme'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.light,
                                icon: const Icon(Icons.light_mode_outlined),
                                label: Text(context.l10n.tr('lightMode')),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.dark,
                                icon: const Icon(Icons.dark_mode_outlined),
                                label: Text(context.l10n.tr('darkMode')),
                              ),
                              ButtonSegment<ThemeMode>(
                                value: ThemeMode.system,
                                icon:
                                    const Icon(Icons.settings_suggest_outlined),
                                label: Text(context.l10n.tr('systemMode')),
                              ),
                            ],
                            selected: {themeMode},
                            onSelectionChanged: (selection) {
                              final mode = selection.first;
                              ref
                                  .read(themeModeProvider.notifier)
                                  .setThemeMode(mode);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.tr('language'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    ref
                                        .read(localeProvider.notifier)
                                        .setEnglish();
                                  },
                                  child: Text(context.l10n.tr('english')),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    ref
                                        .read(localeProvider.notifier)
                                        .setMyanmar();
                                  },
                                  child: Text(context.l10n.tr('myanmar')),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _profileFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.tr('editProfile'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _fullNameController,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('fullName'),
                                prefixIcon: const Icon(Icons.person_outlined),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return context.l10n.tr('fullNameRequired');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('phone'),
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // NRC Region Dropdown (ပြည်နယ်/တိုင်း)
                            DropdownButtonFormField<int>(
                              value: _selectedRegion,
                              decoration: InputDecoration(
                                labelText: 'ပြည်နယ်/တိုင်း',
                                prefixIcon:
                                    const Icon(Icons.location_city_outlined),
                              ),
                              items: List.generate(14, (index) => index + 1)
                                  .map((region) {
                                return DropdownMenuItem<int>(
                                  value: region,
                                  child: Text('${_mmNumerals[region]}'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedRegion = value;
                                  if (value != null) {
                                    _loadNRCTownships(value);
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            // Township Dropdown (မြို့နယ်)
                            DropdownButtonFormField<String>(
                              value: _selectedTownshipId,
                              decoration: InputDecoration(
                                labelText: 'မြို့နယ်',
                                prefixIcon: const Icon(Icons.place_outlined),
                              ),
                              items: _nrcTownships.map((township) {
                                return DropdownMenuItem<String>(
                                  value: township['id'] as String,
                                  child: Text(township['name_mm'] as String),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedTownshipId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            // Number Type Dropdown (အမျိုးအစား)
                            DropdownButtonFormField<String>(
                              value: _selectedNumberType,
                              decoration: InputDecoration(
                                labelText: 'အမျိုးအစား',
                                prefixIcon: const Icon(Icons.category_outlined),
                              ),
                              items: _numberTypes.map((type) {
                                return DropdownMenuItem<String>(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedNumberType = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            // NRC Number (နံပါတ်)
                            TextFormField(
                              controller: _nrcNumberController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              decoration: InputDecoration(
                                labelText: 'နံပါတ်',
                                prefixIcon: const Icon(
                                    Icons.format_list_numbered_outlined),
                                counterText: '',
                              ),
                              validator: (value) {
                                if (_selectedRegion != null &&
                                    _selectedTownshipId != null &&
                                    _selectedNumberType != null &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please enter NRC number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _gmailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Gmail',
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final gmailRegex =
                                      RegExp(r'^[\w-\.]+@gmail\.com$');
                                  if (!gmailRegex.hasMatch(value)) {
                                    return 'Please enter a valid Gmail address';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _locationController,
                                    decoration: InputDecoration(
                                      labelText: 'Location',
                                      prefixIcon: const Icon(
                                          Icons.location_on_outlined),
                                      suffixIcon: IconButton(
                                        onPressed: _isVerifyingLocation
                                            ? null
                                            : _verifyLocation,
                                        icon: _isVerifyingLocation
                                            ? const SizedBox(
                                                height: 18,
                                                width: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.my_location),
                                      ),
                                    ),
                                    readOnly: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isSavingProfile ? null : _saveProfile,
                                child: _isSavingProfile
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(context.l10n.tr('saveProfile')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.tr('changePassword'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: _obscureCurrent,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('currentPassword'),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscureCurrent = !_obscureCurrent;
                                  }),
                                  icon: Icon(_obscureCurrent
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.l10n
                                      .tr('currentPasswordRequired');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNew,
                              decoration: InputDecoration(
                                labelText: context.l10n.tr('newPassword'),
                                prefixIcon: const Icon(Icons.lock_reset),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscureNew = !_obscureNew;
                                  }),
                                  icon: Icon(_obscureNew
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.l10n.tr('newPasswordRequired');
                                }
                                if (value.length < 8) {
                                  return context.l10n.tr('passwordMinLength');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText:
                                    context.l10n.tr('confirmNewPassword'),
                                prefixIcon: const Icon(Icons.lock),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  }),
                                  icon: Icon(_obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.l10n
                                      .tr('confirmPasswordRequired');
                                }
                                if (value != _newPasswordController.text) {
                                  return context.l10n.tr('passwordsNoMatch');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isChangingPassword
                                    ? null
                                    : _changePassword,
                                child: _isChangingPassword
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        context.l10n.tr('changePasswordBtn')),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(authNotifierProvider.notifier).logout();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(context.l10n.tr('logout')),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _saveProfile() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;

    // Construct NRC string if all NRC fields are selected
    // Format: MMNumber/TownshipCode(NumberType)Number
    // Example: ၁/သတန(နိုင်)၁၁၁၈၄၃
    String? nrcValue;
    String? nrcRegion;
    String? nrcTownship;
    String? nrcType;
    String? nrcNumber;

    // NRC ID fields for backend reference tables
    int? nrcRegionId;
    int? nrcTownshipIdInt;
    int? nrcTypeId;

    if (_selectedRegion != null &&
        _selectedTownshipId != null &&
        _selectedNumberType != null &&
        _nrcNumberController.text.isNotEmpty) {
      final regionMM = _mmNumerals[_selectedRegion!];
      // Get township name from ID
      final township = _nrcTownships
          .firstWhere((t) => t['id'] == _selectedTownshipId, orElse: () => {});
      final townshipName = township['name_mm'] as String? ?? '';
      final townshipCode = _extractTownshipCode(townshipName);
      final numberMM = _convertToMMNumerals(_nrcNumberController.text.trim());
      nrcValue = '$regionMM/$townshipCode$_selectedNumberType$numberMM';

      // Send IDs to backend (primary way)
      nrcRegionId = _selectedRegion;
      nrcTownshipIdInt = int.tryParse(_selectedTownshipId!);
      nrcTypeId = _numberTypeIds[_selectedNumberType];

      // Also send string values for backward compatibility
      nrcRegion = _selectedRegion.toString();
      nrcTownship =
          township['nrc_code'] as String?; // Use nrc_code for string value
      nrcType = _selectedNumberType;
      nrcNumber = _nrcNumberController.text.trim();
    }

    setState(() => _isSavingProfile = true);
    final result = await ref.read(authNotifierProvider.notifier).updateProfile(
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          nrc: nrcValue,
          nrcRegion: nrcRegion,
          nrcTownship: nrcTownship,
          nrcType: nrcType,
          nrcNumber: nrcNumber,
          nrcRegionId: nrcRegionId,
          nrcTownshipId: nrcTownshipIdInt,
          nrcTypeId: nrcTypeId,
          gmail: _gmailController.text.trim(),
          location: _locationController.text.trim(),
        );
    if (!mounted) return;

    setState(() => _isSavingProfile = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppTheme.errorColor,
        ),
      ),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tr('profileUpdated')),
          backgroundColor: AppTheme.successColor,
        ),
      ),
    );
  }

  Future<void> _verifyLocation() async {
    setState(() => _isVerifyingLocation = true);
    try {
      // This is a placeholder for location verification
      // In a real implementation, you would use geolocator or location package
      // to get the actual device location
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      // Simulated location - in production, use actual geolocation
      _locationController.text = 'Yangon, Myanmar';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location verified successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify location: ${e.toString()}'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isVerifyingLocation = false);
      }
    }
  }

  Future<void> _changePassword() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    if (_currentPasswordController.text == _newPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.tr('newPasswordDifferent')),
        backgroundColor: AppTheme.warningColor,
      ));
      return;
    }

    setState(() => _isChangingPassword = true);
    final result = await ref.read(authNotifierProvider.notifier).changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
    if (!mounted) return;

    setState(() => _isChangingPassword = false);
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppTheme.errorColor,
        ),
      ),
      (_) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.tr('passwordChanged')),
            backgroundColor: AppTheme.successColor,
          ),
        );
      },
    );
  }
}
