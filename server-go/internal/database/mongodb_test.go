package database

import (
	"testing"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

func TestCollectionMethods(t *testing.T) {
	clientOpts := options.Client().ApplyURI("mongodb://localhost:27017")
	client, err := mongo.NewClient(clientOpts)
	if err != nil {
		t.Skipf("Skipping test: MongoDB client creation failed: %v", err)
		return
	}

	db := &MongoDB{
		Client:   client,
		Database: client.Database("test_db"),
	}

	tests := []struct {
		name            string
		method          func() *mongo.Collection
		expectedColName string
	}{
		{
			name:            "Podcasts collection",
			method:          db.Podcasts,
			expectedColName: "podcasts",
		},
		{
			name:            "Episodes collection",
			method:          db.Episodes,
			expectedColName: "episodes",
		},
		{
			name:            "BulkTranscribeJobs collection",
			method:          db.BulkTranscribeJobs,
			expectedColName: "bulk_transcribe_jobs",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			collection := tt.method()
			if collection == nil {
				t.Fatal("Collection method returned nil")
			}
			if collection.Name() != tt.expectedColName {
				t.Errorf("Expected collection name %s, got %s", tt.expectedColName, collection.Name())
			}
		})
	}
}

func TestCollection(t *testing.T) {
	clientOpts := options.Client().ApplyURI("mongodb://localhost:27017")
	client, err := mongo.NewClient(clientOpts)
	if err != nil {
		t.Skipf("Skipping test: MongoDB client creation failed: %v", err)
		return
	}

	db := &MongoDB{
		Client:   client,
		Database: client.Database("test_db"),
	}

	collectionName := "test_collection"
	collection := db.Collection(collectionName)

	if collection == nil {
		t.Fatal("Collection() returned nil")
	}
	if collection.Name() != collectionName {
		t.Errorf("Expected collection name %s, got %s", collectionName, collection.Name())
	}
}
