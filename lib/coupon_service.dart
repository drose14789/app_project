import 'dart:convert';

import 'package:http/http.dart' as http;


// =========================================================
// FastAPI 주소
// =========================================================

// Android Emulator에서 PC FastAPI에 접근하는 주소
const String couponApiBaseUrl = 'http://10.0.2.2:8000';


// =========================================================
// 쿠폰 모델
// =========================================================

class Coupon {
  final int id;
  final String storeId;
  final String title;
  final String description;
  final String? validUntil;
  final bool isActive;

  Coupon({
    required this.id,
    required this.storeId,
    required this.title,
    required this.description,
    required this.validUntil,
    required this.isActive,
  });


  // FastAPI JSON 데이터를 Coupon 객체로 변환
  factory Coupon.fromJson(
    Map<String, dynamic> json,
  ) {
    return Coupon(
      id: json['id'] as int,
      storeId:
          json['store_id'].toString(),
      title:
          json['title'].toString(),
      description:
          json['description'].toString(),
      validUntil:
          json['valid_until']?.toString(),
      isActive:
          json['is_active'] as bool,
    );
  }
}


// =========================================================
// 쿠폰 API 서비스
// =========================================================

class CouponService {
  // 특정 가맹점의 사용 가능한 쿠폰 조회
  Future<List<Coupon>> getStoreCoupons(
    String storeId,
  ) async {
    final Uri uri = Uri.parse(
      '$couponApiBaseUrl/stores/$storeId/coupons',
    );

    final http.Response response =
        await http
            .get(uri)
            .timeout(
      const Duration(
        seconds: 10,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception(
        '쿠폰 조회 실패: ${response.statusCode}',
      );
    }

    // 한글 깨짐 방지를 위해 UTF-8 처리
    final Map<String, dynamic> data =
        jsonDecode(
      utf8.decode(
        response.bodyBytes,
      ),
    ) as Map<String, dynamic>;

    final List<dynamic> couponList =
        data['coupons'] as List<dynamic>;

    return couponList.map(
      (dynamic item) {
        return Coupon.fromJson(
          Map<String, dynamic>.from(
            item as Map,
          ),
        );
      },
    ).toList();
  }
}