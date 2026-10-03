import React, { useState, useRef, useEffect, useCallback } from 'react';
import {
  X,
  Check,
  ZoomIn,
  ZoomOut,
  RotateCw,
  RotateCcw,
  Crop as CropIcon,
  Smartphone,
  Sparkles
} from 'lucide-react';
import './ImageCropperModal.css';

export interface CropRatio {
  label: string;
  subLabel: string;
  ratio: number | null; // width / height
  outputWidth: number;
  outputHeight: number;
}

export const CROP_RATIOS: CropRatio[] = [
  { label: '2 : 1', subLabel: 'Chuẩn App (720x360)', ratio: 2 / 1, outputWidth: 1440, outputHeight: 720 },
  { label: '16 : 9', subLabel: 'Màn ảnh rộng', ratio: 16 / 9, outputWidth: 1280, outputHeight: 720 },
  { label: '3 : 2', subLabel: 'Tiêu chuẩn', ratio: 3 / 2, outputWidth: 1200, outputHeight: 800 },
  { label: '1 : 1', subLabel: 'Vuông', ratio: 1 / 1, outputWidth: 800, outputHeight: 800 },
];

interface ImageCropperModalProps {
  isOpen: boolean;
  imageSrc: string;
  fileName?: string;
  onClose: () => void;
  onCropComplete: (croppedFile: File, previewUrl: string) => void;
}

