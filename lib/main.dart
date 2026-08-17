import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:native_geofence/native_geofence.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:shared_preferences/shared_preferences.dart';

import 'coupon_service.dart';
import 'coupon_storage_service.dart';
import 'coupon_wallet_screen.dart';
import 'login_screen.dart';


// =========================================================
// 앱 공통 설정
// =========================================================

// 화면 이동용 Navigator Key
final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey<NavigatorState>();

// 로컬 알림 객체
final FlutterLocalNotificationsPlugin
    flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// 단말기 저장소
final SharedPreferencesAsync sharedPreferences =
    SharedPreferencesAsync();

// Android Emulator에서 PC FastAPI에 접근하는 주소
const String apiBaseUrl =
    'http://10.0.2.2:8000';


// =========================================================
// 카카오 설정
// =========================================================

// 실제 Native App Key를 코드에 직접 적지 않음.
//
// 실행할 때:
//
// flutter run \
//   --dart-define=KAKAO_NATIVE_APP_KEY=실제키
//
// 형태로 외부에서 전달
const String kakaoNativeAppKey =
    String.fromEnvironment(
  'KAKAO_NATIVE_APP_KEY',
);


// =========================================================
// 단말기 저장 키
// =========================================================

// 하루 1회 근접 알림 날짜 저장
const String lastNotificationDateKey =
    'last_nearby_notification_date';

// 백그라운드 알림용 가맹점 정보 저장
const String backgroundStoresKey =
    'background_stores_json';


// =========================================================
// 알림 클릭 처리용 데이터
// =========================================================

// 알림 클릭 후 이동할 가맹점 ID
String? pendingNotificationStoreId;

// 알림 클릭용 가맹점 캐시
final Map<String, Store> notificationStoreCache = {};


// =========================================================
// 날짜 처리
// =========================================================

String getTodayDate() {
  final DateTime now =
      DateTime.now();

  final String month =
      now.month
          .toString()
          .padLeft(
            2,
            '0',
          );

  final String day =
      now.day
          .toString()
          .padLeft(
            2,
            '0',
          );

  return '${now.year}-$month-$day';
}


// =========================================================
// Geofence 백그라운드 진입 이벤트
// =========================================================

@pragma('vm:entry-point')
Future<void> geofenceTriggered(
  GeofenceCallbackParams params,
) async {
  // 백그라운드 isolate에서
  // Flutter 플러그인 사용 준비
  DartPluginRegistrant.ensureInitialized();

  // 가맹점 진입 이벤트만 처리
  if (params.event != GeofenceEvent.enter) {
    return;
  }

  if (params.geofences.isEmpty) {
    return;
  }

  final String storeId =
      params.geofences.first.id;

  final SharedPreferencesAsync preferences =
      SharedPreferencesAsync();

  // FastAPI에서 받아 저장한 가맹점 정보 조회
  final String? storesJson =
      await preferences.getString(
    backgroundStoresKey,
  );

  if (storesJson == null ||
      storesJson.isEmpty) {
    return;
  }

  Map<String, dynamic>? storeInfo;

  try {
    final List<dynamic> savedStores =
        jsonDecode(
      storesJson,
    ) as List<dynamic>;

    for (final dynamic item in savedStores) {
      final Map<String, dynamic> store =
          Map<String, dynamic>.from(
        item as Map,
      );

      if (store['id'] == storeId) {
        storeInfo = store;
        break;
      }
    }
  } catch (_) {
    return;
  }

  if (storeInfo == null) {
    return;
  }

  // 오늘 날짜
  final String today =
      getTodayDate();

  // 마지막 알림 날짜
  final String? lastNotificationDate =
      await preferences.getString(
    lastNotificationDateKey,
  );

  // 하루에 이미 한 번 알림을 받았다면 종료
  if (lastNotificationDate == today) {
    return;
  }

  // 백그라운드 알림 객체
  final FlutterLocalNotificationsPlugin
      notificationPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings
      androidSettings =
      AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );

  const InitializationSettings
      initializationSettings =
      InitializationSettings(
    android: androidSettings,
  );

  await notificationPlugin.initialize(
    settings: initializationSettings,
  );

  // 근접 할인 알림 채널
  const AndroidNotificationDetails
      androidDetails =
      AndroidNotificationDetails(
    'discount_nearby_channel',
    '근접 할인 알림',
    channelDescription:
        '가맹점 근처에 접근했을 때 할인 혜택을 알려주는 알림',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails
      notificationDetails =
      NotificationDetails(
    android: androidDetails,
  );

  // 근접 할인 알림
  await notificationPlugin.show(
    id: 1,

    title:
        storeInfo['name']?.toString() ??
            '할인 가맹점',

    body:
        storeInfo['benefit']?.toString() ??
            '근처 할인 혜택을 확인해보세요.',

    notificationDetails:
        notificationDetails,

    payload:
        storeId,
  );

  // 오늘 알림을 보냈다는 날짜 저장
  await preferences.setString(
    lastNotificationDateKey,
    today,
  );
}


