from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from db import get_db_connection


# =========================================================
# FastAPI 서버 생성
# =========================================================

app = FastAPI(
    title="할인꿀팁 API",
    description="위치 기반 가맹점 할인 알림 및 쿠폰 서비스 API",
    version="1.0.0",
)


# =========================================================
# 요청 데이터 형식
# =========================================================

class NotificationRadiusUpdate(BaseModel):
    # 가맹점별 근접 알림 거리
    # 최소 30m ~ 최대 100m
    notification_radius: int = Field(
        ge=30,
        le=100,
    )


# =========================================================
# 데이터 변환
# =========================================================

def serialize_store(store: dict) -> dict:
    """
    MySQL 가맹점 데이터를
    Flutter에서 사용하기 좋은 형식으로 변환
    """

    return {
        "id": store["id"],
        "name": store["name"],
        "benefit": store["benefit"],
        "latitude": float(store["latitude"]),
        "longitude": float(store["longitude"]),
        "notification_radius": store["notification_radius"],
    }


def serialize_coupon(coupon: dict) -> dict:
    """
    MySQL 쿠폰 데이터를
    JSON으로 반환하기 좋은 형식으로 변환
    """

    return {
        "id": coupon["id"],
        "store_id": coupon["store_id"],
        "title": coupon["title"],
        "description": coupon["description"],
        "valid_until": (
            coupon["valid_until"].isoformat()
            if coupon["valid_until"]
            else None
        ),
        "is_active": bool(coupon["is_active"]),
    }


# =========================================================
# 기본 API
# =========================================================

@app.get("/")
def root():
    return {
        "message": "할인꿀팁 FastAPI 서버가 정상 실행 중입니다."
    }


@app.get("/health")
def health():
    return {
        "status": "ok"
    }


# =========================================================
# 가맹점 전체 조회
# =========================================================

@app.get("/stores")
def get_stores():
    connection = get_db_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    id,
                    name,
                    benefit,
                    latitude,
                    longitude,
                    notification_radius
                FROM stores
                ORDER BY id;
                """
            )

            stores = cursor.fetchall()

            return {
                "stores": [
                    serialize_store(store)
                    for store in stores
                ]
            }

    finally:
        connection.close()


# =========================================================
# 특정 가맹점 조회
# =========================================================

@app.get("/stores/{store_id}")
def get_store(store_id: str):
    connection = get_db_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    id,
                    name,
                    benefit,
                    latitude,
                    longitude,
                    notification_radius
                FROM stores
                WHERE id = %s;
                """,
                (store_id,),
            )

            store = cursor.fetchone()

            if store is None:
                raise HTTPException(
                    status_code=404,
                    detail="가맹점을 찾을 수 없습니다.",
                )

            return serialize_store(store)

    finally:
        connection.close()


# =========================================================
# 가맹점 근접 알림 거리 변경
# =========================================================

@app.put("/stores/{store_id}/notification-radius")
def update_notification_radius(
    store_id: str,
    request: NotificationRadiusUpdate,
):
    connection = get_db_connection()

    try:
        with connection.cursor() as cursor:

            # 가맹점 존재 여부 확인
            cursor.execute(
                """
                SELECT id
                FROM stores
                WHERE id = %s;
                """,
                (store_id,),
            )

            store_exists = cursor.fetchone()

            if store_exists is None:
                raise HTTPException(
                    status_code=404,
                    detail="가맹점을 찾을 수 없습니다.",
                )

            # 알림 거리 변경
            cursor.execute(
                """
                UPDATE stores
                SET notification_radius = %s
                WHERE id = %s;
                """,
                (
                    request.notification_radius,
                    store_id,
                ),
            )

            # 변경된 가맹점 조회
            cursor.execute(
                """
                SELECT
                    id,
                    name,
                    benefit,
                    latitude,
                    longitude,
                    notification_radius
                FROM stores
                WHERE id = %s;
                """,
                (store_id,),
            )

            updated_store = cursor.fetchone()

            return {
                "message": "근접 알림 거리가 변경되었습니다.",
                "store": serialize_store(updated_store),
            }

    finally:
        connection.close()


# =========================================================
# 특정 가맹점 쿠폰 조회
# =========================================================

@app.get("/stores/{store_id}/coupons")
def get_store_coupons(store_id: str):
    """
    선택한 가맹점에서 현재 사용 가능한 쿠폰 조회
    """

    connection = get_db_connection()

    try:
        with connection.cursor() as cursor:

            # 가맹점 존재 여부 확인
            cursor.execute(
                """
                SELECT id
                FROM stores
                WHERE id = %s;
                """,
                (store_id,),
            )

            store = cursor.fetchone()

            if store is None:
                raise HTTPException(
                    status_code=404,
                    detail="가맹점을 찾을 수 없습니다.",
                )

            # 사용 가능한 쿠폰 조회
            cursor.execute(
                """
                SELECT
                    id,
                    store_id,
                    title,
                    description,
                    valid_until,
                    is_active
                FROM coupons
                WHERE store_id = %s
                  AND is_active = TRUE
                ORDER BY id;
                """,
                (store_id,),
            )

            coupons = cursor.fetchall()

            return {
                "store_id": store_id,
                "coupons": [
                    serialize_coupon(coupon)
                    for coupon in coupons
                ],
            }

    finally:
        connection.close()