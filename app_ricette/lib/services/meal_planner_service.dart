import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/planned_meal.dart';

class MealPlannerService extends ChangeNotifier {
  static final MealPlannerService _instance = MealPlannerService._internal();
  static const String _storageKey = 'planned_meals_v1';
  
  final DeviceCalendarPlugin _deviceCalendarPlugin;

  factory MealPlannerService() {
    return _instance;
  }

  MealPlannerService._internal() : _deviceCalendarPlugin = DeviceCalendarPlugin();

  @visibleForTesting
  MealPlannerService.create({DeviceCalendarPlugin? calendarPlugin})
      : _deviceCalendarPlugin = calendarPlugin ?? DeviceCalendarPlugin();

  List<PlannedMeal> _meals = [];

  Future<void> loadMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final String? mealsJson = prefs.getString(_storageKey);

    if (mealsJson != null) {
      final List<dynamic> decodedList = jsonDecode(mealsJson);
      _meals = decodedList.map((item) => PlannedMeal.fromJson(item)).toList();
      notifyListeners();
    }
  }

  List<PlannedMeal> getMeals() {
    _meals.sort((a, b) => a.date.compareTo(b.date));
    return _meals;
  }

  Future<void> addMeal(PlannedMeal meal) async {
    _meals.add(meal);
    await _saveToDisk();
    notifyListeners();
    await _addToDeviceCalendar(meal);
  }

  Future<void> removeMeal(String id) async {
    _meals.removeWhere((element) => element.id == id);
    await _saveToDisk();
    notifyListeners();
  }

  Future<void> removeMissingIngredient(String ingredientName) async {
    bool hasChanged = false;
    final normalizeName = ingredientName.toLowerCase().trim();

    for (var meal in _meals) {
      final initialLength = meal.recipe.missedIngredients.length;
      
      meal.recipe.missedIngredients.removeWhere(
        (item) => item.name.toLowerCase().trim() == normalizeName
      );

      if (meal.recipe.missedIngredients.length != initialLength) {
        hasChanged = true;
      }
    }

    if (hasChanged) {
      await _saveToDisk();
      notifyListeners();
    }
  }

  Future<void> _saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(_meals.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> _addToDeviceCalendar(PlannedMeal meal) async {
    try {
      var permissionsGranted = await _deviceCalendarPlugin.requestPermissions();
      if (permissionsGranted.isSuccess && !permissionsGranted.data!) {
        return;
      }

      final calendarsResult = await _deviceCalendarPlugin.retrieveCalendars();
      if (!calendarsResult.isSuccess || calendarsResult.data!.isEmpty) {
        return;
      }

      Calendar? targetCalendar;
      targetCalendar = calendarsResult.data!.firstWhere(
        (c) => c.isDefault == true && c.isReadOnly == false,
        orElse: () => calendarsResult.data!.firstWhere(
          (c) => c.isReadOnly == false,
          orElse: () => calendarsResult.data!.first,
        ),
      );

      final event = Event(
        targetCalendar.id,
        title: 'Cook: ${meal.recipe.title}',
        start: tz.TZDateTime.from(meal.date, tz.local),
        end: tz.TZDateTime.from(meal.date.add(const Duration(hours: 1)), tz.local),
        description: 'Prepare ${meal.recipe.title}. Check the app for ingredients.',
      );

      await _deviceCalendarPlugin.createOrUpdateEvent(event);

    } catch (e) {
      debugPrint("Exception adding to calendar: $e");
    }
  }
}