// =========================================================
// 알림 클릭 처리
// =========================================================

void handleNotificationTap(
  NotificationResponse response,
) {
  final String? storeId =
      response.payload;

  if (storeId == null ||
      storeId.isEmpty) {
    return;
  }

  final Store? store =
      notificationStoreCache[
          storeId];

  // 가맹점 데이터가 준비되어 있으면
  // 바로 상세페이지로 이동
  if (store != null &&
      navigatorKey.currentState != null) {
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (context) =>
            StoreDetailScreen(
          store: store,
        ),
      ),
    );

    return;
  }

  // 앱 시작 중이면 ID만 저장
  pendingNotificationStoreId =
      storeId;
}


// =========================================================
// 알림 초기화
// =========================================================

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings
      androidSettings =
      AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );

  const InitializationSettings
      initializationSettings =
      InitializationSettings(
    android: androidSettings,
  );

  await flutterLocalNotificationsPlugin
      .initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse:
        handleNotificationTap,
  );

  // Android 알림 권한 요청
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}


// =========================================================
// 앱 시작
// =========================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 카카오 Native App Key가 전달된 경우에만
  // Kakao SDK 초기화
  if (kakaoNativeAppKey.isNotEmpty) {
    await KakaoSdk.init(
      nativeAppKey:
          kakaoNativeAppKey,
    );
  } else {
    // 실제 키는 출력하지 않고
    // 설정 누락 여부만 개발 로그에 표시
    debugPrint(
      'KAKAO_NATIVE_APP_KEY가 설정되지 않았습니다.',
    );
  }

  // 알림 초기화
  await initializeNotifications();

  // Native Geofence 초기화
  await NativeGeofenceManager.instance
      .initialize();

  // 알림 클릭으로 앱이 실행됐는지 확인
  final NotificationAppLaunchDetails?
      launchDetails =
      await flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();

  if (launchDetails
          ?.didNotificationLaunchApp ??
      false) {
    pendingNotificationStoreId =
        launchDetails
            ?.notificationResponse
            ?.payload;
  }

  runApp(
    const DiscountHoneyTipApp(),
  );
}


// =========================================================
// 앱 전체 설정
// =========================================================

class DiscountHoneyTipApp
    extends StatefulWidget {
  const DiscountHoneyTipApp({
    super.key,
  });

  @override
  State<DiscountHoneyTipApp> createState() =>
      _DiscountHoneyTipAppState();
}


class _DiscountHoneyTipAppState
    extends State<DiscountHoneyTipApp> {
  // 현재 로그인 여부
  bool _isLoggedIn = false;


  // =======================================================
  // 카카오 로그인 성공
  // =======================================================

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }


  @override
  Widget build(
    BuildContext context,
  ) {
    return MaterialApp(
      navigatorKey:
          navigatorKey,

      debugShowCheckedModeBanner:
          false,

      title:
          '할인꿀팁',

      theme:
          ThemeData(
        useMaterial3:
            true,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              Colors.orange,
        ),
      ),

      // 로그인 전
      // → 카카오 로그인 화면
      //
      // 로그인 성공
      // → 할인 매장 메인 화면
      home:
          _isLoggedIn
              ? const HomeScreen()
              : LoginScreen(
                  onLoginSuccess:
                      _handleLoginSuccess,
                ),
    );
  }
}


