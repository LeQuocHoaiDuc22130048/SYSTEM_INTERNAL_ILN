import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  X,
  ChevronLeft,
  ChevronRight,
  ZoomIn,
  ZoomOut,
  RotateCw,
  RefreshCw,
  Download,
  ExternalLink,
  Play,
  FileText,
  Trash2,
  FileSpreadsheet,
  FileCode,
  FileArchive
} from 'lucide-react';
import './MediaPreviewModal.css';

export interface RepairMedia {
  id: string;
  imageUrl: string;
  mediaType?: 'IMAGE' | 'VIDEO' | 'DOCUMENT' | string;
  caption?: string;
  createdAt?: string;
}

interface MediaPreviewModalProps {
  isOpen: boolean;
  onClose: () => void;
  mediaList: RepairMedia[];
  currentIndex: number;
  onIndexChange: (newIndex: number) => void;
  onDelete?: (mediaId: string) => void;
}

export const MediaPreviewModal: React.FC<MediaPreviewModalProps> = ({
  isOpen,
  onClose,
  mediaList,
  currentIndex,
  onIndexChange,
  onDelete
}) => {
  // Zoom, Rotation, Drag states for Images
  const [zoom, setZoom] = useState<number>(1);
  const [rotation, setRotation] = useState<number>(0);
  const [position, setPosition] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [dragStart, setDragStart] = useState<{ x: number; y: number }>({ x: 0, y: 0 });

  // Video playback speed
  const [playbackSpeed, setPlaybackSpeed] = useState<number>(1);
  const videoRef = useRef<HTMLVideoElement | null>(null);

  // Reset image transform when active media changes
  const resetImageState = useCallback(() => {
    setZoom(1);
    setRotation(0);
    setPosition({ x: 0, y: 0 });
    setIsDragging(false);
    setPlaybackSpeed(1);
  }, []);

  useEffect(() => {
    resetImageState();
  }, [currentIndex, resetImageState]);

  // Helper functions to detect media type
  const currentMedia = mediaList && mediaList.length > 0 ? mediaList[currentIndex] : null;

  const isVideo = useCallback((media?: RepairMedia | null) => {
    if (!media) return false;
    if (media.mediaType === 'VIDEO') return true;
    const url = (media.imageUrl || '').toLowerCase();
    return (
      url.endsWith('.mp4') ||
      url.endsWith('.mov') ||
      url.endsWith('.webm') ||
      url.endsWith('.avi') ||
      url.endsWith('.mkv') ||
      url.endsWith('.3gp')
    );
  }, []);

  const isDocument = useCallback((media?: RepairMedia | null) => {
    if (!media) return false;
    if (media.mediaType === 'DOCUMENT') return true;
    const url = (media.imageUrl || '').toLowerCase();
    return (
      url.endsWith('.pdf') ||
      url.endsWith('.doc') ||
      url.endsWith('.docx') ||
      url.endsWith('.xls') ||
      url.endsWith('.xlsx') ||
      url.endsWith('.ppt') ||
      url.endsWith('.pptx') ||
      url.endsWith('.txt') ||
      url.endsWith('.zip') ||
      url.endsWith('.rar') ||
      url.endsWith('.7z') ||
      url.endsWith('.csv')
    );
  }, []);

  const isPdf = useCallback((url?: string) => {
    if (!url) return false;
    const lower = url.toLowerCase();
    return lower.endsWith('.pdf') || lower.includes('/pdf');
  }, []);

  // Keyboard navigation & controls
  useEffect(() => {
    if (!isOpen) return;

    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'ArrowLeft') {
        if (currentIndex > 0) onIndexChange(currentIndex - 1);
      } else if (e.key === 'ArrowRight') {
        if (currentIndex < mediaList.length - 1) onIndexChange(currentIndex + 1);
      } else if (e.key === '+' || e.key === '=') {
        setZoom(prev => Math.min(prev + 0.25, 4));
      } else if (e.key === '-') {
        setZoom(prev => Math.max(prev - 0.25, 0.5));
      } else if (e.key === 'r' || e.key === 'R') {
        setRotation(prev => (prev + 90) % 360);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [isOpen, currentIndex, mediaList.length, onClose, onIndexChange]);

  if (!isOpen || !currentMedia) return null;

  // Zoom handlers
  const handleZoomIn = () => setZoom(prev => Math.min(prev + 0.25, 4));
  const handleZoomOut = () => setZoom(prev => Math.max(prev - 0.25, 0.5));
  const handleRotate = () => setRotation(prev => (prev + 90) % 360);
  const handleToggleDoubleZoom = () => {
    if (zoom === 1) setZoom(2);
    else setZoom(1);
    setPosition({ x: 0, y: 0 });
  };

  // Mouse wheel zoom for image
  const handleWheel = (e: React.WheelEvent) => {
    if (isVideo(currentMedia) || isDocument(currentMedia)) return;
    e.preventDefault();
    if (e.deltaY < 0) {
      setZoom(prev => Math.min(prev + 0.2, 4));
    } else {
      setZoom(prev => Math.max(prev - 0.2, 0.5));
    }
  };

  // Drag image when zoomed
  const handleMouseDown = (e: React.MouseEvent) => {
    if (zoom <= 1) return;
    setIsDragging(true);
    setDragStart({ x: e.clientX - position.x, y: e.clientY - position.y });
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    if (!isDragging) return;
    setPosition({
      x: e.clientX - dragStart.x,
      y: e.clientY - dragStart.y,
    });
  };

  const handleMouseUp = () => setIsDragging(false);

  // Download media
  const handleDownload = () => {
    const link = document.createElement('a');
    link.href = currentMedia.imageUrl;
    link.download = currentMedia.caption || `file_${currentMedia.id}`;
    link.target = '_blank';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Video speed change
  const handleSpeedChange = (speed: number) => {
    setPlaybackSpeed(speed);
    if (videoRef.current) {
      videoRef.current.playbackRate = speed;
    }
  };

  const mediaIsVid = isVideo(currentMedia);
  const mediaIsDoc = isDocument(currentMedia);
  const mediaIsPdf = mediaIsDoc && isPdf(currentMedia.imageUrl);

  // Helper for document icon
  const getDocIcon = (url: string) => {
    const lower = url.toLowerCase();
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
      return <FileSpreadsheet size={48} className="doc-type-icon excel" />;
    }
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) {
      return <FileArchive size={48} className="doc-type-icon zip" />;
    }
    if (lower.endsWith('.code') || lower.endsWith('.txt') || lower.endsWith('.json')) {
      return <FileCode size={48} className="doc-type-icon code" />;
    }
    return <FileText size={48} className="doc-type-icon default" />;
  };

  return (
    <div className="media-modal-backdrop" onClick={onClose}>
      <div className="media-modal-container" onClick={e => e.stopPropagation()}>
        
        {/* Top Header Bar */}
        <div className="media-modal-header">
          <div className="media-info-col">
            <h4 className="media-title">
              {currentMedia.caption || (mediaIsVid ? 'Video đính kèm' : mediaIsDoc ? 'Tài liệu đính kèm' : 'Hình ảnh đính kèm')}
            </h4>
            <span className="media-counter">
              {currentIndex + 1} / {mediaList.length}
            </span>
          </div>

          <div className="media-modal-header-actions">
            {/* Download Button */}
            <button className="media-icon-btn" onClick={handleDownload} title="Tải xuống tệp">
              <Download size={18} />
              <span className="btn-label">Tải xuống</span>
            </button>

            {/* External Link */}
            <a
              href={currentMedia.imageUrl}
              target="_blank"
              rel="noreferrer"
              className="media-icon-btn"
              title="Mở tab mới"
            >
              <ExternalLink size={18} />
            </a>

            {/* Delete button (optional) */}
            {onDelete && (
              <button
                className="media-icon-btn danger"
                onClick={() => {
                  if (confirm('Bạn có chắc muốn xóa phương tiện này?')) {
                    onDelete(currentMedia.id);
                  }
                }}
                title="Xóa phương tiện"
              >
                <Trash2 size={18} />
              </button>
            )}

            {/* Close Button */}
            <button className="media-modal-close-btn" onClick={onClose} title="Đóng (Esc)">
              <X size={22} />
            </button>
          </div>
        </div>

        {/* Main Content Stage */}
        <div className="media-modal-stage">
          {/* Previous Arrow */}
          {mediaList.length > 1 && (
            <button
              className="media-nav-arrow prev"
              onClick={() => onIndexChange((currentIndex - 1 + mediaList.length) % mediaList.length)}
              title="Phương tiện trước (Phím ←)"
            >
              <ChevronLeft size={32} />
            </button>
          )}

          {/* Media Rendering Area */}
          <div className="media-display-area">
            {mediaIsVid ? (
              /* Video Player */
              <div className="video-player-wrapper">
                <video
                  ref={videoRef}
                  src={currentMedia.imageUrl}
                  controls
                  autoPlay
                  playsInline
                  className="main-video-element"
                />
                <div className="video-custom-toolbar">
                  <span className="toolbar-label">Tốc độ phát:</span>
                  {[0.5, 1, 1.25, 1.5, 2].map(speed => (
                    <button
                      key={speed}
                      className={`speed-chip ${playbackSpeed === speed ? 'active' : ''}`}
                      onClick={() => handleSpeedChange(speed)}
                    >
                      {speed}x
                    </button>
                  ))}
                </div>
              </div>
            ) : mediaIsPdf ? (
              /* PDF Embedded Viewer */
              <div className="pdf-preview-wrapper">
                <iframe
                  src={currentMedia.imageUrl}
                  title="Xem tài liệu PDF"
                  className="pdf-preview-iframe"
                />
              </div>
            ) : mediaIsDoc ? (
              /* Non-PDF Document Preview Card */
              <div className="document-preview-card">
                {getDocIcon(currentMedia.imageUrl)}
                <h3 className="doc-card-title">{currentMedia.caption || 'Tài liệu đính kèm'}</h3>
                <p className="doc-card-sub">
                  Tệp đính kèm không thể xem trực tiếp hoặc cần ứng dụng tương thích.
                </p>
                <div className="doc-card-actions">
                  <button className="btn-primary-action" onClick={handleDownload}>
                    <Download size={16} />
                    Tải về tài liệu
                  </button>
                  <a
                    href={currentMedia.imageUrl}
                    target="_blank"
                    rel="noreferrer"
                    className="btn-secondary-action"
                  >
                    <ExternalLink size={16} />
                    Mở liên kết
                  </a>
                </div>
              </div>
            ) : (
              /* Image Lightbox View */
              <div
                className="image-viewer-wrapper"
                onWheel={handleWheel}
                onMouseDown={handleMouseDown}
                onMouseMove={handleMouseMove}
                onMouseUp={handleMouseUp}
                onMouseLeave={handleMouseUp}
                onDoubleClick={handleToggleDoubleZoom}
                style={{ cursor: zoom > 1 ? (isDragging ? 'grabbing' : 'grab') : 'default' }}
              >
                <img
                  src={currentMedia.imageUrl}
                  alt={currentMedia.caption || 'Phương tiện đính kèm'}
                  className="main-lightbox-img"
                  style={{
                    transform: `translate(${position.x}px, ${position.y}px) scale(${zoom}) rotate(${rotation}deg)`,
                    transition: isDragging ? 'none' : 'transform 0.2s ease-out',
                  }}
                  draggable={false}
                />
              </div>
            )}
          </div>

          {/* Next Arrow */}
          {mediaList.length > 1 && (
            <button
              className="media-nav-arrow next"
              onClick={() => onIndexChange((currentIndex + 1) % mediaList.length)}
              title="Phương tiện tiếp theo (Phím →)"
            >
              <ChevronRight size={32} />
            </button>
          )}

          {/* Image Toolbar Floating Bar (Only for Images) */}
          {!mediaIsVid && !mediaIsDoc && (
            <div className="image-toolbar-floating">
              <button className="toolbar-btn" onClick={handleZoomOut} title="Thu nhỏ (-)">
                <ZoomOut size={18} />
              </button>
              <span className="zoom-indicator">{Math.round(zoom * 100)}%</span>
              <button className="toolbar-btn" onClick={handleZoomIn} title="Phóng to (+)">
                <ZoomIn size={18} />
              </button>
              <div className="toolbar-divider" />
              <button className="toolbar-btn" onClick={handleRotate} title="Xoay 90° (R)">
                <RotateCw size={18} />
              </button>
              <button className="toolbar-btn" onClick={resetImageState} title="Đặt lại ảnh">
                <RefreshCw size={18} />
              </button>
            </div>
          )}
        </div>

        {/* Bottom Thumbnails Carousel Bar */}
        {mediaList.length > 1 && (
          <div className="media-carousel-bar">
            {mediaList.map((item, idx) => {
              const itemIsVid = isVideo(item);
              const itemIsDoc = isDocument(item);
              const active = idx === currentIndex;
              return (
                <button
                  key={item.id || idx}
                  className={`carousel-thumb-btn ${active ? 'active' : ''}`}
                  onClick={() => onIndexChange(idx)}
                >
                  {itemIsVid ? (
                    <div className="thumb-video-placeholder">
                      <Play size={14} className="thumb-play-icon" />
                      <video src={item.imageUrl} className="thumb-media" />
                    </div>
                  ) : itemIsDoc ? (
                    <div className="thumb-doc-placeholder">
                      <FileText size={16} />
                    </div>
                  ) : (
                    <img src={item.imageUrl} alt="thumbnail" className="thumb-media" />
                  )}
                  {itemIsVid && <span className="thumb-badge vid">VID</span>}
                  {itemIsDoc && <span className="thumb-badge doc">DOC</span>}
                </button>
              );
            })}
          </div>
        )}

      </div>
    </div>
  );
};
