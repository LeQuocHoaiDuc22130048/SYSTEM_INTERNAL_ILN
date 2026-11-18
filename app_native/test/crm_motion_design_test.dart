import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:system_inverter_likenew/models/repair_order.dart';
import 'package:system_inverter_likenew/theme/app_colors.dart';
import 'package:system_inverter_likenew/theme/app_motion.dart';
import 'package:system_inverter_likenew/theme/app_theme.dart';
import 'package:system_inverter_likenew/widgets/animated_kpi_value.dart';
import 'package:system_inverter_likenew/widgets/interactive_bounce.dart';
import 'package:system_inverter_likenew/widgets/navigation/mobile_dashboard_app_bar.dart';
import 'package:system_inverter_likenew/widgets/skeleton_box.dart';

void main() {
  test('AppColors defines CRM brand navy, blue, and cyan tokens', () {
    expect(AppColors.brandNavy, const Color(0xFF263F63));
    expect(AppColors.brandBlue, const Color(0xFF4778B8));
    expect(AppColors.brandCyan, const Color(0xFF55C7E8));
  });

  test('AppMotion defines all CRM Motion Design System tokens', () {
    expect(AppMotion.instant, const Duration(milliseconds: 100));
    expect(AppMotion.fast, const Duration(milliseconds: 150));
    expect(AppMotion.normal, const Duration(milliseconds: 250));
    expect(AppMotion.medium, const Duration(milliseconds: 350));
    expect(AppMotion.slow, const Duration(milliseconds: 500));
    expect(AppMotion.data, const Duration(milliseconds: 800));
    expect(AppMotion.easeStandard, Curves.easeInOutCubic);
    expect(AppMotion.easeEnter, Curves.easeOutCubic);
    expect(AppMotion.easeExit, Curves.easeInCubic);
    expect(AppMotion.easeEmphasized, Curves.easeOutCubic);
    expect(AppMotion.distanceXs, 4.0);
    expect(AppMotion.distanceSm, 8.0);
    expect(AppMotion.distanceMd, 16.0);
    expect(AppMotion.scalePressed, 0.97);
    expect(AppMotion.scaleEnter, 0.98);
  });

  testWidgets('AppMotion.resolveDuration and resolveCurve respect disableAnimations', (
    tester,
  ) async {
    late Duration normalDuration;
    late Duration reducedDuration;
    late Curve normalCurve;
    late Curve reducedCurve;

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            MediaQuery(
              data: const MediaQueryData(disableAnimations: false),
              child: Builder(
                builder: (context) {
                  normalDuration = AppMotion.resolveDuration(
                    context,
                    AppMotion.normal,
                  );
                  normalCurve = AppMotion.resolveCurve(
                    context,
                    AppMotion.easeEnter,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
            MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Builder(
                builder: (context) {
                  reducedDuration = AppMotion.resolveDuration(
                    context,
                    AppMotion.normal,
                  );
                  reducedCurve = AppMotion.resolveCurve(
                    context,
                    AppMotion.easeEnter,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(normalDuration, AppMotion.normal);
    expect(reducedDuration, Duration.zero);
    expect(normalCurve, AppMotion.easeEnter);
    expect(reducedCurve, Curves.linear);
  });

  test('AppTheme light and dark themes configure consistent overlay themes', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(
      AppTheme.lightTheme.snackBarTheme.behavior,
      SnackBarBehavior.floating,
    );
    expect(
      AppTheme.darkTheme.snackBarTheme.behavior,
      SnackBarBehavior.floating,
    );
    expect(AppTheme.lightTheme.dialogTheme.backgroundColor, AppColors.surfaceLight);
    expect(AppTheme.darkTheme.dialogTheme.backgroundColor, AppColors.surfaceDark);
  });

  testWidgets('AnimatedKpiValue counts up once on first appear and settles at final value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedKpiValue(value: '40/50'),
        ),
      ),
    );

    // At t=0 animation starts from 0/50
    expect(find.text('0/50'), findsOneWidget);

    // Mid-animation value is between 0 and 40
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('40/50'), findsNothing);

    // Settles at exact final string
    await tester.pumpAndSettle();
    expect(find.text('40/50'), findsOneWidget);

    // Subsequent polling/refresh update jumps directly without resetting to 0
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AnimatedKpiValue(value: '45/50'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('45/50'), findsOneWidget);
  });

  testWidgets('AnimatedKpiValue skips count-up immediately when disableAnimations is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: AnimatedKpiValue(value: '128'),
          ),
        ),
      ),
    );

    expect(find.text('128'), findsOneWidget);
  });

  testWidgets('SkeletonBox disables Shimmer when disableAnimations is true in light and dark themes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: Scaffold(body: SkeletonBox(width: 100, height: 16)),
        ),
      ),
    );
    expect(find.byType(Shimmer), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: DashboardSkeleton(wide: true)),
        ),
      ),
    );
    expect(find.byType(Shimmer), findsNothing);
    expect(find.byType(DashboardSkeleton), findsOneWidget);
  });

  testWidgets('InteractiveBounce skips scale transform when disableAnimations is true', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: InteractiveBounce(
                onTap: () => tapped = true,
                child: const SizedBox(
                  width: 80,
                  height: 44,
                  child: Center(child: Text('Save')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(InteractiveBounce),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('DashboardMobileAppBar uses brandNavy background and white icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: DashboardMobileAppBar(
            isDark: false,
            notificationBadge: '3',
            showNotification: true,
            onToggleTheme: () {},
            onToggleNotifications: () {},
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, AppColors.brandNavy);
    expect(appBar.foregroundColor, Colors.white);
    expect(appBar.iconTheme?.color, Colors.white);
  });

  test('RepairOrder.isAwaitingCustomerConfirmation detects unconfirmed active orders', () {
    final pendingOrder = RepairOrder.fromJson({
      'id': '1',
      'orderCode': 'RO-01',
      'deviceName': 'Biến tần ABB',
      'customerName': 'Khách A',
      'status': 'IN_PROGRESS',
      'createdAt': '2026-11-17T08:00:00Z',
    });
    expect(pendingOrder.confirmationStatus, 'PENDING_CUSTOMER');
    expect(pendingOrder.isAwaitingCustomerConfirmation, isTrue);

    final approvedOrder = RepairOrder.fromJson({
      'id': '2',
      'orderCode': 'RO-02',
      'deviceName': 'Biến tần Fuji',
      'customerName': 'Khách B',
      'status': 'IN_PROGRESS',
      'confirmationStatus': 'APPROVED',
      'createdAt': '2026-11-17T08:00:00Z',
    });
    expect(approvedOrder.isAwaitingCustomerConfirmation, isFalse);

    final deliveredUnconfirmed = RepairOrder.fromJson({
      'id': '3',
      'orderCode': 'RO-03',
      'deviceName': 'PLC',
      'customerName': 'Khách C',
      'status': 'DELIVERED',
      'confirmationStatus': 'PENDING_CUSTOMER',
      'createdAt': '2026-11-17T08:00:00Z',
    });
    expect(deliveredUnconfirmed.isAwaitingCustomerConfirmation, isFalse);
  });
}

