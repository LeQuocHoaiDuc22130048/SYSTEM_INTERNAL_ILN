import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  Terminal as TerminalIcon,
  Play,
  Pause,
  Trash2,
  Download,
  Search,
  Maximize2,
  Minimize2,
  Send,
  Zap,
} from 'lucide-react';
import type { UserInfo } from '../mockData';
import { getAuthHeaders, getJsonAuthHeaders } from '../utils/auth';
import './TerminalTab.css';

export interface SystemActivityDto {
  id: string;
  timestamp: string;
  category: string;
  action: string;
  details: string;
  username: string;
  role: string;
  ip: string;
  status: string;
  latencyMs?: number;
}

interface CommandHistoryItem {
  type: 'command' | 'response' | 'activity' | 'system';
  id: string;
  timestamp: string;
  command?: string;
  output?: string;
  status?: string;
  executionTimeMs?: number;
  activity?: SystemActivityDto;
  systemText?: string;
}

interface TerminalTabProps {
  currentUser: UserInfo | null;
  showToast?: (type: 'success' | 'error' | 'warning' | 'info', title: string, message: string) => void;
}

const CATEGORIES = [
  { key: 'ALL', label: 'Tất cả' },
  { key: 'AUTH', label: 'Xác thực (AUTH)' },
  { key: 'REPAIR', label: 'Sửa chữa (REPAIR)' },
  { key: 'ATTENDANCE', label: 'Chấm công' },
  { key: 'WAREHOUSE', label: 'Kho bãi' },
  { key: 'TERMINAL', label: 'Lệnh Terminal' },
  { key: 'HTTP', label: 'HTTP Requests' },
];

const SUGGESTED_COMMANDS = [
  { cmd: 'help', desc: 'Trợ giúp' },
  { cmd: 'status', desc: 'Tình trạng hệ thống' },
  { cmd: 'activity 20', desc: '20 hoạt động gần nhất' },
  { cmd: 'users', desc: 'Thống kê tài khoản' },
  { cmd: 'orders', desc: 'Đơn sửa chữa' },
  { cmd: 'chamcong', desc: 'Điểm danh hôm nay' },
  { cmd: 'kho', desc: 'Tồn kho linh kiện' },
  { cmd: 'logs 20', desc: 'Nhật ký HTTP' },
  { cmd: 'clear', desc: 'Xóa màn hình' },
];

