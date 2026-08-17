import 'package:flutter/material.dart';

import 'coupon_storage_service.dart';


// =========================================================
// 내 쿠폰함 화면
// =========================================================

class CouponWalletScreen extends StatefulWidget {
  const CouponWalletScreen({
    super.key,
  });

  @override
  State<CouponWalletScreen> createState() =>
      _CouponWalletScreenState();
}


class _CouponWalletScreenState
    extends State<CouponWalletScreen> {
  // 단말기에 저장된 쿠폰 조회 서비스
  final CouponStorageService _couponStorageService =
      CouponStorageService();

  // 다운로드한 쿠폰 목록
  List<Map<String, dynamic>> _coupons = [];

  // 쿠폰 조회 중 여부
  bool _isLoading = true;


  // =======================================================
  // 화면 시작
  // =======================================================

  @override
  void initState() {
    super.initState();

    _loadCoupons();
  }


  // =======================================================
  // 다운로드한 쿠폰 불러오기
  // =======================================================

  Future<void> _loadCoupons() async {
    final List<Map<String, dynamic>> coupons =
        await _couponStorageService
            .getDownloadedCoupons();

    if (!mounted) {
      return;
    }

    setState(() {
      _coupons = coupons;
      _isLoading = false;
    });
  }


  // =======================================================
  // 쿠폰함 화면
  // =======================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '내 쿠폰함',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }


  // =======================================================
  // 쿠폰함 내용
  // =======================================================

  Widget _buildBody() {
    // 쿠폰 불러오는 중
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    // 다운로드한 쿠폰이 없는 경우
    if (_coupons.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 70,
              color: Colors.grey,
            ),

            SizedBox(
              height: 15,
            ),

            Text(
              '다운로드한 쿠폰이 없습니다.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              '가맹점 상세페이지에서\n할인쿠폰을 다운로드해보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 다운로드한 쿠폰 목록
    return RefreshIndicator(
      onRefresh: _loadCoupons,

      child: ListView.builder(
        padding: const EdgeInsets.all(
          16,
        ),

        itemCount: _coupons.length,

        itemBuilder:
            (
          BuildContext context,
          int index,
        ) {
          final Map<String, dynamic> coupon =
              _coupons[index];

          final String title =
              coupon['title']?.toString() ??
                  '할인쿠폰';

          final String description =
              coupon['description']?.toString() ??
                  '';

          final String? validUntil =
              coupon['valid_until']
                  ?.toString();

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),

            child: Padding(
              padding: const EdgeInsets.all(
                16,
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  // 쿠폰 아이콘
                  const CircleAvatar(
                    radius: 25,

                    child: Icon(
                      Icons.local_offer,
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  // 쿠폰 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        // 쿠폰 이름
                        Text(
                          title,

                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        // 쿠폰 혜택
                        Text(
                          description,
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        // 쿠폰 사용기한
                        Text(
                          validUntil == null
                              ? '사용기한: 제한 없음'
                              : '사용기한: $validUntil',

                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}