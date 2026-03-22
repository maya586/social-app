package middleware

import (
	"time"

	"github.com/example/social-app/server/internal/monitor"
	"github.com/gin-gonic/gin"
)

var globalMonitor *monitor.SystemMonitor

func InitMonitor(m *monitor.SystemMonitor) {
	globalMonitor = m
}

func MonitorMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if globalMonitor == nil {
			c.Next()
			return
		}

		start := time.Now()
		c.Next()
		duration := time.Since(start)

		isError := c.Writer.Status() >= 400
		globalMonitor.RecordRequest(duration.Milliseconds(), isError)
	}
}
