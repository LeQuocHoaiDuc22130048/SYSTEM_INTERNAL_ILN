import React, { useState, useEffect, useCallback, useMemo, useRef } from 'react';
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
  Move,
  Type,
  Crop
} from 'lucide-react';
import { getAuthHeaders } from '../utils/auth';
import type { UserInfo } from '../mockData';
import './BannerTab.css';
import { ImageCropperModal } from './ImageCropperModal';

export interface BannerButton {
  text: string;
  actionType: 'BOOKING' | 'REPAIR_ORDER' | 'LINK' | 'SCREEN' | 'CALL' | 'NONE';
  actionValue?: string;
  styleType: 'PRIMARY' | 'SECONDARY' | 'OUTLINE';
}

export interface FontOption {
  id: string;
  name: string;
  family: string;
  description: string;
}

export const BANNER_FONTS: FontOption[] = [
  { id: 'Be Vietnam Pro', name: 'Be Vietnam Pro', family: "'Be Vietnam Pro', sans-serif", description: 'Chuẩn Việt ngữ, hiện đại & tối ưu' },
  { id: 'Inter', name: 'Inter', family: "'Inter', sans-serif", description: 'Công nghệ, tối giản & thanh lịch' },
  { id: 'Roboto', name: 'Roboto', family: "'Roboto', sans-serif", description: 'Rõ ràng, phổ thông & dễ đọc' },
  { id: 'Montserrat', name: 'Montserrat', family: "'Montserrat', sans-serif", description: 'Hình học, trẻ trung & năng động' },
  { id: 'Plus Jakarta Sans', name: 'Plus Jakarta Sans', family: "'Plus Jakarta Sans', sans-serif", description: 'Thanh lịch, cao cấp & xu hướng' },
  { id: 'Playfair Display', name: 'Playfair Display', family: "'Playfair Display', serif", description: 'Cổ điển, sang trọng & quý phái' },
  { id: 'Oswald', name: 'Oswald', family: "'Oswald', sans-serif", description: 'Đậm nét, mạnh mẽ & nổi bật' },
  { id: 'Lexend', name: 'Lexend', family: "'Lexend', sans-serif", description: 'Đọc lướt nhanh, trực quan & sạch sẽ' },
];

export const getBannerFontFamily = (fontName?: string): string => {
  if (!fontName) return "'Be Vietnam Pro', sans-serif";
  const found = BANNER_FONTS.find(f => f.id.toLowerCase() === fontName.toLowerCase());
  return found ? found.family : "'Be Vietnam Pro', sans-serif";
};

export interface AppBanner {
  id: string;
  title: string;
  badgeText?: string;
  subtitle?: string;
  buttonText?: string;
  actionType: 'BOOKING' | 'REPAIR_ORDER' | 'LINK' | 'SCREEN' | 'CALL' | 'NONE';
  actionValue?: string;
  buttonPosition?: 'BOTTOM_LEFT' | 'BOTTOM_CENTER' | 'BOTTOM_RIGHT' | 'TOP_RIGHT' | 'TOP_LEFT' | 'CUSTOM';
  buttonTop?: number | null;
  buttonBottom?: number | null;
  buttonLeft?: number | null;
  buttonRight?: number | null;
  buttons?: BannerButton[];
  buttonsJson?: string;
  imageUrl?: string;
  imagePosition?: 'RIGHT' | 'LEFT' | 'RIGHT_TOP' | 'NONE';
  fontFamily?: string;
  backgroundImageUrl?: string;
  darkenOverlay?: boolean;
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
  const [formButtonPosition, setFormButtonPosition] = useState<
    'BOTTOM_LEFT' | 'BOTTOM_CENTER' | 'BOTTOM_RIGHT' | 'TOP_RIGHT' | 'TOP_LEFT' | 'CUSTOM'
  >('BOTTOM_LEFT');
  const [formButtonTop, setFormButtonTop] = useState<number | ''>('');
  const [formButtonBottom, setFormButtonBottom] = useState<number | ''>('');
  const [formButtonLeft, setFormButtonLeft] = useState<number | ''>('');
  const [formButtonRight, setFormButtonRight] = useState<number | ''>('');
  const [formButtons, setFormButtons] = useState<BannerButton[]>([
    {
      text: 'Đặt lịch ngay',
      actionType: 'BOOKING',
      actionValue: 'Gói bảo trì ưu đãi 25%',
      styleType: 'PRIMARY',
    },
  ]);

  // Form Fields - Font Family
  const [formFontFamily, setFormFontFamily] = useState<string>('Be Vietnam Pro');

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
  const [imageType, setImageType] = useState<'default' | 'upload' | 'url' | 'none'>('none');
  const [formImageUrl, setFormImageUrl] = useState<string>('');
  const [formImagePosition, setFormImagePosition] = useState<'RIGHT' | 'LEFT' | 'RIGHT_TOP' | 'NONE'>('NONE');
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [filePreviewUrl, setFilePreviewUrl] = useState<string | null>(null);

  // Custom Background / Banner Image & Darken Overlay
  const [formDarkenOverlay, setFormDarkenOverlay] = useState<boolean>(false);

  // Image Cropper State & File Refs
  const [cropperOpen, setCropperOpen] = useState<boolean>(false);
  const [cropSourceSrc, setCropSourceSrc] = useState<string>('');
  const [cropFileName, setCropFileName] = useState<string>('banner.jpg');
  const [cropTarget, setCropTarget] = useState<'BANNER_IMAGE' | 'BACKGROUND' | 'MASCOT'>('BANNER_IMAGE');
  const quickUploadInputRef = useRef<HTMLInputElement>(null);
  const modalBannerUploadRef = useRef<HTMLInputElement>(null);
  const modalBgUploadRef = useRef<HTMLInputElement>(null);