// =========================================================
// 가맹점 모델
// =========================================================

class Store {
  final String id;
  final String name;
  final String benefit;
  final double latitude;
  final double longitude;
  final double distance;
  final double notificationRadius;

  Store({
    required this.id,
    required this.name,
    required this.benefit,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.notificationRadius,
  });


  // =======================================================
  // FastAPI JSON → Store
  // =======================================================

  factory Store.fromApi(
    Map<String, dynamic> json,
    Position currentPosition,
  ) {
    final double latitude =
        (json['latitude'] as num)
            .toDouble();

    final double longitude =
        (json['longitude'] as num)
            .toDouble();

    // 현재 위치와 매장 거리 계산
    final double distance =
        Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      latitude,
      longitude,
    );

    return Store(
      id:
          json['id'].toString(),

      name:
          json['name'].toString(),

      benefit:
          json['benefit'].toString(),

      latitude:
          latitude,

      longitude:
          longitude,

      distance:
          distance,

      notificationRadius:
          (json['notification_radius']
                  as num)
              .toDouble(),
    );
  }


  // =======================================================
  // 백그라운드 알림용 가맹점 정보
  // =======================================================

  Map<String, dynamic>
      toBackgroundJson() {
    return {
      'id':
          id,

      'name':
          name,

      'benefit':
          benefit,
    };
  }
}


// =========================================================
// 메인 화면
// =========================================================

