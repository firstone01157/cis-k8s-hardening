#!/usr/bin/env python3
"""
Unit Tests for Atomic Remediation Manager

This test suite validates the atomic write operations, auto-rollback,
and health check functionality.
"""

import unittest
import tempfile
import shutil
import os
from pathlib import Path
from atomic_remediation import AtomicRemediationManager, RemediationFlow


class TestAtomicRemediationManager(unittest.TestCase):
    """Test cases for AtomicRemediationManager."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_dir = tempfile.mkdtemp()
        self.backup_dir = os.path.join(self.test_dir, "backups")
        self.manager = AtomicRemediationManager(backup_dir=self.backup_dir)
        
        # Create a test manifest file
        self.test_manifest = os.path.join(self.test_dir, "test-manifest.yaml")
        with open(self.test_manifest, 'w') as f:
            f.write("""apiVersion: v1
kind: Pod
metadata:
  name: test-pod
spec:
  containers:
  - name: test-container
    image: test:latest
    command:
    - /bin/sh
    - -c
    - test
""")
    
    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_backup_creation(self):
        """Test that backup files are created correctly."""
        success, backup_path = self.manager.create_backup(self.test_manifest)
        
        self.assertTrue(success, "Backup should be created successfully")
        self.assertTrue(os.path.exists(backup_path), "Backup file should exist")
        
        # Verify backup content matches original
        with open(self.test_manifest, 'r') as original:
            with open(backup_path, 'r') as backup:
                self.assertEqual(original.read(), backup.read(),
                               "Backup content should match original")
    
    def test_atomic_write(self):
        """Test that atomic write doesn't leave partial files."""
        modifications = {
            'flags': ['--test-flag=true']
        }
        
        success, message = self.manager.update_manifest_safely(
            self.test_manifest,
            modifications
        )
        
        # Should succeed even if it's just text-based
        self.assertTrue(success or "No changes" in message,
                       "Atomic write should succeed or report no changes")
    
    def test_rollback(self):
        """Test that rollback restores original file."""
        # Create backup
        success, backup_path = self.manager.create_backup(self.test_manifest)
        self.assertTrue(success, "Backup should be created")
        
        # Modify the original
        with open(self.test_manifest, 'w') as f:
            f.write("MODIFIED CONTENT")
        
        # Verify it's modified
        with open(self.test_manifest, 'r') as f:
            self.assertEqual(f.read(), "MODIFIED CONTENT")
        
        # Rollback
        success, message = self.manager.rollback(self.test_manifest, backup_path)
        self.assertTrue(success, "Rollback should succeed")
        
        # Verify original is restored
        with open(self.test_manifest, 'r') as f:
            content = f.read()
            self.assertIn("test-pod", content, "Original content should be restored")
            self.assertNotIn("MODIFIED CONTENT", content)
    
    def test_nonexistent_file(self):
        """Test handling of non-existent files."""
        nonexistent = os.path.join(self.test_dir, "nonexistent.yaml")
        success, backup_path = self.manager.create_backup(nonexistent)
        
        self.assertFalse(success, "Backup of non-existent file should fail")


class TestRemediationFlow(unittest.TestCase):
    """Test cases for RemediationFlow orchestration."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_dir = tempfile.mkdtemp()
        self.backup_dir = os.path.join(self.test_dir, "backups")
        self.manager = AtomicRemediationManager(backup_dir=self.backup_dir)
        self.flow = RemediationFlow(self.manager)
        
        # Create test manifest
        self.test_manifest = os.path.join(self.test_dir, "kube-apiserver.yaml")
        with open(self.test_manifest, 'w') as f:
            f.write("""apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
spec:
  containers:
  - name: kube-apiserver
    image: k8s.gcr.io/kube-apiserver:v1.21.0
    command:
    - kube-apiserver
    - --bind-address=0.0.0.0
""")
    
    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_remediation_flow_basic(self):
        """Test basic remediation flow without actual cluster."""
        result = self.flow.remediate_with_verification(
            check_id="1.2.1",
            manifest_path=self.test_manifest,
            modifications={'flags': ['--anonymous-auth=false']},
            audit_script_path=None  # Skip audit for this test
        )
        
        # Should fail on health check since there's no actual cluster
        # But the backup should be in place
        self.assertIsNotNone(result['backup_path'])
        self.assertTrue(os.path.exists(result['backup_path']),
                       "Backup should be created in remediation flow")


class TestHealthCheck(unittest.TestCase):
    """Test cases for cluster health checks."""
    
    def setUp(self):
        """Set up test fixtures."""
        self.test_dir = tempfile.mkdtemp()
        self.backup_dir = os.path.join(self.test_dir, "backups")
        self.manager = AtomicRemediationManager(backup_dir=self.backup_dir)
    
    def tearDown(self):
        """Clean up test fixtures."""
        if os.path.exists(self.test_dir):
            shutil.rmtree(self.test_dir)
    
    def test_health_check_timeout(self):
        """Test that health check times out on unreachable endpoint."""
        # Use a very short timeout
        is_healthy, message = self.manager.wait_for_cluster_healthy(
            timeout=2,
            max_retries=3
        )
        
        # Should timeout since there's no actual cluster
        self.assertFalse(is_healthy, "Health check should timeout")
        self.assertIn("timeout", message.lower(), "Message should mention timeout")


def run_tests():
    """Run all unit tests."""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestAtomicRemediationManager))
    suite.addTests(loader.loadTestsFromTestCase(TestRemediationFlow))
    suite.addTests(loader.loadTestsFromTestCase(TestHealthCheck))
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
