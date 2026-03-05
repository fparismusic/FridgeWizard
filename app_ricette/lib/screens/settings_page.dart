import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/meal_planner_service.dart';
import 'auth_page.dart';
import 'saved_recipes_page.dart';
import '../utils/is_tablet.dart';
import '../utils/app_events.dart';

class SettingsPage extends StatefulWidget {
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final NotificationService? notificationService;
  final MealPlannerService? mealPlannerService;
  final WidgetBuilder? authPageBuilder;

  const SettingsPage({
    super.key,
    this.auth,
    this.firestore,
    this.notificationService,
    this.mealPlannerService,
    this.authPageBuilder,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver, RouteAware {
  // State variables
  bool _notificationsEnabled = true;
  int _selectedReminderIndex = 2; // Default: 3 days before
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0); // Default: 9:00 AM
  int? _selectedAvatarIndex;

  FirebaseAuth get _auth => widget.auth ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore => widget.firestore ?? FirebaseFirestore.instance;
  NotificationService get _notificationService => widget.notificationService ?? NotificationService();

  User? get currentUser => _auth.currentUser;

  // Statistics variables
  int _savedRecipes = 0;
  double _estimatedSavings = 0.0;
  bool _isLoadingStats = true;

  // Timer Options
  final List<String> _reminderOptions = [
    '1 day before',
    '2 days before',
    '3 days before',
    '4 days before',
    '7 days before',
    '14 days before',
  ];

  final List<String> _avatarAssets = [
    'assets/avatars/alien.png',
    'assets/avatars/mummy.png',
    'assets/avatars/vampire.png',
    'assets/avatars/wolf.png',
    'assets/avatars/yeti.png',
    'assets/avatars/zombie.png',
  ];

  // Add stream subscription for real-time updates
  StreamSubscription<QuerySnapshot>? _fridgeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences();
    _loadStatistics();
    _setupRealtimeListener();
    AppEvents.onDataChanged.addListener(_onLocalDataChanged);
  }

  // helper per ricaricare
  void _onLocalDataChanged() {
    debugPrint("Aggiorno statistiche...");
    _loadStatistics();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload statistics every time this page becomes visible
    _loadStatistics();
  }

  @override
  void dispose() {
    AppEvents.onDataChanged.removeListener(_onLocalDataChanged);
    WidgetsBinding.instance.removeObserver(this);
    _fridgeSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh statistics when app becomes active
    if (state == AppLifecycleState.resumed) {
      _loadStatistics();
    }
  }

  // Settings preferences are linked to the specific device
  String _getUserKey(String baseKey) {
    final uid = currentUser?.uid ?? 'guest';
    return '${baseKey}_$uid';
  }

  // Load user preferences
  Future<void> _loadPreferences() async {
    if (currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool(_getUserKey('notifications_enabled')) ?? true;
      _selectedReminderIndex = prefs.getInt(_getUserKey('reminder_index')) ?? 2;
      _selectedAvatarIndex = prefs.getInt(_getUserKey('selected_avatar_index'));
      final hour = prefs.getInt(_getUserKey('notification_hour')) ?? 9;
      final minute = prefs.getInt(_getUserKey('notification_minute')) ?? 0;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  // Load user statistics
  Future<void> _loadStatistics() async {
    if (currentUser == null) {
      setState(() => _isLoadingStats = false);
      return;
    }

    try {
      final userId = currentUser!.uid;

      // Carica ricette salvate
      final recipesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_recipes')
          .get();

      // Carica risparmi stimati dai prodotti usati (non scaduti)
      final usedProductsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('used_products')
          .get();

      double totalSavings = 0.0;
      for (var doc in usedProductsSnapshot.docs) {
        final data = doc.data();
        totalSavings += (data['estimatedValue'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _savedRecipes = recipesSnapshot.docs.length;
          _estimatedSavings = totalSavings;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading statistics: $e');
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  // Setup real-time listener for fridge collection
  void _setupRealtimeListener() {
    if (currentUser == null) return;

    final userId = currentUser!.uid;
    _fridgeSubscription = _firestore
        .collection('users')
        .doc(userId)
        .collection('fridge')
        .snapshots()
        .listen((snapshot) {
      // Update statistics in real-time when fridge data changes
      _updateStatisticsFromSnapshot(snapshot);
    }, onError: (error) {
      debugPrint('Error listening to fridge changes: $error');
    });
  }

  // Update statistics from real-time snapshot
  void _updateStatisticsFromSnapshot(QuerySnapshot snapshot) async {
    if (!mounted) return;

    // Reload all statistics to get accurate counts including recipes
    _loadStatistics();
  }


  // Save notification state
  Future<void> _setNotificationState(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_getUserKey('notifications_enabled'), value);

    // Trigger notification check if enabled, cancel if disabled
    if (value) {
      await _notificationService.checkAndScheduleExpiringProducts();
    } else {
      await _notificationService.cancelAllNotifications();
    }
  }

  // Save reminder index
  Future<void> _setReminderIndex(int index) async {
    setState(() => _selectedReminderIndex = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getUserKey('reminder_index'), index);
    // Recalculate statistics with new warning days using current data
    if (_fridgeSubscription != null) {
      // Trigger a recalculation with current fridge data
      _loadStatistics();
    }
    // Re-check notifications with new settings
    if (_notificationsEnabled) {
      await _notificationService.checkAndScheduleExpiringProducts();
    }
  }

  // Save notification time
  Future<void> _setNotificationTime(TimeOfDay time) async {
    setState(() => _notificationTime = time);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getUserKey('notification_hour'), time.hour);
    await prefs.setInt(_getUserKey('notification_minute'), time.minute);

    if (_notificationsEnabled) {
      await _notificationService.checkAndScheduleExpiringProducts();
    }
  }

  // Show time picker
  void _showTimePicker() {
    int tempHour = _notificationTime.hour;
    int tempMinute = _notificationTime.minute;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: const Color.fromARGB(255, 30, 30, 30),
        child: Column(
          children: [
            Container(
              height: 50,
              color: const Color(0xFF3A3A3C),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancel', style: TextStyle(color: CupertinoColors.systemGrey)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done', style: TextStyle(color: CupertinoColors.activeBlue)),
                    onPressed: () {
                      _setNotificationTime(TimeOfDay(hour: tempHour, minute: tempMinute));
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  textTheme: const CupertinoTextThemeData(
                    pickerTextStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  brightness: Brightness.dark,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2024, 1, 1, _notificationTime.hour, _notificationTime.minute),
                  onDateTimeChanged: (DateTime dateTime) {
                    tempHour = dateTime.hour;
                    tempMinute = dateTime.minute;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Save avatar
  Future<void> _saveAvatarIndex(int index) async {
    setState(() {
      _selectedAvatarIndex = index;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_getUserKey('selected_avatar_index'), index);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _logout(BuildContext context) async {
    await _auth.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        CupertinoPageRoute(builder: widget.authPageBuilder ?? (_) => const AuthPage()),
            (route) => false,
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action is irreversible and will delete all your data including:\n\n• All products in your fridge\n• Your preferences and settings\n• Your search history\n\nThis cannot be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete Account'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading dialog
    if (context.mounted) {
      showCupertinoDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CupertinoActivityIndicator(radius: 20),
        ),
      );
    }

    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      final userId = user.uid;

      // 1. Delete all user data from Firestore
      final fridgeCollection = _firestore
          .collection('users')
          .doc(userId)
          .collection('fridge');

      final fridgeSnapshot = await fridgeCollection.get();
      for (var doc in fridgeSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete user document
      await _firestore
          .collection('users')
          .doc(userId)
          .delete();

      // 2. Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Delete user from Firebase Auth
      await user.delete();

      // Close loading dialog and navigate to auth page
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        Navigator.of(context).pushAndRemoveUntil(
          CupertinoPageRoute(builder: widget.authPageBuilder ?? (_) => const AuthPage()),
              (route) => false,
        );
      }

      // Show success message
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Account Deleted'),
            content: const Text('Your account has been successfully deleted.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      String errorMessage = 'Failed to delete account. Please try again.';

      // Handle specific Firebase Auth errors
      if (e.toString().contains('requires-recent-login')) {
        errorMessage = 'For security reasons, please log out and log back in before deleting your account.';
      }

      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  // Picker time
  void _showReminderPicker() {
    int tempIndex = _selectedReminderIndex;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 250,
        color: const Color.fromARGB(255, 30, 30, 30),
        child: Column(
          children: [
            Container(
              height: 50,
              color: const Color(0xFF3A3A3C),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Done', style: TextStyle(color: CupertinoColors.activeBlue)),
                onPressed: () {
                  _setReminderIndex(tempIndex);
                  Navigator.of(context).pop();
                },
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(initialItem: _selectedReminderIndex),
                onSelectedItemChanged: (index) {
                  tempIndex = index;
                },
                children: _reminderOptions.map((item) => Center(
                  child: Text(
                    item,
                    style: const TextStyle(color: Colors.white),
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Avatar picker
  void _showAvatarSelectionModal() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 450,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 30, 30, 30),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Text("Choose an Avatar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: _avatarAssets.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedAvatarIndex == index;
                  return GestureDetector(
                    onTap: () => _saveAvatarIndex(index),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? CupertinoColors.activeBlue : Colors.transparent,
                          width: 4,
                        ),
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scale: 1.3,
                          child: Image.asset(
                            _avatarAssets[index],
                            fit: BoxFit.cover,
                          )
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            CupertinoButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = ScreenSize.isTablet(context);

    return Scaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildMinimalHeader(context),
              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: isTablet
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sinistra: Statistiche
                        Expanded(child: _buildStatisticsSection()),
                        const SizedBox(width: 20),
                        // Destra: Impostazioni
                        Expanded(child: _buildSettingsOptions(context)),
                      ],
                    )
                    : Column(
                      children: [
                        // Sopra: Statistiche
                        _buildStatisticsSection(),
                        const SizedBox(height: 15),
                        // Sotto: Impostazioni
                        _buildSettingsOptions(context),
                        const SizedBox(height: 120),
                      ],
                    ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildSettingsOptions(BuildContext context) {
    return Column(
      children: [
        // NOTIFICATIONS
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF303033),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildRowContent(
                icon: CupertinoIcons.bell_solid,
                title: 'Notifications',
                trailing: CupertinoSwitch(
                  value: _notificationsEnabled,
                  onChanged: _setNotificationState,
                  activeTrackColor: const Color(0xFF4CAF50),
                ),
                showChevron: false,
              ),

              if (_notificationsEnabled) ...[
                const Padding(
                  padding: EdgeInsets.only(left: 56.0),
                  child: Divider(color: Colors.white12, height: 1),
                ),

                GestureDetector(
                  onTap: _showReminderPicker,
                  behavior: HitTestBehavior.opaque,
                  child: _buildRowContent(
                    icon: CupertinoIcons.calendar,
                    title: 'Remind me',
                    trailing: Text(
                      _reminderOptions[_selectedReminderIndex],
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    showChevron: true,
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(left: 56.0),
                  child: Divider(color: Colors.white12, height: 1),
                ),

                GestureDetector(
                  onTap: _showTimePicker,
                  behavior: HitTestBehavior.opaque,
                  child: _buildRowContent(
                    icon: CupertinoIcons.time,
                    title: 'Notification time',
                    trailing: Text(
                      _formatTime(_notificationTime),
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    showChevron: true,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 15),

        // LOGOUT
        GestureDetector(
          // --- ADDED YOUR KEY HERE ---
          key: const Key('settingsLogoutButton'), 
          onTap: () => _logout(context),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF303033),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildRowContent(
              icon: CupertinoIcons.power,
              title: 'Step Out',
              isDestructive: true,
            ),
          ),
        ),

        const SizedBox(height: 15),

        // DELETE ACCOUNT
        GestureDetector(
          onTap: () => _deleteAccount(context),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF303033),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildRowContent(
              icon: CupertinoIcons.trash_fill,
              title: 'Delete Account',
              isDestructive: true,
            ),
          ),
        ),

        const SizedBox(height: 120), // Space for bottom nav bar
      ],
    );
  }

  Widget _buildStatisticsSection() {
    if (_isLoadingStats) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: const Color(0xFF303033),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CupertinoActivityIndicator(),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF303033),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Your FridgeWizard Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Row with stats
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => SavedRecipesPage(
                          firestore: _firestore,
                          auth: _auth,
                        ),
                      ),
                    ).then((_) => _loadStatistics()); // Refresh stats when returning
                  },
                  child: _buildStatCard(
                    icon: CupertinoIcons.book_fill,
                    label: 'Saved Recipes',
                    value: _savedRecipes.toString(),
                    color: CupertinoColors.systemPurple,
                    showChevron: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: CupertinoIcons.money_euro_circle_fill,
                  label: 'Est. Savings',
                  value: '€${_estimatedSavings.toStringAsFixed(2)}',
                  color: CupertinoColors.systemGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool showChevron = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (showChevron)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(
                  CupertinoIcons.chevron_right,
                  color: color.withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRowContent({
    required IconData icon,
    required String title,
    Widget? trailing,
    bool showChevron = true,
    bool isDestructive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Row(
        children: [
          Icon(icon, color: isDestructive ? CupertinoColors.systemRed : Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDestructive ? CupertinoColors.systemRed : Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing,
          if (showChevron && trailing == null)
            const Icon(CupertinoIcons.chevron_right, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _buildMinimalHeader(BuildContext context) {
    Widget avatarContent;

    if (_selectedAvatarIndex != null) {
      avatarContent = Transform.scale(
        scale: 1.4,
        child: Image.asset(
          _avatarAssets[_selectedAvatarIndex!],
          fit: BoxFit.cover,
          width: 75,
          height: 75,
        ),
      );
    } else if (currentUser?.photoURL != null) {
      avatarContent = Image.network(
        currentUser!.photoURL!,
        fit: BoxFit.cover,
        width: 75,
        height: 75,
      );
    } else {
      avatarContent = const Icon(CupertinoIcons.person_solid, size: 35, color: CupertinoColors.systemGrey);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(30, 80, 20, 40),
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showAvatarSelectionModal,
            child: Stack(
              children: [
                Container(
                  width: 75,
                  height: 75,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                    color: CupertinoColors.systemGrey5,
                  ),
                  child: ClipOval(
                    child: Center(child: avatarContent),
                  ),
                ),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: CupertinoColors.activeGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.pencil, size: 14, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(width: 30),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  currentUser?.email ?? 'Nessuna Email',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}