package database

import (
	"context"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

// MongoDB holds the database connection
type MongoDB struct {
	Client   *mongo.Client
	Database *mongo.Database
}

// Connect establishes a connection to MongoDB
func Connect(mongoURI, dbName string) (*MongoDB, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clientOptions := options.Client().ApplyURI(mongoURI)
	client, err := mongo.Connect(ctx, clientOptions)
	if err != nil {
		return nil, err
	}

	// Ping the database to verify connection
	if err := client.Ping(ctx, nil); err != nil {
		return nil, err
	}

	log.Println("Successfully connected to MongoDB")

	return &MongoDB{
		Client:   client,
		Database: client.Database(dbName),
	}, nil
}

// Close closes the MongoDB connection
func (db *MongoDB) Close() error {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	return db.Client.Disconnect(ctx)
}

// Collection returns a collection handle
func (db *MongoDB) Collection(name string) *mongo.Collection {
	return db.Database.Collection(name)
}

// Podcasts returns the podcasts collection
func (db *MongoDB) Podcasts() *mongo.Collection {
	return db.Collection("podcasts")
}

// Episodes returns the episodes collection
func (db *MongoDB) Episodes() *mongo.Collection {
	return db.Collection("episodes")
}

// BulkTranscribeJobs returns the bulk transcribe jobs collection
func (db *MongoDB) BulkTranscribeJobs() *mongo.Collection {
	return db.Collection("bulk_transcribe_jobs")
}
