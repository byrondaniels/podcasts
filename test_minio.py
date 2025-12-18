#!/usr/bin/env python3
"""Test script to verify Minio S3 connectivity."""
import boto3
from botocore.exceptions import ClientError

# Minio configuration
MINIO_ENDPOINT = "http://localhost:9002"
MINIO_ACCESS_KEY = "minioadmin"
MINIO_SECRET_KEY = "minioadmin"
BUCKET_NAME = "podcast-transcripts"

def test_minio_connection():
    """Test Minio S3 connection and bucket operations."""
    print("Testing Minio S3 connection...")

    # Initialize S3 client
    s3_client = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        region_name='us-east-1'
    )

    try:
        # List existing buckets
        print("\n1. Listing existing buckets...")
        response = s3_client.list_buckets()
        print(f"   Found {len(response['Buckets'])} buckets:")
        for bucket in response['Buckets']:
            print(f"   - {bucket['Name']}")

        # Create bucket if it doesn't exist
        print(f"\n2. Creating bucket '{BUCKET_NAME}' (if not exists)...")
        try:
            s3_client.create_bucket(Bucket=BUCKET_NAME)
            print(f"   ✓ Bucket '{BUCKET_NAME}' created successfully")
        except ClientError as e:
            if e.response['Error']['Code'] == 'BucketAlreadyOwnedByYou':
                print(f"   ✓ Bucket '{BUCKET_NAME}' already exists")
            else:
                raise

        # Upload a test file
        print("\n3. Uploading test file...")
        test_key = "test/test-transcript.txt"
        test_content = "This is a test transcript content."
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=test_key,
            Body=test_content.encode('utf-8'),
            ContentType='text/plain'
        )
        print(f"   ✓ Uploaded test file: {test_key}")

        # Retrieve the test file
        print("\n4. Retrieving test file...")
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key=test_key)
        retrieved_content = response['Body'].read().decode('utf-8')
        print(f"   ✓ Retrieved content: '{retrieved_content}'")

        # Verify content matches
        if retrieved_content == test_content:
            print("   ✓ Content matches!")
        else:
            print("   ✗ Content mismatch!")
            return False

        # List objects in bucket
        print("\n5. Listing objects in bucket...")
        response = s3_client.list_objects_v2(Bucket=BUCKET_NAME)
        if 'Contents' in response:
            print(f"   Found {len(response['Contents'])} objects:")
            for obj in response['Contents']:
                print(f"   - {obj['Key']} ({obj['Size']} bytes)")
        else:
            print("   Bucket is empty")

        # Delete test file
        print("\n6. Cleaning up test file...")
        s3_client.delete_object(Bucket=BUCKET_NAME, Key=test_key)
        print(f"   ✓ Deleted test file: {test_key}")

        print("\n✅ All Minio S3 tests passed!")
        return True

    except Exception as e:
        print(f"\n❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = test_minio_connection()
    exit(0 if success else 1)
