import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/database_helper.dart';
import '../repositories/debt_repository_impl.dart';
import '../repositories/received_debt_repository_impl.dart';
import '../repositories/settings_repository_impl.dart';
import 'auth_service.dart';
import 'biometric_service.dart';
import 'debt_service.dart';
import 'interest_service.dart';
import 'notification_service.dart';
import 'profile_service.dart';
import 'received_debt_service.dart';
import 'role_service.dart';

/// Lightweight service locator / dependency-injection container.
///
/// OOP principle: Dependency Inversion — screens ask the locator for a
/// service; they never instantiate concrete implementations themselves.
///
/// Call [configure] in tests to inject mock services without changing
/// any screen or controller code.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  static DebtService? _overriddenDebtService;
  static AuthService? _overriddenAuthService;
  static InterestService? _overriddenInterestService;
  static BiometricService? _overriddenBiometricService;
  static NotificationService? _overriddenNotificationService;
  static RoleService? _overriddenRoleService;
  static ReceivedDebtService? _overriddenReceivedDebtService;
  static ProfileService? _overriddenProfileService;

  static final DebtRepositoryImpl _debtRepo =
      DebtRepositoryImpl(DatabaseHelper.instance);
  static final InterestService _defaultInterestService =
      InterestService(_debtRepo);
  static final DebtService _defaultDebtService =
      DebtService(_debtRepo, _defaultInterestService,
          notificationService: _defaultNotificationService);
  static final AuthService _defaultAuthService = AuthService(
    SettingsRepositoryImpl(DatabaseHelper.instance),
    notificationService: _defaultNotificationService,
  );
  static final BiometricService _defaultBiometricService = BiometricService();
  static final NotificationService _defaultNotificationService =
      NotificationService();
  static const RoleService _defaultRoleService = RoleService();
  static final ReceivedDebtService _defaultReceivedDebtService =
      ReceivedDebtService(ReceivedDebtRepositoryImpl(DatabaseHelper.instance));
  static final ProfileService _defaultProfileService =
      ProfileService(SharedPreferences.getInstance());

  /// Override services for testing. Pass `null` to reset to defaults.
  static void configure({
    DebtService? debtService,
    AuthService? authService,
    InterestService? interestService,
    BiometricService? biometricService,
    NotificationService? notificationService,
    RoleService? roleService,
    ReceivedDebtService? receivedDebtService,
    ProfileService? profileService,
  }) {
    _overriddenDebtService = debtService;
    _overriddenAuthService = authService;
    _overriddenInterestService = interestService;
    _overriddenBiometricService = biometricService;
    _overriddenNotificationService = notificationService;
    _overriddenRoleService = roleService;
    _overriddenReceivedDebtService = receivedDebtService;
    _overriddenProfileService = profileService;
  }

  DebtService get debtService =>
      _overriddenDebtService ?? _defaultDebtService;
  AuthService get authService =>
      _overriddenAuthService ?? _defaultAuthService;
  InterestService get interestService =>
      _overriddenInterestService ?? _defaultInterestService;
  BiometricService get biometricService =>
      _overriddenBiometricService ?? _defaultBiometricService;
  NotificationService get notificationService =>
      _overriddenNotificationService ?? _defaultNotificationService;
  RoleService get roleService =>
      _overriddenRoleService ?? _defaultRoleService;
  ReceivedDebtService get receivedDebtService =>
      _overriddenReceivedDebtService ?? _defaultReceivedDebtService;
  ProfileService get profileService =>
      _overriddenProfileService ?? _defaultProfileService;
}
