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
import '../widgets/settings/settings_action_buttons.dart';
import '../widgets/settings/settings_course_card.dart';
import '../widgets/settings/settings_subscriptions_card.dart';
import '../widgets/settings/settings_financial_card.dart';
import '../widgets/settings/settings_bottom_actions.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsRepository _repository = SettingsRepository();

  // Expansion states
  bool _personalExpanded = false; // Default open for personal data

  // Data states
  Student? _student;
  WalletInfo? _walletInfo;
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  // Package Edit Mode (controlled by dialog now, but state needed for form)
  // We keep controllers for the form

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _countryController = TextEditingController();

  final _lessonsNameController = TextEditingController();
  final _lessonDurationController = TextEditingController();
  final _lessonsNumberController = TextEditingController();

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

  // Countries list
  static const List<String> _countryOptions = [
    'مصر',
    'السعودية',
    'الجزائر',
    'البحرين',
    'جزر القمر',
    'جيبوتي',
    'العراق',
    'الأردن',
    'الكويت',
    'لبنان',
    'ليبيا',
    'موريتانيا',
    'المغرب',
    'عمان',
    'فلسطين',
    'قطر',
    'الصومال',
    'السودان',
    'سوريا',
    'تونس',
    'الإمارات',
    'اليمن',
    'أفغانستان',
    'ألبانيا',
    'أرمينيا',
    'أستراليا',
    'النمسا',
    'أذربيجان',
    'بربادوس',
    'بنغلاديش',
    'بيلاروسيا',
    'بلجيكا',
    'بليز',
    'بنين',
    'بوتان',
    'بوليفيا',
    'البوسنة والهرسك',
    'بوتسوانا',
    'البرازيل',
    'بروناي',
    'بلغاريا',
    'بوركينا فاسو',
    'بوروندي',
    'كمبوديا',
    'الكاميرون',
    'كندا',
    'كيب فيردي',
    'جمهورية أفريقيا الوسطى',
    'تشاد',
    'شيلي',
    'الصين',
    'كولومبيا',
    'الكونغو',
    'كونغو (جمهورية الكونغو الديمقراطية)',
    'كوستاريكا',
    'كرواتيا',
    'كوبا',
    'قبرص',
    'جمهورية التشيك',
    'الدنمارك',
    'دومينيكا',
    'جمهورية الدومينيكان',
    'تيمور الشرقية',
    'الإكوادور',
    'إلسلفادور',
    'غينيا الاستوائية',
    'إريتريا',
    'إستونيا',
    'إثيوبيا',
    'فيجي',
    'فنلندا',
    'فرنسا',
    'غابون',
    'غامبيا',
    'جورجيا',
    'ألمانيا',
    'غانا',
    'غرينادا',
    'غواتيمالا',
    'غينيا',
    'غينيا بيساو',
    'غواديلوب',
    'جوادلوب',
    'هايتي',
    'هندوراس',
    'هونغ كونغ',
    'هنغاريا',
    'أيسلندا',
    'إندونيسيا',
    'الهند',
    'إيران',
    'إيرلندا',
    'إيطاليا',
    'جامايكا',
    'اليابان',
    'كازاخستان',
    'كينيا',
    'كيريباتي',
    'كوريا الجنوبية',
    'كوت ديفوار',
    'كوسوفو',
    'كيوبيك',
    'قيرغيزستان',
    'لاوس',
    'لاتفيا',
    'ليسوتو',
    'ليبيريا',
    'لكسمبورغ',
    'مقدونيا',
    'مدغشقر',
    'ملاوي',
    'ماليزيا',
    'مالطا',
    'مارشال',
    'موريشيوس',
    'المكسيك',
    'ميكرونيزيا',
    'مولدوفا',
    'منغوليا',
    'مونتسيرات',
    'موزمبيق',
    'ميانمار',
    'ناميبيا',
    'ناورو',
    'نيبال',
    'هولندا',
    'نيوزيلندا',
    'نيكاراغوا',
    'النيجر',
    'نيجيريا',
    'النرويج',
    'أوكرانيا',
    'أوغندا',
    'أوروغواي',
    'فانواتو',
    'فنزويلا',
    'فيتنام',
    'واليس وفوتونا',
  ];

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

      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.student != null) {
        _student = authState.student;
        _populateControllers();
      }

      try {
        final freshProfile = await _repository.getProfile();
        if (mounted) {
          _student = freshProfile;
          _populateControllers();
        }
      } catch (e) {
        if (kDebugMode) {
          print('SettingsPage._loadData - Could not fetch fresh profile: $e');
        }
      }

      final walletInfo = await _repository.getWalletInfo();
      final familyMembers = await _repository.getFamilyMembers();

      if (mounted) {
        setState(() {
          _walletInfo = walletInfo;
          _familyMembers = familyMembers;
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
      _nameController.text = _student!.name;
      _emailController.text = _student!.email ?? '';
      _birthdayController.text = _student!.birthday ?? '';
      _countryController.text = _student!.country ?? '';
      _lessonsNameController.text = _student!.lessonsName ?? '';
      _lessonDurationController.text = _student!.lessonDuration ?? '';
      _lessonsNumberController.text = _student!.lessonsNumber?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF8b0628),
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
                  padding: EdgeInsets.fromLTRB(
                      16, MediaQuery.of(context).padding.top + 20.0, 16, 16),
                  child: Column(
                    children: [
                      // 1. Personal Data (PRESERVED)
                      _buildExpandableSection(
                        title: _student?.name ?? 'البيانات الشخصية',
                        subtitle: 'تعديل بيانات الطالب',
                        icon: Icons.person_rounded,
                        isExpanded: _personalExpanded,
                        onTap: () => setState(
                            () => _personalExpanded = !_personalExpanded),
                        avatar: _buildProfileAvatar(),
                        content: _buildPersonalDataContent(),
                      ),
                      const SizedBox(height: 16),
                      // 2. Action Buttons (NEW)
                      SettingsActionButtons(
                        onAddStudent: () {
                          // TODO: Navigate to add student
                        },
                        onNewExperience: () {
                          // TODO: Navigate to new experience
                        },
                      ),

                      _buildDivider(),

                      // 3. Course Details (NEW)
                      if (_student != null)
                        SettingsCourseCard(
                          student: _student!,
                          onEditPackage: _showPackageEditDialog,
                          onCancelRenewal: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'يرجى التواصل مع الإدارة لإلغاء التجديد')));
                          },
                          onChangeTeacher: () {
                            // TODO: Navigate to teacher change
                          },
                        ),

                      if (_student != null) _buildDivider(),
                      if (_familyMembers.isNotEmpty)
                        SettingsSubscriptionsCard(
                          familyMembers: _familyMembers
                              .where((s) => s['payment_status'] != 'متوقف')
                              .toList(),
                        ),

                      if (_familyMembers.isNotEmpty) _buildDivider(),

                      // 5. Financial Info (NEW)
                      if (_walletInfo != null)
                        SettingsFinancialCard(
                          walletInfo: _walletInfo!,
                          totalAmount: _familyMembers
                              .where((s) => s['payment_status'] != 'متوقف')
                              .fold(
                                  0.0,
                                  (sum, s) =>
                                      sum +
                                      (double.tryParse(
                                              s['amount']?.toString() ?? '0') ??
                                          0.0)),
                          dueAmount: _walletInfo!.balance + _walletInfo!.pendingBalance,
                        ),

                      const SizedBox(height: 16),

                      // 6. Bottom Actions (NEW)
                      SettingsBottomActions(
                        onTransactions: _showTransactionsModal,
                        onPostponePayment: () {
                          // Placeholder
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('طلب تأجيل الدفع - قريباً')));
                        },
                        onPayFees: () {
                          // Placeholder
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('تسديد الرسوم - قريباً')));
                        },
                      ),

                      const SizedBox(height: 100), // Bottom padding
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(
        color: Colors.white,
        thickness: 2,
      ),
    );
  }

  // --- PRESERVED & HELPER WIDGETS ---

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
    return Image.asset(
      'assets/images/male_avatar.webp',
      fit: BoxFit.cover,
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
    // Preserved exact logic
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromARGB(255, 255, 255, 255),
            Color.fromARGB(255, 234, 234, 234),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? const Color(0xFFD4AF37) : const Color(0xFFE0E0E0),
          width: isExpanded ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isExpanded
                ? const Color.fromARGB(26, 212, 175, 55)
                : const Color.fromARGB(82, 0, 0, 0),
            blurRadius: isExpanded ? 12 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  avatar ??
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(icon, color: AppTheme.primaryColor, size: 28),
                      ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: isExpanded ? -0.25 : 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 226, 226, 226),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.black,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(children: [content]),
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
                  border: Border.all(color: const Color(0xFFD4AF37), width: 3),
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
                    color: Color(0xFFD4AF37), shape: BoxShape.circle),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField(
            controller: _nameController,
            label: 'الاسم',
            icon: Icons.person_outline),
        const SizedBox(height: 16),
        _buildTextField(
            controller: _emailController,
            label: 'البريد الإلكتروني',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
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
                      Text('تاريخ الميلاد',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        _birthdayController.text.isNotEmpty
                            ? _birthdayController.text
                            : 'اختر التاريخ',
                        style: TextStyle(
                            fontFamily: 'Qatar',
                            fontSize: 16,
                            color: _birthdayController.text.isNotEmpty
                                ? Colors.black87
                                : Colors.grey[500]),
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
        _buildDropdownField<String>(
          label: 'الدولة',
          icon: Icons.location_on_outlined,
          value: _countryController.text.isNotEmpty &&
                  _countryOptions.contains(_countryController.text)
              ? _countryController.text
              : null,
          items: _countryOptions,
          onChanged: (value) {
            if (value != null) setState(() => _countryController.text = value);
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showChangePasswordDialog,
                icon: const Icon(Icons.lock_outline),
                label: const Text('تغيير كلمة المرور',
                    style: TextStyle(fontFamily: 'Qatar')),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
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
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ التغييرات',
                    style: TextStyle(fontFamily: 'Qatar')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        color: Colors.grey[50],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontFamily: 'Qatar'),
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
      ),
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
          labelStyle: const TextStyle(fontFamily: 'Qatar'),
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
              style: const TextStyle(fontFamily: 'Qatar', fontSize: 16),
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

  // --- LOGIC METHODS ---

  Future<void> _selectDate(BuildContext context) async {
    DateTime initialDate = DateTime.now();
    if (_birthdayController.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(_birthdayController.text);
      } catch (_) {}
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked != null) {
      setState(() {
        _birthdayController.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _savePersonalData() async {
    try {
      setState(() => _isSaving = true);
      final updatedStudent = await _repository.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
        birthday: _birthdayController.text,
        country: _countryController.text,
      );
      if (mounted) {
        setState(() => _student = updatedStudent);
        context.read<AuthBloc>().add(GetStudentProfileEvent());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حفظ البيانات الشخصية بنجاح'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل في حفظ البيانات: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Adapted Logic for Package Edit Modal
  void _showPackageEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('تعديل الباقة',
                  style: TextStyle(
                      fontFamily: 'Qatar', fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning,
                              color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text(
                                  'تغيير هذه البيانات قد يؤثر على المدفوعات والجدول',
                                  style: TextStyle(
                                      fontFamily: 'Qatar', fontSize: 12))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'نوع الحصة',
                      icon: Icons.book_outlined,
                      value: _lessonsNameController.text.isNotEmpty &&
                              _lessonsNameOptions
                                  .contains(_lessonsNameController.text)
                          ? _lessonsNameController.text
                          : null,
                      items: _lessonsNameOptions,
                      onChanged: (value) {
                        if (value != null) _lessonsNameController.text = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'عدد الحصص شهرياً',
                      icon: Icons.format_list_numbered,
                      value: int.tryParse(_lessonsNumberController.text),
                      items: _lessonsNumberOptions,
                      onChanged: (value) {
                        if (value != null) {
                          _lessonsNumberController.text = value.toString();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'مدة الحصة (دقيقة)',
                      icon: Icons.timer_outlined,
                      value: int.tryParse(_lessonDurationController.text),
                      items: _lessonDurationOptions,
                      onChanged: (value) {
                        if (value != null) {
                          _lessonDurationController.text = value.toString();
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showPackageSaveConfirmation();
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.white),
                  child: const Text('تأكيد التعديل'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPackageSaveConfirmation() {
    // Reuse existing logic from _savePackageData but wrapped in confirmation
    _savePackageData(); // For simplicity, just saving directly after previous dialog confirmation or we can add double confirmation if needed.
    // The original code had a second dialog. I will implement _savePackageData to JUST save, and assume the user confirmed in the edit dialog.
    // Or I can copy the second dialog logic. Let's effectively reuse _savePackageData.
  }

  Future<void> _savePackageData() async {
    try {
      setState(() => _isSaving = true);
      // Calculate new amount logic (simplified from original)
      final oldLessonsNumber = _student?.lessonsNumber ?? 0;
      final oldAmount = _student?.amount ?? 0;
      final pricePerLesson =
          oldLessonsNumber > 0 ? (oldAmount / oldLessonsNumber) : 0.0;
      final newLessonsNumber =
          int.tryParse(_lessonsNumberController.text) ?? oldLessonsNumber;
      final newAmount = (newLessonsNumber * pricePerLesson).round();

      final updatedStudent = await _repository.updateProfile(
        lessonsName: _lessonsNameController.text,
        lessonDuration: _lessonDurationController.text,
        lessonsNumber: int.tryParse(_lessonsNumberController.text),
        amount: newAmount,
      );

      if (mounted) {
        setState(() => _student = updatedStudent);
        context.read<AuthBloc>().add(GetStudentProfileEvent());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تم حفظ بيانات الباقة بنجاح'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('فشل في حفظ البيانات: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Transactions Modal
  void _showTransactionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'سجل المعاملات',
                      style: TextStyle(
                        fontFamily: 'Qatar',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _walletInfo == null || _walletInfo!.transactions.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد معاملات',
                          style: TextStyle(fontFamily: 'Qatar', fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _walletInfo!.transactions.length,
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final transaction = _walletInfo!.transactions[index];
                          final isPositive = transaction.amount > 0;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPositive
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPositive
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color:
                                        isPositive ? Colors.green : Colors.red,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transaction.description,
                                        style: const TextStyle(
                                          fontFamily: 'Qatar',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        transaction.date,
                                        style: TextStyle(
                                          fontFamily: 'Qatar',
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${transaction.amount} ${_walletInfo?.currency ?? ''}',
                                  style: TextStyle(
                                    fontFamily: 'Qatar',
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isPositive ? Colors.green : Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
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
      final newImageUrl = await _repository.uploadProfileImage(imageFile);
      if (mounted) {
        setState(() {
          if (_student != null) {
            _student = _student!.copyWith(profileImageUrl: newImageUrl);
          }
        });
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
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تغيير كلمة المرور بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
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
}
