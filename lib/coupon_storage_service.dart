import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'coupon_service.dart';


// =========================================================
// 다운로드한 쿠폰 단말기 저장 기능
// =========================================================

class CouponStorageService {
  // SharedPreferences에 저장할 키
  static const String _couponStorageKey =
      'downloaded_coupons';

  // 단말기 저장소
  final SharedPreferencesAsync _preferences =
      SharedPreferencesAsync();


  // =======================================================
  // 쿠폰 저장
  // =======================================================

  Future<void> saveCoupon(
    Coupon coupon,
  ) async {
    // 기존에 저장된 쿠폰 불러오기
    final List<Map<String, dynamic>> coupons =
        await getDownloadedCoupons();

    // 같은 쿠폰을 이미 받았는지 확인
    final bool alreadyDownloaded =
        coupons.any(
      (Map<String, dynamic> item) =>
          item['id'] == coupon.id,
    );

    // 이미 받은 쿠폰이면 중복 저장하지 않음
    if (alreadyDownloaded) {
      return;
    }

    // 새 쿠폰 추가
    coupons.add(
      {
        'id': coupon.id,
        'store_id': coupon.storeId,
        'title': coupon.title,
        'description': coupon.description,
        'valid_until': coupon.validUntil,
        'is_active': coupon.isActive,
      },
    );

    // JSON 문자열로 변환해서 단말기에 저장
    await _preferences.setString(
      _couponStorageKey,
      jsonEncode(coupons),
    );
  }


  // =======================================================
  // 다운로드한 쿠폰 전체 조회
  // =======================================================

  Future<List<Map<String, dynamic>>>
      getDownloadedCoupons() async {
    final String? savedJson =
        await _preferences.getString(
      _couponStorageKey,
    );

    if (savedJson == null ||
        savedJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded =
          jsonDecode(savedJson)
              as List<dynamic>;

      return decoded
          .map(
            (dynamic item) =>
                Map<String, dynamic>.from(
              item as Map,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }


  // =======================================================
  // 특정 쿠폰 다운로드 여부 확인
  // =======================================================

  Future<bool> isDownloaded(
    int couponId,
  ) async {
    final List<Map<String, dynamic>> coupons =
        await getDownloadedCoupons();

    return coupons.any(
      (Map<String, dynamic> item) =>
          item['id'] == couponId,
    );
  }
}