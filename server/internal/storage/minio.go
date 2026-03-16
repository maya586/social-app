package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
	"github.com/example/social-app/server/internal/config"
	"github.com/google/uuid"
)

var MinioClient *minio.Client
var BucketName string

func InitMinio(cfg *config.MinioConfig) error {
	var err error
	MinioClient, err = minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return fmt.Errorf("failed to initialize minio client: %w", err)
	}

	BucketName = cfg.Bucket
	ctx := context.Background()

	exists, err := MinioClient.BucketExists(ctx, BucketName)
	if err != nil {
		return fmt.Errorf("failed to check bucket existence: %w", err)
	}
	if !exists {
		err = MinioClient.MakeBucket(ctx, BucketName, minio.MakeBucketOptions{})
		if err != nil {
			return fmt.Errorf("failed to create bucket: %w", err)
		}
		log.Printf("Created bucket: %s", BucketName)
	}

	log.Println("MinIO connected successfully")
	return nil
}

func UploadFile(ctx context.Context, objectName string, reader io.Reader, objectSize int64, contentType string) (string, error) {
	if MinioClient == nil {
		return "", fmt.Errorf("minio client not initialized")
	}

	_, err := MinioClient.PutObject(ctx, BucketName, objectName, reader, objectSize, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %w", err)
	}

	return fmt.Sprintf("/files/%s", objectName), nil
}

func GetFile(ctx context.Context, objectName string) (*minio.Object, error) {
	if MinioClient == nil {
		return nil, fmt.Errorf("minio client not initialized")
	}

	object, err := MinioClient.GetObject(ctx, BucketName, objectName, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to get file: %w", err)
	}

	return object, nil
}

func DeleteFile(ctx context.Context, objectName string) error {
	if MinioClient == nil {
		return fmt.Errorf("minio client not initialized")
	}

	err := MinioClient.RemoveObject(ctx, BucketName, objectName, minio.RemoveObjectOptions{})
	if err != nil {
		return fmt.Errorf("failed to delete file: %w", err)
	}

	return nil
}

func GenerateObjectName(prefix string) string {
	return fmt.Sprintf("%s/%s", prefix, uuid.New().String())
}