package handlers

import (
	"log"
	"net/http"

	"github.com/byrondaniels/podcasts/server-go/internal/models"
	"github.com/byrondaniels/podcasts/server-go/internal/services"
	"github.com/gin-gonic/gin"
)

// BulkTranscribeHandler handles bulk transcription endpoints
type BulkTranscribeHandler struct {
	service *services.BulkTranscribeService
}

// NewBulkTranscribeHandler creates a new bulk transcribe handler
func NewBulkTranscribeHandler(service *services.BulkTranscribeService) *BulkTranscribeHandler {
	return &BulkTranscribeHandler{service: service}
}

// StartBulkTranscribe starts a new bulk transcription job
// POST /api/dev/bulk-transcribe
func (h *BulkTranscribeHandler) StartBulkTranscribe(c *gin.Context) {
	var req models.BulkTranscribeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, models.ErrorResponse{
			Error:  "Invalid request",
			Detail: err.Error(),
		})
		return
	}

	// Create job
	job, err := h.service.CreateJob(c.Request.Context(), req.RSSURL, req.MaxEpisodes)
	if err != nil {
		log.Printf("Error creating bulk transcribe job: %v", err)
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:  "Failed to create bulk transcription job",
			Detail: err.Error(),
		})
		return
	}

	// Start processing in background
	go h.service.ProcessJob(job.JobID)

	c.JSON(http.StatusOK, job)
}

// GetBulkTranscribeJob gets the status and progress of a bulk transcription job
// GET /api/dev/bulk-transcribe/:job_id
func (h *BulkTranscribeHandler) GetBulkTranscribeJob(c *gin.Context) {
	jobID := c.Param("job_id")

	job, err := h.service.GetJob(c.Request.Context(), jobID)
	if err != nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{
			Error:  "Job not found",
			Detail: err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, job)
}

// ListBulkTranscribeJobs lists all bulk transcription jobs
// GET /api/dev/bulk-transcribe
func (h *BulkTranscribeHandler) ListBulkTranscribeJobs(c *gin.Context) {
	limit := 50 // Default limit

	jobs, err := h.service.ListJobs(c.Request.Context(), limit)
	if err != nil {
		log.Printf("Error listing bulk transcribe jobs: %v", err)
		c.JSON(http.StatusInternalServerError, models.ErrorResponse{
			Error:  "Failed to list jobs",
			Detail: err.Error(),
		})
		return
	}

	response := models.BulkTranscribeJobListResponse{
		Jobs:  jobs,
		Total: len(jobs),
	}

	c.JSON(http.StatusOK, response)
}

// CancelBulkTranscribeJob cancels a running bulk transcription job
// POST /api/dev/bulk-transcribe/:job_id/cancel
func (h *BulkTranscribeHandler) CancelBulkTranscribeJob(c *gin.Context) {
	jobID := c.Param("job_id")

	// Check if job exists
	job, err := h.service.GetJob(c.Request.Context(), jobID)
	if err != nil {
		c.JSON(http.StatusNotFound, models.ErrorResponse{
			Error:  "Job not found",
			Detail: err.Error(),
		})
		return
	}

	// Try to cancel
	cancelled := h.service.CancelJob(jobID)

	message := "Job cancellation requested"
	if !cancelled {
		message = "Job is not running"
	}

	c.JSON(http.StatusOK, models.SuccessResponse{
		Message: message,
		Data: map[string]interface{}{
			"job_id":    jobID,
			"cancelled": cancelled,
		},
	})

	_ = job // Suppress unused variable warning
}
