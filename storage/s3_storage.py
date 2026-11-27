"""
Amazon S3 Storage Manager for AECIP Platform.
Handles seamless storage and retrieval of model artifacts and datasets on AWS S3.
Gracefully falls back to local storage if AWS is not configured.
"""
import os
import logging
from pathlib import Path

logger = logging.getLogger("AECIP.Storage")
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")

try:
    import boto3
    from botocore.exceptions import ClientError, NoCredentialsError
    BOTO3_AVAILABLE = True
except ImportError:
    BOTO3_AVAILABLE = False
    logger.warning("boto3 is not installed. S3 integration disabled; local fallback active.")


class S3StorageManager:
    """Manages cloud object storage for model weights, training datasets, and checkpoints."""

    def __init__(self, bucket_name=None, region_name=None):
        self.bucket_name = bucket_name or os.getenv("AECIP_S3_BUCKET") or os.getenv("S3_BUCKET_NAME")
        self.region_name = region_name or os.getenv("AWS_REGION", "us-east-1")
        self._s3_client = None

        if BOTO3_AVAILABLE and self.bucket_name:
            try:
                self._s3_client = boto3.client("s3", region_name=self.region_name)
                logger.info(f"S3 Storage Manager initialized with bucket '{self.bucket_name}' in region '{self.region_name}'.")
            except Exception as e:
                logger.warning(f"Could not initialize S3 client: {e}. Operating in local mode.")
                self._s3_client = None
        else:
            if not self.bucket_name:
                logger.debug("No S3 bucket specified. Operating in local mode.")

    @property
    def is_enabled(self) -> bool:
        """Returns True if S3 client is actively configured with a valid bucket."""
        return self._s3_client is not None and bool(self.bucket_name)

    def upload_file(self, local_path: str, s3_key: str) -> bool:
        """Uploads a local file to S3."""
        if not self.is_enabled:
            logger.debug(f"S3 not configured. Skipping cloud upload of {local_path}.")
            return False

        if not os.path.exists(local_path):
            logger.error(f"Local file does not exist: {local_path}")
            return False

        try:
            logger.info(f"Uploading {local_path} -> s3://{self.bucket_name}/{s3_key}")
            self._s3_client.upload_file(local_path, self.bucket_name, s3_key)
            logger.info(f"Successfully uploaded {s3_key} to S3.")
            return True
        except (ClientError, NoCredentialsError) as e:
            logger.error(f"Failed to upload {local_path} to S3: {e}")
            return False

    def download_file(self, s3_key: str, local_path: str) -> bool:
        """Downloads a file from S3 to local storage."""
        if not self.is_enabled:
            logger.debug(f"S3 not configured. Skipping download for {s3_key}.")
            return False

        try:
            os.makedirs(os.path.dirname(os.path.abspath(local_path)), exist_ok=True)
            logger.info(f"Downloading s3://{self.bucket_name}/{s3_key} -> {local_path}")
            self._s3_client.download_file(self.bucket_name, s3_key, local_path)
            logger.info(f"Successfully downloaded {s3_key} from S3.")
            return True
        except ClientError as e:
            if e.response.get("Error", {}).get("Code") == "404":
                logger.warning(f"File s3://{self.bucket_name}/{s3_key} not found in S3.")
            else:
                logger.error(f"Error downloading {s3_key} from S3: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error downloading {s3_key} from S3: {e}")
            return False

    def upload_model(self, local_model_path: str, s3_prefix: str = "models") -> bool:
        """Uploads a model binary (.pkl) to s3://<bucket>/models/<filename>."""
        filename = os.path.basename(local_model_path)
        s3_key = f"{s3_prefix}/{filename}"
        return self.upload_file(local_model_path, s3_key)

    def download_model(self, model_filename: str, local_dest_path: str, s3_prefix: str = "models") -> bool:
        """Downloads a model binary from S3 if missing locally."""
        s3_key = f"{s3_prefix}/{model_filename}"
        return self.download_file(s3_key, local_dest_path)

    def upload_dataset(self, local_csv_path: str, s3_prefix: str = "datasets") -> bool:
        """Uploads a CSV dataset to S3."""
        filename = os.path.basename(local_csv_path)
        s3_key = f"{s3_prefix}/{filename}"
        return self.upload_file(local_csv_path, s3_key)

    def download_dataset(self, dataset_filename: str, local_dest_path: str, s3_prefix: str = "datasets") -> bool:
        """Downloads a dataset from S3."""
        s3_key = f"{s3_prefix}/{dataset_filename}"
        return self.download_file(s3_key, local_dest_path)


# Singleton instance for platform-wide usage
default_s3_storage = S3StorageManager()
