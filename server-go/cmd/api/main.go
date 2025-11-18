package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/byrondaniels/podcasts/server-go/internal/config"
	"github.com/byrondaniels/podcasts/server-go/internal/database"
	"github.com/byrondaniels/podcasts/server-go/internal/handlers"
	"github.com/byrondaniels/podcasts/server-go/internal/services"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	// Load configuration
	cfg := config.Load()

	// Connect to MongoDB
	db, err := database.Connect(cfg.MongoDBURL, cfg.MongoDBName)
	if err != nil {
		log.Fatalf("Failed to connect to MongoDB: %v", err)
	}
	defer db.Close()

	log.Println("Successfully connected to MongoDB")

	// Initialize services
	whisperService := services.NewWhisperService(cfg.WhisperServiceURL)
	bulkTranscribeService := services.NewBulkTranscribeService(db, whisperService)

	// Initialize handlers
	bulkTranscribeHandler := handlers.NewBulkTranscribeHandler(bulkTranscribeService)

	// Setup Gin router
	if cfg.LogLevel != "debug" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.Default()

	// Configure CORS
	corsConfig := cors.Config{
		AllowOrigins:     cfg.CORSOrigins,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	}
	router.Use(cors.New(corsConfig))

	// Request logging middleware
	router.Use(func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method

		c.Next()

		duration := time.Since(start)
		statusCode := c.Writer.Status()

		log.Printf("%s %s - %d (%v)", method, path, statusCode, duration)
	})

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "healthy",
			"service": "podcast-subscription-api",
			"version": "2.0.0-go",
		})
	})

	// Root endpoint
	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "Podcast Subscription API (Go)",
			"version": "2.0.0-go",
			"docs":    "/docs",
			"health":  "/health",
		})
	})

	// API routes
	api := router.Group("/api")
	{
		// Dev bulk transcribe endpoints
		devBulkTranscribe := api.Group("/dev/bulk-transcribe")
		{
			devBulkTranscribe.POST("", bulkTranscribeHandler.StartBulkTranscribe)
			devBulkTranscribe.GET("", bulkTranscribeHandler.ListBulkTranscribeJobs)
			devBulkTranscribe.GET("/:job_id", bulkTranscribeHandler.GetBulkTranscribeJob)
			devBulkTranscribe.POST("/:job_id/cancel", bulkTranscribeHandler.CancelBulkTranscribeJob)
		}
	}

	// Start server
	addr := cfg.AppHost + ":" + cfg.AppPort
	log.Printf("Starting server on %s", addr)

	server := &http.Server{
		Addr:           addr,
		Handler:        router,
		ReadTimeout:    60 * time.Second,
		WriteTimeout:   60 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Failed to start server: %v", err)
	}
}