  // Select file from PC to open in Cropper
  const handleSelectFileForCrop = (
    e: React.ChangeEvent<HTMLInputElement>,
    target: 'BANNER_IMAGE' | 'BACKGROUND' | 'MASCOT' = 'BANNER_IMAGE'
  ) => {
    if (e.target.files && e.target.files[0]) {
      const file = e.target.files[0];
      setCropTarget(target);
      setCropFileName(file.name);
      const reader = new FileReader();
      reader.onload = () => {
        if (typeof reader.result === 'string') {
          setCropSourceSrc(reader.result);
          setCropperOpen(true);
        }
      };
      reader.readAsDataURL(file);
    }
    e.target.value = '';
  };

  // Complete Crop Action
  const handleCropComplete = (croppedFile: File, previewUrl: string) => {
    if (cropTarget === 'BANNER_IMAGE') {
      setSelectedBgFile(croppedFile);
      setBgFilePreviewUrl(previewUrl);
      setBgMode('CUSTOM_BG');
      // Full image banner: DO NOT darken the image (không làm mờ tối ảnh!)
      setFormDarkenOverlay(false);
      // When uploading an image banner, mascot can be empty! Set imagePosition = 'NONE', imageType = 'none'
      setFormImagePosition('NONE');
      setImageType('none');
      setFormImageUrl('');
      // Information on banner (title, badge, subtitle, buttons) can be left completely empty
      setFormBadgeText('');
      setFormSubtitle('');
      setFormButtons([]);
      if (!showModal) {
        handleOpenCreateModal();
        setSelectedBgFile(croppedFile);
        setBgFilePreviewUrl(previewUrl);
        setBgMode('CUSTOM_BG');
        setFormDarkenOverlay(false);
        setFormImagePosition('NONE');
        setImageType('none');
        setFormImageUrl('');
        setFormTitle('');
        setFormBadgeText('');
        setFormSubtitle('');
        setFormButtons([]);
      }
      showToast('Đã tải ảnh banner lên thành công! Không làm tối ảnh (hiển thị màu sắc gốc 100%).');
    } else if (cropTarget === 'BACKGROUND') {
      setSelectedBgFile(croppedFile);
      setBgFilePreviewUrl(previewUrl);
      setBgMode('CUSTOM_BG');
      // Background upload from device: DO DARKEN overlay to ensure text and buttons stand out legibly!
      setFormDarkenOverlay(true);
      showToast('Đã tải ảnh nền từ thiết bị (bật làm tối 35% để làm nổi bật chữ & nút bấm)!');
    } else {
      setSelectedFile(croppedFile);
      setFilePreviewUrl(previewUrl);
      setImageType('upload');
      showToast('Đã cắt và áp dụng ảnh minh họa thành công!');
    }
  };

