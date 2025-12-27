import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/models/student.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/wallet_info.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsRepository _repository = SettingsRepository();

  // Expansion states
  bool _personalExpanded = false;
  bool _packageExpanded = false;
  bool _subscriptionExpanded = false;

  // Data states
  Student? _student;
  WalletInfo? _walletInfo;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _packageEditMode = false;

  // Dropdown options
  static const List<String> _lessonsNameOptions = [
    'قرآن',
    'لغة عربية',
    'تجويد',
    'تربية اسلامية',
    'تربية اسلامية لغير الناطقين',
    'قرآن لغير الناطقين',
    'لغة عربية لغير الناطقين',
  ];
  static const List<int> _lessonsNumberOptions = [4, 8, 12, 16, 20, 24];
  static const List<int> _lessonDurationOptions = [30, 45, 60];

  // Countries list (Arab countries first, then others)
  static const List<String> _countryOptions = [
    // Arab Countries
    'مصر', 'السعودية', 'الجزائر', 'البحرين', 'جزر القمر', 'جيبوتي', 'العراق',
    'الأردن', 'الكويت', 'لبنان', 'ليبيا', 'موريتانيا', 'المغرب', 'عمان',
    'فلسطين', 'قطر', 'الصومال', 'السودان', 'سوريا', 'تونس', 'الإمارات', 'اليمن',
    // Other Countries
    'أفغانستان', 'ألبانيا', 'أرمينيا', 'أستراليا', 'النمسا', 'أذربيجان',
    'بربادوس', 'بنغلاديش', 'بيلاروسيا', 'بلجيكا', 'بليز', 'بنين', 'بوتان',
    'بوليفيا', 'البوسنة والهرسك', 'بوتسوانا', 'البرازيل', 'بروناي', 'بلغاريا',
    'بوركينا فاسو', 'بوروندي', 'كمبوديا', 'الكاميرون', 'كندا', 'كيب فيردي',
    'جمهورية أفريقيا الوسطى', 'تشاد', 'شيلي', 'الصين', 'كولومبيا', 'الكونغو',
    'كونغو (جمهورية الكونغو الديمقراطية)', 'كوستاريكا', 'كرواتيا', 'كوبا',
    'قبرص', 'جمهورية التشيك', 'الدنمارك', 'دومينيكا', 'جمهورية الدومينيكان',
    'تيمور الشرقية', 'الإكوادور', 'إلسلفادور', 'غينيا الاستوائية', 'إريتريا',
    'إستونيا', 'إثيوبيا', 'فيجي', 'فنلندا', 'فرنسا', 'غابون', 'غامبيا',
    'جورجيا', 'ألمانيا', 'غانا', 'غرينادا', 'غواتيمالا', 'غينيا', 'غينيا بيساو',
    'غواديلوب', 'جوادلوب', 'هايتي', 'هندوراس', 'هونغ كونغ', 'هنغاريا',
    'أيسلندا', 'إندونيسيا', 'الهند', 'إيران', 'إيرلندا', 'إيطاليا', 'جامايكا',
    'اليابان', 'كازاخستان', 'كينيا', 'كيريباتي', 'كوريا الجنوبية', 'كوت ديفوار',
    'كوسوفو', 'كيوبيك', 'قيرغيزستان', 'لاوس', 'لاتفيا', 'ليسوتو', 'ليبيريا',
    'لكسمبورغ', 'مقدونيا', 'مدغشقر', 'ملاوي', 'ماليزيا', 'مالطا', 'مارشال',
    'موريشيوس', 'المكسيك', 'ميكرونيزيا', 'مولدوفا', 'منغوليا', 'مونتسيرات',
    'موزمبيق', 'ميانمار', 'ناميبيا', 'ناورو', 'نيبال', 'هولندا', 'نيوزيلندا',
    'نيكاراغوا', 'النيجر', 'نيجيريا', 'النرويج', 'أوكرانيا', 'أوغندا',
    'أوروغواي', 'فانواتو', 'فنزويلا', 'فيتنام', 'واليس وفوتونا',
  ];

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _countryController = TextEditingController();
  final _lessonsNameController = TextEditingController();
  final _lessonDurationController = TextEditingController();
  final _lessonsNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    _countryController.dispose();
    _lessonsNameController.dispose();
    _lessonDurationController.dispose();
    _lessonsNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // First try to get from auth state for quick display
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        _student = authState.student;
        _populateControllers();
      }

      // Always fetch fresh profile to get latest data including dob
      try {
        final freshProfile = await _repository.getProfile();
        if (mounted) {
          _student = freshProfile;
          _populateControllers();
          if (kDebugMode) {
            print(
                'SettingsPage._loadData - Fresh profile loaded, dob: ${freshProfile.birthday}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('SettingsPage._loadData - Could not fetch fresh profile: $e');
        }
      }

      // Load wallet info
      final walletInfo = await _repository.getWalletInfo();

      if (mounted) {
        setState(() {
          _walletInfo = walletInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في تحميل البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _populateControllers() {
    if (_student != null) {
      if (kDebugMode) {
        print('SettingsPage._populateControllers - student: ${_student!.name}');
        print(
            'SettingsPage._populateControllers - birthday/dob: ${_student!.birthday}');
        print(
            'SettingsPage._populateControllers - country: ${_student!.country}');
      }
      _nameController.text = _student!.name;
      _emailController.text = _student!.email ?? '';
      _birthdayController.text = _student!.birthday ?? '';
      _countryController.text = _student!.country ?? '';
      _lessonsNameController.text = _student!.lessonsName ?? '';
      _lessonDurationController.text = _student!.lessonDuration ?? '';
      _lessonsNumberController.text = _student!.lessonsNumber?.toString() ?? '';
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Try to parse existing date
    DateTime initialDate = DateTime.now();
    if (_birthdayController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_birthdayController.text);
      } catch (_) {
        // If parsing fails, use current date
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        // Format as YYYY-MM-DD
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _savePersonalData() async {
    try {
      setState(() => _isSaving = true);

      if (kDebugMode) {
        print('SettingsPage._savePersonalData - name: ${_nameController.text}');
        print(
            'SettingsPage._savePersonalData - email: ${_emailController.text}');
      }

      // Call repository and get updated student data
      final updatedStudent = await _repository.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        birthday: _birthdayController.text,
        country: _countryController.text,
      );

      if (kDebugMode) {
        print(
            'SettingsPage._savePersonalData - Updated student: ${updatedStudent.name}');
      }

      // Update local state with returned data
      if (mounted) {
        setState(() {
          _student = updatedStudent;
        });

        // Refresh profile in auth bloc
        context.read<AuthBloc>().add(GetStudentProfileEvent());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ البيانات الشخصية بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('SettingsPage._savePersonalData - Error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _savePackageData() async {
    try {
      setState(() => _isSaving = true);

      // Calculate new amount based on new lessons number with same per-lesson price
      final oldLessonsNumber = _student?.lessonsNumber ?? 0;
      final oldAmount = _student?.amount ?? 0;
      final pricePerLesson =
          oldLessonsNumber > 0 ? (oldAmount / oldLessonsNumber) : 0.0;
      final newLessonsNumber =
          int.tryParse(_lessonsNumberController.text) ?? oldLessonsNumber;
      final newAmount = (newLessonsNumber * pricePerLesson).round();

      if (kDebugMode) {
        print(
            'SettingsPage._savePackageData - lessonsName: ${_lessonsNameController.text}');
        print(
            'SettingsPage._savePackageData - lessonDuration: ${_lessonDurationController.text}');
        print(
            'SettingsPage._savePackageData - lessonsNumber: ${_lessonsNumberController.text}');
        print('SettingsPage._savePackageData - calculated amount: $newAmount');
      }

      final updatedStudent = await _repository.updateProfile(
        lessonsName: _lessonsNameController.text,
        lessonDuration: _lessonDurationController.text,
        lessonsNumber: int.tryParse(_lessonsNumberController.text),
        amount: newAmount,
      );

      if (kDebugMode) {
        print(
            'SettingsPage._savePackageData - Updated student: ${updatedStudent.lessonsName}');
      }

      // Update local state with returned data
      if (mounted) {
        setState(() {
          _student = updatedStudent;
          _packageEditMode = false; // Exit edit mode after save
        });

        // Refresh profile in auth bloc
        context.read<AuthBloc>().add(GetStudentProfileEvent());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ بيانات الباقة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('SettingsPage._savePackageData - Error: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل في حفظ البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('المعرض'),
                onTap: () {
                  _getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('الكاميرا'),
                onTap: () {
                  _getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        await _uploadImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل اختيار الصورة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    try {
      setState(() => _isSaving = true);

      // Upload image
      final newImageUrl = await _repository.uploadProfileImage(imageFile);

      if (mounted) {
        setState(() {
          // Update local student object with new image URL
          if (_student != null) {
            _student = _student!.copyWith(profileImageUrl: newImageUrl);
          }
        });

        // Refresh auth bloc
        context.read<AuthBloc>().add(GetStudentProfileEvent());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث الصورة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الصورة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تغيير كلمة المرور',
          style: TextStyle(color: AppTheme.primaryColor),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الحالية',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                prefixIcon: Icon(Icons.lock),
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                prefixIcon: Icon(Icons.lock),
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text !=
                  confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور غير متطابقة'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await _repository.changePassword(
                  currentPasswordController.text,
                  newPasswordController.text,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير كلمة المرور بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('فشل في تغيير كلمة المرور: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF5),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Section 1: Personal Data
                      _buildExpandableSection(
                        title: 'البيانات الشخصية',
                        subtitle: _student?.name ?? 'تعديل بياناتك الشخصية',
                        icon: Icons.person_rounded,
                        isExpanded: _personalExpanded,
                        onTap: () => setState(
                            () => _personalExpanded = !_personalExpanded),
                        avatar: _buildProfileAvatar(),
                        content: _buildPersonalDataContent(),
                      ),

                      const SizedBox(height: 16),

                      // Section 2: Package Management
                      _buildExpandableSection(
                        title: 'إدارة الباقة',
                        subtitle: _student?.lessonsName ?? 'تعديل بيانات الحصص',
                        icon: Icons.school_rounded,
                        isExpanded: _packageExpanded,
                        onTap: () => setState(
                            () => _packageExpanded = !_packageExpanded),
                        content: _buildPackageContent(),
                      ),

                      const SizedBox(height: 16),

                      // Section 3: Subscription
                      _buildExpandableSection(
                        title: 'الاشتراك والرصيد',
                        subtitle: _walletInfo != null
                            ? '${_walletInfo!.balance.toStringAsFixed(2)} ${_walletInfo!.currency}'
                            : 'عرض تفاصيل المحفظة',
                        icon: Icons.account_balance_wallet_rounded,
                        isExpanded: _subscriptionExpanded,
                        onTap: () => setState(() =>
                            _subscriptionExpanded = !_subscriptionExpanded),
                        content: _buildSubscriptionContent(),
                      ),

                      const SizedBox(height: 100), // Bottom padding for nav bar
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD4AF37),
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26D4AF37),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: _student?.profileImageUrl != null &&
                _student!.profileImageUrl!.isNotEmpty
            ? Image.network(
                _student!.profileImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
              )
            : _buildDefaultAvatar(),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Icon(
        Icons.person,
        color: AppTheme.primaryColor,
        size: 30,
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
    Widget? avatar,
    required Widget content,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFFD4AF37) : const Color(0xFFE0E0E0),
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isExpanded ? const Color(0x26D4AF37) : const Color(0x0D000000),
            blurRadius: isExpanded ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon/Avatar on the right
                  avatar ??
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: AppTheme.primaryColor,
                          size: 28,
                        ),
                      ),

                  const SizedBox(width: 16),

                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Arrow - points left when collapsed, down when expanded (RTL)
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? -0.25 : 0,
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFFD4AF37),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expandable Content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(color: Color(0xFFE0E0E0)),
                  const SizedBox(height: 16),
                  content,
                ],
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDataContent() {
    return Column(
      children: [
        // Profile image section
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _student?.profileImageUrl != null &&
                          _student!.profileImageUrl!.isNotEmpty
                      ? Image.network(
                          _student!.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                        )
                      : _buildDefaultAvatar(),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Form fields
        _buildTextField(
          controller: _nameController,
          label: 'الاسم',
          icon: Icons.person_outline,
        ),

        const SizedBox(height: 16),

        _buildTextField(
          controller: _emailController,
          label: 'البريد الإلكتروني',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        // Birthday date picker
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                const Icon(Icons.cake_outlined, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تاريخ الميلاد',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _birthdayController.text.isNotEmpty
                            ? _birthdayController.text
                            : 'اختر التاريخ',
                        style: TextStyle(
                          fontSize: 16,
                          color: _birthdayController.text.isNotEmpty
                              ? Colors.black87
                              : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.calendar_today_outlined,
                    color: const Color(0xFFD4AF37), size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Country dropdown
        _buildDropdownField<String>(
          label: 'الدولة',
          icon: Icons.location_on_outlined,
          value: _countryController.text.isNotEmpty &&
                  _countryOptions.contains(_countryController.text)
              ? _countryController.text
              : null,
          items: _countryOptions,
          onChanged: (value) {
            if (value != null) {
              setState(() => _countryController.text = value);
            }
          },
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text('تغيير كلمة المرور'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _savePersonalData,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ التغييرات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPackageContent() {
    // If not in edit mode, show compact view
    if (!_packageEditMode) {
      return Column(
        children: [
          // Compact info display - all 3 values in one beautiful card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFF8E1),
                  const Color(0xFFFFF3CD).withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Lessons Name
                    _buildPackageInfoItem(
                      icon: Icons.book_rounded,
                      label: 'نوع الحصة',
                      value: _student?.lessonsName ?? '-',
                    ),
                    // Divider
                    Container(
                      height: 50,
                      width: 1,
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                    ),
                    // Lessons Number
                    _buildPackageInfoItem(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'عدد الحصص',
                      value: '${_student?.lessonsNumber ?? 0}',
                    ),
                    // Divider
                    Container(
                      height: 50,
                      width: 1,
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                    ),
                    // Duration
                    _buildPackageInfoItem(
                      icon: Icons.timer_rounded,
                      label: 'المدة',
                      value: '${_student?.lessonDuration ?? 0} د',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Teacher info
          if (_student?.teacherName != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'المعلم',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          _student!.teacherName!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Edit button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showPackageEditConfirmation,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('تعديل بيانات الباقة'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      );
    }

    // Edit mode with dropdowns
    return Column(
      children: [
        // Warning banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تغيير هذه البيانات قد يؤثر على المدفوعات والجدول',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Lessons Name Dropdown
        _buildDropdownField(
          label: 'نوع الحصة',
          icon: Icons.book_outlined,
          value: _lessonsNameController.text.isNotEmpty &&
                  _lessonsNameOptions.contains(_lessonsNameController.text)
              ? _lessonsNameController.text
              : null,
          items: _lessonsNameOptions,
          onChanged: (value) {
            if (value != null) {
              setState(() => _lessonsNameController.text = value);
            }
          },
        ),

        const SizedBox(height: 16),

        // Lessons Number Dropdown
        _buildDropdownField(
          label: 'عدد الحصص شهرياً',
          icon: Icons.format_list_numbered,
          value: int.tryParse(_lessonsNumberController.text),
          items: _lessonsNumberOptions,
          onChanged: (value) {
            if (value != null) {
              setState(() => _lessonsNumberController.text = value.toString());
            }
          },
        ),

        const SizedBox(height: 16),

        // Lesson Duration Dropdown
        _buildDropdownField(
          label: 'مدة الحصة (دقيقة)',
          icon: Icons.timer_outlined,
          value: int.tryParse(_lessonDurationController.text),
          items: _lessonDurationOptions,
          onChanged: (value) {
            if (value != null) {
              setState(() => _lessonDurationController.text = value.toString());
            }
          },
        ),

        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _packageEditMode = false;
                    _populateControllers(); // Reset to original values
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('إلغاء'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _showPackageSaveConfirmation,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('تأكيد التعديل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPackageInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color(0xFFD4AF37),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required IconData icon,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        color: Colors.grey[50],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(
              item.toString(),
              style: const TextStyle(fontSize: 16),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFFD4AF37)),
        dropdownColor: Colors.white,
        isExpanded: true,
      ),
    );
  }

  void _showPackageEditConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.orange),
            ),
            const SizedBox(width: 12),
            const Text(
              'تعديل الباقة',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ],
        ),
        content: const Text(
          'تغيير بيانات الباقة (نوع الحصة، العدد، المدة) قد يؤثر على:\n\n'
          '• المدفوعات والفواتير\n'
          '• جدول الحصص\n'
          '• الرصيد المعلق\n\n'
          'هل تريد المتابعة؟',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _packageEditMode = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
            child: const Text('متابعة التعديل'),
          ),
        ],
      ),
    );
  }

  void _showPackageSaveConfirmation() {
    if (_student == null) return;

    // Get current and new values
    final oldLessonsNumber = _student!.lessonsNumber ?? 0;
    final oldDuration = int.tryParse(_student!.lessonDuration ?? '0') ?? 0;
    final oldAmount = _student!.amount ?? 0;
    final currency = _student!.currency ?? 'SAR';

    final newLessonsNumber =
        int.tryParse(_lessonsNumberController.text) ?? oldLessonsNumber;
    final newDuration =
        int.tryParse(_lessonDurationController.text) ?? oldDuration;
    final newLessonsName = _lessonsNameController.text;

    // Check if there are actual changes
    final hasLessonsNumberChanged = newLessonsNumber != oldLessonsNumber;
    final hasDurationChanged = newDuration != oldDuration;
    final hasNameChanged = newLessonsName != (_student!.lessonsName ?? '');

    // Formula from API docs:
    // 1. remaining_lessons = old_lessons_number - sessions_completed
    // 2. per_lesson_price = old_amount / old_lessons_number
    // 3. total_credit = remaining_lessons × per_lesson_price
    // 4. adjustment = total_credit - new_amount

    // Note: sessions_completed is not available in client, server will calculate actual amount
    // We show an estimate assuming all lessons are remaining

    // Calculate price per lesson
    final pricePerLesson =
        oldLessonsNumber > 0 ? (oldAmount / oldLessonsNumber) : 0.0;

    // Calculate new amount based on new lessons number with same per-lesson price
    final newAmount = newLessonsNumber * pricePerLesson;

    // Estimate: assuming all old lessons are remaining (server has actual sessions_completed)
    final estimatedRemainingLessons = oldLessonsNumber;
    final totalCredit = estimatedRemainingLessons * pricePerLesson;
    final estimatedAdjustment = totalCredit - newAmount;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text(
              'تأكيد تعديل الباقة',
              style: TextStyle(color: AppTheme.primaryColor, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Changes summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (hasNameChanged)
                      _buildConfirmationRow(
                        'نوع الحصة',
                        '${_student!.lessonsName ?? "-"} ← $newLessonsName',
                      ),
                    if (hasLessonsNumberChanged)
                      _buildConfirmationRow(
                        'عدد الحصص',
                        '$oldLessonsNumber ← $newLessonsNumber',
                      ),
                    if (hasDurationChanged)
                      _buildConfirmationRow(
                        'مدة الحصة',
                        '$oldDuration دقيقة ← $newDuration دقيقة',
                      ),
                  ],
                ),
              ),

              if (hasLessonsNumberChanged || hasDurationChanged) ...[
                const SizedBox(height: 16),

                // Financial impact
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    children: [
                      _buildFinancialRow(
                        'الدروس المتبقية (تقديري)',
                        '$estimatedRemainingLessons',
                        icon: Icons.school_outlined,
                      ),
                      const Divider(height: 16),
                      _buildFinancialRow(
                        'إجمالي رصيد الحصص',
                        '${totalCredit.toStringAsFixed(2)} $currency',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const Divider(height: 16),
                      _buildFinancialRow(
                        'سعر الباقة الجديدة',
                        '${newAmount.toStringAsFixed(2)} $currency',
                        icon: Icons.price_change_outlined,
                      ),
                      const Divider(height: 16),
                      _buildFinancialRow(
                        estimatedAdjustment >= 0
                            ? 'سيتم إضافة للرصيد المعلق'
                            : 'سيتم خصم من الرصيد المعلق',
                        '${estimatedAdjustment >= 0 ? "+" : ""}${estimatedAdjustment.toStringAsFixed(2)} $currency',
                        icon: estimatedAdjustment >= 0
                            ? Icons.add_circle_outline
                            : Icons.remove_circle_outline,
                        valueColor: estimatedAdjustment >= 0
                            ? Colors.green
                            : Colors.red,
                        isBold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Note
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'القيم أعلاه تقديرية. سيتم احتساب التعديل الفعلي بناءً على عدد الحصص المكتملة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _savePackageData();
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('تأكيد وحفظ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value, {
    required IconData icon,
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: valueColor ?? AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionContent() {
    return Column(
      children: [
        // Balance card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B0628), Color(0xFFAD0A33)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x338B0628),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'رصيد المحفظة',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_walletInfo?.balance.toStringAsFixed(2) ?? '0.00'} ${_walletInfo?.currency ?? 'EGP'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_walletInfo != null && _walletInfo!.pendingBalance != 0) ...[
                const SizedBox(height: 8),
                Text(
                  'رصيد معلق: ${_walletInfo!.pendingBalance.toStringAsFixed(2)} ${_walletInfo!.currency}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Payment status
        if (_student?.paymentStatus != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getPaymentStatusColor(_student!.paymentStatus!)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getPaymentStatusColor(_student!.paymentStatus!),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getPaymentStatusIcon(_student!.paymentStatus!),
                  color: _getPaymentStatusColor(_student!.paymentStatus!),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'حالة الدفع',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _student!.paymentStatus!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              _getPaymentStatusColor(_student!.paymentStatus!),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Amount info
        if (_student?.amount != null && _student!.amount! > 0) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'قيمة الاشتراك',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '${_student!.amount!.toStringAsFixed(2)} ${_student!.currency ?? 'EGP'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Recent transactions
        if (_walletInfo != null && _walletInfo!.transactions.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'آخر المعاملات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...(_walletInfo!.transactions
              .take(5)
              .map((t) => _buildTransactionItem(t))),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد معاملات',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactionItem(WalletTransaction transaction) {
    // Determine if it's a credit based on description (fallback)
    final isCredit = transaction.isCredit ||
        transaction.description.contains('إضافة') ||
        transaction.description.contains('رصيد');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCredit
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCredit
                  ? Colors.green.withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCredit
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: isCredit ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          // Description & Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCredit
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    transaction.typeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCredit ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Description - allow multiple lines
                Text(
                  transaction.description.isNotEmpty
                      ? transaction.description
                      : transaction.typeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Date & student name
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      transaction.date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (transaction.studentName != null &&
                        transaction.studentName!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.person_outline,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          transaction.studentName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isCredit ? '+' : '-',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green[700] : Colors.red[700],
                ),
              ),
              Text(
                transaction.amount.abs().toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Color _getPaymentStatusColor(String status) {
    if (status.contains('تم الدفع')) return Colors.green;
    if (status.contains('انتظار')) return Colors.orange;
    if (status.contains('متوقف')) return Colors.red;
    return Colors.grey;
  }

  IconData _getPaymentStatusIcon(String status) {
    if (status.contains('تم الدفع')) return Icons.check_circle;
    if (status.contains('انتظار')) return Icons.schedule;
    if (status.contains('متوقف')) return Icons.pause_circle;
    return Icons.info;
  }
}
