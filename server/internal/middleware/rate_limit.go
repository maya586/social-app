package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type RateLimiter struct {
	visitors map[string]*visitor
	mu       sync.RWMutex
	rate     int
	window   time.Duration
}

type visitor struct {
	lastSeen time.Time
	count    int
}

func NewRateLimiter(rate int, window time.Duration) *RateLimiter {
	limiter := &RateLimiter{
		visitors: make(map[string]*visitor),
		rate:     rate,
		window:   window,
	}
	
	go limiter.cleanupVisitors()
	
	return limiter
}

func (rl *RateLimiter) cleanupVisitors() {
	for {
		time.Sleep(time.Minute)
		rl.mu.Lock()
		for ip, v := range rl.visitors {
			if time.Since(v.lastSeen) > rl.window {
				delete(rl.visitors, ip)
			}
		}
		rl.mu.Unlock()
	}
}

func (rl *RateLimiter) Allow(ip string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()
	
	v, exists := rl.visitors[ip]
	if !exists {
		rl.visitors[ip] = &visitor{
			lastSeen: time.Now(),
			count:    1,
		}
		return true
	}
	
	if time.Since(v.lastSeen) > rl.window {
		v.count = 1
		v.lastSeen = time.Now()
		return true
	}
	
	if v.count >= rl.rate {
		return false
	}
	
	v.count++
	v.lastSeen = time.Now()
	return true
}

func RateLimit(rate int, window time.Duration) gin.HandlerFunc {
	limiter := NewRateLimiter(rate, window)
	
	return func(c *gin.Context) {
		ip := c.ClientIP()
		
		if !limiter.Allow(ip) {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}

type UserRateLimiter struct {
	limits map[string]*userLimit
	mu     sync.RWMutex
}

type userLimit struct {
	count    int
	resetAt  time.Time
	rate     int
	window   time.Duration
}

func NewUserRateLimiter() *UserRateLimiter {
	return &UserRateLimiter{
		limits: make(map[string]*userLimit),
	}
}

func (url *UserRateLimiter) Allow(userID string, rate int, window time.Duration) bool {
	url.mu.Lock()
	defer url.mu.Unlock()
	
	limit, exists := url.limits[userID]
	if !exists || time.Now().After(limit.resetAt) {
		url.limits[userID] = &userLimit{
			count:   1,
			resetAt: time.Now().Add(window),
			rate:    rate,
			window:  window,
		}
		return true
	}
	
	if limit.count >= rate {
		return false
	}
	
	limit.count++
	return true
}

func UserRateLimit(rate int, window time.Duration) gin.HandlerFunc {
	limiter := NewUserRateLimiter()
	
	return func(c *gin.Context) {
		userID, exists := c.Get("user_id")
		if !exists {
			c.Next()
			return
		}
		
		userIDStr, ok := userID.(string)
		if !ok {
			c.Next()
			return
		}
		
		if !limiter.Allow(userIDStr, rate, window) {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "rate limit exceeded",
			})
			c.Abort()
			return
		}
		
		c.Next()
	}
}