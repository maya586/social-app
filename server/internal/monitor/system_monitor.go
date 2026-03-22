package monitor

import (
	"bufio"
	"os"
	"runtime"
	"strconv"
	"strings"
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

	// Try gopsutil first
	if percent, err := cpu.Percent(time.Second, false); err == nil && len(percent) > 0 {
		stats.CPUPercent = percent[0]
	} else {
		// Fallback: read from /proc/stat for Docker containers
		stats.CPUPercent = m.readCPUFromProc()
	}

	if vm, err := mem.VirtualMemory(); err == nil {
		stats.MemoryPercent = vm.UsedPercent
	} else {
		// Fallback: read from /proc/meminfo
		stats.MemoryPercent = m.readMemFromProc()
	}

	if usage, err := disk.Usage("/"); err == nil {
		stats.DiskPercent = usage.UsedPercent
	} else if runtime.GOOS == "windows" {
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

func (m *SystemMonitor) readCPUFromProc() float64 {
	file, err := os.Open("/proc/stat")
	if err != nil {
		return 0
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	if !scanner.Scan() {
		return 0
	}

	line := scanner.Text()
	fields := strings.Fields(line)
	if len(fields) < 5 || fields[0] != "cpu" {
		return 0
	}

	var total, idle uint64
	for i := 1; i < len(fields) && i <= 8; i++ {
		val, _ := strconv.ParseUint(fields[i], 10, 64)
		total += val
		if i == 4 {
			idle = val
		}
	}

	if total == 0 {
		return 0
	}
	return float64(total-idle) * 100 / float64(total)
}

func (m *SystemMonitor) readMemFromProc() float64 {
	file, err := os.Open("/proc/meminfo")
	if err != nil {
		return 0
	}
	defer file.Close()

	var total, available uint64
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		fields := strings.Fields(line)
		if len(fields) < 2 {
			continue
		}

		val, _ := strconv.ParseUint(fields[1], 10, 64)
		switch fields[0] {
		case "MemTotal:":
			total = val
		case "MemAvailable:", "MemFree:":
			available = val
		}
	}

	if total == 0 {
		return 0
	}
	return float64(total-available) * 100 / float64(total)
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
