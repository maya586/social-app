package monitor

import (
	"runtime"
	"time"

	"github.com/example/social-app/server/internal/websocket"
	"github.com/shirou/gopsutil/v3/cpu"
	"github.com/shirou/gopsutil/v3/disk"
	"github.com/shirou/gopsutil/v3/mem"
	"github.com/shirou/gopsutil/v3/net"
)

type ServerStats struct {
	CPUPercent      float64 `json:"cpu_percent"`
	MemoryPercent   float64 `json:"memory_percent"`
	DiskPercent     float64 `json:"disk_percent"`
	NetworkInBytes  uint64  `json:"network_in_bytes"`
	NetworkOutBytes uint64  `json:"network_out_bytes"`
}

type APIStats struct {
	RequestsPerSecond float64 `json:"requests_per_second"`
	AvgResponseTimeMs float64 `json:"avg_response_time_ms"`
	ErrorRate         float64 `json:"error_rate"`
}

type RealtimeStats struct {
	WebSocketConnections int `json:"websocket_connections"`
	OnlineUsers          int `json:"online_users"`
	ActiveCallRooms      int `json:"active_call_rooms"`
}

type MonitorData struct {
	Server   ServerStats   `json:"server"`
	API      APIStats      `json:"api"`
	Realtime RealtimeStats `json:"realtime"`
}

type SystemMonitor struct {
	hub             *websocket.Hub
	lastNetIO       net.IOCountersStat
	lastNetIOTime   time.Time
	requestCount    int64
	errorCount      int64
	totalResponseMs int64
}

func NewSystemMonitor(hub *websocket.Hub) *SystemMonitor {
	return &SystemMonitor{hub: hub}
}

func (m *SystemMonitor) GetMonitorData() *MonitorData {
	data := &MonitorData{}

	data.Server = m.getServerStats()
	data.API = m.getAPIStats()
	data.Realtime = m.getRealtimeStats()

	return data
}

func (m *SystemMonitor) getServerStats() ServerStats {
	stats := ServerStats{}

	if percent, err := cpu.Percent(time.Second, false); err == nil && len(percent) > 0 {
		stats.CPUPercent = percent[0]
	}

	if vm, err := mem.VirtualMemory(); err == nil {
		stats.MemoryPercent = vm.UsedPercent
	}

	if usage, err := disk.Usage("/"); err == nil {
		stats.DiskPercent = usage.UsedPercent
	}
	if runtime.GOOS == "windows" {
		if usage, err := disk.Usage("C:"); err == nil {
			stats.DiskPercent = usage.UsedPercent
		}
	}

	if netIO, err := net.IOCounters(false); err == nil && len(netIO) > 0 {
		now := time.Now()
		stats.NetworkInBytes = netIO[0].BytesRecv
		stats.NetworkOutBytes = netIO[0].BytesSent
		m.lastNetIO = netIO[0]
		m.lastNetIOTime = now
	}

	return stats
}

func (m *SystemMonitor) getAPIStats() APIStats {
	stats := APIStats{}

	if m.requestCount > 0 {
		stats.RequestsPerSecond = float64(m.requestCount) / 60.0
		stats.AvgResponseTimeMs = float64(m.totalResponseMs) / float64(m.requestCount)
		stats.ErrorRate = float64(m.errorCount) / float64(m.requestCount)
	}

	return stats
}

func (m *SystemMonitor) getRealtimeStats() RealtimeStats {
	stats := RealtimeStats{}

	if m.hub != nil {
		stats.WebSocketConnections = m.hub.GetConnectionCount()
		stats.OnlineUsers = m.hub.GetOnlineUserCount()
		stats.ActiveCallRooms = m.hub.GetActiveRoomCount()
	}

	return stats
}

func (m *SystemMonitor) RecordRequest(responseMs int64, isError bool) {
	m.requestCount++
	m.totalResponseMs += responseMs
	if isError {
		m.errorCount++
	}
}

func (m *SystemMonitor) ResetCounters() {
	m.requestCount = 0
	m.errorCount = 0
	m.totalResponseMs = 0
}
