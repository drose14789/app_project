import os

import pymysql
from dotenv import load_dotenv


# .env 파일의 환경변수 불러오기
load_dotenv()


def get_db_connection():
    """
    FastAPI에서 사용할 MySQL 연결을 생성하는 함수
    """

    return pymysql.connect(
        host=os.getenv("DB_HOST"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


if __name__ == "__main__":
    # MySQL 연결 테스트
    connection = get_db_connection()

    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT DATABASE() AS database_name;")
            result = cursor.fetchone()

            print("MySQL 연결 성공")
            print(result)

    finally:
        connection.close()