export const TerminalTab: React.FC<TerminalTabProps> = ({ currentUser, showToast }) => {
  const [entries, setEntries] = useState<CommandHistoryItem[]>([]);
  const [commandInput, setCommandInput] = useState<string>('');
  const [isExecuting, setIsExecuting] = useState<boolean>(false);
  const [isConnected, setIsConnected] = useState<boolean>(false);
  const [isPaused, setIsPaused] = useState<boolean>(false);
  const [selectedCategory, setSelectedCategory] = useState<string>('ALL');
  const [searchFilter, setSearchFilter] = useState<string>('');
  const [autoScroll, setAutoScroll] = useState<boolean>(true);
  const [isFullscreen, setIsFullscreen] = useState<boolean>(false);
  const [viewMode, setViewMode] = useState<'both' | 'stream' | 'cli'>('both');

  // Command history buffer for arrow-up / arrow-down
  const [commandHistory, setCommandHistory] = useState<string[]>([]);
  const [historyIndex, setHistoryIndex] = useState<number>(-1);

  const terminalBodyRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const eventSourceRef = useRef<EventSource | null>(null);

  // Auto-scroll to bottom when new entries arrive
  useEffect(() => {
    if (autoScroll && terminalBodyRef.current) {
      terminalBodyRef.current.scrollTop = terminalBodyRef.current.scrollHeight;
    }
  }, [entries, autoScroll]);

  // Initial welcome message and historical activity fetch
  useEffect(() => {
    const welcomeEntry: CommandHistoryItem = {
      type: 'system',
      id: 'welcome-0',
      timestamp: new Date().toLocaleTimeString('vi-VN'),
      systemText: `================================================================================
  INVERTER LIKE NEW - WEB MANAGEMENT TERMINAL & ACTIVITY STREAM v2.6.0
  Đăng nhập với tư cách: ${currentUser?.fullName || currentUser?.username || 'Quản trị viên'} (${currentUser?.role || 'ADMIN'})
  Thời gian: ${new Date().toLocaleString('vi-VN')}
  Gõ "help" hoặc click các câu lệnh nhanh để tra cứu nghiệp vụ hệ thống.
================================================================================`,
    };

    setEntries([welcomeEntry]);

    // Fetch initial historical activities (50 items)
    fetchRecentActivities();

    // Start SSE stream
    setupEventSource();

    return () => {
      if (eventSourceRef.current) {
        eventSourceRef.current.close();
      }
    };
  }, []);

  const fetchRecentActivities = async () => {
    try {
      const res = await fetch('/api/v1/terminal/activities?limit=50', {
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        const json = await res.json();
        if (json.data && Array.isArray(json.data)) {
          const loaded: CommandHistoryItem[] = json.data.map((act: SystemActivityDto) => ({
            type: 'activity',
            id: act.id || String(Math.random()),
            timestamp: formatTime(act.timestamp),
            activity: act,
          }));
          setEntries(prev => [...prev, ...loaded]);
        }
      }
    } catch (err) {
      console.error('Không thể tải lịch sử hoạt động:', err);
    }
  };

  const setupEventSource = () => {
    if (eventSourceRef.current) {
      eventSourceRef.current.close();
    }

    const token = localStorage.getItem('accessToken');
    if (!token) {
      setIsConnected(false);
      return;
    }

    const url = `/api/v1/terminal/stream?token=${encodeURIComponent(token)}`;
    const es = new EventSource(url);
    eventSourceRef.current = es;

    es.onopen = () => {
      setIsConnected(true);
      addSystemEntry('✓ Đã thiết lập kết nối thời gian thực với máy chủ (SSE Active).');
    };

    es.addEventListener('activity', (event: MessageEvent) => {
      try {
        const act: SystemActivityDto = JSON.parse(event.data);
        if (!isPaused) {
          setEntries(prev => {
            // Keep maximum 500 items to avoid UI lag
            const next = [
              ...prev,
              {
                type: 'activity',
                id: act.id || String(Date.now() + Math.random()),
                timestamp: formatTime(act.timestamp),
                activity: act,
              } as CommandHistoryItem,
            ];
            if (next.length > 500) {
              return next.slice(next.length - 500);
            }
            return next;
          });
        }
      } catch (e) {
        console.error('Lỗi phân tích cú pháp sự kiện activity:', e);
      }
    });

    es.onerror = () => {
      setIsConnected(false);
      // Wait before attempting reconnection
      setTimeout(() => {
        if (!isPaused && eventSourceRef.current?.readyState === EventSource.CLOSED) {
          setupEventSource();
        }
      }, 5000);
    };
  };

  const addSystemEntry = (text: string) => {
    setEntries(prev => [
      ...prev,
      {
        type: 'system',
        id: `sys-${Date.now()}-${Math.random()}`,
        timestamp: new Date().toLocaleTimeString('vi-VN'),
        systemText: text,
      },
    ]);
  };

  const formatTime = (ts: string) => {
    try {
      const d = new Date(ts);
      return d.toLocaleTimeString('vi-VN', { hour12: false });
    } catch {
      return ts || '--:--:--';
    }
  };

  const handleExecuteCommand = async (cmdToRun?: string) => {
    const raw = cmdToRun !== undefined ? cmdToRun : commandInput;
    const trimmed = raw.trim();
    if (!trimmed) return;

    // Clear input
    setCommandInput('');
    setHistoryIndex(-1);

    // Save to history
    setCommandHistory(prev => [trimmed, ...prev.filter(c => c !== trimmed)].slice(0, 50));

    // Special local command: clear / cls
    if (trimmed.toLowerCase() === 'clear' || trimmed.toLowerCase() === 'cls') {
      setEntries([
        {
          type: 'system',
          id: `clear-${Date.now()}`,
          timestamp: new Date().toLocaleTimeString('vi-VN'),
          systemText: 'Màn hình terminal đã được làm sạch. Gõ "help" để xem danh sách câu lệnh.',
        },
      ]);
      return;
    }

    // Add command item to screen
    const cmdId = `cmd-${Date.now()}`;
    const nowTime = new Date().toLocaleTimeString('vi-VN');

    setEntries(prev => [
      ...prev,
      {
        type: 'command',
        id: cmdId,
        timestamp: nowTime,
        command: trimmed,
      },
    ]);

    setIsExecuting(true);

    try {
      const res = await fetch('/api/v1/terminal/exec', {
        method: 'POST',
        headers: getJsonAuthHeaders(),
        body: JSON.stringify({ command: trimmed }),
      });

      const json = await res.json();
      if (res.ok && json.data) {
        const resp = json.data;
        if (resp.output === '__CLEAR__') {
          setEntries([]);
        } else {
          setEntries(prev => [
            ...prev,
            {
              type: 'response',
              id: `resp-${Date.now()}`,
              timestamp: new Date().toLocaleTimeString('vi-VN'),
              output: resp.output,
              status: resp.status,
              executionTimeMs: resp.executionTimeMs,
            },
          ]);
        }
      } else {
        setEntries(prev => [
          ...prev,
          {
            type: 'response',
            id: `resp-err-${Date.now()}`,
            timestamp: new Date().toLocaleTimeString('vi-VN'),
            output: json.message || 'Lỗi khi gửi yêu cầu thực thi lệnh đến máy chủ.',
            status: 'ERROR',
            executionTimeMs: 0,
          },
        ]);
      }
    } catch (err: any) {
      setEntries(prev => [
        ...prev,
        {
          type: 'response',
          id: `resp-err-${Date.now()}`,
          timestamp: new Date().toLocaleTimeString('vi-VN'),
          output: `Lỗi kết nối máy chủ: ${err?.message || err}`,
          status: 'ERROR',
          executionTimeMs: 0,
        },
      ]);
    } finally {
      setIsExecuting(false);
      // Re-focus input
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleExecuteCommand();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (commandHistory.length > 0) {
        const nextIdx = Math.min(historyIndex + 1, commandHistory.length - 1);
        setHistoryIndex(nextIdx);
        setCommandInput(commandHistory[nextIdx]);
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (historyIndex > 0) {
        const prevIdx = historyIndex - 1;
        setHistoryIndex(prevIdx);
        setCommandInput(commandHistory[prevIdx]);
      } else if (historyIndex === 0) {
        setHistoryIndex(-1);
        setCommandInput('');
      }
    } else if (e.key === 'Tab') {
      e.preventDefault();
      // Simple autocompletion
      const current = commandInput.trim().toLowerCase();
      if (current) {
        const match = SUGGESTED_COMMANDS.find(s => s.cmd.startsWith(current));
        if (match) {
          setCommandInput(match.cmd);
        }
      }
    }
  };

  const handleClearScreen = () => {
    setEntries([
      {
        type: 'system',
        id: `clear-${Date.now()}`,
        timestamp: new Date().toLocaleTimeString('vi-VN'),
        systemText: 'Màn hình console đã được làm sạch. Gõ "help" để xem danh sách câu lệnh.',
      },
    ]);
  };

  const handleExportLogs = () => {
    const lines = entries.map(e => {
      if (e.type === 'command') return `[${e.timestamp}] $ ${e.command}`;
      if (e.type === 'response') return `[${e.timestamp}] (${e.status} ${e.executionTimeMs}ms)\n${e.output}`;
      if (e.type === 'activity' && e.activity) {
        return `[${e.timestamp}] [${e.activity.category}] [${e.activity.status}] ${e.activity.username}: ${e.activity.action} - ${e.activity.details}`;
      }
      return `[${e.timestamp}] ${e.systemText}`;
    });

    const blob = new Blob([lines.join('\n\n')], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `terminal-activity-log-${new Date().toISOString().slice(0, 10)}.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    if (showToast) {
      showToast('success', 'Đã tải nhật ký', 'Đã lưu tệp nhật ký Terminal thành công.');
    }
  };

  // Filter entries based on category and search text
  const filteredEntries = useMemo(() => {
    return entries.filter(item => {
      // Filter by view mode (both, stream only, cli only)
      if (viewMode === 'stream' && (item.type === 'command' || item.type === 'response')) return false;
      if (viewMode === 'cli' && item.type === 'activity') return false;

      // Filter by category
      if (selectedCategory !== 'ALL' && item.type === 'activity') {
        if (item.activity?.category?.toUpperCase() !== selectedCategory) return false;
      }

      // Filter by search keyword
      if (searchFilter.trim()) {
        const q = searchFilter.toLowerCase();
        if (item.type === 'command') return item.command?.toLowerCase().includes(q);
        if (item.type === 'response') return item.output?.toLowerCase().includes(q);
        if (item.type === 'system') return item.systemText?.toLowerCase().includes(q);
        if (item.type === 'activity' && item.activity) {
          const act = item.activity;
          return (
            act.action?.toLowerCase().includes(q) ||
            act.details?.toLowerCase().includes(q) ||
            act.username?.toLowerCase().includes(q) ||
            act.category?.toLowerCase().includes(q) ||
            act.ip?.toLowerCase().includes(q)
          );
        }
      }
      return true;
    });
  }, [entries, selectedCategory, searchFilter, viewMode]);

  const getActivityBadgeClass = (category: string) => {
    switch (category?.toUpperCase()) {
      case 'AUTH':
        return 'badge-auth';
      case 'REPAIR':
        return 'badge-repair';
      case 'ATTENDANCE':
        return 'badge-attendance';
      case 'WAREHOUSE':
        return 'badge-warehouse';
      case 'TERMINAL':
        return 'badge-terminal';
      case 'HTTP':
        return 'badge-http';
      default:
        return 'badge-default';
    }
  };

  const getStatusBadge = (status: string) => {
    const s = (status || '').toUpperCase();
    if (s === 'SUCCESS' || s.startsWith('20')) {
      return <span className="status-tag status-success">✓ {status}</span>;
    }
    if (s === 'FAILED' || s === 'ERROR' || s.startsWith('40') || s.startsWith('50')) {
      return <span className="status-tag status-error">✕ {status}</span>;
    }
    if (s === 'WARN' || s === 'WARNING') {
      return <span className="status-tag status-warn">⚠ {status}</span>;
    }
    return <span className="status-tag status-info">{status || 'INFO'}</span>;
  };

  return (
    <div className={`terminal-tab-container ${isFullscreen ? 'terminal-fullscreen' : ''}`}>
      {/* Top Bar / Header */}
      <div className="terminal-header-bar">
        <div className="terminal-header-left">
          <div className="terminal-title-group">
            <div className="terminal-icon-wrapper">
              <TerminalIcon size={20} className="terminal-main-icon" />
            </div>
            <div>
              <div className="terminal-title">Quản Trị Terminal & Live Activity</div>
              <div className="terminal-subtitle">
                Giám sát luồng hoạt động thời gian thực & Thực thi câu lệnh quản trị hệ thống
              </div>
            </div>
          </div>
        </div>

        <div className="terminal-header-right">
          {/* Connection status pill */}
          <div className={`connection-pill ${isConnected ? 'connected' : 'disconnected'}`}>
            <span className="pulse-dot" />
            <span className="connection-text">
              {isConnected ? (isPaused ? 'SSE TẠM DỪNG' : 'SSE LIVE') : 'MẤT KẾT NỐI SSE'}
            </span>
          </div>

          {/* View mode segmented switch */}
          <div className="view-mode-switch">
            <button
              className={`mode-btn ${viewMode === 'both' ? 'active' : ''}`}
              onClick={() => setViewMode('both')}
              title="Hiển thị kết hợp cả Luồng Activity và Lệnh CLI"
            >
              Hợp nhất
            </button>
            <button
              className={`mode-btn ${viewMode === 'stream' ? 'active' : ''}`}
              onClick={() => setViewMode('stream')}
              title="Chỉ hiển thị dòng sự kiện hoạt động (Activity Stream)"
            >
              Activity
            </button>
            <button
              className={`mode-btn ${viewMode === 'cli' ? 'active' : ''}`}
              onClick={() => setViewMode('cli')}
              title="Chỉ hiển thị bảng điều khiển lệnh CLI"
            >
              Lệnh CLI
            </button>
          </div>

          {/* Pause / Resume */}
          <button
            className={`terminal-action-btn ${isPaused ? 'btn-paused' : ''}`}
            onClick={() => setIsPaused(!isPaused)}
            title={isPaused ? 'Tiếp tục nhận luồng sự kiện' : 'Tạm dừng luồng sự kiện'}
          >
            {isPaused ? <Play size={15} /> : <Pause size={15} />}
            <span>{isPaused ? 'Tiếp tục' : 'Tạm dừng'}</span>
          </button>

          {/* Clear */}
          <button
            className="terminal-action-btn"
            onClick={handleClearScreen}
            title="Xóa sạch màn hình console"
          >
            <Trash2 size={15} />
            <span>Xóa</span>
          </button>

          {/* Export */}
          <button
            className="terminal-action-btn"
            onClick={handleExportLogs}
            title="Tải tệp nhật ký về máy tính"
          >
            <Download size={15} />
            <span>Xuất file</span>
          </button>

          {/* Fullscreen toggle */}
          <button
            className="terminal-action-btn"
            onClick={() => setIsFullscreen(!isFullscreen)}
            title={isFullscreen ? 'Thu nhỏ cửa sổ' : 'Phóng to toàn màn hình'}
          >
            {isFullscreen ? <Minimize2 size={15} /> : <Maximize2 size={15} />}
          </button>
        </div>
      </div>

      {/* Control Filter Bar */}
      <div className="terminal-filter-bar">
        {/* Category Chips */}
        <div className="category-chips">
          {CATEGORIES.map(cat => (
            <button
              key={cat.key}
              className={`category-chip ${selectedCategory === cat.key ? 'active' : ''}`}
              onClick={() => setSelectedCategory(cat.key)}
            >
              {cat.label}
            </button>
          ))}
        </div>

        {/* Search input & auto-scroll checkbox */}
        <div className="filter-controls-right">
          <div className="search-input-wrapper">
            <Search size={14} className="search-icon" />
            <input
              type="text"
              placeholder="Lọc sự kiện, tài khoản, IP..."
              value={searchFilter}
              onChange={e => setSearchFilter(e.target.value)}
              className="search-input"
            />
            {searchFilter && (
              <button className="clear-search" onClick={() => setSearchFilter('')}>
                ✕
              </button>
            )}
          </div>

          <label className="autoscroll-toggle" title="Tự động cuộn màn hình khi có sự kiện mới">
            <input
              type="checkbox"
              checked={autoScroll}
              onChange={e => setAutoScroll(e.target.checked)}
            />
            <span>Tự cuộn</span>
          </label>
        </div>
      </div>

      {/* Quick Command Suggestions Pill Toolbar */}
      <div className="quick-command-bar">
        <span className="quick-label">
          <Zap size={13} /> Lệnh nhanh:
        </span>
        <div className="quick-buttons">
          {SUGGESTED_COMMANDS.map(sc => (
            <button
              key={sc.cmd}
              className="quick-cmd-btn"
              onClick={() => handleExecuteCommand(sc.cmd)}
              title={sc.desc}
            >
              <code>{sc.cmd}</code>
            </button>
          ))}
        </div>
      </div>

      {/* Terminal Main Window Frame */}
      <div className="terminal-window">
        {/* Terminal Window Header (macOS dots) */}
        <div className="terminal-window-header">
          <div className="mac-dots">
            <span className="dot dot-close" />
            <span className="dot dot-minimize" />
            <span className="dot dot-maximize" />
          </div>
          <div className="terminal-window-title">
            <span>root@inverterlikenew:~ (bash)</span>
            <span className="title-sep">•</span>
            <span className="activity-counter">{filteredEntries.length} dòng hiển thị</span>
          </div>
          <div className="terminal-header-tools">
            <span className="user-badge">{currentUser?.username || 'admin'}</span>
          </div>
        </div>

        {/* Terminal Body (Scrollable Output) */}
        <div className="terminal-body" ref={terminalBodyRef}>
          {filteredEntries.map(item => {
            if (item.type === 'system') {
              return (
                <div key={item.id} className="terminal-line line-system">
                  <pre className="system-text">{item.systemText}</pre>
                </div>
              );
            }

            if (item.type === 'command') {
              return (
                <div key={item.id} className="terminal-line line-command">
                  <span className="prompt-time">[{item.timestamp}]</span>
                  <span className="prompt-user">{currentUser?.username || 'admin'}@inverterlikenew</span>
                  <span className="prompt-symbol">:~$</span>
                  <span className="command-text">{item.command}</span>
                </div>
              );
            }

            if (item.type === 'response') {
              return (
                <div key={item.id} className={`terminal-line line-response ${item.status === 'ERROR' ? 'resp-error' : ''}`}>
                  <div className="resp-meta">
                    <span className="resp-badge">{item.status || 'OK'}</span>
                    <span className="resp-time">{item.executionTimeMs}ms</span>
                  </div>
                  <pre className="response-output">{item.output}</pre>
                </div>
              );
            }

            if (item.type === 'activity' && item.activity) {
              const act = item.activity;
              return (
                <div key={item.id} className="terminal-line line-activity">
                  <span className="act-time">[{item.timestamp}]</span>
                  <span className={`act-badge ${getActivityBadgeClass(act.category)}`}>
                    {act.category}
                  </span>
                  <span className="act-user">
                    {act.username || 'system'}
                    {act.role ? ` (${act.role})` : ''}
                  </span>
                  <span className="act-action">{act.action}</span>
                  <span className="act-details">{act.details}</span>
                  {act.ip && <span className="act-ip">[{act.ip}]</span>}
                  {getStatusBadge(act.status)}
                  {act.latencyMs !== undefined && act.latencyMs !== null && (
                    <span className="act-latency">{act.latencyMs}ms</span>
                  )}
                </div>
              );
            }

            return null;
          })}

          {isExecuting && (
            <div className="terminal-line line-executing">
              <span className="spinner-dot" />
              <span>Đang thực thi câu lệnh trên máy chủ...</span>
            </div>
          )}
        </div>

        {/* Terminal Interactive Input Line */}
        <div className="terminal-input-bar">
          <span className="input-prompt">
            <span className="prompt-user">{currentUser?.username || 'admin'}@inverterlikenew</span>
            <span className="prompt-symbol">:~$</span>
          </span>
          <input
            ref={inputRef}
            type="text"
            className="terminal-command-input"
            value={commandInput}
            onChange={e => setCommandInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Nhập câu lệnh (ví dụ: help, status, users, orders, chamcong, kho, clear) và nhấn Enter..."
            disabled={isExecuting}
            autoFocus
          />
          <button
            className="terminal-send-btn"
            onClick={() => handleExecuteCommand()}
            disabled={isExecuting || !commandInput.trim()}
            title="Thực thi lệnh"
          >
            <Send size={15} />
          </button>
        </div>
      </div>
    </div>
  );
};
