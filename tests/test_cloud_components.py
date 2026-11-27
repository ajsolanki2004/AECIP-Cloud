"""
Unit and integration tests for AECIP cloud components, S3 storage, and API.
"""
import unittest
import os
import sys

# Ensure root directory is on PYTHONPATH
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from storage.s3_storage import S3StorageManager
from monitoring.psi_calculator import calculate_psi
from monitoring.kl_divergence import calculate_kl
from monitoring.drift_intelligence import DriftIntelligence
from decision_engine.action_recommender import ActionRecommender
import numpy as np


class TestCloudComponents(unittest.TestCase):

    def test_s3_storage_fallback_without_bucket(self):
        """Tests that S3StorageManager falls back gracefully when S3 is unconfigured."""
        s3 = S3StorageManager(bucket_name="")
        self.assertFalse(s3.is_enabled)
        # Upload should return False instead of raising an uncaught exception
        result = s3.upload_file("non_existent_file.pkl", "models/test.pkl")
        self.assertFalse(result)

    def test_psi_and_kl_divergence_calculation(self):
        """Tests drift metrics calculation on synthetic distributions."""
        np.random.seed(42)
        expected = np.random.normal(100, 15, 500)
        actual = np.random.normal(100, 15, 500)

        psi = calculate_psi(expected, actual)
        kl = calculate_kl(expected, actual)

        self.assertIsInstance(psi, float)
        self.assertIsInstance(kl, float)
        self.assertGreaterEqual(psi, 0.0)
        self.assertGreaterEqual(kl, 0.0)

    def test_action_recommender_rules(self):
        """Tests business rule recommendations based on churn and CLV."""
        # High churn, high value -> VIP Retention
        action_vip = ActionRecommender.get_recommendation(segment_id=0, churn_prob=0.85, clv=3500)
        self.assertIn("Retention Campaign - VIP Offer", action_vip)

        # High churn, low value -> Win-back discount
        action_discount = ActionRecommender.get_recommendation(segment_id=2, churn_prob=0.75, clv=500)
        self.assertIn("Discount Campaign - Win-Back", action_discount)

        # Low churn, high value -> Cross-sell / upsell
        action_upsell = ActionRecommender.get_recommendation(segment_id=0, churn_prob=0.15, clv=4000)
        self.assertIn("Premium Cross-Sell / Upsell", action_upsell)

    def test_api_health_endpoint(self):
        """Tests Flask API /health endpoint."""
        from api.app import app
        app.testing = True
        client = app.test_client()
        response = client.get('/health')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data.get("status"), "healthy")
        self.assertEqual(data.get("service"), "aecip-api")


if __name__ == "__main__":
    unittest.main()
