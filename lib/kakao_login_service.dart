import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';


// =========================================================
// 카카오 로그인 결과
// =========================================================

class KakaoLoginUser {
  // 카카오에서 발급하는 사용자 고유 회원번호
  final String userId;

  // 카카오 프로필 닉네임
  final String nickname;

  KakaoLoginUser({
    required this.userId,
    required this.nickname,
  });
}


// =========================================================
// 카카오 로그인 서비스
// =========================================================

class KakaoLoginService {
  // 카카오 로그인
  Future<KakaoLoginUser> login() async {
    // 카카오톡이 설치되어 있는지 확인
    final bool kakaoTalkInstalled =
        await isKakaoTalkInstalled();

    if (kakaoTalkInstalled) {
      try {
        // 카카오톡 앱으로 로그인
        await UserApi.instance
            .loginWithKakaoTalk();
      } on PlatformException catch (error) {
        // 사용자가 직접 로그인을 취소한 경우
        if (error.code == 'CANCELED') {
          rethrow;
        }

        // 카카오톡 로그인이 실패하면
        // 카카오계정 로그인으로 재시도
        await UserApi.instance
            .loginWithKakaoAccount();
      } catch (_) {
        // 기타 카카오톡 로그인 오류 발생 시
        // 브라우저 카카오계정 로그인 사용
        await UserApi.instance
            .loginWithKakaoAccount();
      }
    } else {
      // 카카오톡이 설치되지 않은 경우
      // 브라우저에서 카카오계정 로그인
      await UserApi.instance
          .loginWithKakaoAccount();
    }

    // 로그인한 사용자 정보 조회
    final User user =
        await UserApi.instance.me();

    // 회원번호와 닉네임 반환
    return KakaoLoginUser(
      userId: user.id.toString(),
      nickname:
          user.kakaoAccount
                  ?.profile
                  ?.nickname ??
              '카카오 사용자',
    );
  }


  // =======================================================
  // 카카오 로그아웃
  // =======================================================

  Future<void> logout() async {
    await UserApi.instance.logout();
  }
}