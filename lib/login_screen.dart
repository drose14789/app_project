import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'kakao_login_service.dart';


// =========================================================
// 카카오 로그인 화면
// =========================================================

class LoginScreen extends StatefulWidget {
  // 로그인 성공 후 실행할 함수
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}


class _LoginScreenState
    extends State<LoginScreen> {
  // 카카오 로그인 서비스
  final KakaoLoginService _kakaoLoginService =
      KakaoLoginService();

  // 로그인 처리 중 여부
  bool _isLoading = false;

  // 오류 메시지
  String? _errorMessage;


  // =======================================================
  // 카카오 로그인
  // =======================================================

  Future<void> _loginWithKakao() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 카카오 로그인 실행
      await _kakaoLoginService.login();

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // 로그인 성공 후 메인 화면으로 이동
      widget.onLoginSuccess();

    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;

        if (error.code == 'CANCELED') {
          _errorMessage =
              '카카오 로그인이 취소되었습니다.';
        } else {
          _errorMessage =
              '카카오 로그인에 실패했습니다.';
        }
      });

    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            '카카오 로그인 중 오류가 발생했습니다.';
      });

      debugPrint(
        '카카오 로그인 오류: $error',
      );
    }
  }


  // =======================================================
  // 화면
  // =======================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 28,
          ),

          child: Column(
            children: [
              const Spacer(),

              // 서비스 로고
              Container(
                width: 100,
                height: 100,

                decoration: BoxDecoration(
                  color: Colors.orange
                      .withValues(
                    alpha: 0.12,
                  ),

                  shape: BoxShape.circle,
                ),

                child: const Icon(
                  Icons.local_offer_rounded,
                  size: 55,
                  color: Colors.orange,
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // 앱 이름
              const Text(
                '할인꿀팁',

                style: TextStyle(
                  fontSize: 34,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // 서비스 설명
              const Text(
                '내 주변 할인 혜택을\n놓치지 말고 확인하세요.',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Colors.grey,
                ),
              ),

              const Spacer(),

              // 카카오 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 54,

                child: ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _loginWithKakao,

                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(
                      0xFFFEE500,
                    ),

                    foregroundColor:
                        const Color(
                      0xFF191919,
                    ),

                    disabledBackgroundColor:
                        const Color(
                      0xFFFEE500,
                    ).withValues(
                      alpha: 0.5,
                    ),

                    elevation: 0,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),

                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [
                      if (_isLoading) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,

                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),
                      ] else ...[
                        const Icon(
                          Icons.chat_bubble,
                          size: 20,
                        ),

                        const SizedBox(
                          width: 10,
                        ),
                      ],

                      Text(
                        _isLoading
                            ? '카카오 로그인 중...'
                            : '카카오로 시작하기',

                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 로그인 오류 메시지
              if (_errorMessage != null) ...[
                const SizedBox(
                  height: 14,
                ),

                Text(
                  _errorMessage!,

                  textAlign:
                      TextAlign.center,

                  style:
                      const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              ],

              const SizedBox(
                height: 18,
              ),

              const Text(
                '카카오 계정으로 간편하게 시작할 수 있습니다.',

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(
                height: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}