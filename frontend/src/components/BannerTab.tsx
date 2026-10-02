import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  Plus,
  RefreshCw,
  ArrowUp,
  ArrowDown,
  Edit,
  Trash2,
  Eye,
  EyeOff,
  Smartphone,
  Sparkles,
  CheckCircle2,
  X,
  ChevronLeft,
  ChevronRight,
  UploadCloud,
  Search,
  Check,
  Palette,
  Layers,
  Phone,
  ExternalLink,
  ImageIcon,
  Move
} from 'lucide-react';
import { getAuthHeaders } from '../utils/auth';
import type { UserInfo } from '../mockData';
import './BannerTab.css';

export interface BannerButton {
  text: string;
  actionType: 'BOOKING' | 'REPAIR_ORDER' | 'LINK' | 'SCREEN' | 'CALL' | 'NONE';
  actionValue?: string;
  styleType: 'PRIMARY' | 'SECONDARY' | 'OUTLINE';
}

export interface AppBanner {
  id: string;
  title: string;
  badgeText?: string;
  subtitle?: string;
  buttonText?: string;
  actionType: 'BOOKING' | 'REPAIR_ORDER' | 'LINK' | 'SCREEN' | 'CALL' | 'NONE';
  actionValue?: string;
  buttonPosition?: 'BOTTOM_LEFT' | 'BOTTOM_CENTER' | 'BOTTOM_RIGHT' | 'TOP_RIGHT';
  buttons?: BannerButton[];
  buttonsJson?: string;
  imageUrl?: string;
  backgroundImageUrl?: string;
  gradientColors: string;
  displayOrder: number;
  isActive: boolean;
  startDate?: string | null;
  endDate?: string | null;
  createdAt: string;
  updatedAt: string;
}

interface BannerTabProps {
  showToast: (message: string) => void;
  currentUser: UserInfo | null;
}

const GRADIENT_PRESETS = [
  {
    name: 'Xanh công nghệ (Mặc định)',
    value: '#2563EB,#4F46E5,#1D4ED8',
    preview: 'linear-gradient(135deg, #2563EB, #4F46E5, #1D4ED8)',
  },
  {
    name: 'Tím Indigo Huyền Bí',
    value: '#7C3AED,#9333EA,#4F46E5',
    preview: 'linear-gradient(135deg, #7C3AED, #9333EA, #4F46E5)',
  },
  {
    name: 'Xanh Lục Emerald',
    value: '#059669,#10B981,#047857',
    preview: 'linear-gradient(135deg, #059669, #10B981, #047857)',
  },
  {
    name: 'Cam Hoàng Hôn Năng Động',
    value: '#EA580C,#F59E0B,#C2410C',
    preview: 'linear-gradient(135deg, #EA580C, #F59E0B, #C2410C)',
  },
  {
    name: 'Đỏ Hồng Nổi Bật',
    value: '#E11D48,#F43F5E,#BE123C',
    preview: 'linear-gradient(135deg, #E11D48, #F43F5E, #BE123C)',
  },
  {
    name: 'Xanh Cyan Đại Dương',
    value: '#0891B2,#06B6D4,#0E7490',
    preview: 'linear-gradient(135deg, #0891B2, #06B6D4, #0E7490)',
  },
  {
    name: 'Vàng Gold Sang Trọng',
    value: '#D97706,#F59E0B,#B45309',
    preview: 'linear-gradient(135deg, #D97706, #F59E0B, #B45309)',
  },
  {
    name: 'Đen Graphite Huyền Thoại',
    value: '#1E293B,#334155,#0F172A',
    preview: 'linear-gradient(135deg, #1E293B, #334155, #0F172A)',
  },
];