export const ImageCropperModal: React.FC<ImageCropperModalProps> = ({
  isOpen,
  imageSrc,
  fileName = 'banner.jpg',
  onClose,
  onCropComplete,
}) => {
  const [selectedRatio, setSelectedRatio] = useState<CropRatio>(CROP_RATIOS[0]);
  const [zoom, setZoom] = useState<number>(1);
  const [rotation, setRotation] = useState<number>(0); // 0, 90, 180, 270
  const [pan, setPan] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState<boolean>(false);
  const [dragStart, setDragStart] = useState<{ x: number; y: number }>({ x: 0, y: 0 });
  const [imgNaturalSize, setImgNaturalSize] = useState<{ width: number; height: number }>({ width: 0, height: 0 });
  const [imageLoaded, setImageLoaded] = useState<boolean>(false);

  const containerRef = useRef<HTMLDivElement>(null);
  const imgRef = useRef<HTMLImageElement>(null);
  const previewCanvasRef = useRef<HTMLCanvasElement>(null);

  // Viewport and Crop Frame calculations
  // Max frame inside viewport: 500px width x 260px height
  const getCropFrameSize = useCallback((ratio: CropRatio) => {
    const maxW = 480;
    const maxH = 260;
    if (!ratio.ratio) return { width: maxW, height: maxH };

    if (maxW / maxH > ratio.ratio) {
      // Height is constraint
      const height = maxH;
      const width = Math.round(height * ratio.ratio);
      return { width, height };
    } else {
      // Width is constraint
      const width = maxW;
      const height = Math.round(width / ratio.ratio);
      return { width, height };
    }
  }, []);

  const cropFrame = getCropFrameSize(selectedRatio);

  // Compute base scale so image covers the crop frame at zoom = 1
  const getBaseScale = useCallback(() => {
    if (!imgNaturalSize.width || !imgNaturalSize.height) return 1;
    const isRotated90or270 = rotation % 180 !== 0;
    const effectiveW = isRotated90or270 ? imgNaturalSize.height : imgNaturalSize.width;
    const effectiveH = isRotated90or270 ? imgNaturalSize.width : imgNaturalSize.height;

    const scaleX = cropFrame.width / effectiveW;
    const scaleY = cropFrame.height / effectiveH;
    return Math.max(scaleX, scaleY);
  }, [imgNaturalSize, rotation, cropFrame]);

  // Load natural image size
  useEffect(() => {
    if (!imageSrc) return;
    const img = new Image();
    img.src = imageSrc;
    img.onload = () => {
      setImgNaturalSize({ width: img.naturalWidth, height: img.naturalHeight });
      setImageLoaded(true);
      setZoom(1);
      setPan({ x: 0, y: 0 });
      setRotation(0);
    };
  }, [imageSrc]);

  // Mouse / Touch Drag handlers
  const handleMouseDown = (e: React.MouseEvent) => {
    e.preventDefault();
    setIsDragging(true);
    setDragStart({ x: e.clientX - pan.x, y: e.clientY - pan.y });
  };

  const handleMouseMove = useCallback((e: MouseEvent) => {
    if (!isDragging) return;
    setPan({
      x: e.clientX - dragStart.x,
      y: e.clientY - dragStart.y,
    });
  }, [isDragging, dragStart]);

  const handleMouseUp = useCallback(() => {
    setIsDragging(false);
  }, []);

  // Touch handlers for mobile/tablet admin
  const handleTouchStart = (e: React.TouchEvent) => {
    if (e.touches.length === 1) {
      setIsDragging(true);
      setDragStart({
        x: e.touches[0].clientX - pan.x,
        y: e.touches[0].clientY - pan.y,
      });
    }
  };

  const handleTouchMove = useCallback((e: TouchEvent) => {
    if (!isDragging || e.touches.length !== 1) return;
    setPan({
      x: e.touches[0].clientX - dragStart.x,
      y: e.touches[0].clientY - dragStart.y,
    });
  }, [isDragging, dragStart]);

  const handleTouchEnd = useCallback(() => {
    setIsDragging(false);
  }, []);

  useEffect(() => {
    if (isDragging) {
      window.addEventListener('mousemove', handleMouseMove);
      window.addEventListener('mouseup', handleMouseUp);
      window.addEventListener('touchmove', handleTouchMove);
      window.addEventListener('touchend', handleTouchEnd);
    }
    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
      window.removeEventListener('touchmove', handleTouchMove);
      window.removeEventListener('touchend', handleTouchEnd);
    };
  }, [isDragging, handleMouseMove, handleMouseUp, handleTouchMove, handleTouchEnd]);

  // Wheel zoom
  const handleWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    const delta = e.deltaY < 0 ? 0.1 : -0.1;
    setZoom(prev => Math.min(3, Math.max(1, +(prev + delta).toFixed(2))));
  };

  // Render Real-time Cropped Preview on Mini Canvas
  useEffect(() => {
    if (!imageLoaded || !imgRef.current || !previewCanvasRef.current) return;
    const canvas = previewCanvasRef.current;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const baseScale = getBaseScale();
    const totalScale = baseScale * zoom;

    const targetW = canvas.width;
    const targetH = canvas.height;
    ctx.clearRect(0, 0, targetW, targetH);

    ctx.save();
    // Scale from crop frame coordinate system to mini preview canvas
    const multiplier = targetW / cropFrame.width;
    ctx.scale(multiplier, multiplier);

    ctx.translate(cropFrame.width / 2 + pan.x, cropFrame.height / 2 + pan.y);
    ctx.rotate((rotation * Math.PI) / 180);
    ctx.scale(totalScale, totalScale);

    ctx.drawImage(
      imgRef.current,
      -imgNaturalSize.width / 2,
      -imgNaturalSize.height / 2
    );
    ctx.restore();
  }, [imageLoaded, cropFrame, pan, zoom, rotation, imgNaturalSize, getBaseScale]);

  // Rotate 90 degrees clockwise
  const handleRotate = () => {
    setRotation(prev => (prev + 90) % 360);
    setPan({ x: 0, y: 0 });
  };

  // Reset to center
  const handleReset = () => {
    setZoom(1);
    setPan({ x: 0, y: 0 });
    setRotation(0);
  };

  // Confirm and Crop image into File object
  const handleConfirmCrop = () => {
    if (!imgRef.current) return;

    const outputW = selectedRatio.outputWidth;
    const outputH = selectedRatio.outputHeight;

    const offscreenCanvas = document.createElement('canvas');
    offscreenCanvas.width = outputW;
    offscreenCanvas.height = outputH;
    const ctx = offscreenCanvas.getContext('2d');
    if (!ctx) return;

    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';

    const baseScale = getBaseScale();
    const totalScale = baseScale * zoom;

    ctx.save();
    const multiplier = outputW / cropFrame.width;
    ctx.scale(multiplier, multiplier);

    ctx.translate(cropFrame.width / 2 + pan.x, cropFrame.height / 2 + pan.y);
    ctx.rotate((rotation * Math.PI) / 180);
    ctx.scale(totalScale, totalScale);

    ctx.drawImage(
      imgRef.current,
      -imgNaturalSize.width / 2,
      -imgNaturalSize.height / 2
    );
    ctx.restore();

    // Export as high quality JPEG blob
    offscreenCanvas.toBlob(
      blob => {
        if (!blob) return;
        const cleanName = fileName.replace(/\.[^/.]+$/, '') + '-cropped.jpg';
        const file = new File([blob], cleanName, { type: 'image/jpeg' });
        const previewUrl = URL.createObjectURL(blob);
        onCropComplete(file, previewUrl);
        onClose();
      },
      'image/jpeg',
      0.92
    );
  };

  if (!isOpen) return null;

  const baseScale = getBaseScale();
  const currentRenderScale = baseScale * zoom;

  return (
    <div className="image-cropper-overlay" onClick={onClose}>
      <div className="image-cropper-modal" onClick={e => e.stopPropagation()}>
        {/* Modal Header */}
        <div className="cropper-modal-header">
          <div className="cropper-title-group">
            <div className="cropper-icon-box">
              <CropIcon size={20} color="#2563eb" />
            </div>
            <div>
              <h3>Cắt & Tối Ưu Hóa Banner Ứng Dụng</h3>
              <p className="cropper-subtitle">
                Điều chỉnh vị trí, tỉ lệ và phóng to để vừa vặn khung hiển thị banner trên ứng dụng di động
              </p>
            </div>
          </div>
          <button type="button" className="cropper-close-btn" onClick={onClose} title="Đóng">
            <X size={20} />
          </button>
        </div>

        {/* Modal Body */}
        <div className="cropper-modal-body">
          {/* Main Visual Crop Viewport */}
          <div className="cropper-main-stage">
            <div
              className="cropper-viewport-container"
              ref={containerRef}
              onWheel={handleWheel}
              onMouseDown={handleMouseDown}
              onTouchStart={handleTouchStart}
              style={{ cursor: isDragging ? 'grabbing' : 'grab' }}
            >
              {/* Crop Aperture with Rounded Corners & Thirds Grid */}
              <div
                className="cropper-aperture"
                style={{
                  width: `${cropFrame.width}px`,
                  height: `${cropFrame.height}px`,
                }}
              >
                {/* The Transformed Image */}
                <img
                  ref={imgRef}
                  src={imageSrc}
                  alt="Source for cropping"
                  className="cropper-source-image"
                  style={{
                    transform: `translate(calc(-50% + ${pan.x}px), calc(-50% + ${pan.y}px)) rotate(${rotation}deg) scale(${currentRenderScale})`,
                  }}
                  draggable={false}
                />

                {/* Rule of Thirds Grid Overlay */}
                <div className="cropper-grid-overlay">
                  <div className="grid-line vertical line-1" />
                  <div className="grid-line vertical line-2" />
                  <div className="grid-line horizontal line-1" />
                  <div className="grid-line horizontal line-2" />
                </div>

                {/* 4 Corner Markers */}
                <div className="corner-bracket top-left" />
                <div className="corner-bracket top-right" />
                <div className="corner-bracket bottom-left" />
                <div className="corner-bracket bottom-right" />

                {/* App Aspect Tag */}
                <div className="cropper-frame-badge">
                  <span>{selectedRatio.label} • {selectedRatio.subLabel}</span>
                </div>
              </div>

              {/* Drag Hint Overlay */}
              <div className="cropper-drag-hint">
                <span>Kéo ảnh để căn chỉnh vị trí • Cuộn chuột để phóng to/thu nhỏ</span>
              </div>
            </div>

            {/* Controls Toolbar: Ratios, Zoom, Rotate, Reset */}
            <div className="cropper-toolbar">
              {/* Aspect Ratio Pills */}
              <div className="toolbar-section">
                <span className="toolbar-label">Tỉ lệ cắt:</span>
                <div className="ratio-pills-row">
                  {CROP_RATIOS.map((item, idx) => (
                    <button
                      key={idx}
                      type="button"
                      className={`ratio-pill-btn ${selectedRatio.label === item.label ? 'active' : ''}`}
                      onClick={() => {
                        setSelectedRatio(item);
                        setPan({ x: 0, y: 0 });
                      }}
                    >
                      <span>{item.label}</span>
                      <small>{item.subLabel.split(' ')[0]}</small>
                    </button>
                  ))}
                </div>
              </div>

              {/* Zoom Slider */}
              <div className="toolbar-section">
                <span className="toolbar-label">Thu / Phóng:</span>
                <div className="zoom-slider-wrapper">
                  <button
                    type="button"
                    className="zoom-btn"
                    onClick={() => setZoom(prev => Math.max(1, +(prev - 0.15).toFixed(2)))}
                    title="Thu nhỏ"
                  >
                    <ZoomOut size={15} />
                  </button>
                  <input
                    type="range"
                    min="1"
                    max="3"
                    step="0.05"
                    value={zoom}
                    onChange={e => setZoom(parseFloat(e.target.value))}
                    className="zoom-slider"
                  />
                  <button
                    type="button"
                    className="zoom-btn"
                    onClick={() => setZoom(prev => Math.min(3, +(prev + 0.15).toFixed(2)))}
                    title="Phóng to"
                  >
                    <ZoomIn size={15} />
                  </button>
                  <span className="zoom-value">{Math.round(zoom * 100)}%</span>
                </div>
              </div>

              {/* Rotate & Reset Buttons */}
              <div className="toolbar-section actions-row">
                <button
                  type="button"
                  className="cropper-tool-btn"
                  onClick={handleRotate}
                  title="Xoay 90 độ"
                >
                  <RotateCw size={14} />
                  <span>Xoay 90°</span>
                </button>
                <button
                  type="button"
                  className="cropper-tool-btn"
                  onClick={handleReset}
                  title="Căn giữa & Đặt lại"
                >
                  <RotateCcw size={14} />
                  <span>Đặt lại</span>
                </button>
              </div>
            </div>
          </div>

          {/* Right Panel: Live Mobile App Banner Preview */}
          <div className="cropper-side-preview">
            <div className="preview-panel-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <Smartphone size={16} color="#2563eb" />
                <span style={{ fontSize: '13px', fontWeight: 700, color: '#1e293b' }}>
                  Mô phỏng hiển thị trên App
                </span>
              </div>
              <span className="preview-live-badge">
                <Sparkles size={11} />
                Live
              </span>
            </div>

            <p style={{ fontSize: '11.5px', color: '#64748b', margin: '0 0 12px 0' }}>
              Ảnh sau khi cắt sẽ được bo góc 20px, vừa vặn tuyệt đối với kích thước banner của ứng dụng.
            </p>

            {/* Mobile Mockup Card */}
            <div className="mobile-mockup-wrapper">
              <div className="mobile-mockup-topbar">
                <span className="mockup-time">9:41</span>
                <div className="mockup-icons">
                  <span className="mockup-bar" />
                  <span className="mockup-wifi" />
                  <span className="mockup-battery" />
                </div>
              </div>

              {/* The Cropped Banner Mockup Card */}
              <div className="mockup-banner-card">
                <canvas
                  ref={previewCanvasRef}
                  width={340}
                  height={170}
                  className="mockup-banner-canvas"
                />

                {/* Sample App Banner Overlay Elements */}
                <div className="mockup-banner-overlay">
                  <div className="mockup-badge">⚡ ƯU ĐÃI ĐẶC BIỆT</div>
                  <div className="mockup-title">Banner Ứng Dụng</div>
                  <div className="mockup-btn">
                    <span>Xem ngay</span>
                  </div>
                </div>
              </div>

              <div className="mockup-meta-info">
                <div>
                  <span className="meta-label">Kích thước ảnh gốc:</span>
                  <span className="meta-val">{imgNaturalSize.width} × {imgNaturalSize.height} px</span>
                </div>
                <div>
                  <span className="meta-label">Độ phân giải cắt xuất:</span>
                  <span className="meta-val" style={{ color: '#2563eb', fontWeight: 600 }}>
                    {selectedRatio.outputWidth} × {selectedRatio.outputHeight} px
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Modal Footer */}
        <div className="cropper-modal-footer">
          <div className="footer-info-text">
            <span>💡 Mẹo: Dùng chuột kéo ảnh hoặc dùng thanh trượt phóng to để chọn góc ảnh đẹp nhất.</span>
          </div>
          <div className="footer-buttons">
            <button type="button" className="btn-secondary" onClick={onClose}>
              Hủy bỏ
            </button>
            <button
              type="button"
              className="btn-primary"
              onClick={handleConfirmCrop}
              disabled={!imageLoaded}
            >
              <Check size={16} />
              <span>Áp dụng ảnh đã cắt cho Banner</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
