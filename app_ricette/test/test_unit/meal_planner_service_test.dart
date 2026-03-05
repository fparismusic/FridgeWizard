import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:app_ricette/services/meal_planner_service.dart';
import 'package:app_ricette/models/planned_meal.dart';
import 'package:app_ricette/models/recipe.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'dart:collection';

// --- MOCK CALENDAR PLUGIN ---
class MockDeviceCalendarPlugin implements DeviceCalendarPlugin {
  bool requestPermissionsCalled = false;
  bool createEventCalled = false;
  
  // Control flags for testing edge cases
  bool permissionGranted = true;
  bool returnNoCalendars = false;
  bool shouldThrowException = false;

  @override
  Future<Result<bool>> requestPermissions() async {
    requestPermissionsCalled = true;
    return Result<bool>()..data = permissionGranted;
  }

  @override
  Future<Result<UnmodifiableListView<Calendar>>> retrieveCalendars() async {
    if (returnNoCalendars) {
      return Result<UnmodifiableListView<Calendar>>()
        ..data = UnmodifiableListView([]);
    }

    final calendars = [
      Calendar(id: '1', name: 'Test Calendar', isReadOnly: false, isDefault: true)
    ];

    return Result<UnmodifiableListView<Calendar>>()
      ..data = UnmodifiableListView(calendars);
  }

  @override
  Future<Result<String>?> createOrUpdateEvent(Event? event) async {
    if (shouldThrowException) throw Exception("Calendar Error");
    createEventCalled = true;
    return Result<String>()..data = 'event_id_123';
  }

  @override dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {

  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('MealPlannerService Tests', () {
    late MealPlannerService service;
    late MockDeviceCalendarPlugin mockCalendar;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockCalendar = MockDeviceCalendarPlugin();
      service = MealPlannerService.create(calendarPlugin: mockCalendar);
    });

    test('addMeal aggiunge il pasto alla lista e chiama il calendario', () async {
      final meal = PlannedMeal(
        id: 'meal_1',
        date: DateTime.now(),
        cachedDetails: {},
        recipe: Recipe(id: 1, title: 'Pasta', image: '', usedIngredientCount: 0, missedIngredientCount: 0),
      );

      await service.addMeal(meal);

      expect(service.getMeals().length, 1);
      expect(mockCalendar.requestPermissionsCalled, isTrue);
      expect(mockCalendar.createEventCalled, isTrue);
    });

    test('removeMeal rimuove il pasto corretto', () async {
      final meal1 = PlannedMeal(id: '1', date: DateTime.now(), cachedDetails: {}, recipe: Recipe(id: 1, title: 'A', image: '', usedIngredientCount: 0, missedIngredientCount: 0));
      final meal2 = PlannedMeal(id: '2', date: DateTime.now(), cachedDetails: {}, recipe: Recipe(id: 2, title: 'B', image: '', usedIngredientCount: 0, missedIngredientCount: 0));

      await service.addMeal(meal1);
      await service.addMeal(meal2);

      expect(service.getMeals().length, 2);

      await service.removeMeal('1');

      expect(service.getMeals().length, 1);
      expect(service.getMeals().first.id, '2');
    });

    test('removeMissingIngredient rimuove ingrediente da TUTTI i pasti pianificati', () async {
      final missingIng = IngredientData(name: 'Basilico', amount: 10, unit: 'g');

      final meal = PlannedMeal(
          id: '1',
          date: DateTime.now(),
          cachedDetails: {},
          recipe: Recipe(
            id: 1,
            title: 'Pesto',
            image: '',
            usedIngredientCount: 0,
            missedIngredientCount: 1,
            missedIngredients: [missingIng],
          )
      );

      await service.addMeal(meal);

      expect(service.getMeals().first.recipe.missedIngredients.length, 1);

      await service.removeMissingIngredient('basilico');

      expect(service.getMeals().first.recipe.missedIngredients.isEmpty, isTrue);
    });

    test('Persistenza: I dati sopravvivono al riavvio del service', () async {
      final meal = PlannedMeal(
        id: 'persistent_meal',
        date: DateTime(2025, 1, 1),
        cachedDetails: {},
        recipe: Recipe(id: 99, title: 'Persistent Soup', image: '', usedIngredientCount: 0, missedIngredientCount: 0),
      );
      await service.addMeal(meal);

      final newService = MealPlannerService.create(calendarPlugin: mockCalendar);
      await newService.loadMeals();

      expect(newService.getMeals().length, 1);
      expect(newService.getMeals().first.id, 'persistent_meal');
    });

    // --- NUOVI TEST EDGE CASES CALENDARIO ---

    test('addMeal: Non aggiunge al calendario se permesso negato', () async {
      mockCalendar.permissionGranted = false; // Permesso negato

      final meal = PlannedMeal(id: '1', date: DateTime.now(), cachedDetails: {}, recipe: Recipe(id: 1, title: 'NoPerm', image: ''));
      await service.addMeal(meal);

      expect(mockCalendar.requestPermissionsCalled, isTrue);
      expect(mockCalendar.createEventCalled, isFalse); // Non deve chiamare createEvent
    });

    test('addMeal: Non aggiunge al calendario se nessun calendario disponibile', () async {
      mockCalendar.returnNoCalendars = true; // Nessun calendario

      final meal = PlannedMeal(id: '1', date: DateTime.now(), cachedDetails: {}, recipe: Recipe(id: 1, title: 'NoCal', image: ''));
      await service.addMeal(meal);

      expect(mockCalendar.requestPermissionsCalled, isTrue);
      expect(mockCalendar.createEventCalled, isFalse);
    });

    test('addMeal: Gestisce eccezioni del calendario senza crashare', () async {
      mockCalendar.shouldThrowException = true; // Simula crash plugin

      final meal = PlannedMeal(id: '1', date: DateTime.now(), cachedDetails: {}, recipe: Recipe(id: 1, title: 'Crash', image: ''));
      
      // Non deve lanciare eccezione
      await service.addMeal(meal); 

      expect(service.getMeals().length, 1); // Il pasto deve comunque essere salvato in locale
    });

    test('Singleton: factory restituisce sempre la stessa istanza', () {
      final s1 = MealPlannerService();
      final s2 = MealPlannerService();
      expect(s1, same(s2));
    });

  });
}