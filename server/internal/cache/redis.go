package cache

import (
	"context"
	"fmt"
	"github.com/redis/go-redis/v9"
	"github.com/example/social-app/server/internal/config"
)

var RDB *redis.Client

func Connect(cfg *config.RedisConfig) error {
	RDB = redis.NewClient(&redis.Options{
		Addr:     cfg.Addr,
		Password: cfg.Password,
		DB:       cfg.DB,
	})
	
	ctx := context.Background()
	if err := RDB.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("failed to connect redis: %w", err)
	}
	
	return nil
}