export const BannerTab: React.FC<BannerTabProps> = ({ showToast }) => {
  const [banners, setBanners] = useState<AppBanner[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [refreshing, setRefreshing] = useState<boolean>(false);
  const [filterStatus, setFilterStatus] = useState<'ALL' | 'ACTIVE' | 'INACTIVE'>('ALL');
  const [searchTerm, setSearchTerm] = useState<string>('');

  // Simulator active index
  const [activePreviewIndex, setActivePreviewIndex] = useState<number>(0);

  // Modal State
  const [showModal, setShowModal] = useState<boolean>(false);
  const [editingBanner, setEditingBanner] = useState<AppBanner | null>(null);
  const [submitting, setSubmitting] = useState<boolean>(false);

  // Form Fields - Content
  const [formTitle, setFormTitle] = useState<string>('Bảo Trì & Sửa Chữa Inverter');
  const [formBadgeText, setFormBadgeText] = useState<string>('⚡ ƯU ĐÃI ĐẶC BIỆT');
  const [formSubtitle, setFormSubtitle] = useState<string>('Giảm ngay 25% GIÁ TRỊ cho lượt đặt dịch vụ đầu tiên!');

  // Form Fields - Buttons & Position
  const [formButtonPosition, setFormButtonPosition] = useState<'BOTTOM_LEFT' | 'BOTTOM_CENTER' | 'BOTTOM_RIGHT' | 'TOP_RIGHT'>('BOTTOM_LEFT');
  const [formButtons, setFormButtons] = useState<BannerButton[]>([
    {
      text: 'Đặt lịch ngay',
      actionType: 'BOOKING',
      actionValue: 'Gói bảo trì ưu đãi 25%',
      styleType: 'PRIMARY',
    },
  ]);

  // Form Fields - Colors & Background
  const [bgMode, setBgMode] = useState<'GRADIENT' | 'CUSTOM_BG'>('GRADIENT');
  const [formGradient, setFormGradient] = useState<string>('#2563EB,#4F46E5,#1D4ED8');
  const [formCustomGradient, setFormCustomGradient] = useState<string>('');
  const [colorStop1, setColorStop1] = useState<string>('#2563EB');
  const [colorStop2, setColorStop2] = useState<string>('#4F46E5');
  const [colorStop3, setColorStop3] = useState<string>('#1D4ED8');

  // Custom Background Upload
  const [formBackgroundImageUrl, setFormBackgroundImageUrl] = useState<string>('');
  const [selectedBgFile, setSelectedBgFile] = useState<File | null>(null);
  const [bgFilePreviewUrl, setBgFilePreviewUrl] = useState<string | null>(null);

  // Display Order & Active
  const [formDisplayOrder, setFormDisplayOrder] = useState<number>(1);
  const [formIsActive, setFormIsActive] = useState<boolean>(true);

  // Mascot Image handling
  const [imageType, setImageType] = useState<'default' | 'upload' | 'url'>('default');
  const [formImageUrl, setFormImageUrl] = useState<string>('');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [filePreviewUrl, setFilePreviewUrl] = useState<string | null>(null);

  // Fetch Banners from Backend
  const fetchBanners = useCallback(async (isRefresh = false) => {
    if (isRefresh) setRefreshing(true);
    else setLoading(true);

    try {
      const response = await fetch('/api/v1/banners/all', {
        headers: getAuthHeaders(),
      });

      if (response.ok) {
        const result = await response.json();
        if (result?.data) {
          setBanners(result.data);
        }
      } else {
        const activeRes = await fetch('/api/v1/banners');
        if (activeRes.ok) {
          const actResult = await activeRes.json();
          if (actResult?.data) setBanners(actResult.data);
        } else {
          showToast('Không thể tải danh sách banner.');
        }
      }
    } catch (err) {
      console.error('Lỗi khi tải banners:', err);
      showToast('Lỗi kết nối tới máy chủ khi tải danh sách banner.');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, [showToast]);

  useEffect(() => {
    fetchBanners();
  }, [fetchBanners]);

  // Active banners for simulator
  const activeBanners = useMemo(() => {
    return banners.filter(b => b.isActive);
  }, [banners]);

  // Adjust preview index if active banners list changes
  useEffect(() => {
    if (activePreviewIndex >= activeBanners.length && activeBanners.length > 0) {
      setActivePreviewIndex(activeBanners.length - 1);
    }
  }, [activeBanners.length, activePreviewIndex]);

  // Filtered banners for the list
  const filteredBanners = useMemo(() => {
    return banners.filter(b => {
      const matchesStatus =
        filterStatus === 'ALL' ? true : filterStatus === 'ACTIVE' ? b.isActive : !b.isActive;
      const matchesSearch =
        searchTerm.trim() === '' ||
        b.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
        (b.badgeText && b.badgeText.toLowerCase().includes(searchTerm.toLowerCase())) ||
        (b.subtitle && b.subtitle.toLowerCase().includes(searchTerm.toLowerCase()));
      return matchesStatus && matchesSearch;
    });
  }, [banners, filterStatus, searchTerm]);

  // Helpers to parse CSS linear gradient
  const getGradientStyle = (gradientStr: string) => {
    if (!gradientStr) return 'linear-gradient(135deg, #2563EB, #4F46E5, #1D4ED8)';
    const colors = gradientStr.split(',').map(c => c.trim()).filter(Boolean);
    if (colors.length === 1) return colors[0];
    return `linear-gradient(135deg, ${colors.join(', ')})`;
  };

  // Helper to compute banner background style
  const getBannerBackgroundStyle = (banner: {
    gradientColors?: string;
    backgroundImageUrl?: string;
  }, previewBgUrl?: string | null) => {
    const bgUrl = previewBgUrl || banner.backgroundImageUrl;
    if (bgUrl) {
      return `linear-gradient(rgba(15, 23, 42, 0.3), rgba(15, 23, 42, 0.45)), url(${bgUrl}) center / cover no-repeat`;
    }
    return getGradientStyle(banner.gradientColors || '#2563EB,#4F46E5,#1D4ED8');
  };

  // Helper to extract buttons from banner (with fallback)
  const getBannerButtons = (banner: AppBanner): BannerButton[] => {
    if (banner.buttons && banner.buttons.length > 0) {
      return banner.buttons;
    }
    if (banner.buttonsJson) {
      try {
        const parsed = JSON.parse(banner.buttonsJson);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      } catch (_) {}
    }
    return [
      {
        text: banner.buttonText || 'Đặt lịch ngay',
        actionType: banner.actionType || 'BOOKING',
        actionValue: banner.actionValue,
        styleType: 'PRIMARY',
      },
    ];
  };

  // Update 3 color stops and gradient string
  const handleColorStopChange = (index: 1 | 2 | 3, value: string) => {
    let s1 = colorStop1;
    let s2 = colorStop2;
    let s3 = colorStop3;
    if (index === 1) {
      s1 = value;
      setColorStop1(value);
    } else if (index === 2) {
      s2 = value;
      setColorStop2(value);
    } else {
      s3 = value;
      setColorStop3(value);
    }
    const combined = `${s1},${s2},${s3}`;
    setFormCustomGradient(combined);
  };

  // Open Create Modal
  const handleOpenCreateModal = () => {
    setEditingBanner(null);
    setFormTitle('');
    setFormBadgeText('⚡ ƯU ĐÃI ĐẶC BIỆT');
    setFormSubtitle('');
    setFormButtonPosition('BOTTOM_LEFT');
    setFormButtons([
      {
        text: 'Đặt lịch ngay',
        actionType: 'BOOKING',
        actionValue: 'Gói bảo trì ưu đãi 25%',
        styleType: 'PRIMARY',
      },
    ]);
    setBgMode('GRADIENT');
    setFormGradient('#2563EB,#4F46E5,#1D4ED8');
    setFormCustomGradient('');
    setColorStop1('#2563EB');
    setColorStop2('#4F46E5');
    setColorStop3('#1D4ED8');
    setFormBackgroundImageUrl('');
    setSelectedBgFile(null);
    setBgFilePreviewUrl(null);
    setFormDisplayOrder(banners.length + 1);
    setFormIsActive(true);
    setImageType('default');
    setFormImageUrl('');
    setSelectedFile(null);
    setFilePreviewUrl(null);
    setShowModal(true);
  };

  // Open Edit Modal
  const handleOpenEditModal = (banner: AppBanner) => {
    setEditingBanner(banner);
    setFormTitle(banner.title);
    setFormBadgeText(banner.badgeText || '');
    setFormSubtitle(banner.subtitle || '');
    setFormButtonPosition(banner.buttonPosition || 'BOTTOM_LEFT');
    setFormButtons(getBannerButtons(banner));

    // Gradient or Custom Background
    if (banner.backgroundImageUrl) {
      setBgMode('CUSTOM_BG');
      setFormBackgroundImageUrl(banner.backgroundImageUrl);
    } else {
      setBgMode('GRADIENT');
      setFormBackgroundImageUrl('');
    }
    setSelectedBgFile(null);
    setBgFilePreviewUrl(null);

    setFormGradient(banner.gradientColors || '#2563EB,#4F46E5,#1D4ED8');
    const isPreset = GRADIENT_PRESETS.some(p => p.value === banner.gradientColors);
    setFormCustomGradient(isPreset ? '' : banner.gradientColors);

    // Parse stops if available
    const stops = (banner.gradientColors || '#2563EB,#4F46E5,#1D4ED8').split(',');
    if (stops.length >= 3) {
      setColorStop1(stops[0].trim());
      setColorStop2(stops[1].trim());
      setColorStop3(stops[2].trim());
    } else if (stops.length === 2) {
      setColorStop1(stops[0].trim());
      setColorStop2(stops[1].trim());
      setColorStop3(stops[1].trim());
    }

    setFormDisplayOrder(banner.displayOrder);
    setFormIsActive(banner.isActive);

    // Mascot
    if (!banner.imageUrl) {
      setImageType('default');
      setFormImageUrl('');
    } else if (banner.imageUrl.startsWith('/api/v1/banners/images/')) {
      setImageType('upload');
      setFormImageUrl(banner.imageUrl);
    } else {
      setImageType('url');
      setFormImageUrl(banner.imageUrl);
    }

    setSelectedFile(null);
    setFilePreviewUrl(null);
    setShowModal(true);
  };

  // Button management handlers
  const handleAddButton = () => {
    if (formButtons.length >= 3) {
      showToast('Tối đa 3 nút bấm trên banner để đảm bảo thẩm mỹ tối ưu.');
      return;
    }
    setFormButtons(prev => [
      ...prev,
      {
        text: 'Hotline tư vấn',
        actionType: 'CALL',
        actionValue: '0901234567',
        styleType: prev.length === 0 ? 'PRIMARY' : 'SECONDARY',
      },
    ]);
  };

  const handleRemoveButton = (idx: number) => {
    if (formButtons.length <= 1) {
      showToast('Banner cần có ít nhất 1 nút bấm hành động.');
      return;
    }
    setFormButtons(prev => prev.filter((_, i) => i !== idx));
  };

  const handleUpdateButton = (idx: number, field: keyof BannerButton, value: any) => {
    setFormButtons(prev =>
      prev.map((btn, i) => (i === idx ? { ...btn, [field]: value } : btn))
    );
  };

  // Handle Mascot File change
  const handleMascotFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setSelectedFile(file);
      setFilePreviewUrl(URL.createObjectURL(file));
    }
  };

  // Handle Custom Background File change
  const handleBgFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setSelectedBgFile(file);
      setBgFilePreviewUrl(URL.createObjectURL(file));
    }
  };

  // Toggle Active
  const handleToggleActive = async (banner: AppBanner) => {
    try {
      const res = await fetch(`/api/v1/banners/${banner.id}/toggle-active`, {
        method: 'PATCH',
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        showToast(
          banner.isActive
            ? `Đã ẩn banner "${banner.title}"`
            : `Đã kích hoạt banner "${banner.title}" trên App`
        );
        fetchBanners(true);
      } else {
        showToast('Không thể thay đổi trạng thái banner.');
      }
    } catch {
      showToast('Lỗi kết nối khi cập nhật banner.');
    }
  };

  // Reorder Banners
  const handleMove = async (index: number, direction: 'UP' | 'DOWN') => {
    const targetIndex = direction === 'UP' ? index - 1 : index + 1;
    if (targetIndex < 0 || targetIndex >= banners.length) return;

    const reordered = [...banners];
    const [moved] = reordered.splice(index, 1);
    reordered.splice(targetIndex, 0, moved);

    setBanners(reordered);

    try {
      const bannerIds = reordered.map(b => b.id);
      const res = await fetch('/api/v1/banners/reorder', {
        method: 'PATCH',
        headers: {
          ...getAuthHeaders(),
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ bannerIds }),
      });
      if (res.ok) {
        showToast('Đã lưu thứ tự hiển thị banner.');
        fetchBanners(true);
      } else {
        showToast('Không thể lưu thứ tự hiển thị.');
        fetchBanners();
      }
    } catch {
      showToast('Lỗi kết nối khi sắp xếp banner.');
      fetchBanners();
    }
  };

  // Delete Banner
  const handleDelete = async (banner: AppBanner) => {
    if (!window.confirm(`Bạn có chắc chắn muốn xóa banner "${banner.title}"?`)) {
      return;
    }

    try {
      const res = await fetch(`/api/v1/banners/${banner.id}`, {
        method: 'DELETE',
        headers: getAuthHeaders(),
      });
      if (res.ok) {
        showToast(`Đã xóa banner "${banner.title}".`);
        fetchBanners(true);
      } else {
        showToast('Không thể xóa banner.');
      }
    } catch {
      showToast('Lỗi kết nối khi xóa banner.');
    }
  };

  // Submit Form (Create / Update)
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formTitle.trim()) {
      showToast('Vui lòng nhập tiêu đề banner.');
      return;
    }
    if (formButtons.length === 0 || !formButtons[0].text.trim()) {
      showToast('Vui lòng nhập văn bản cho ít nhất một nút bấm.');
      return;
    }

    setSubmitting(true);
    const finalGradient = formCustomGradient.trim() || formGradient;
    const firstBtn = formButtons[0];

    try {
      if (selectedFile || selectedBgFile) {
        // Multipart upload
        const formData = new FormData();
        formData.append('title', formTitle.trim());
        formData.append('badgeText', formBadgeText.trim());
        formData.append('subtitle', formSubtitle.trim());
        formData.append('buttonText', firstBtn.text.trim());
        formData.append('actionType', firstBtn.actionType);
        formData.append('actionValue', (firstBtn.actionValue || '').trim());
        formData.append('buttonPosition', formButtonPosition);
        formData.append('buttonsJson', JSON.stringify(formButtons));
        formData.append('gradientColors', finalGradient);
        formData.append('displayOrder', String(formDisplayOrder));
        formData.append('isActive', String(formIsActive));

        if (selectedFile) {
          formData.append('image', selectedFile);
        }
        if (selectedBgFile) {
          formData.append('bgImage', selectedBgFile);
        } else if (bgMode === 'CUSTOM_BG' && formBackgroundImageUrl.trim()) {
          formData.append('backgroundImageUrl', formBackgroundImageUrl.trim());
        }

        const url = editingBanner ? `/api/v1/banners/${editingBanner.id}` : '/api/v1/banners';
        const method = editingBanner ? 'PUT' : 'POST';

        const res = await fetch(url, {
          method,
          headers: getAuthHeaders(),
          body: formData,
        });

        if (res.ok) {
          showToast(editingBanner ? 'Cập nhật banner thành công!' : 'Tạo mới banner thành công!');
          setShowModal(false);
          fetchBanners(true);
        } else {
          showToast('Có lỗi xảy ra khi lưu banner.');
        }
      } else {
        // JSON upload
        const payload = {
          title: formTitle.trim(),
          badgeText: formBadgeText.trim(),
          subtitle: formSubtitle.trim(),
          buttonText: firstBtn.text.trim(),
          actionType: firstBtn.actionType,
          actionValue: (firstBtn.actionValue || '').trim(),
          buttonPosition: formButtonPosition,
          buttonsJson: JSON.stringify(formButtons),
          buttons: formButtons,
          imageUrl: imageType === 'default' ? null : formImageUrl.trim() || null,
          backgroundImageUrl: bgMode === 'CUSTOM_BG' ? formBackgroundImageUrl.trim() || null : null,
          gradientColors: finalGradient,
          displayOrder: formDisplayOrder,
          isActive: formIsActive,
        };

        const url = editingBanner ? `/api/v1/banners/${editingBanner.id}` : '/api/v1/banners';
        const method = editingBanner ? 'PUT' : 'POST';

        const res = await fetch(url, {
          method,
          headers: {
            ...getAuthHeaders(),
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(payload),
        });

        if (res.ok) {
          showToast(editingBanner ? 'Cập nhật banner thành công!' : 'Tạo mới banner thành công!');
          setShowModal(false);
          fetchBanners(true);
        } else {
          showToast('Có lỗi xảy ra khi lưu banner.');
        }
      }
    } catch (err) {
      console.error('Lỗi lưu banner:', err);
      showToast('Lỗi kết nối khi lưu banner.');
    } finally {
      setSubmitting(false);
    }
  };

  // Helper to render banner buttons inside any preview container
  const renderBannerButtonsGroup = (
    btns: BannerButton[],
    position: string = 'BOTTOM_LEFT',
    isSmall = false
  ) => {
    const posClass =
      position === 'BOTTOM_CENTER'
        ? 'pos-bottom-center'
        : position === 'BOTTOM_RIGHT'
        ? 'pos-bottom-right'
        : position === 'TOP_RIGHT'
        ? 'pos-top-right'
        : 'pos-bottom-left';

    return (
      <div className={`stitch-banner-buttons-group ${posClass}`}>
        {btns.map((btn, bIdx) => {
          const styleClass =
            btn.styleType === 'SECONDARY'
              ? 'secondary'
              : btn.styleType === 'OUTLINE'
              ? 'outline'
              : '';

          return (
            <div
              key={bIdx}
              className={`stitch-banner-cta-btn ${styleClass}`}
              style={
                isSmall
                  ? { padding: '4px 10px', fontSize: '10.5px' }
                  : undefined
              }
              onClick={e => {
                e.stopPropagation();
                showToast(
                  `Thao tác: ${btn.actionType} - ${btn.actionValue || 'Mặc định'}`
                );
              }}
            >
              <span>{btn.text || 'Bấm vào đây'}</span>
              {btn.actionType === 'CALL' ? (
                <Phone size={isSmall ? 10 : 12} />
              ) : btn.actionType === 'LINK' ? (
                <ExternalLink size={isSmall ? 10 : 12} />
              ) : (
                <ChevronRight size={isSmall ? 11 : 13} />
              )}
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div className="banner-container">
      {/* 1. Header & Stats Grid */}
      <div className="banner-stats-grid">
        <div className="banner-stat-card">
          <div className="banner-stat-icon total">
            <Sparkles size={24} />
          </div>
          <div className="banner-stat-info">
            <span className="banner-stat-label">Tổng số banner</span>
            <span className="banner-stat-val">{banners.length}</span>
          </div>
        </div>

        <div className="banner-stat-card">
          <div className="banner-stat-icon active">
            <Eye size={24} />
          </div>
          <div className="banner-stat-info">
            <span className="banner-stat-label">Đang hiển thị trên App</span>
            <span className="banner-stat-val">
              {banners.filter(b => b.isActive).length}
            </span>
          </div>
        </div>

        <div className="banner-stat-card">
          <div className="banner-stat-icon inactive">
            <EyeOff size={24} />
          </div>
          <div className="banner-stat-info">
            <span className="banner-stat-label">Đang tạm ẩn</span>
            <span className="banner-stat-val">
              {banners.filter(b => !b.isActive).length}
            </span>
          </div>
        </div>
      </div>

      {/* 2. Live Mobile App Banner Simulator */}
      <div className="banner-preview-section">
        <div className="preview-header">
          <div className="preview-title">
            <Smartphone size={20} />
            <span>Mô phỏng hiển thị trên ứng dụng di động</span>
          </div>
          <div className="preview-device-toggle">
            <CheckCircle2 size={16} color="#10b981" />
            <span>Đồng bộ nút bấm, vị trí & màu sắc thời gian thực</span>
          </div>
        </div>

        <div className="mobile-simulator-wrapper">
          <div className="mobile-simulator-notch" />

          {activeBanners.length > 0 ? (
            (() => {
              const currentBanner = activeBanners[activePreviewIndex] || activeBanners[0];
              const bannerBg = getBannerBackgroundStyle(currentBanner);
              const mascotSrc = currentBanner.imageUrl || '/image_character.png';
              const currentBtns = getBannerButtons(currentBanner);
              const pos = currentBanner.buttonPosition || 'BOTTOM_LEFT';

              return (
                <div className="stitch-banner-card" style={{ background: bannerBg }}>
                  <div className="stitch-banner-bg-orb" />

                  {/* Top Right Positioned Buttons */}
                  {pos === 'TOP_RIGHT' && renderBannerButtonsGroup(currentBtns, pos)}

                  <div className="stitch-banner-content">
                    {currentBanner.badgeText && (
                      <div className="stitch-banner-badge">
                        <span>{currentBanner.badgeText}</span>
                      </div>
                    )}

                    <h4 className="stitch-banner-title">{currentBanner.title}</h4>

                    <div className="stitch-banner-subtitle">
                      <span>{currentBanner.subtitle}</span>
                    </div>

                    {/* Bottom positioned buttons */}
                    {pos !== 'TOP_RIGHT' && renderBannerButtonsGroup(currentBtns, pos)}
                  </div>

                  <img
                    src={mascotSrc}
                    alt="Banner Mascot"
                    className="stitch-banner-mascot"
                    onError={e => {
                      (e.target as HTMLImageElement).src = '/image_character.png';
                    }}
                  />

                  {/* Indicator Dots */}
                  <div className="stitch-banner-dots">
                    {activeBanners.map((_, idx) => (
                      <span
                        key={idx}
                        className={`stitch-dot ${idx === activePreviewIndex ? 'active' : ''}`}
                        onClick={() => setActivePreviewIndex(idx)}
                      />
                    ))}
                  </div>
                </div>
              );
            })()
          ) : (
            <div
              className="stitch-banner-card"
              style={{
                background: 'linear-gradient(135deg, #2563EB, #4F46E5, #1D4ED8)',
                padding: '24px',
                textAlign: 'center',
              }}
            >
              <div className="stitch-banner-bg-orb" />
              <div style={{ position: 'relative', zIndex: 2 }}>
                <h4 className="stitch-banner-title">Chưa có banner nào được kích hoạt</h4>
                <p style={{ fontSize: '12px', color: '#dbeafe', margin: '8px 0 16px' }}>
                  Bật trạng thái hiển thị cho ít nhất 1 banner để xem trước trên app.
                </p>
                <button
                  type="button"
                  className="stitch-banner-cta-btn"
                  onClick={handleOpenCreateModal}
                >
                  <Plus size={13} />
                  <span>Tạo banner ngay</span>
                </button>
              </div>
            </div>
          )}

          {activeBanners.length > 1 && (
            <div className="preview-controls">
              <button
                type="button"
                className="preview-nav-btn"
                disabled={activePreviewIndex === 0}
                onClick={() => setActivePreviewIndex(prev => Math.max(0, prev - 1))}
                title="Banner trước"
              >
                <ChevronLeft size={16} />
              </button>
              <span style={{ fontSize: '12.5px', color: '#64748b', fontWeight: 600 }}>
                Banner {activePreviewIndex + 1} / {activeBanners.length}
              </span>
              <button
                type="button"
                className="preview-nav-btn"
                disabled={activePreviewIndex === activeBanners.length - 1}
                onClick={() =>
                  setActivePreviewIndex(prev => Math.min(activeBanners.length - 1, prev + 1))
                }
                title="Banner kế tiếp"
              >
                <ChevronRight size={16} />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* 3. Toolbar */}
      <div className="banner-toolbar">
        <div className="toolbar-left">
          <div className="search-box">
            <Search size={16} />
            <input
              type="text"
              placeholder="Tìm banner..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
            />
          </div>

          <select
            className="filter-select"
            value={filterStatus}
            onChange={e => setFilterStatus(e.target.value as any)}
          >
            <option value="ALL">Tất cả trạng thái</option>
            <option value="ACTIVE">Đang hiển thị trên App</option>
            <option value="INACTIVE">Đã tạm ẩn</option>
          </select>
        </div>

        <div className="toolbar-right">
          <button
            type="button"
            className="btn-refresh"
            onClick={() => fetchBanners(true)}
            disabled={refreshing}
            title="Làm mới"
          >
            <RefreshCw size={15} className={refreshing ? 'animate-spin' : ''} />
            <span>Làm mới</span>
          </button>

          <button type="button" className="btn-create" onClick={handleOpenCreateModal}>
            <Plus size={16} />
            <span>Thêm Banner Mới</span>
          </button>
        </div>
      </div>

      {/* 4. Banner Cards Grid */}
      {loading ? (
        <div className="banner-empty-state">
          <RefreshCw size={32} className="animate-spin" style={{ margin: '0 auto 12px' }} />
          <p>Đang tải danh sách banner ứng dụng...</p>
        </div>
      ) : filteredBanners.length === 0 ? (
        <div className="banner-empty-state">
          <div className="banner-empty-icon">
            <Sparkles size={28} />
          </div>
          <h3>Không tìm thấy banner nào</h3>
          <p>Chưa có banner nào khớp với điều kiện tìm kiếm hoặc chưa được tạo.</p>
          <button
            type="button"
            className="btn-create"
            onClick={handleOpenCreateModal}
            style={{ marginTop: '16px' }}
          >
            <Plus size={15} />
            <span>Thêm Banner Mới</span>
          </button>
        </div>
      ) : (
        <div className="banner-cards-grid">
          {filteredBanners.map((banner, index) => {
            const bannerBg = getBannerBackgroundStyle(banner);
            const mascotSrc = banner.imageUrl || '/image_character.png';
            const bannerBtns = getBannerButtons(banner);
            const pos = banner.buttonPosition || 'BOTTOM_LEFT';

            return (
              <div key={banner.id} className="banner-item-card">
                {/* Visual Preview Header */}
                <div className="banner-card-top-preview">
                  <div
                    className="stitch-banner-card"
                    style={{ background: bannerBg, minHeight: '145px' }}
                  >
                    <div className="stitch-banner-bg-orb" />

                    {pos === 'TOP_RIGHT' && renderBannerButtonsGroup(bannerBtns, pos, true)}

                    <div className="stitch-banner-content" style={{ padding: '12px 90px 14px 14px' }}>
                      {banner.badgeText && (
                        <div
                          className="stitch-banner-badge"
                          style={{ fontSize: '9px', padding: '2px 8px' }}
                        >
                          <span>{banner.badgeText}</span>
                        </div>
                      )}
                      <h4
                        className="stitch-banner-title"
                        style={{ fontSize: '14px', marginBottom: '2px' }}
                      >
                        {banner.title}
                      </h4>
                      <div
                        className="stitch-banner-subtitle"
                        style={{ fontSize: '10px', marginBottom: '8px' }}
                      >
                        {banner.subtitle}
                      </div>

                      {pos !== 'TOP_RIGHT' && renderBannerButtonsGroup(bannerBtns, pos, true)}
                    </div>

                    <img
                      src={mascotSrc}
                      alt="Mascot"
                      className="stitch-banner-mascot"
                      style={{ width: '90px', height: '120px' }}
                      onError={e => {
                        (e.target as HTMLImageElement).src = '/image_character.png';
                      }}
                    />
                  </div>
                </div>

                {/* Body Meta Details */}
                <div className="banner-card-body">
                  <div className="banner-card-meta">
                    <span className="banner-order-badge">Thứ tự: #{banner.displayOrder}</span>
                    <span
                      className={`banner-status-badge ${banner.isActive ? 'active' : 'inactive'}`}
                    >
                      <span className="banner-status-dot" />
                      {banner.isActive ? 'Hiển thị trên App' : 'Đang tạm ẩn'}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Vị trí nút:</strong>
                    <span>
                      {pos === 'BOTTOM_LEFT' && 'Góc trái - dưới (Mặc định)'}
                      {pos === 'BOTTOM_CENTER' && 'Ở giữa - dưới'}
                      {pos === 'BOTTOM_RIGHT' && 'Góc phải - dưới'}
                      {pos === 'TOP_RIGHT' && 'Góc phải - trên'}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Nút bấm ({bannerBtns.length}):</strong>
                    <span>
                      {bannerBtns.map(b => b.text).join(' • ')}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Màu / Nền:</strong>
                    <span>
                      {banner.backgroundImageUrl ? 'Ảnh nền tùy chỉnh' : 'Màu gradient'}
                    </span>
                  </div>
                </div>

                {/* Card Actions */}
                <div className="banner-card-actions">
                  <button
                    type="button"
                    className={`btn-toggle-switch ${banner.isActive ? 'active' : 'inactive'}`}
                    onClick={() => handleToggleActive(banner)}
                    title={banner.isActive ? 'Bấm để ẩn khỏi App' : 'Bấm để kích hoạt trên App'}
                  >
                    {banner.isActive ? <Eye size={15} /> : <EyeOff size={15} />}
                    <span>{banner.isActive ? 'Đang bật' : 'Đã tắt'}</span>
                  </button>

                  <div className="action-buttons-group">
                    <button
                      type="button"
                      className="btn-icon-action"
                      disabled={index === 0}
                      onClick={() => handleMove(index, 'UP')}
                      title="Chuyển lên trước"
                    >
                      <ArrowUp size={14} />
                    </button>
                    <button
                      type="button"
                      className="btn-icon-action"
                      disabled={index === banners.length - 1}
                      onClick={() => handleMove(index, 'DOWN')}
                      title="Chuyển xuống sau"
                    >
                      <ArrowDown size={14} />
                    </button>
                    <button
                      type="button"
                      className="btn-icon-action"
                      onClick={() => handleOpenEditModal(banner)}
                      title="Chỉnh sửa banner"
                    >
                      <Edit size={14} />
                    </button>
                    <button
                      type="button"
                      className="btn-icon-action delete"
                      onClick={() => handleDelete(banner)}
                      title="Xóa banner"
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* 5. Create / Edit Banner Modal */}
      {showModal && (
        <div className="banner-modal-overlay" onClick={() => setShowModal(false)}>
          <div className="banner-modal-content" onClick={e => e.stopPropagation()}>
            <div className="banner-modal-header">
              <h3>{editingBanner ? 'Chỉnh sửa Banner Ứng Dụng' : 'Tạo Mới Banner Ứng Dụng'}</h3>
              <button
                type="button"
                className="modal-close-btn"
                onClick={() => setShowModal(false)}
                title="Đóng"
              >
                <X size={20} />
              </button>
            </div>

            <form onSubmit={handleSubmit}>
              <div className="banner-modal-body">
                {/* Live Real-time Preview Inside Modal */}
                <div style={{ marginBottom: '8px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: '#334155', display: 'block', marginBottom: '8px' }}>
                    Xem trước banner theo thời gian thực (Cập nhật vị trí nút, hành động & màu sắc):
                  </label>
                  <div
                    className="stitch-banner-card"
                    style={{
                      background: bgMode === 'CUSTOM_BG'
                        ? getBannerBackgroundStyle({}, bgFilePreviewUrl || formBackgroundImageUrl)
                        : getGradientStyle(formCustomGradient.trim() || formGradient),
                      minHeight: '150px',
                    }}
                  >
                    <div className="stitch-banner-bg-orb" />

                    {formButtonPosition === 'TOP_RIGHT' &&
                      renderBannerButtonsGroup(formButtons, formButtonPosition)}

                    <div className="stitch-banner-content">
                      {formBadgeText && (
                        <div className="stitch-banner-badge">
                          <span>{formBadgeText}</span>
                        </div>
                      )}
                      <h4 className="stitch-banner-title">{formTitle || 'Tiêu đề banner mẫu'}</h4>
                      <div className="stitch-banner-subtitle">
                        {formSubtitle || 'Mô tả nội dung ưu đãi khuyến mãi cho khách hàng'}
                      </div>

                      {formButtonPosition !== 'TOP_RIGHT' &&
                        renderBannerButtonsGroup(formButtons, formButtonPosition)}
                    </div>

                    <img
                      src={
                        filePreviewUrl ||
                        (imageType === 'url' && formImageUrl ? formImageUrl : '/image_character.png')
                      }
                      alt="Banner Mascot Preview"
                      className="stitch-banner-mascot"
                      onError={e => {
                        (e.target as HTMLImageElement).src = '/image_character.png';
                      }}
                    />
                  </div>
                </div>

                {/* Content Inputs */}
                <div className="form-grid-2">
                  <div className="form-group">
                    <label>Tiêu đề chính (*)</label>
                    <input
                      type="text"
                      required
                      placeholder="Ví dụ: Bảo Trì & Sửa Chữa Inverter"
                      value={formTitle}
                      onChange={e => setFormTitle(e.target.value)}
                    />
                  </div>

                  <div className="form-group">
                    <label>Huy hiệu / Tag nổi bật</label>
                    <input
                      type="text"
                      placeholder="Ví dụ: ⚡ ƯU ĐÃI ĐẶC BIỆT"
                      value={formBadgeText}
                      onChange={e => setFormBadgeText(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Mô tả chi tiết / Nội dung ưu đãi</label>
                  <textarea
                    rows={2}
                    placeholder="Ví dụ: Giảm ngay 25% GIÁ TRỊ cho lượt đặt dịch vụ đầu tiên!"
                    value={formSubtitle}
                    onChange={e => setFormSubtitle(e.target.value)}
                  />
                </div>

                {/* 1. BUTTON POSITION SELECTION */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Move size={15} color="#2563eb" />
                    <span>Vị trí nút bấm trên banner</span>
                  </label>
                  <div className="position-options-grid">
                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'BOTTOM_LEFT' ? 'selected' : ''}`}
                      onClick={() => setFormButtonPosition('BOTTOM_LEFT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot bottom-left" />
                      </div>
                      <span>Trái - Dưới (Mặc định)</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'BOTTOM_CENTER' ? 'selected' : ''}`}
                      onClick={() => setFormButtonPosition('BOTTOM_CENTER')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot bottom-center" />
                      </div>
                      <span>Ở giữa - Dưới</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'BOTTOM_RIGHT' ? 'selected' : ''}`}
                      onClick={() => setFormButtonPosition('BOTTOM_RIGHT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot bottom-right" />
                      </div>
                      <span>Phải - Dưới</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'TOP_RIGHT' ? 'selected' : ''}`}
                      onClick={() => setFormButtonPosition('TOP_RIGHT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot top-right" />
                      </div>
                      <span>Phải - Trên</span>
                    </button>
                  </div>
                </div>

                {/* 2. MULTIPLE BUTTONS & ACTIONS MANAGER */}
                <div className="form-group">
                  <div className="buttons-manager-header">
                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', margin: 0 }}>
                      <Layers size={15} color="#2563eb" />
                      <span>Các nút bấm và hành động trên banner ({formButtons.length}/3)</span>
                    </label>
                    {formButtons.length < 3 && (
                      <button
                        type="button"
                        className="btn-add-button"
                        onClick={handleAddButton}
                      >
                        <Plus size={14} />
                        <span>Thêm nút bấm</span>
                      </button>
                    )}
                  </div>

                  {formButtons.map((btn, bIdx) => (
                    <div key={bIdx} className="button-item-card">
                      <div className="button-item-top">
                        <span className="button-badge-num">
                          <span>Nút #{bIdx + 1}</span>
                          <span style={{ fontSize: '11px', color: '#64748b', fontWeight: 'normal' }}>
                            {btn.styleType === 'PRIMARY' ? '(Nút chính)' : btn.styleType === 'SECONDARY' ? '(Nút phụ)' : '(Viền ngoài)'}
                          </span>
                        </span>
                        {formButtons.length > 1 && (
                          <button
                            type="button"
                            className="btn-remove-button"
                            onClick={() => handleRemoveButton(bIdx)}
                            title="Xóa nút này"
                          >
                            <Trash2 size={13} />
                          </button>
                        )}
                      </div>

                      <div className="form-grid-2">
                        <div>
                          <label style={{ fontSize: '11.5px', color: '#475569' }}>Tên nút bấm</label>
                          <input
                            type="text"
                            required
                            placeholder="Ví dụ: Đặt lịch ngay"
                            value={btn.text}
                            onChange={e => handleUpdateButton(bIdx, 'text', e.target.value)}
                            style={{ fontSize: '12.5px' }}
                          />
                        </div>

                        <div>
                          <label style={{ fontSize: '11.5px', color: '#475569' }}>Kiểu giao diện nút</label>
                          <select
                            value={btn.styleType}
                            onChange={e => handleUpdateButton(bIdx, 'styleType', e.target.value)}
                            style={{ fontSize: '12.5px' }}
                          >
                            <option value="PRIMARY">Nút chính (Nền trắng nổi bật)</option>
                            <option value="SECONDARY">Nút phụ (Kính mờ viền trắng)</option>
                            <option value="OUTLINE">Nút viền trong suốt</option>
                          </select>
                        </div>
                      </div>

                      <div className="form-grid-2" style={{ marginTop: '8px' }}>
                        <div>
                          <label style={{ fontSize: '11.5px', color: '#475569' }}>Hành động khi bấm</label>
                          <select
                            value={btn.actionType}
                            onChange={e => handleUpdateButton(bIdx, 'actionType', e.target.value)}
                            style={{ fontSize: '12.5px' }}
                          >
                            <option value="BOOKING">Mở khung Đặt dịch vụ (Booking Sheet)</option>
                            <option value="CALL">Gọi điện thoại Hotline</option>
                            <option value="REPAIR_ORDER">Mở danh sách Đơn sửa chữa</option>
                            <option value="LINK">Mở liên kết Web (URL)</option>
                            <option value="SCREEN">Chuyển hướng màn hình App</option>
                            <option value="NONE">Không có hành động</option>
                          </select>
                        </div>

                        <div>
                          <label style={{ fontSize: '11.5px', color: '#475569' }}>
                            {btn.actionType === 'BOOKING'
                              ? 'Tên dịch vụ đặt hẹn'
                              : btn.actionType === 'CALL'
                              ? 'Số điện thoại hotline'
                              : btn.actionType === 'LINK'
                              ? 'Đường dẫn liên kết (URL)'
                              : 'Tham số / Tên màn hình'}
                          </label>
                          <input
                            type="text"
                            placeholder={
                              btn.actionType === 'BOOKING'
                                ? 'Ví dụ: Gói bảo trì ưu đãi 25%'
                                : btn.actionType === 'CALL'
                                ? 'Ví dụ: 0901234567'
                                : btn.actionType === 'LINK'
                                ? 'https://example.com'
                                : 'warehouse, messages'
                            }
                            value={btn.actionValue || ''}
                            onChange={e => handleUpdateButton(bIdx, 'actionValue', e.target.value)}
                            style={{ fontSize: '12.5px' }}
                          />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>

                {/* 3. COLOR PALETTE, PICKER & CUSTOM BACKGROUND */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Palette size={15} color="#2563eb" />
                    <span>Màu sắc & Nền banner</span>
                  </label>

                  {/* Mode Tabs */}
                  <div className="bg-mode-tabs">
                    <button
                      type="button"
                      className={`bg-mode-tab ${bgMode === 'GRADIENT' ? 'active' : ''}`}
                      onClick={() => setBgMode('GRADIENT')}
                    >
                      <Palette size={14} />
                      <span>Bảng màu Gradient & Tự chọn mã màu</span>
                    </button>
                    <button
                      type="button"
                      className={`bg-mode-tab ${bgMode === 'CUSTOM_BG' ? 'active' : ''}`}
                      onClick={() => setBgMode('CUSTOM_BG')}
                    >
                      <ImageIcon size={14} />
                      <span>Tải ảnh nền banner tự thiết kế / custom</span>
                    </button>
                  </div>

                  {bgMode === 'GRADIENT' ? (
                    <div>
                      {/* Presets */}
                      <span className="form-hint" style={{ marginBottom: '6px', display: 'block' }}>
                        Chọn từ bộ màu thiết kế sẵn:
                      </span>
                      <div className="gradient-picker-row">
                        {GRADIENT_PRESETS.map((preset, idx) => (
                          <button
                            key={idx}
                            type="button"
                            className={`gradient-preset-btn ${formGradient === preset.value && !formCustomGradient ? 'selected' : ''}`}
                            style={{ background: preset.preview }}
                            onClick={() => {
                              setFormGradient(preset.value);
                              setFormCustomGradient('');
                              const parts = preset.value.split(',');
                              if (parts.length >= 3) {
                                setColorStop1(parts[0].trim());
                                setColorStop2(parts[1].trim());
                                setColorStop3(parts[2].trim());
                              }
                            }}
                            title={preset.name}
                          >
                            {formGradient === preset.value && !formCustomGradient && (
                              <Check size={16} color="#ffffff" style={{ margin: 'auto' }} />
                            )}
                          </button>
                        ))}
                      </div>

                      {/* Interactive Color Stops Pickers */}
                      <div style={{ marginTop: '14px' }}>
                        <span className="form-hint" style={{ display: 'block', marginBottom: '6px' }}>
                          Hoặc tùy chỉnh trực tiếp từng điểm màu trên bảng màu (Color Picker & Mã HEX):
                        </span>
                        <div className="color-picker-stops-grid">
                          <div className="color-stop-item">
                            <span className="color-stop-label">Màu bắt đầu (Điểm 1)</span>
                            <div className="color-input-wrapper">
                              <input
                                type="color"
                                className="color-native-picker"
                                value={colorStop1}
                                onChange={e => handleColorStopChange(1, e.target.value)}
                              />
                              <input
                                type="text"
                                className="color-hex-input"
                                value={colorStop1}
                                onChange={e => handleColorStopChange(1, e.target.value)}
                              />
                            </div>
                          </div>

                          <div className="color-stop-item">
                            <span className="color-stop-label">Màu chuyển tiếp (Điểm 2)</span>
                            <div className="color-input-wrapper">
                              <input
                                type="color"
                                className="color-native-picker"
                                value={colorStop2}
                                onChange={e => handleColorStopChange(2, e.target.value)}
                              />
                              <input
                                type="text"
                                className="color-hex-input"
                                value={colorStop2}
                                onChange={e => handleColorStopChange(2, e.target.value)}
                              />
                            </div>
                          </div>

                          <div className="color-stop-item">
                            <span className="color-stop-label">Màu kết thúc (Điểm 3)</span>
                            <div className="color-input-wrapper">
                              <input
                                type="color"
                                className="color-native-picker"
                                value={colorStop3}
                                onChange={e => handleColorStopChange(3, e.target.value)}
                              />
                              <input
                                type="text"
                                className="color-hex-input"
                                value={colorStop3}
                                onChange={e => handleColorStopChange(3, e.target.value)}
                              />
                            </div>
                          </div>
                        </div>
                      </div>

                      <div style={{ marginTop: '10px' }}>
                        <input
                          type="text"
                          placeholder="Mã màu gradient HEX tổng hợp (Ví dụ: #1E3A8A,#3B82F6,#1D4ED8)"
                          value={formCustomGradient}
                          onChange={e => setFormCustomGradient(e.target.value)}
                          style={{ fontSize: '12px' }}
                        />
                      </div>
                    </div>
                  ) : (
                    /* Custom Background Image Upload / URL */
                    <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '12px', padding: '14px' }}>
                      <div style={{ border: '2px dashed #cbd5e1', borderRadius: '10px', padding: '16px', textAlign: 'center', background: '#ffffff', marginBottom: '12px' }}>
                        <UploadCloud size={26} color="#64748b" style={{ margin: '0 auto 6px' }} />
                        <span style={{ fontSize: '13px', fontWeight: 600, display: 'block', color: '#1e293b' }}>
                          Tải ảnh nền banner từ máy tính
                        </span>
                        <input
                          type="file"
                          accept="image/png, image/jpeg, image/webp"
                          onChange={handleBgFileChange}
                          style={{ display: 'block', margin: '8px auto', fontSize: '12px' }}
                        />
                        <span className="form-hint">
                          Hỗ trợ PNG, JPG, WebP. Kích thước đề xuất: 720x360px.
                        </span>
                      </div>

                      <div>
                        <label style={{ fontSize: '12px', color: '#475569' }}>Hoặc nhập URL ảnh nền trực tuyến:</label>
                        <input
                          type="url"
                          placeholder="https://example.com/images/banner_bg.jpg"
                          value={formBackgroundImageUrl}
                          onChange={e => setFormBackgroundImageUrl(e.target.value)}
                          style={{ fontSize: '12.5px' }}
                        />
                      </div>

                      {(bgFilePreviewUrl || formBackgroundImageUrl) && (
                        <div style={{ marginTop: '10px', display: 'flex', justifyContent: 'flex-end' }}>
                          <button
                            type="button"
                            className="btn-secondary"
                            style={{ fontSize: '11.5px', padding: '5px 10px', color: '#dc2626' }}
                            onClick={() => {
                              setSelectedBgFile(null);
                              setBgFilePreviewUrl(null);
                              setFormBackgroundImageUrl('');
                            }}
                          >
                            Xóa ảnh nền custom này
                          </button>
                        </div>
                      )}
                    </div>
                  )}
                </div>

                {/* 4. Banner Mascot Image */}
                <div className="form-group">
                  <label>Hình ảnh minh họa góc phải banner</label>
                  <div style={{ display: 'flex', gap: '16px', marginBottom: '8px' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="imageType"
                        checked={imageType === 'default'}
                        onChange={() => {
                          setImageType('default');
                          setSelectedFile(null);
                          setFilePreviewUrl(null);
                        }}
                      />
                      <span>Mascot 3D Inverter (Mặc định)</span>
                    </label>

                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="imageType"
                        checked={imageType === 'upload'}
                        onChange={() => setImageType('upload')}
                      />
                      <span>Tải ảnh lên từ máy</span>
                    </label>

                    <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="imageType"
                        checked={imageType === 'url'}
                        onChange={() => {
                          setImageType('url');
                          setSelectedFile(null);
                          setFilePreviewUrl(null);
                        }}
                      />
                      <span>Nhập URL ảnh</span>
                    </label>
                  </div>

                  {imageType === 'upload' && (
                    <div style={{ border: '2px dashed #cbd5e1', borderRadius: '12px', padding: '16px', textAlign: 'center', background: '#f8fafc' }}>
                      <UploadCloud size={28} color="#64748b" style={{ margin: '0 auto 8px' }} />
                      <input
                        type="file"
                        accept="image/png, image/jpeg, image/webp"
                        onChange={handleMascotFileChange}
                        style={{ display: 'block', margin: '0 auto', fontSize: '12.5px' }}
                      />
                      <span className="form-hint" style={{ marginTop: '6px', display: 'block' }}>
                        Hỗ trợ PNG, JPG, WebP. Nên dùng ảnh PNG nền trong suốt để khớp với banner.
                      </span>
                    </div>
                  )}

                  {imageType === 'url' && (
                    <input
                      type="url"
                      placeholder="https://example.com/images/banner_illustration.png"
                      value={formImageUrl}
                      onChange={e => setFormImageUrl(e.target.value)}
                    />
                  )}
                </div>

                {/* Display Order & Active */}
                <div className="form-grid-2">
                  <div className="form-group">
                    <label>Thứ tự hiển thị (Ưu tiên)</label>
                    <input
                      type="number"
                      min={1}
                      value={formDisplayOrder}
                      onChange={e => setFormDisplayOrder(Number(e.target.value))}
                    />
                  </div>

                  <div className="form-group" style={{ justifyContent: 'center' }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', marginTop: '14px' }}>
                      <input
                        type="checkbox"
                        checked={formIsActive}
                        onChange={e => setFormIsActive(e.target.checked)}
                        style={{ width: '18px', height: '18px' }}
                      />
                      <span style={{ fontSize: '13.5px', fontWeight: 600 }}>
                        Kích hoạt hiển thị ngay trên ứng dụng di động
                      </span>
                    </label>
                  </div>
                </div>
              </div>

              <div className="banner-modal-footer">
                <button
                  type="button"
                  className="btn-secondary"
                  onClick={() => setShowModal(false)}
                  disabled={submitting}
                >
                  Hủy
                </button>
                <button type="submit" className="btn-primary" disabled={submitting}>
                  {submitting ? (
                    <>
                      <RefreshCw size={15} className="animate-spin" />
                      <span>Đang lưu...</span>
                    </>
                  ) : (
                    <>
                      <CheckCircle2 size={15} />
                      <span>{editingBanner ? 'Lưu thay đổi' : 'Tạo banner'}</span>
                    </>
                  )}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