class HomeScreen
    extends StatefulWidget {
  const HomeScreen({
    super.key,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}


class _HomeScreenState
    extends State<HomeScreen>
    with WidgetsBindingObserver {
  // 현재 위치 표시
  String _locationText =
      '현재 위치를 확인하고 있습니다...';

  // 백그라운드 위치 상태
  String _backgroundLocationText =
      '백그라운드 위치 권한 확인 중...';

  // Geofence 상태
  String _geofenceText =
      'Geofence 등록 확인 중...';

  // FastAPI 상태
  String _apiText =
      '가맹점 데이터 확인 중...';

  // 로딩 여부
  bool _isLoading =
      false;

  // 주변 가맹점
  List<Store> _nearbyStores =
      [];


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addObserver(
      this,
    );

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        _startApp();
      },
    );
  }


  @override
  void dispose() {
    WidgetsBinding.instance
        .removeObserver(
      this,
    );

    super.dispose();
  }


  // =======================================================
  // 앱 상태 변화
  // =======================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state ==
        AppLifecycleState.resumed) {
      _checkBackgroundLocationStatus();
    }
  }


  // =======================================================
  // 앱 시작
  // =======================================================

  Future<void> _startApp() async {
    await _checkBackgroundLocationStatus();

    await _getCurrentLocation();
  }


  // =======================================================
  // 백그라운드 위치 권한 확인
  // =======================================================

  Future<bool>
      _checkBackgroundLocationStatus() async {
    final permission_handler.PermissionStatus
        status =
        await permission_handler
            .Permission
            .locationAlways
            .status;

    if (!mounted) {
      return false;
    }

    setState(() {
      if (status.isGranted) {
        _backgroundLocationText =
            '백그라운드 위치: 항상 허용됨';
      } else {
        _backgroundLocationText =
            '백그라운드 위치: 항상 허용 필요';
      }
    });

    return status.isGranted;
  }


  // =======================================================
  // Android 위치 권한 설정
  // =======================================================

  Future<void>
      _openBackgroundLocationSettings() async {
    await permission_handler
        .openAppSettings();
  }


  // =======================================================
  // 개발용 하루 알림 기록 초기화
  // =======================================================

  Future<void>
      _resetDailyNotificationForTest() async {
    await sharedPreferences.remove(
      lastNotificationDateKey,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content:
            Text(
          '테스트용 하루 알림 기록을 초기화했습니다.',
        ),
      ),
    );
  }


  // =======================================================
  // 내 쿠폰함
  // =======================================================

  void _openCouponWallet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const CouponWalletScreen(),
      ),
    );
  }


  // =======================================================
  // FastAPI 가맹점 조회
  // =======================================================

  Future<List<Store>> _fetchStores(
    Position currentPosition,
  ) async {
    final Uri uri =
        Uri.parse(
      '$apiBaseUrl/stores',
    );

    final http.Response response =
        await http
            .get(
      uri,
    ).timeout(
      const Duration(
        seconds: 10,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        '가맹점 API 오류: ${response.statusCode}',
      );
    }

    // 한글 UTF-8 처리
    final Map<String, dynamic> data =
        jsonDecode(
      utf8.decode(
        response.bodyBytes,
      ),
    ) as Map<String, dynamic>;

    final List<dynamic> storeList =
        data['stores']
            as List<dynamic>;

    final List<Store> stores =
        storeList.map(
      (dynamic item) {
        final Map<String, dynamic>
            storeJson =
            Map<String, dynamic>.from(
          item as Map,
        );

        return Store.fromApi(
          storeJson,
          currentPosition,
        );
      },
    ).toList();

    // 가까운 거리순 정렬
    stores.sort(
      (
        Store a,
        Store b,
      ) =>
          a.distance.compareTo(
        b.distance,
      ),
    );

    // 백그라운드 알림용 가맹점 정보 저장
    final List<Map<String, dynamic>>
        backgroundStores =
        stores
            .map(
              (
                Store store,
              ) =>
                  store
                      .toBackgroundJson(),
            )
            .toList();

    await sharedPreferences.setString(
      backgroundStoresKey,
      jsonEncode(
        backgroundStores,
      ),
    );

    return stores;
  }


  // =======================================================
  // Geofence 최신 DB 값 적용
  // =======================================================

  Future<void> _registerGeofences(
    List<Store> stores,
  ) async {
    final bool backgroundGranted =
        await _checkBackgroundLocationStatus();

    if (!backgroundGranted) {
      if (!mounted) {
        return;
      }

      setState(() {
        _geofenceText =
            'Geofence 등록 실패: 항상 허용 권한 필요';
      });

      return;
    }

    try {
      final NativeGeofenceManager manager =
          NativeGeofenceManager.instance;

      // DB에서 위치 또는 알림 거리가
      // 변경될 수 있으므로
      // 기존 Geofence 제거
      await manager.removeAllGeofences();

      // 최신 가맹점 정보로 재등록
      for (final Store store
          in stores) {
        final Geofence geofence =
            Geofence(
          id:
              store.id,

          location:
              Location(
            latitude:
                store.latitude,

            longitude:
                store.longitude,
          ),

          // MySQL notification_radius
          radiusMeters:
              store.notificationRadius,

          triggers:
              const {
            GeofenceEvent.enter,
          },

          iosSettings:
              const IosGeofenceSettings(
            initialTrigger:
                true,
          ),

          androidSettings:
              const AndroidGeofenceSettings(
            initialTriggers:
                {
              GeofenceEvent.enter,
            },

            notificationResponsiveness:
                Duration(
              seconds:
                  10,
            ),
          ),
        );

        await manager.createGeofence(
          geofence,
          geofenceTriggered,
        );
      }

      final List<String> finalIds =
          await manager
              .getRegisteredGeofenceIds();

      if (!mounted) {
        return;
      }

      setState(() {
        _geofenceText =
            '등록된 Geofence: '
            '${finalIds.join(', ')}';
      });
    } on NativeGeofenceException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _geofenceText =
            'Geofence 오류: ${e.code}';
      });
    }
  }


  // =======================================================
  // 현재 위치 + FastAPI 조회
  // =======================================================

  Future<void>
      _getCurrentLocation() async {
    setState(() {
      _isLoading =
          true;

      _locationText =
          '현재 위치를 확인하고 있습니다...';

      _apiText =
          'FastAPI에서 가맹점 정보를 불러오는 중...';
    });

    try {
      // 위치 서비스 확인
      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationText =
              '휴대폰 위치 서비스를 켜주세요.';

          _isLoading =
              false;
        });

        return;
      }

      // 위치 권한 확인
      LocationPermission permission =
          await Geolocator
              .checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator
                .requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission
                  .deniedForever) {
        if (!mounted) {
          return;
        }

        setState(() {
          _locationText =
              '위치 권한이 필요합니다.';

          _isLoading =
              false;
        });

        return;
      }

      // 현재 GPS 위치
      final Position position =
          await Geolocator
              .getCurrentPosition();

      // FastAPI → MySQL 가맹점 조회
      final List<Store> stores =
          await _fetchStores(
        position,
      );

      // 알림 클릭용 캐시
      notificationStoreCache.clear();

      for (final Store store
          in stores) {
        notificationStoreCache[
                store.id] =
            store;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _locationText =
            '위도: ${position.latitude}\n'
            '경도: ${position.longitude}';

        _apiText =
            'FastAPI 가맹점 데이터 연결됨';

        _nearbyStores =
            stores;

        _isLoading =
            false;
      });

      // 알림 클릭으로 앱이 실행됐다면
      // 가맹점 상세페이지 열기
      _openPendingNotificationStore();

      // 최신 DB 값으로 Geofence 재등록
      await _registerGeofences(
        stores,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _locationText =
            '위치 또는 가맹점 정보를 가져오는 중 오류가 발생했습니다.';

        _apiText =
            'FastAPI 연결 실패';

        _isLoading =
            false;
      });

      debugPrint(
        '위치/API 오류: $e',
      );
    }
  }


  // =======================================================
  // 알림 클릭 → 상세페이지
  // =======================================================

  void _openPendingNotificationStore() {
    final String? storeId =
        pendingNotificationStoreId;

    if (storeId == null) {
      return;
    }

    final Store? store =
        notificationStoreCache[
            storeId];

    if (store == null) {
      return;
    }

    pendingNotificationStoreId =
        null;

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) =>
                StoreDetailScreen(
              store:
                  store,
            ),
          ),
        );
      },
    );
  }


  // =======================================================
  // 메인 화면 UI
  // =======================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          '할인꿀팁',

          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        centerTitle:
            true,

        // 내 쿠폰함
        actions: [
          IconButton(
            onPressed:
                _openCouponWallet,

            tooltip:
                '내 쿠폰함',

            icon:
                const Icon(
              Icons.local_offer,
            ),
          ),
        ],
      ),

      body:
          SafeArea(
        child:
            Padding(
          padding:
              const EdgeInsets.all(
            16,
          ),

          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // 화면 제목
              const Text(
                '내 주변 할인 매장',

                style:
                    TextStyle(
                  fontSize:
                      24,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height:
                    8,
              ),

              const Text(
                '현재 위치를 기준으로 가까운 가맹점을 보여드립니다.',

                style:
                    TextStyle(
                  color:
                      Colors.grey,
                ),
              ),

              const SizedBox(
                height:
                    15,
              ),

              // 권한 / API / Geofence 상태
              Container(
                width:
                    double.infinity,

                padding:
                    const EdgeInsets.all(
                  12,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      Colors.orange
                          .withValues(
                    alpha:
                        0.08,
                  ),

                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),

                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      _backgroundLocationText,

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      _apiText,
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    Text(
                      _geofenceText,
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    // 위치 권한 설정
                    OutlinedButton.icon(
                      onPressed:
                          _openBackgroundLocationSettings,

                      icon:
                          const Icon(
                        Icons.location_history,
                      ),

                      label:
                          const Text(
                        '위치 권한 설정',
                      ),
                    ),

                    const SizedBox(
                      height:
                          5,
                    ),

                    // 개발 테스트용
                    OutlinedButton.icon(
                      onPressed:
                          _resetDailyNotificationForTest,

                      icon:
                          const Icon(
                        Icons.refresh,
                      ),

                      label:
                          const Text(
                        '테스트 알림 기록 초기화',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    15,
              ),

              // 현재 위치
              Center(
                child:
                    Column(
                  children: [
                    const Icon(
                      Icons.location_on,

                      size:
                          45,

                      color:
                          Colors.orange,
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    Text(
                      _locationText,

                      textAlign:
                          TextAlign.center,
                    ),

                    const SizedBox(
                      height:
                          8,
                    ),

                    ElevatedButton(
                      onPressed:
                          _isLoading
                              ? null
                              : _getCurrentLocation,

                      child:
                          Text(
                        _isLoading
                            ? '위치 확인 중...'
                            : '내 위치 확인하기',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height:
                    15,
              ),

              // 가까운 가맹점 목록
              Expanded(
                child:
                    ListView.builder(
                  itemCount:
                      _nearbyStores.length,

                  itemBuilder:
                      (
                    context,
                    index,
                  ) {
                    final Store store =
                        _nearbyStores[
                            index];

                    return Card(
                      margin:
                          const EdgeInsets.only(
                        bottom:
                            10,
                      ),

                      child:
                          ListTile(
                        leading:
                            const CircleAvatar(
                          child:
                              Icon(
                            Icons.store,
                          ),
                        ),

                        title:
                            Text(
                          store.name,

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        subtitle:
                            Text(
                          '${store.benefit}\n'
                          '알림 거리: '
                          '${store.notificationRadius.round()}m',
                        ),

                        trailing:
                            Text(
                          '${store.distance.round()}m',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        onTap:
                            () {
                          Navigator.push(
                            context,

                            MaterialPageRoute(
                              builder:
                                  (context) =>
                                      StoreDetailScreen(
                                store:
                                    store,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// =========================================================
// 가맹점 상세페이지
// =========================================================

class StoreDetailScreen
    extends StatefulWidget {
  final Store store;

  const StoreDetailScreen({
    super.key,
    required this.store,
  });

  @override
  State<StoreDetailScreen> createState() =>
      _StoreDetailScreenState();
}


class _StoreDetailScreenState
    extends State<StoreDetailScreen> {
  // FastAPI 쿠폰 조회
  final CouponService _couponService =
      CouponService();

  // 다운로드 쿠폰 단말기 저장
  final CouponStorageService
      _couponStorageService =
      CouponStorageService();

  // 쿠폰 API 로딩 여부
  bool _isCouponLoading =
      false;


  // =======================================================
  // 쿠폰 다운로드
  // =======================================================

  Future<void> _downloadCoupon() async {
    if (_isCouponLoading) {
      return;
    }

    setState(() {
      _isCouponLoading =
          true;
    });

    try {
      // 현재 가맹점의 활성 쿠폰 조회
      final List<Coupon> coupons =
          await _couponService
              .getStoreCoupons(
        widget.store.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isCouponLoading =
            false;
      });

      // 쿠폰 없음
      if (coupons.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content:
                Text(
              '현재 다운로드할 수 있는 쿠폰이 없습니다.',
            ),
          ),
        );

        return;
      }

      // 현재 테스트 데이터는
      // 가맹점당 1개 쿠폰
      final Coupon coupon =
          coupons.first;

      // 쿠폰 확인 팝업
      await showDialog<void>(
        context:
            context,

        builder:
            (
          BuildContext dialogContext,
        ) {
          return AlertDialog(
            title:
                const Row(
              children: [
                Icon(
                  Icons.local_offer,

                  color:
                      Colors.orange,
                ),

                SizedBox(
                  width:
                      8,
                ),

                Text(
                  '쿠폰 다운로드',
                ),
              ],
            ),

            content:
                Column(
              mainAxisSize:
                  MainAxisSize.min,

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                // 쿠폰 이름
                Text(
                  coupon.title,

                  style:
                      const TextStyle(
                    fontSize:
                        18,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height:
                      12,
                ),

                // 쿠폰 혜택
                Text(
                  coupon.description,
                ),

                const SizedBox(
                  height:
                      12,
                ),

                // 사용기한
                Text(
                  coupon.validUntil == null
                      ? '사용기한: 제한 없음'
                      : '사용기한: ${coupon.validUntil}',
                ),
              ],
            ),

            actions: [
              // 닫기
              TextButton(
                onPressed:
                    () {
                  Navigator.pop(
                    dialogContext,
                  );
                },

                child:
                    const Text(
                  '닫기',
                ),
              ),

              // 실제 다운로드
              ElevatedButton(
                onPressed:
                    () async {
                  // 기존 다운로드 여부 확인
                  final bool
                      alreadyDownloaded =
                      await _couponStorageService
                          .isDownloaded(
                    coupon.id,
                  );

                  // 비동기 이후
                  // State와 dialogContext 확인
                  if (!mounted ||
                      !dialogContext.mounted) {
                    return;
                  }

                  // 팝업 닫기
                  Navigator.pop(
                    dialogContext,
                  );

                  // 중복 다운로드 방지
                  if (alreadyDownloaded) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(
                      const SnackBar(
                        content:
                            Text(
                          '이미 다운로드한 쿠폰입니다.',
                        ),
                      ),
                    );

                    return;
                  }

                  // 단말기에 쿠폰 저장
                  await _couponStorageService
                      .saveCoupon(
                    coupon,
                  );

                  if (!mounted) {
                    return;
                  }

                  // 다운로드 완료
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(
                    SnackBar(
                      content:
                          Text(
                        '${coupon.title}을 다운로드했습니다.',
                      ),
                    ),
                  );
                },

                child:
                    const Text(
                  '다운로드',
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isCouponLoading =
            false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text(
            '쿠폰 정보를 불러오지 못했습니다.',
          ),
        ),
      );

      debugPrint(
        '쿠폰 API 오류: $e',
      );
    }
  }


  // =======================================================
  // 상세페이지 UI
  // =======================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final Store store =
        widget.store;

    return Scaffold(
      appBar:
          AppBar(
        title:
            const Text(
          '가맹점 상세',
        ),
      ),

      body:
          Padding(
        padding:
            const EdgeInsets.all(
          20,
        ),

        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            // 가맹점 아이콘
            const Center(
              child:
                  CircleAvatar(
                radius:
                    45,

                child:
                    Icon(
                  Icons.store,

                  size:
                      45,
                ),
              ),
            ),

            const SizedBox(
              height:
                  30,
            ),

            // 가맹점 이름
            Text(
              store.name,

              style:
                  const TextStyle(
                fontSize:
                    26,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            const Text(
              '할인 혜택',

              style:
                  TextStyle(
                fontSize:
                    18,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            // 혜택 내용
            Text(
              store.benefit,

              style:
                  const TextStyle(
                fontSize:
                    16,
              ),
            ),

            const SizedBox(
              height:
                  25,
            ),

            // 현재 거리
            Text(
              '현재 위치에서 약 '
              '${store.distance.round()}m',
            ),

            const SizedBox(
              height:
                  10,
            ),

            // 근접 알림 거리
            Text(
              '근접 알림 거리: '
              '${store.notificationRadius.round()}m',
            ),

            const Spacer(),

            // 쿠폰 다운로드
            SizedBox(
              width:
                  double.infinity,

              child:
                  ElevatedButton.icon(
                onPressed:
                    _isCouponLoading
                        ? null
                        : _downloadCoupon,

                icon:
                    const Icon(
                  Icons.download,
                ),

                label:
                    Text(
                  _isCouponLoading
                      ? '쿠폰 확인 중...'
                      : '할인쿠폰 다운로드',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}