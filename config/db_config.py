"""
Database configuration and connection management.
Supports both local PostgreSQL and Amazon RDS PostgreSQL instances.
"""
import os
import psycopg2

def get_connection():
    """
    Establishes and returns a connection to the PostgreSQL database.
    Supports local Docker/host PostgreSQL and AWS RDS PostgreSQL via environment variables.
    """
    dbname = os.getenv("DB_NAME", "enterprise_segmentation_v2")
    user = os.getenv("DB_USER", "postgres")
    password = os.getenv("DB_PASS") or os.getenv("DB_PASSWORD", "5432")
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    
    # RDS frequently requires sslmode=require; local postgres typically uses disable or prefer
    default_ssl = "disable" if host in ("localhost", "127.0.0.1") else "prefer"
    sslmode = os.getenv("DB_SSLMODE", default_ssl)
    connect_timeout = int(os.getenv("DB_CONNECT_TIMEOUT", "10"))

    try:
        conn = psycopg2.connect(
            dbname=dbname,
            user=user,
            password=password,
            host=host,
            port=port,
            sslmode=sslmode,
            connect_timeout=connect_timeout
        )
        return conn
    except Exception as e:
        print(f"Error connecting to the database ({host}:{port}/{dbname}): {e}")
        raise