  // Re-crop background/banner image
  const handleReCropBackground = () => {
    const target = formDarkenOverlay ? 'BACKGROUND' : 'BANNER_IMAGE';
    if (cropSourceSrc) {
      setCropTarget(target);
      setCropperOpen(true);
    } else if (bgFilePreviewUrl || formBackgroundImageUrl) {
      setCropTarget(target);
      setCropSourceSrc(bgFilePreviewUrl || formBackgroundImageUrl);
      setCropperOpen(true);
    } else {
      if (target === 'BANNER_IMAGE') {
        modalBannerUploadRef.current?.click();
      } else {
        modalBgUploadRef.current?.click();
      }
    }
  };

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
    darkenOverlay?: boolean;
  }, previewBgUrl?: string | null, overrideDarken?: boolean) => {
    const bgUrl = previewBgUrl || banner.backgroundImageUrl;
    const shouldDarken = overrideDarken !== undefined ? overrideDarken : (banner.darkenOverlay ?? false);
    if (bgUrl) {
      if (shouldDarken) {
        return `linear-gradient(rgba(15, 23, 42, 0.35), rgba(15, 23, 42, 0.45)), url(${bgUrl}) center / cover no-repeat`;
      }
      return `url(${bgUrl}) center / cover no-repeat`;
    }
    return getGradientStyle(banner.gradientColors || '#2563EB,#4F46E5,#1D4ED8');
  };

  // Helper to extract buttons from banner (with fallback)
  const getBannerButtons = (banner: AppBanner): BannerButton[] => {
    if (banner.buttons && Array.isArray(banner.buttons)) {
      return banner.buttons;
    }
    if (banner.buttonsJson !== undefined && banner.buttonsJson !== null && banner.buttonsJson !== '') {
      try {
        const parsed = JSON.parse(banner.buttonsJson);
        if (Array.isArray(parsed)) return parsed;
      } catch (_) {}
    }
    if (banner.buttonText && banner.buttonText.trim()) {
      return [
        {
          text: banner.buttonText,
          actionType: banner.actionType || 'BOOKING',
          actionValue: banner.actionValue,
          styleType: 'PRIMARY',
        },
      ];
    }
    return [];
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
    setFormButtonTop('');
    setFormButtonBottom('');
    setFormButtonLeft('');
    setFormButtonRight('');
    setFormFontFamily('Be Vietnam Pro');
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
    setFormDarkenOverlay(false);
    setFormDisplayOrder(banners.length + 1);
    setFormIsActive(true);
    setImageType('none');
    setFormImageUrl('');
    setFormImagePosition('NONE');
    setSelectedFile(null);
    setFilePreviewUrl(null);
    setCropSourceSrc('');
    setShowModal(true);
  };

  // Open Edit Modal
  const handleOpenEditModal = (banner: AppBanner) => {
    setEditingBanner(banner);
    setFormTitle(banner.title);
    setFormBadgeText(banner.badgeText || '');
    setFormSubtitle(banner.subtitle || '');
    setFormButtonPosition(banner.buttonPosition || 'BOTTOM_LEFT');
    setFormButtonTop(banner.buttonTop != null ? banner.buttonTop : '');
    setFormButtonBottom(banner.buttonBottom != null ? banner.buttonBottom : '');
    setFormButtonLeft(banner.buttonLeft != null ? banner.buttonLeft : '');
    setFormButtonRight(banner.buttonRight != null ? banner.buttonRight : '');
    setFormFontFamily(banner.fontFamily || 'Be Vietnam Pro');
    setFormButtons(getBannerButtons(banner));
    setFormImagePosition(banner.imagePosition || 'RIGHT');

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
    setFormDarkenOverlay(banner.darkenOverlay ?? false);

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
    if (banner.imagePosition === 'NONE' || (!banner.imageUrl && banner.backgroundImageUrl)) {
      setImageType('none');
      setFormImageUrl('');
    } else if (!banner.imageUrl) {
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
    setCropSourceSrc(banner.backgroundImageUrl || '');
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
    if (formButtons.length > 0 && formButtons.some(b => !b.text.trim())) {
      showToast('Vui lòng nhập văn bản cho tất cả các nút bấm hoặc xóa nút không cần thiết.');
      return;
    }

    setSubmitting(true);
    const finalGradient = formCustomGradient.trim() || formGradient;
    const firstBtn = formButtons.length > 0 ? formButtons[0] : null;
    const primaryButtonText = firstBtn ? firstBtn.text.trim() : '';
    const primaryActionType = firstBtn ? firstBtn.actionType : 'NONE';
    const primaryActionValue = firstBtn ? (firstBtn.actionValue || '').trim() : '';

    const bTop = formButtonTop !== '' ? Number(formButtonTop) : null;
    const bBottom = formButtonBottom !== '' ? Number(formButtonBottom) : null;
    const bLeft = formButtonLeft !== '' ? Number(formButtonLeft) : null;
    const bRight = formButtonRight !== '' ? Number(formButtonRight) : null;

    try {
      if (selectedFile || selectedBgFile) {
        // Multipart upload
        const formData = new FormData();
        formData.append('title', formTitle.trim());
        formData.append('badgeText', formBadgeText.trim());
        formData.append('subtitle', formSubtitle.trim());
        formData.append('buttonText', primaryButtonText);
        formData.append('actionType', primaryActionType);
        formData.append('actionValue', primaryActionValue);
        formData.append('buttonPosition', formButtonPosition);
        formData.append('buttonsJson', JSON.stringify(formButtons));
        if (bTop !== null) formData.append('buttonTop', String(bTop));
        if (bBottom !== null) formData.append('buttonBottom', String(bBottom));
        if (bLeft !== null) formData.append('buttonLeft', String(bLeft));
        if (bRight !== null) formData.append('buttonRight', String(bRight));
        const finalImagePos = imageType === 'none' ? 'NONE' : formImagePosition;
        formData.append('imagePosition', finalImagePos);
        formData.append('fontFamily', formFontFamily);
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
        formData.append('darkenOverlay', String(formDarkenOverlay));

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
          buttonText: primaryButtonText,
          actionType: primaryActionType,
          actionValue: primaryActionValue,
          buttonPosition: formButtonPosition,
          buttonTop: bTop,
          buttonBottom: bBottom,
          buttonLeft: bLeft,
          buttonRight: bRight,
          buttonsJson: JSON.stringify(formButtons),
          buttons: formButtons,
          imageUrl: (imageType === 'default' || imageType === 'none') ? null : formImageUrl.trim() || null,
          imagePosition: imageType === 'none' ? 'NONE' : formImagePosition,
          fontFamily: formFontFamily,
          backgroundImageUrl: bgMode === 'CUSTOM_BG' ? formBackgroundImageUrl.trim() || null : null,
          darkenOverlay: formDarkenOverlay,
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

  interface ButtonCoords {
    top?: number | '' | null;
    bottom?: number | '' | null;
    left?: number | '' | null;
    right?: number | '' | null;
  }

  // Helper to render banner buttons inside any preview container
  const renderBannerButtonsGroup = (
    btns: BannerButton[],
    position: string = 'BOTTOM_LEFT',
    isSmall = false,
    coords?: ButtonCoords
  ) => {
    if (!btns || btns.length === 0) return null;

    let posClass = 'pos-bottom-left';
    const customStyle: React.CSSProperties = {};

    if (position === 'CUSTOM') {
      posClass = 'pos-custom';
      customStyle.position = 'absolute';
      customStyle.zIndex = 5;
      if (coords) {
        if (coords.top !== '' && coords.top !== null && coords.top !== undefined) customStyle.top = `${coords.top}px`;
        if (coords.bottom !== '' && coords.bottom !== null && coords.bottom !== undefined) customStyle.bottom = `${coords.bottom}px`;
        if (coords.left !== '' && coords.left !== null && coords.left !== undefined) customStyle.left = `${coords.left}px`;
        if (coords.right !== '' && coords.right !== null && coords.right !== undefined) customStyle.right = `${coords.right}px`;
      }
    } else if (position === 'TOP_LEFT') {
      posClass = 'pos-top-left';
      customStyle.position = 'absolute';
      customStyle.top = isSmall ? '8px' : '12px';
      customStyle.left = isSmall ? '10px' : '14px';
      customStyle.zIndex = 5;
    } else if (position === 'TOP_RIGHT') {
      posClass = 'pos-top-right';
      customStyle.position = 'absolute';
      customStyle.top = isSmall ? '8px' : '12px';
      customStyle.right = isSmall ? '10px' : '14px';
      customStyle.zIndex = 5;
    } else if (position === 'BOTTOM_CENTER') {
      posClass = 'pos-bottom-center';
    } else if (position === 'BOTTOM_RIGHT') {
      posClass = 'pos-bottom-right';
    } else {
      posClass = 'pos-bottom-left';
    }

    return (
      <div
        className={`stitch-banner-buttons-group ${posClass}`}
        style={Object.keys(customStyle).length > 0 ? customStyle : undefined}
      >
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
              const imgPos = currentBanner.imagePosition || 'RIGHT';
              const imgPosClass = imgPos.toLowerCase().replace('_', '-');

              return (
                <div
                  className="stitch-banner-card"
                  style={{
                    background: bannerBg,
                    fontFamily: getBannerFontFamily(currentBanner.fontFamily),
                  }}
                >
                  <div className="stitch-banner-bg-orb" />

                  {/* Absolute Positioned Buttons (TOP_RIGHT, TOP_LEFT, CUSTOM) */}
                  {(pos === 'TOP_RIGHT' || pos === 'TOP_LEFT' || pos === 'CUSTOM') &&
                    renderBannerButtonsGroup(currentBtns, pos, false, {
                      top: currentBanner.buttonTop,
                      bottom: currentBanner.buttonBottom,
                      left: currentBanner.buttonLeft,
                      right: currentBanner.buttonRight,
                    })}

                  <div className={`stitch-banner-content mascot-${imgPosClass}`}>
                    {currentBanner.badgeText && (
                      <div className="stitch-banner-badge">
                        <span>{currentBanner.badgeText}</span>
                      </div>
                    )}

                    {currentBanner.title && (
                      <h4 className="stitch-banner-title">{currentBanner.title}</h4>
                    )}

                    {currentBanner.subtitle && (
                      <div className="stitch-banner-subtitle">
                        <span>{currentBanner.subtitle}</span>
                      </div>
                    )}

                    {/* Bottom positioned buttons */}
                    {pos !== 'TOP_RIGHT' && pos !== 'TOP_LEFT' && pos !== 'CUSTOM' &&
                      renderBannerButtonsGroup(currentBtns, pos, false)}
                  </div>

                  {imgPos !== 'NONE' && (currentBanner.imageUrl || (!currentBanner.backgroundImageUrl)) && (
                    <img
                      src={mascotSrc}
                      alt="Banner Mascot"
                      className={`stitch-banner-mascot pos-${imgPosClass}`}
                      onError={e => {
                        (e.target as HTMLImageElement).src = '/image_character.png';
                      }}
                    />
                  )}

                  {/* Indicator Dots */}
                  <div className={`stitch-banner-dots ${imgPos === 'LEFT' ? 'mascot-left' : ''}`}>
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
          {/* Hidden Quick Upload Input */}
          <input
            type="file"
            ref={quickUploadInputRef}
            accept="image/png, image/jpeg, image/webp"
            style={{ display: 'none' }}
            onChange={e => handleSelectFileForCrop(e, 'BANNER_IMAGE')}
          />

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

          <button
            type="button"
            className="btn-upload-crop-banner"
            onClick={() => quickUploadInputRef.current?.click()}
            title="Tải ảnh banner từ máy tính và cắt ảnh chuẩn tỉ lệ App"
          >
            <Crop size={16} />
            <span>Tải & Cắt Banner từ Máy</span>
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
            const imgPos = banner.imagePosition || 'RIGHT';

            const cardPadding =
              imgPos === 'LEFT'
                ? '12px 14px 14px 85px'
                : imgPos === 'RIGHT_TOP'
                ? '12px 75px 14px 14px'
                : imgPos === 'NONE'
                ? '12px 14px 14px 14px'
                : '12px 90px 14px 14px';

            const cardMascotStyle: React.CSSProperties =
              imgPos === 'LEFT'
                ? { left: '6px', right: 'auto', bottom: 0, width: '80px', height: '110px' }
                : imgPos === 'RIGHT_TOP'
                ? { right: '8px', top: '8px', bottom: 'auto', left: 'auto', width: '60px', height: '60px' }
                : { right: '6px', bottom: 0, width: '90px', height: '120px' };

            return (
              <div key={banner.id} className="banner-item-card">
                {/* Visual Preview Header */}
                <div className="banner-card-top-preview">
                  <div
                    className="stitch-banner-card"
                    style={{
                      background: bannerBg,
                      minHeight: '145px',
                      fontFamily: getBannerFontFamily(banner.fontFamily),
                    }}
                  >
                    <div className="stitch-banner-bg-orb" />

                    {(pos === 'TOP_RIGHT' || pos === 'TOP_LEFT' || pos === 'CUSTOM') &&
                      renderBannerButtonsGroup(bannerBtns, pos, true, {
                        top: banner.buttonTop,
                        bottom: banner.buttonBottom,
                        left: banner.buttonLeft,
                        right: banner.buttonRight,
                      })}

                    <div className="stitch-banner-content" style={{ padding: cardPadding }}>
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
                        {banner.title || (
                          <span style={{ opacity: 0.65, fontStyle: 'italic', fontWeight: 500 }}>
                            (Banner hình ảnh - Không có chữ)
                          </span>
                        )}
                      </h4>
                      {banner.subtitle && (
                        <div
                          className="stitch-banner-subtitle"
                          style={{ fontSize: '10px', marginBottom: '8px' }}
                        >
                          {banner.subtitle}
                        </div>
                      )}

                      {pos !== 'TOP_RIGHT' && pos !== 'TOP_LEFT' && pos !== 'CUSTOM' &&
                        renderBannerButtonsGroup(bannerBtns, pos, true)}
                    </div>

                    {imgPos !== 'NONE' && (banner.imageUrl || (!banner.backgroundImageUrl)) && (
                      <img
                        src={mascotSrc}
                        alt="Mascot"
                        className="stitch-banner-mascot"
                        style={cardMascotStyle}
                        onError={e => {
                          (e.target as HTMLImageElement).src = '/image_character.png';
                        }}
                      />
                    )}
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
                      {bannerBtns.length === 0 ? (
                        <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Không có nút bấm</span>
                      ) : pos === 'CUSTOM' ? (
                        `Tùy chỉnh (${[
                          banner.buttonTop != null ? `T:${banner.buttonTop}px` : null,
                          banner.buttonBottom != null ? `B:${banner.buttonBottom}px` : null,
                          banner.buttonLeft != null ? `L:${banner.buttonLeft}px` : null,
                          banner.buttonRight != null ? `R:${banner.buttonRight}px` : null,
                        ].filter(Boolean).join(', ') || 'Chưa đặt tọa độ'})`
                      ) : pos === 'TOP_LEFT' ? (
                        'Góc trái - trên'
                      ) : pos === 'TOP_RIGHT' ? (
                        'Góc phải - trên'
                      ) : pos === 'BOTTOM_CENTER' ? (
                        'Ở giữa - dưới'
                      ) : pos === 'BOTTOM_RIGHT' ? (
                        'Góc phải - dưới'
                      ) : (
                        'Góc trái - dưới (Mặc định)'
                      )}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Vị trí ảnh:</strong>
                    <span>
                      {imgPos === 'RIGHT' && 'Góc phải - dưới (Mặc định)'}
                      {imgPos === 'LEFT' && 'Góc trái - dưới'}
                      {imgPos === 'RIGHT_TOP' && 'Góc phải - trên'}
                      {imgPos === 'NONE' && 'Ẩn ảnh minh họa'}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Nút bấm ({bannerBtns.length}):</strong>
                    <span>
                      {bannerBtns.length === 0 ? (
                        <span style={{ color: '#94a3b8', fontStyle: 'italic' }}>Không có nút hành động (0 nút)</span>
                      ) : (
                        bannerBtns.map(b => b.text).join(' • ')
                      )}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Phông chữ:</strong>
                    <span style={{ fontFamily: getBannerFontFamily(banner.fontFamily), fontWeight: 600 }}>
                      {banner.fontFamily || 'Be Vietnam Pro'}
                    </span>
                  </div>

                  <div className="banner-info-row">
                    <strong>Màu / Nền:</strong>
                    <span>
                      {banner.backgroundImageUrl
                        ? (banner.darkenOverlay
                            ? 'Ảnh nền (Có làm tối 35%)'
                            : 'Ảnh banner tải lên (Không làm tối)')
                        : 'Màu gradient'}
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
                        ? getBannerBackgroundStyle({ darkenOverlay: formDarkenOverlay }, bgFilePreviewUrl || formBackgroundImageUrl, formDarkenOverlay)
                        : getGradientStyle(formCustomGradient.trim() || formGradient),
                      minHeight: '150px',
                      fontFamily: getBannerFontFamily(formFontFamily),
                    }}
                  >
                    {(formButtonPosition === 'TOP_RIGHT' || formButtonPosition === 'TOP_LEFT' || formButtonPosition === 'CUSTOM') &&
                      renderBannerButtonsGroup(formButtons, formButtonPosition, false, {
                        top: formButtonTop,
                        bottom: formButtonBottom,
                        left: formButtonLeft,
                        right: formButtonRight,
                      })}

                    <div className={`stitch-banner-content mascot-${formImagePosition.toLowerCase().replace('_', '-')}`}>
                      {formBadgeText && (
                        <div className="stitch-banner-badge">
                          <span>{formBadgeText}</span>
                        </div>
                      )}
                      {formTitle ? (
                        <h4 className="stitch-banner-title">{formTitle}</h4>
                      ) : null}
                      {formSubtitle ? (
                        <div className="stitch-banner-subtitle">
                          {formSubtitle}
                        </div>
                      ) : null}

                      {formButtonPosition !== 'TOP_RIGHT' && formButtonPosition !== 'TOP_LEFT' && formButtonPosition !== 'CUSTOM' &&
                        renderBannerButtonsGroup(formButtons, formButtonPosition, false)}
                    </div>

                    {formImagePosition !== 'NONE' && imageType !== 'none' && (
                      <img
                        src={
                          filePreviewUrl ||
                          (imageType === 'url' && formImageUrl ? formImageUrl : '/image_character.png')
                        }
                        alt="Banner Mascot Preview"
                        className={`stitch-banner-mascot pos-${formImagePosition.toLowerCase().replace('_', '-')}`}
                        onError={e => {
                          (e.target as HTMLImageElement).src = '/image_character.png';
                        }}
                      />
                    )}
                  </div>
                </div>

                {/* Dedicated Banner Image Upload & Cropper Section */}
                <div className="banner-upload-cropper-card">
                  <input
                    type="file"
                    ref={modalBannerUploadRef}
                    accept="image/png, image/jpeg, image/webp"
                    style={{ display: 'none' }}
                    onChange={e => handleSelectFileForCrop(e, 'BANNER_IMAGE')}
                  />

                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '10px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                      <Crop size={16} color="#2563eb" />
                      <span style={{ fontSize: '13px', fontWeight: 700, color: '#1e293b' }}>
                        Tải ảnh banner từ máy tính (Có công cụ Cắt & Căn chỉnh tỉ lệ chuẩn App)
                      </span>
                    </div>
                    {bgMode === 'CUSTOM_BG' && (bgFilePreviewUrl || formBackgroundImageUrl) && (
                      <span className="cropped-thumb-badge">
                        <Sparkles size={11} />
                        {formDarkenOverlay ? 'Ảnh nền (Có làm tối)' : 'Ảnh banner gốc (Không làm tối)'}
                      </span>
                    )}
                  </div>

                  {bgMode === 'CUSTOM_BG' && (bgFilePreviewUrl || formBackgroundImageUrl) ? (
                    <div>
                      <div className="banner-cropped-active-box">
                        <img
                          src={bgFilePreviewUrl || formBackgroundImageUrl}
                          alt="Banner Preview"
                          className="cropped-thumb-preview"
                        />
                        <div className="cropped-thumb-info">
                          <span className="cropped-thumb-name">
                            {selectedBgFile ? selectedBgFile.name : 'Ảnh banner đã tải lên'}
                          </span>
                          <div className="cropped-thumb-meta">
                            <span className="cropped-thumb-badge">✓ Chuẩn tỉ lệ App (2:1)</span>
                            {selectedBgFile && (
                              <span>{Math.round(selectedBgFile.size / 1024)} KB</span>
                            )}
                          </div>
                          <div className="cropped-thumb-actions">
                            <button
                              type="button"
                              className="btn-recrop"
                              onClick={handleReCropBackground}
                            >
                              <Crop size={13} />
                              <span>Cắt lại / Căn chỉnh ảnh</span>
                            </button>
                            <button
                              type="button"
                              className="btn-change-crop"
                              onClick={() => modalBannerUploadRef.current?.click()}
                            >
                              Đổi ảnh khác
                            </button>
                            <button
                              type="button"
                              className="btn-remove-crop"
                              onClick={() => {
                                setSelectedBgFile(null);
                                setBgFilePreviewUrl(null);
                                setFormBackgroundImageUrl('');
                                setBgMode('GRADIENT');
                              }}
                            >
                              Xóa ảnh
                            </button>
                          </div>
                        </div>
                      </div>

                      {/* Darken Overlay Toggle */}
                      <div style={{ marginTop: '10px', padding: '10px 14px', background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '10px' }}>
                        <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', margin: 0 }}>
                          <input
                            type="checkbox"
                            checked={formDarkenOverlay}
                            onChange={e => setFormDarkenOverlay(e.target.checked)}
                            style={{ width: '16px', height: '16px' }}
                          />
                          <span style={{ fontSize: '13px', fontWeight: 600, color: '#1e293b' }}>
                            Làm mờ tối ảnh banner (Darken Overlay 35%)
                          </span>
                        </label>
                        <span className="form-hint" style={{ marginTop: '4px', display: 'block', fontSize: '12px', color: '#64748b' }}>
                          {formDarkenOverlay
                            ? '✓ Đang bật làm tối ảnh banner (35% Dark Overlay).'
                            : '✓ Không làm mờ tối ảnh: Giữ nguyên 100% màu sắc và độ sáng gốc của ảnh banner tải lên.'}
                        </span>
                      </div>
                    </div>
                  ) : (
                    <div
                      className="banner-crop-dropzone"
                      onClick={() => modalBannerUploadRef.current?.click()}
                    >
                      <div className="dropzone-icon-box">
                        <UploadCloud size={24} />
                      </div>
                      <span className="dropzone-title">
                        Bấm để tải ảnh banner từ máy tính lên
                      </span>
                      <span className="dropzone-desc">
                        Hỗ trợ PNG, JPG, WebP. Hệ thống sẽ tự động mở công cụ cắt ảnh để căn chỉnh vừa vặn với kích thước banner ứng dụng (720x360 px).
                      </span>
                      <span className="dropzone-badge-tag">
                        <Crop size={12} />
                        Có xem trước & cắt ảnh trực quan 2:1
                      </span>
                    </div>
                  )}
                </div>

                {/* Content Inputs */}
                <div className="form-grid-2">
                  <div className="form-group">
                    <label>Tiêu đề banner (Có thể để trống nếu dùng ảnh tự thiết kế)</label>
                    <input
                      type="text"
                      placeholder="Ví dụ: Bảo Trì & Sửa Chữa Inverter (hoặc để trống)"
                      value={formTitle}
                      onChange={e => setFormTitle(e.target.value)}
                    />
                  </div>

                  <div className="form-group">
                    <label>Huy hiệu / Tag nổi bật (Tùy chọn)</label>
                    <input
                      type="text"
                      placeholder="Ví dụ: ⚡ ƯU ĐÃI ĐẶC BIỆT"
                      value={formBadgeText}
                      onChange={e => setFormBadgeText(e.target.value)}
                    />
                  </div>
                </div>

                <div className="form-group">
                  <label>Mô tả chi tiết / Nội dung ưu đãi (Tùy chọn)</label>
                  <textarea
                    rows={2}
                    placeholder="Ví dụ: Giảm ngay 25% GIÁ TRỊ cho lượt đặt dịch vụ đầu tiên! (hoặc để trống)"
                    value={formSubtitle}
                    onChange={e => setFormSubtitle(e.target.value)}
                  />
                </div>

                {/* FONT FAMILY SELECTION */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Type size={15} color="#2563eb" />
                    <span>Phông chữ hiển thị trên banner (Typography)</span>
                  </label>
                  <div className="font-options-grid">
                    {BANNER_FONTS.map(font => {
                      const isSelected = formFontFamily.toLowerCase() === font.id.toLowerCase();
                      return (
                        <button
                          key={font.id}
                          type="button"
                          className={`font-option-card ${isSelected ? 'selected' : ''}`}
                          onClick={() => setFormFontFamily(font.id)}
                          style={{ fontFamily: font.family }}
                        >
                          <div className="font-card-top">
                            <span className="font-card-name">{font.name}</span>
                            {isSelected && (
                              <span className="font-card-check">
                                <Check size={12} color="#ffffff" />
                              </span>
                            )}
                          </div>
                          <div className="font-card-preview">
                            Ưu Đãi Inverter 2026
                          </div>
                          <div className="font-card-desc">
                            {font.description}
                          </div>
                        </button>
                      );
                    })}
                  </div>
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
                      className={`position-option-btn ${formButtonPosition === 'TOP_LEFT' ? 'selected' : ''}`}
                      onClick={() => setFormButtonPosition('TOP_LEFT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot top-left" />
                      </div>
                      <span>Trái - Trên</span>
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

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'CUSTOM' ? 'selected' : ''}`}
                      onClick={() => setFormButtonPosition('CUSTOM')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot custom" />
                      </div>
                      <span>Tùy chỉnh tọa độ</span>
                    </button>
                  </div>

                  {/* Custom Coordinates Inputs */}
                  {formButtonPosition === 'CUSTOM' && (
                    <div className="button-coords-box">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '6px', marginBottom: '8px' }}>
                        <Move size={14} color="#2563eb" />
                        <span style={{ fontSize: '12px', fontWeight: 600, color: '#1e293b' }}>
                          Thông số tọa độ vị trí nút (pixel - px):
                        </span>
                      </div>
                      <p style={{ fontSize: '11.5px', color: '#64748b', margin: '0 0 10px 0' }}>
                        Nhập khoảng cách từ mép banner tới nút bấm. Bạn có thể kết hợp Top/Bottom và Left/Right để định vị tự do.
                      </p>
                      <div className="button-coords-grid">
                        <div className="button-coord-item">
                          <label className="button-coord-label">Cách mép Trên (Top)</label>
                          <div className="button-coord-input-wrap">
                            <input
                              type="number"
                              min="0"
                              placeholder="VD: 14"
                              value={formButtonTop}
                              onChange={e =>
                                setFormButtonTop(e.target.value === '' ? '' : Number(e.target.value))
                              }
                            />
                            <span className="button-coord-unit">px</span>
                          </div>
                        </div>

                        <div className="button-coord-item">
                          <label className="button-coord-label">Cách mép Dưới (Bottom)</label>
                          <div className="button-coord-input-wrap">
                            <input
                              type="number"
                              min="0"
                              placeholder="VD: 14"
                              value={formButtonBottom}
                              onChange={e =>
                                setFormButtonBottom(e.target.value === '' ? '' : Number(e.target.value))
                              }
                            />
                            <span className="button-coord-unit">px</span>
                          </div>
                        </div>

                        <div className="button-coord-item">
                          <label className="button-coord-label">Cách mép Trái (Left)</label>
                          <div className="button-coord-input-wrap">
                            <input
                              type="number"
                              min="0"
                              placeholder="VD: 16"
                              value={formButtonLeft}
                              onChange={e =>
                                setFormButtonLeft(e.target.value === '' ? '' : Number(e.target.value))
                              }
                            />
                            <span className="button-coord-unit">px</span>
                          </div>
                        </div>

                        <div className="button-coord-item">
                          <label className="button-coord-label">Cách mép Phải (Right)</label>
                          <div className="button-coord-input-wrap">
                            <input
                              type="number"
                              min="0"
                              placeholder="VD: 16"
                              value={formButtonRight}
                              onChange={e =>
                                setFormButtonRight(e.target.value === '' ? '' : Number(e.target.value))
                              }
                            />
                            <span className="button-coord-unit">px</span>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
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

                  {formButtons.length === 0 ? (
                    <div className="button-empty-state">
                      <p style={{ fontSize: '13px', color: '#64748b', margin: '0 0 10px 0' }}>
                        Hiện banner chưa có nút bấm hành động nào (0 nút). Banner sẽ hiển thị nội dung thông tin / quảng bá thuần túy.
                      </p>
                      <button
                        type="button"
                        className="btn-add-button"
                        onClick={handleAddButton}
                      >
                        <Plus size={14} />
                        <span>Thêm nút bấm</span>
                      </button>
                    </div>
                  ) : (
                    formButtons.map((btn, bIdx) => (
                      <div key={bIdx} className="button-item-card">
                        <div className="button-item-top">
                          <span className="button-badge-num">
                            <span>Nút #{bIdx + 1}</span>
                            <span style={{ fontSize: '11px', color: '#64748b', fontWeight: 'normal' }}>
                              {btn.styleType === 'PRIMARY' ? '(Nút chính)' : btn.styleType === 'SECONDARY' ? '(Nút phụ)' : '(Viền ngoài)'}
                            </span>
                          </span>
                          <button
                            type="button"
                            className="btn-remove-button"
                            onClick={() => handleRemoveButton(bIdx)}
                            title="Xóa nút này"
                          >
                            <Trash2 size={13} />
                          </button>
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
                  ))
                )}
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
                      <input
                        type="file"
                        ref={modalBgUploadRef}
                        accept="image/png, image/jpeg, image/webp"
                        style={{ display: 'none' }}
                        onChange={e => handleSelectFileForCrop(e, 'BACKGROUND')}
                      />

                      {(bgFilePreviewUrl || formBackgroundImageUrl) ? (
                        <>
                          <div className="banner-cropped-active-box" style={{ marginBottom: '12px' }}>
                          <img
                            src={bgFilePreviewUrl || formBackgroundImageUrl}
                            alt="Cropped BG Preview"
                            className="cropped-thumb-preview"
                          />
                          <div className="cropped-thumb-info">
                            <span className="cropped-thumb-name">
                              {selectedBgFile ? selectedBgFile.name : 'Ảnh nền banner đã chọn'}
                            </span>
                            <div className="cropped-thumb-meta">
                              <span className="cropped-thumb-badge">✓ Chuẩn tỉ lệ App (2:1)</span>
                              {selectedBgFile && (
                                <span>{Math.round(selectedBgFile.size / 1024)} KB</span>
                              )}
                            </div>
                            <div className="cropped-thumb-actions">
                              <button
                                type="button"
                                className="btn-recrop"
                                onClick={handleReCropBackground}
                              >
                                <Crop size={13} />
                                <span>Cắt lại ảnh</span>
                              </button>
                              <button
                                type="button"
                                className="btn-change-crop"
                                onClick={() => modalBgUploadRef.current?.click()}
                              >
                                Đổi ảnh
                              </button>
                              <button
                                type="button"
                                className="btn-remove-crop"
                                onClick={() => {
                                  setSelectedBgFile(null);
                                  setBgFilePreviewUrl(null);
                                  setFormBackgroundImageUrl('');
                                }}
                              >
                                Xóa ảnh
                              </button>
                            </div>
                          </div>
                        </div>

                        {/* Darken Overlay Toggle for Background */}
                        <div style={{ marginBottom: '12px', padding: '10px 14px', background: '#ffffff', border: '1px solid #e2e8f0', borderRadius: '10px' }}>
                          <label style={{ display: 'flex', alignItems: 'center', gap: '8px', cursor: 'pointer', margin: 0 }}>
                            <input
                              type="checkbox"
                              checked={formDarkenOverlay}
                              onChange={e => setFormDarkenOverlay(e.target.checked)}
                              style={{ width: '16px', height: '16px' }}
                            />
                            <span style={{ fontSize: '13px', fontWeight: 600, color: '#1e293b' }}>
                              Làm mờ tối ảnh nền (Darken Overlay 35%)
                            </span>
                          </label>
                          <span className="form-hint" style={{ marginTop: '4px', display: 'block', fontSize: '12px', color: '#64748b' }}>
                            {formDarkenOverlay
                              ? '✓ Đang bật làm tối ảnh nền để chữ và các nút bấm màu trắng nổi bật rõ ràng.'
                              : '✓ Không làm tối: Ảnh nền giữ nguyên 100% độ sáng gốc.'}
                          </span>
                        </div>
                      </>
                    ) : (
                        <div
                          className="banner-crop-dropzone"
                          onClick={() => modalBgUploadRef.current?.click()}
                          style={{ marginBottom: '12px' }}
                        >
                          <div className="dropzone-icon-box">
                            <UploadCloud size={24} />
                          </div>
                          <span className="dropzone-title">
                            Chọn tệp ảnh nền từ máy tính
                          </span>
                          <span className="dropzone-desc">
                            Hỗ trợ PNG, JPG, WebP. Mở công cụ cắt ảnh tỉ lệ chuẩn App (720x360 px).
                          </span>
                          <span className="dropzone-badge-tag">
                            <Crop size={12} />
                            Cắt ảnh tỉ lệ chuẩn 2:1
                          </span>
                        </div>
                      )}

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
                    </div>
                  )}
                </div>

                {/* 4. Banner Mascot Image & Position */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <ImageIcon size={15} color="#2563eb" />
                    <span>Hình ảnh minh họa banner & Vị trí tùy chỉnh</span>
                  </label>

                  {/* 4.1 Image Position Selector */}
                  <div style={{ marginBottom: '12px' }}>
                    <span className="form-hint" style={{ display: 'block', marginBottom: '6px' }}>
                      Chọn vị trí xuất hiện của hình ảnh trên banner:
                    </span>
                    <div className="position-options-grid">
                      <button
                        type="button"
                        className={`position-option-btn ${formImagePosition === 'RIGHT' ? 'selected' : ''}`}
                        onClick={() => setFormImagePosition('RIGHT')}
                      >
                        <div className="image-pos-box">
                          <span className="image-pos-shape right-bottom" />
                        </div>
                        <span>Phải - Dưới (Mặc định)</span>
                      </button>

                      <button
                        type="button"
                        className={`position-option-btn ${formImagePosition === 'LEFT' ? 'selected' : ''}`}
                        onClick={() => setFormImagePosition('LEFT')}
                      >
                        <div className="image-pos-box">
                          <span className="image-pos-shape left-bottom" />
                        </div>
                        <span>Trái - Dưới</span>
                      </button>

                      <button
                        type="button"
                        className={`position-option-btn ${formImagePosition === 'RIGHT_TOP' ? 'selected' : ''}`}
                        onClick={() => setFormImagePosition('RIGHT_TOP')}
                      >
                        <div className="image-pos-box">
                          <span className="image-pos-shape right-top" />
                        </div>
                        <span>Phải - Trên</span>
                      </button>

                      <button
                        type="button"
                        className={`position-option-btn ${formImagePosition === 'NONE' ? 'selected' : ''}`}
                        onClick={() => {
                          setFormImagePosition('NONE');
                          setImageType('none');
                        }}
                      >
                        <div className="image-pos-box">
                          <span className="image-pos-shape none-img">✕</span>
                        </div>
                        <span>Không có mascot (Để trống)</span>
                      </button>
                    </div>
                  </div>

                  {/* 4.2 Image Source Selection */}
                  <div>
                    <span className="form-hint" style={{ display: 'block', marginBottom: '6px' }}>
                      Nguồn ảnh minh họa / mascot:
                    </span>
                    <div style={{ display: 'flex', gap: '16px', marginBottom: '8px', flexWrap: 'wrap' }}>
                      <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', cursor: 'pointer' }}>
                        <input
                          type="radio"
                          name="imageType"
                          checked={imageType === 'none'}
                          onChange={() => {
                            setImageType('none');
                            setFormImagePosition('NONE');
                            setSelectedFile(null);
                            setFilePreviewUrl(null);
                            setFormImageUrl('');
                          }}
                        />
                        <span style={{ fontWeight: imageType === 'none' ? 600 : 400 }}>Không dùng mascot (Để trống)</span>
                      </label>

                      <label style={{ display: 'flex', alignItems: 'center', gap: '6px', fontSize: '13px', cursor: 'pointer' }}>
                        <input
                          type="radio"
                          name="imageType"
                          checked={imageType === 'default'}
                          onChange={() => {
                            setImageType('default');
                            if (formImagePosition === 'NONE') setFormImagePosition('RIGHT');
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
                          onChange={() => {
                            setImageType('upload');
                            if (formImagePosition === 'NONE') setFormImagePosition('RIGHT');
                          }}
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
                            if (formImagePosition === 'NONE') setFormImagePosition('RIGHT');
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

      {/* Interactive Image Cropper Modal */}
      <ImageCropperModal
        isOpen={cropperOpen}
        imageSrc={cropSourceSrc}
        fileName={cropFileName}
        onClose={() => setCropperOpen(false)}
        onCropComplete={handleCropComplete}
      />
    </div>
  );
};
