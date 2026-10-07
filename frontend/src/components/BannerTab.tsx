import { useBannerHistory } from './useBannerHistory';
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
  Crop,
  ArrowLeft
} from 'lucide-react';
import { getAuthHeaders } from '../utils/auth';
import type { UserInfo } from '../mockData';
import './BannerTab.css';
import { ImageCropperModal } from './ImageCropperModal';
import { BannerCanvas, CanvasInspector } from './BannerCanvas';
import { defaultDesign, parseDesign, savedDesignMatches, templateDesign, snapPosition, removeButtonDesign, legacyDesign, type BannerDesign } from './bannerDesign';

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

const BANNER_FONTS: FontOption[] = [
  { id: 'Be Vietnam Pro', name: 'Be Vietnam Pro', family: "'Be Vietnam Pro', sans-serif", description: 'Chuẩn Việt ngữ, hiện đại & tối ưu' },
  { id: 'Inter', name: 'Inter', family: "'Inter', sans-serif", description: 'Công nghệ, tối giản & thanh lịch' },
  { id: 'Roboto', name: 'Roboto', family: "'Roboto', sans-serif", description: 'Rõ ràng, phổ thông & dễ đọc' },
  { id: 'Montserrat', name: 'Montserrat', family: "'Montserrat', sans-serif", description: 'Hình học, trẻ trung & năng động' },
  { id: 'Plus Jakarta Sans', name: 'Plus Jakarta Sans', family: "'Plus Jakarta Sans', sans-serif", description: 'Thanh lịch, cao cấp & xu hướng' },
  { id: 'Playfair Display', name: 'Playfair Display', family: "'Playfair Display', serif", description: 'Cổ điển, sang trọng & quý phái' },
  { id: 'Oswald', name: 'Oswald', family: "'Oswald', sans-serif", description: 'Đậm nét, mạnh mẽ & nổi bật' },
  { id: 'Lexend', name: 'Lexend', family: "'Lexend', sans-serif", description: 'Đọc lướt nhanh, trực quan & sạch sẽ' },
];

const getBannerFontFamily = (fontName?: string): string => {
  if (!fontName) return "'Be Vietnam Pro', sans-serif";
  const found = BANNER_FONTS.find(f => f.id.toLowerCase() === fontName.toLowerCase());
  return found ? found.family : "'Be Vietnam Pro', sans-serif";
};

export interface AppBanner {
  designJson?: string;
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

const APP_SCREEN_OPTIONS = [
  ['dashboard', 'Dashboard'], ['repair_orders', 'Đơn sửa chữa'], ['warehouse', 'Kho linh kiện'],
  ['attendance', 'Chấm công (Android)'], ['messages', 'Nhắn tin'], ['notifications', 'Thông báo'],
  ['employee_management', 'Quản lý nhân viên'], ['account_approval', 'Duyệt tài khoản'], ['profile', 'Cá nhân'],
];

function BannerActionFields({ actionType, actionValue, onTypeChange, onValueChange }: {
  actionType: BannerButton['actionType']; actionValue: string;
  onTypeChange: (type: BannerButton['actionType']) => void; onValueChange: (value: string) => void;
}) {
  return <div className="form-grid-2 banner-action-fields">
    <label>Hành động khi bấm
      <select value={actionType} onChange={e => onTypeChange(e.target.value as BannerButton['actionType'])}>
        <option value="NONE">Chỉ hiển thị, không điều hướng</option>
        <option value="SCREEN">Mở màn hình trong app</option>
        <option value="REPAIR_ORDER">Mở Đơn sửa chữa</option>
        <option value="BOOKING">Mở đặt dịch vụ</option>
        <option value="LINK">Mở URL ngoài trình duyệt</option>
        <option value="CALL">Mở cuộc gọi điện thoại</option>
      </select>
    </label>
    {actionType === 'SCREEN' ? <label>Màn hình đích
      <select required value={actionValue} onChange={e => onValueChange(e.target.value)}>
        <option value="">Chọn màn hình</option>
        {actionValue && !APP_SCREEN_OPTIONS.some(([route]) => route === actionValue) && <option value={actionValue}>{actionValue}</option>}
        {APP_SCREEN_OPTIONS.map(([route, label]) => <option key={route} value={route}>{label}</option>)}
      </select>
    </label> : ['LINK', 'CALL', 'BOOKING'].includes(actionType) ? <label>
      {actionType === 'LINK' ? 'URL đích' : actionType === 'CALL' ? 'Số điện thoại' : 'Dịch vụ'}
      <input type={actionType === 'LINK' ? 'url' : actionType === 'CALL' ? 'tel' : 'text'}
        required={actionType !== 'BOOKING'} value={actionValue} onChange={e => onValueChange(e.target.value)}
        placeholder={actionType === 'LINK' ? 'https://example.com' : actionType === 'CALL' ? '0901234567 hoặc +84901234567' : 'Tên dịch vụ'} />
      {actionType === 'CALL' && <small>Mở ứng dụng Điện thoại với số đã nhập để người dùng xác nhận gọi.</small>}
    </label> : null}
  </div>;
}

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

  const [formActionType, setFormActionType] = useState<BannerButton['actionType']>('NONE');
  const [formActionValue, setFormActionValue] = useState('');
  const [bgSource, setBgSource] = useState<'UPLOAD' | 'URL'>('UPLOAD');

  const [design, setDesign] = useState<BannerDesign>(defaultDesign);
  const [selectedElement, setSelectedElement] = useState('title');
  const [snapToGrid, setSnapToGrid] = useState(true);

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

  const [previewDevice, setPreviewDevice] = useState("390");
  const [previewDark, setPreviewDark] = useState(false);
  const editorSnapshot = useMemo(() => ({ formTitle, formBadgeText, formSubtitle, formActionType, formActionValue, bgSource, design, formButtonPosition, formButtonTop, formButtonBottom, formButtonLeft, formButtonRight, formButtons, formFontFamily, bgMode, formGradient, formCustomGradient, colorStop1, colorStop2, colorStop3, formBackgroundImageUrl, selectedBgFile, bgFilePreviewUrl, formDisplayOrder, formIsActive, imageType, formImageUrl, formImagePosition, selectedFile, filePreviewUrl, formDarkenOverlay }), [formTitle, formBadgeText, formSubtitle, formActionType, formActionValue, bgSource, design, formButtonPosition, formButtonTop, formButtonBottom, formButtonLeft, formButtonRight, formButtons, formFontFamily, bgMode, formGradient, formCustomGradient, colorStop1, colorStop2, colorStop3, formBackgroundImageUrl, selectedBgFile, bgFilePreviewUrl, formDisplayOrder, formIsActive, imageType, formImageUrl, formImagePosition, selectedFile, filePreviewUrl, formDarkenOverlay]);
  const history = useBannerHistory(editorSnapshot, showModal, snapshot => {
    setFormTitle(snapshot.formTitle);
    setFormBadgeText(snapshot.formBadgeText);
    setFormSubtitle(snapshot.formSubtitle);
    setFormActionType(snapshot.formActionType);
    setFormActionValue(snapshot.formActionValue);
    setBgSource(snapshot.bgSource);
    setDesign(snapshot.design);
    setFormButtonPosition(snapshot.formButtonPosition);
    setFormButtonTop(snapshot.formButtonTop);
    setFormButtonBottom(snapshot.formButtonBottom);
    setFormButtonLeft(snapshot.formButtonLeft);
    setFormButtonRight(snapshot.formButtonRight);
    setFormButtons(snapshot.formButtons);
    setFormFontFamily(snapshot.formFontFamily);
    setBgMode(snapshot.bgMode);
    setFormGradient(snapshot.formGradient);
    setFormCustomGradient(snapshot.formCustomGradient);
    setColorStop1(snapshot.colorStop1);
    setColorStop2(snapshot.colorStop2);
    setColorStop3(snapshot.colorStop3);
    setFormBackgroundImageUrl(snapshot.formBackgroundImageUrl);
    setSelectedBgFile(snapshot.selectedBgFile);
    setBgFilePreviewUrl(snapshot.bgFilePreviewUrl);
    setFormDisplayOrder(snapshot.formDisplayOrder);
    setFormIsActive(snapshot.formIsActive);
    setImageType(snapshot.imageType);
    setFormImageUrl(snapshot.formImageUrl);
    setFormImagePosition(snapshot.formImagePosition);
    setSelectedFile(snapshot.selectedFile);
    setFilePreviewUrl(snapshot.filePreviewUrl);
    setFormDarkenOverlay(snapshot.formDarkenOverlay);
  });

  // Image Cropper State & File Refs
  const [cropperOpen, setCropperOpen] = useState<boolean>(false);
  const [cropSourceSrc, setCropSourceSrc] = useState<string>('');
  const [cropFileName, setCropFileName] = useState<string>('banner.jpg');
  const [cropTarget, setCropTarget] = useState<'BANNER_IMAGE' | 'BACKGROUND' | 'MASCOT'>('BANNER_IMAGE');
  const quickUploadInputRef = useRef<HTMLInputElement>(null);
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
      setBgSource('UPLOAD');
      // Background upload from device: DO DARKEN overlay to ensure text and buttons stand out legibly!
      showToast('Đã cắt và áp dụng ảnh nền.');
    } else {
      setSelectedFile(croppedFile);
      setFilePreviewUrl(previewUrl);
      setImageType('upload');
      showToast('Đã cắt và áp dụng ảnh minh họa thành công!');
    }
  };

  // Re-crop background/banner image
  const handleReCropBackground = () => {
    const source = bgFilePreviewUrl || formBackgroundImageUrl;
    if (source) {
      setCropTarget('BACKGROUND');
      setCropSourceSrc(source);
      setCropperOpen(true);
    } else {
      modalBgUploadRef.current?.click();
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
      } catch {
        /* ignore json parse error */
      }
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
    setDesign(defaultDesign());
    setSelectedElement('title');
    setFormActionType('NONE');
    setFormActionValue('');
    setBgSource('UPLOAD');
    setFormTitle('');
    setFormBadgeText('⚡ ƯU ĐÃI ĐẶC BIỆT');
    setFormSubtitle('');
    setFormButtonPosition('BOTTOM_LEFT');
    setFormButtonTop('');
    setFormButtonBottom('');
    setFormButtonLeft('');
    setFormButtonRight('');
    setFormFontFamily('Be Vietnam Pro');
    setFormButtons([]);
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
    setDesign(parseDesign(banner.designJson) || legacyDesign(banner));
    setSelectedElement('title');
    setFormActionType(banner.actionType || 'NONE');
    setFormActionValue(banner.actionValue || '');
    setBgSource(banner.backgroundImageUrl?.startsWith('/api/v1/banners/images/') ? 'UPLOAD' : 'URL');
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
    if (banner.imagePosition === 'NONE') {
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
        text: 'Nút mới',
        actionType: 'NONE',
        actionValue: '',
        styleType: prev.length === 0 ? 'PRIMARY' : 'SECONDARY',
      },
    ]);
  };

  const handleRemoveButton = (idx: number) => {
    setFormButtons(prev => prev.filter((_, i) => i !== idx));
    setDesign(prev => removeButtonDesign(prev, idx));
    setSelectedElement('title');
  };

  const handleUpdateButton = (idx: number, field: keyof BannerButton, value: any) => {
    setFormButtons(prev =>
      prev.map((btn, i) => (i === idx ? { ...btn, [field]: value } : btn))
    );
    if (field === 'styleType') {
      setDesign(prev => ({ ...prev, nodes: { ...prev.nodes,
        [`button${idx}`]: { ...prev.nodes[`button${idx}`], gradient: undefined,
          background: value === 'OUTLINE' ? 'transparent' : value === 'SECONDARY' ? '#ffffff33' : '#ffffff',
          color: value === 'PRIMARY' ? '#2563eb' : '#ffffff' } } }));
      setSelectedElement(`button${idx}`);
    }
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

  const chooseButtonPosition = (position: typeof formButtonPosition) => {
    setFormButtonPosition(position);
    if (position === 'CUSTOM') return;
    setDesign(prev => ({ ...prev, nodes: Object.fromEntries(Object.entries(prev.nodes).map(([id, node]) => {
      if (!id.startsWith('button')) return [id, node];
      const index = Number(id.slice(6));
      const x = position.endsWith('CENTER') ? 50 - node.width / 2 : position.endsWith('RIGHT') ? 96 - node.width : 4;
      const y = position.startsWith('TOP') ? 4 : 96 - node.height;
      return [id, snapPosition(node, x, y - index * (node.height + 2), false)];
    })) }));
  };

  const chooseMascotPosition = (position: typeof formImagePosition) => {
    setFormImagePosition(position);
    if (position === 'NONE') { setImageType('none'); return; }
    if (imageType === 'none') setImageType('default');
    setDesign(prev => {
      const node = prev.nodes.mascot;
      const next = position === 'RIGHT_TOP' ? { ...node, x: 74, y: 4, width: 22, height: 44 }
        : { ...node, x: position === 'LEFT' ? 2 : 68, y: 12, width: 30, height: 86 };
      return { ...prev, nodes: { ...prev.nodes, mascot: next } };
    });
  };

  const applyTemplate = (template: 'promotion' | 'information' | 'image') => {
    history.checkpoint();
    setFormButtonPosition(template === 'information' ? 'BOTTOM_LEFT' : 'BOTTOM_CENTER');
    setDesign(templateDesign(template)); setSelectedElement(template === 'image' ? 'button0' : 'title');
    setFormFontFamily('Be Vietnam Pro'); setFormActionType('NONE'); setFormActionValue('');
    setFormButtons([{ text: template === 'promotion' ? 'Đặt lịch ngay' : template === 'image' ? 'Tìm hiểu thêm' : 'Liên hệ', actionType: 'NONE', actionValue: '', styleType: 'PRIMARY' }]);
    setFormTitle(template === 'promotion' ? 'ƯU ĐÃI ĐẶC BIỆT' : template === 'information' ? 'INVERTER LIKE NEW' : '');
    setFormBadgeText(template === 'promotion' ? 'KHUYẾN MÃI' : template === 'information' ? 'SỬA CHỮA BIẾN TẦN' : '');
    setFormSubtitle(template === 'promotion' ? 'Nhập nội dung ưu đãi của bạn' : template === 'information' ? 'Nhập địa chỉ và thông tin liên hệ' : '');
    setImageType(template === 'information' ? 'default' : 'none');
    setFormImagePosition(template === 'information' ? 'RIGHT' : 'NONE');
    setSelectedFile(null); setFilePreviewUrl(null); setFormImageUrl('');
    if (template === 'image') { setBgMode('CUSTOM_BG'); setBgSource('UPLOAD'); setFormDarkenOverlay(false); }
    else { setBgMode('GRADIENT'); setSelectedBgFile(null); setBgFilePreviewUrl(null); setFormCustomGradient(''); setFormGradient(template === 'promotion' ? '#1e3a8a,#2563eb,#172554' : '#0e7490,#155e75,#164e63'); }
  };

  // Submit Form (Create / Update)
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (formButtons.length > 0 && formButtons.some(b => !b.text.trim())) {
      showToast('Vui lòng nhập văn bản cho tất cả các nút bấm hoặc xóa nút không cần thiết.');
      return;
    }

    const actions = [{ actionType: formActionType, actionValue: formActionValue }, ...formButtons];
    if (actions.some(action => action.actionType === 'LINK' && !/^https?:\/\//i.test(action.actionValue?.trim() || ''))) {
      showToast('Liên kết phải bắt đầu bằng https:// hoặc http://.');
      return;
    }
    if (actions.some(action => ['SCREEN', 'CALL'].includes(action.actionType) && !action.actionValue?.trim())) {
      showToast('Vui lòng chọn màn hình đích hoặc nhập số điện thoại cho hành động.');
      return;
    }
    if (actions.some(action => action.actionType === 'CALL' && !/^\+?[0-9]{3,15}$/.test((action.actionValue || '').trim().replace(/^tel:/i, '').replace(/[\s().-]/g, '')))) {
      showToast('Số điện thoại phải có 3–15 chữ số, có thể bắt đầu bằng +.');
      return;
    }
    setSubmitting(true);
    const finalGradient = formCustomGradient.trim() || formGradient;
    const firstBtn = formButtons.length > 0 ? formButtons[0] : null;
    const primaryButtonText = firstBtn ? firstBtn.text.trim() : '';
    const primaryActionType = formActionType;
    const primaryActionValue = formActionValue.trim();

    const bTop = formButtonPosition === 'CUSTOM' && formButtonTop !== '' ? Number(formButtonTop) : null;
    const bBottom = formButtonPosition === 'CUSTOM' && formButtonBottom !== '' ? Number(formButtonBottom) : null;
    const bLeft = formButtonPosition === 'CUSTOM' && formButtonLeft !== '' ? Number(formButtonLeft) : null;
    const bRight = formButtonPosition === 'CUSTOM' && formButtonRight !== '' ? Number(formButtonRight) : null;

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
        if (!selectedFile) formData.append('imageUrl', imageType === 'default' || imageType === 'none' ? '' : formImageUrl.trim());
        formData.append('fontFamily', formFontFamily);
        formData.append('designJson', JSON.stringify(design));
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
        if (bgMode === 'GRADIENT' || (!selectedBgFile && !formBackgroundImageUrl.trim())) formData.append('backgroundImageUrl', '');
        formData.append('darkenOverlay', String(bgMode === 'CUSTOM_BG' && formDarkenOverlay));

        const url = editingBanner ? `/api/v1/banners/${editingBanner.id}` : '/api/v1/banners';
        const method = editingBanner ? 'PUT' : 'POST';

        const res = await fetch(url, {
          method,
          headers: getAuthHeaders(),
          body: formData,
        });

        if (res.ok) {
          const result = await res.json();
          const saved = result?.data ?? result;
          if (!savedDesignMatches(saved?.designJson, design)) {
            if (!editingBanner && saved?.id) setEditingBanner(saved);
            showToast('Server chưa trả lại đúng cấu hình custom banner. Chưa thể áp dụng bố cục này trên mobile; hãy kiểm tra bản backend và trường designJson.');
            await fetchBanners(true);
            return;
          }
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
          imageUrl: (imageType === 'default' || imageType === 'none') ? '' : formImageUrl.trim(),
          imagePosition: imageType === 'none' ? 'NONE' : formImagePosition,
          fontFamily: formFontFamily,
          designJson: JSON.stringify(design),
          backgroundImageUrl: bgMode === 'CUSTOM_BG' ? formBackgroundImageUrl.trim() : '',
          darkenOverlay: bgMode === 'CUSTOM_BG' && formDarkenOverlay,
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
          const result = await res.json();
          const saved = result?.data ?? result;
          if (!savedDesignMatches(saved?.designJson, design)) {
            if (!editingBanner && saved?.id) setEditingBanner(saved);
            showToast('Server chưa trả lại đúng cấu hình custom banner. Chưa thể áp dụng bố cục này trên mobile; hãy kiểm tra bản backend và trường designJson.');
            await fetchBanners(true);
            return;
          }
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

    let posClass: string;
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
      {/* 1. Header & Stats Grid (Gom 3 thẻ lên 1 hàng ngang: grid-cols-3 gap-2) */}
      <div className="banner-stats-grid">
        <div className="banner-stat-card">
          <div className="banner-stat-icon total">
            <Sparkles size={18} />
          </div>
          <div className="banner-stat-info">
            <span className="banner-stat-label">Tổng số banner</span>
            <span className="banner-stat-val">{banners.length}</span>
          </div>
        </div>

        <div className="banner-stat-card">
          <div className="banner-stat-icon active">
            <Eye size={18} />
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
            <EyeOff size={18} />
          </div>
          <div className="banner-stat-info">
            <span className="banner-stat-label">Đang tạm ẩn</span>
            <span className="banner-stat-val">
              {banners.filter(b => !b.isActive).length}
            </span>
          </div>
        </div>
      </div>

      {/* 2. Main Two-Column Split Layout on Tablet / Desktop */}
      <div className={`banner-main-split ${showModal ? 'banner-editing' : ''}`}>
        {/* Left Column: Banner Form (when editing/creating) OR Toolbar + Cards List */}
        <div className="banner-left-pane">
          {!showModal && (
            <>
              {/* Toolbar */}
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
            const imgPos = banner.imagePosition || 'RIGHT';

            const previewIdx = activeBanners.findIndex(b => b.id === banner.id);

            return (
              <div
                key={banner.id}
                className={`banner-item-card ${previewIdx === activePreviewIndex ? 'active-preview-card' : ''}`}
                onClick={() => {
                  if (previewIdx >= 0) setActivePreviewIndex(previewIdx);
                }}
                style={{ cursor: previewIdx >= 0 ? 'pointer' : 'default' }}
                title={previewIdx >= 0 ? 'Bấm để xem trên mô phỏng điện thoại' : undefined}
              >
                {/* 1. Left: 16:9 Thumbnail */}
                <div className="banner-card-thumb-col">
                  <div
                    className="banner-card-thumbnail"
                    style={{
                      background: bannerBg,
                      fontFamily: getBannerFontFamily(banner.fontFamily),
                    }}
                  >
                    {banner.backgroundImageUrl ? (
                      <img
                        src={banner.backgroundImageUrl}
                        alt={banner.title || 'Banner'}
                        className="banner-thumb-img"
                      />
                    ) : (
                      <>
                        <div className="banner-thumb-orb" />
                        {banner.badgeText && (
                          <span className="banner-thumb-badge">{banner.badgeText}</span>
                        )}
                        {imgPos !== 'NONE' && (
                          <img
                            src={mascotSrc}
                            alt=""
                            className={`banner-thumb-mascot pos-${imgPos.toLowerCase().replace('_', '-')}`}
                            onError={e => {
                              (e.target as HTMLImageElement).src = '/image_character.png';
                            }}
                          />
                        )}
                      </>
                    )}
                  </div>
                </div>

                {/* 2. Middle: Content Info */}
                <div className="banner-card-info-col">
                  <div className="banner-card-title-row">
                    <h4 className="banner-card-title">
                      {banner.title || (
                        <span className="banner-title-empty">(Banner hình ảnh - Không có chữ)</span>
                      )}
                    </h4>
                    {banner.badgeText && (
                      <span className="banner-card-badge-pill">{banner.badgeText}</span>
                    )}
                  </div>

                  {banner.subtitle && (
                    <div className="banner-card-subtitle">{banner.subtitle}</div>
                  )}

                  <div className="banner-card-meta-chips">
                    <span className="meta-chip order-chip">#{banner.displayOrder}</span>
                    <span className="meta-chip">
                      <Palette size={11} />
                      <span>{banner.backgroundImageUrl ? 'Ảnh nền' : 'Gradient'}</span>
                    </span>
                    <span className="meta-chip">
                      <Type size={11} />
                      <span>{banner.fontFamily || 'Be Vietnam Pro'}</span>
                    </span>
                    {bannerBtns.length > 0 ? (
                      <span className="meta-chip buttons-chip">
                        <span>{bannerBtns.length} nút ({bannerBtns.map(b => b.text).join(', ')})</span>
                      </span>
                    ) : (
                      <span className="meta-chip muted">0 nút bấm</span>
                    )}
                  </div>
                </div>

                {/* 3. Right: Action Bar */}
                <div className="banner-card-action-bar" onClick={e => e.stopPropagation()}>
                  {/* Switch Toggle (Bật / Tắt nhanh) */}
                  <div
                    className="banner-switch-container"
                    title={banner.isActive ? 'Đang hiển thị trên App (Bấm để ẩn)' : 'Đang tạm ẩn (Bấm để hiển thị)'}
                    onClick={() => handleToggleActive(banner)}
                  >
                    <div className={`banner-switch-track ${banner.isActive ? 'active' : ''}`}>
                      <div className="banner-switch-thumb" />
                    </div>
                    <span className={`banner-switch-text ${banner.isActive ? 'active' : ''}`}>
                      {banner.isActive ? 'Bật' : 'Tắt'}
                    </span>
                  </div>

                  <div className="banner-action-buttons">
                    <button
                      type="button"
                      className="btn-card-action"
                      disabled={index === 0}
                      onClick={() => handleMove(index, 'UP')}
                      title="Chuyển lên trước"
                    >
                      <ArrowUp size={13} />
                    </button>
                    <button
                      type="button"
                      className="btn-card-action"
                      disabled={index === banners.length - 1}
                      onClick={() => handleMove(index, 'DOWN')}
                      title="Chuyển xuống sau"
                    >
                      <ArrowDown size={13} />
                    </button>

                    {/* Icon bút chì (Chỉnh sửa) */}
                    <button
                      type="button"
                      className="btn-card-action edit-btn"
                      onClick={() => handleOpenEditModal(banner)}
                      title="Chỉnh sửa banner"
                    >
                      <Edit size={14} />
                    </button>

                    {/* Icon thùng rác đỏ (Xóa) */}
                    <button
                      type="button"
                      className="btn-card-action delete-btn"
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
            </>
          )}

          {/* Form Card (Hiển thị ở cột trái khi tạo / chỉnh sửa banner) */}
          {showModal && (
            <div className="banner-form-card">
              <div className="banner-form-header">
                <div className="banner-form-header-left">
                  <button
                    type="button"
                    className="btn-back-to-list"
                    onClick={() => {
                      setShowModal(false);
                      setEditingBanner(null);
                    }}
                    title="Quay lại danh sách banner"
                  >
                    <ArrowLeft size={16} />
                    <span>Danh sách banner</span>
                  </button>
                  <span className="banner-form-header-divider">/</span>
                  <h3>{editingBanner ? 'Chỉnh sửa Banner Ứng Dụng' : 'Tạo Mới Banner Ứng Dụng'}</h3>
                </div>
                <button
                  type="button"
                  className="modal-close-btn"
                  onClick={() => {
                    setShowModal(false);
                    setEditingBanner(null);
                  }}
                  title="Đóng form"
                >
                  <X size={18} />
                </button>
              </div>

              <form onSubmit={handleSubmit}>
              <div className="banner-modal-body">
                <details className="banner-editor-group" open><summary>Mẫu banner & công cụ thiết kế</summary><div className="banner-editor-fields">
                  <div className="banner-template-picker">
                    <button type="button" onClick={() => applyTemplate('promotion')}>Khuyến mãi / Ưu đãi</button>
                    <button type="button" onClick={() => applyTemplate('information')}>Thông tin / Địa chỉ</button>
                    <button type="button" onClick={() => applyTemplate('image')}>Banner thuần ảnh</button>
                  </div>
                  <p className="form-hint">Áp dụng mẫu sẽ thay nội dung và định dạng hiện tại. Kéo phần tử trên preview hoặc dùng phím mũi tên để căn chỉnh.</p>
                  <label className="canvas-toggle"><input type="checkbox" checked={snapToGrid} onChange={e => setSnapToGrid(e.target.checked)} />Căn lưới & đường giữa (giữ Alt để kéo tự do)</label>
                  <div className="canvas-element-picker">
                    {['badge', 'title', 'subtitle', 'mascot', ...formButtons.map((_, index) => `button${index}`)].map(id =>
                      <button type="button" key={id} className={selectedElement === id ? 'active' : ''} onClick={() => setSelectedElement(id)}>
                        {({ badge: 'Tag', title: 'Tiêu đề', subtitle: 'Mô tả', mascot: 'Mascot' } as Record<string, string>)[id] || `Nút ${Number(id.slice(6)) + 1}`}
                      </button>)}
                  </div>
                  <CanvasInspector design={design} selected={selectedElement} fonts={[formFontFamily, ...BANNER_FONTS.map(font => font.id).filter(font => font !== formFontFamily)]}
                    text={selectedElement === 'title' ? formTitle : selectedElement === 'subtitle' ? formSubtitle : selectedElement === 'badge' ? formBadgeText : ''}
                    onChange={setDesign} />
                </div></details>

<details className="banner-editor-group" open><summary>Nội dung & kiểu chữ</summary><div className="banner-editor-fields">
                {/* Content Inputs */}
                <div className="form-grid-2">
                  <div className="form-group">
                    <label>Tiêu đề banner (Có thể để trống nếu dùng ảnh tự thiết kế)</label>
                    <textarea
                      rows={2}
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

                <div className="form-group">
                  <label><Type size={15} /> Font mặc định của banner</label>
                  <select value={formFontFamily} onChange={e => setFormFontFamily(e.target.value)}>
                    {BANNER_FONTS.map(font => <option key={font.id} value={font.id}>{font.name}</option>)}
                  </select>
                  <small>Áp dụng cho phần tử chọn “Font mặc định”. Font riêng được chỉnh trong Định dạng.</small>
                </div>

</div></details>
<details className="banner-editor-group" open><summary>Giao diện & loại nền</summary><div className="banner-editor-fields">
                {/* 3. COLOR PALETTE, PICKER & CUSTOM BACKGROUND */}
                <div className="form-group">
                  <label style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                    <Palette size={15} color="#2563eb" />
                    <span>Loại nền banner</span>
                  </label>

<div className="bg-mode-tabs" role="group" aria-label="Loại nền">
<button type="button" className={`bg-mode-tab ${bgMode === 'CUSTOM_BG' && bgSource === 'UPLOAD' ? 'active' : ''}`}
 onClick={() => { setBgMode('CUSTOM_BG'); setBgSource('UPLOAD'); }}><UploadCloud size={14} />Ảnh tải lên</button>
<button type="button" className={`bg-mode-tab ${bgMode === 'CUSTOM_BG' && bgSource === 'URL' ? 'active' : ''}`}
 onClick={() => { setBgMode('CUSTOM_BG'); setBgSource('URL'); setSelectedBgFile(null); setBgFilePreviewUrl(null); }}><ExternalLink size={14} />URL trực tuyến</button>
<button type="button" className={`bg-mode-tab ${bgMode === 'GRADIENT' ? 'active' : ''}`}
 onClick={() => { setBgMode('GRADIENT'); setSelectedBgFile(null); setBgFilePreviewUrl(null); }}><Palette size={14} />Màu Gradient</button>
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
{bgSource === 'UPLOAD' && (<>
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

</>)}
{bgSource === 'URL' && (
                      <div>
                        <label style={{ fontSize: '12px', color: '#475569' }}>URL ảnh nền trực tuyến:</label>
                        <input
                          type="url"
                          placeholder="https://example.com/images/banner_bg.jpg"
                          value={formBackgroundImageUrl}
                          onChange={e => setFormBackgroundImageUrl(e.target.value)}
                          style={{ fontSize: '12.5px' }}
                        />
                        {formBackgroundImageUrl && <button type="button" className="btn-recrop" onClick={handleReCropBackground}>
                          <Crop size={13} />Cắt ảnh này
                        </button>}
                      </div>
)}
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
                        onClick={() => chooseMascotPosition('RIGHT')}
                      >
                        <div className="image-pos-box">
                          <span className="image-pos-shape right-bottom" />
                        </div>
                        <span>Phải - Dưới (Mặc định)</span>
                      </button>

                      <button
                        type="button"
                        className={`position-option-btn ${formImagePosition === 'LEFT' ? 'selected' : ''}`}
                        onClick={() => chooseMascotPosition('LEFT')}
                      >
                        <div className="image-pos-box">
                          <span className="image-pos-shape left-bottom" />
                        </div>
                        <span>Trái - Dưới</span>
                      </button>

                      <button
                        type="button"
                        className={`position-option-btn ${formImagePosition === 'RIGHT_TOP' ? 'selected' : ''}`}
                        onClick={() => chooseMascotPosition('RIGHT_TOP')}
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
</div></details>
<details className="banner-editor-group" open><summary>Nút bấm (CTA)</summary><div className="banner-editor-fields">
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
                        Chưa có nút CTA. Bạn vẫn có thể cấu hình hành động khi bấm toàn bộ banner ở mục Điều hướng.
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

<BannerActionFields actionType={btn.actionType} actionValue={btn.actionValue || ''}
 onTypeChange={type => { handleUpdateButton(bIdx, 'actionType', type); handleUpdateButton(bIdx, 'actionValue', ''); }}
 onValueChange={value => handleUpdateButton(bIdx, 'actionValue', value)} />
                    </div>
                  ))
                )}
                </div>

{formButtons.length > 0 && (<>
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
                      onClick={() => chooseButtonPosition('BOTTOM_LEFT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot bottom-left" />
                      </div>
                      <span>Trái - Dưới (Mặc định)</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'BOTTOM_CENTER' ? 'selected' : ''}`}
                      onClick={() => chooseButtonPosition('BOTTOM_CENTER')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot bottom-center" />
                      </div>
                      <span>Ở giữa - Dưới</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'BOTTOM_RIGHT' ? 'selected' : ''}`}
                      onClick={() => chooseButtonPosition('BOTTOM_RIGHT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot bottom-right" />
                      </div>
                      <span>Phải - Dưới</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'TOP_LEFT' ? 'selected' : ''}`}
                      onClick={() => chooseButtonPosition('TOP_LEFT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot top-left" />
                      </div>
                      <span>Trái - Trên</span>
                    </button>

                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'TOP_RIGHT' ? 'selected' : ''}`}
                      onClick={() => chooseButtonPosition('TOP_RIGHT')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot top-right" />
                      </div>
                      <span>Phải - Trên</span>
                    </button>

                  </div>
<details className="banner-advanced" open={formButtonPosition === 'CUSTOM'}><summary>Nâng cao: tọa độ tùy chỉnh</summary><p className="form-hint">Ưu tiên preset để bố cục thích ứng với màn hình di động.</p>
                    <button
                      type="button"
                      className={`position-option-btn ${formButtonPosition === 'CUSTOM' ? 'selected' : ''}`}
                      onClick={() => chooseButtonPosition('CUSTOM')}
                    >
                      <div className="position-icon-box">
                        <span className="position-dot custom" />
                      </div>
                      <span>Tùy chỉnh tọa độ</span>
                    </button>
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
</details>
                </div>

</>)}
</div></details>
<details className="banner-editor-group" open><summary>Điều hướng khi bấm banner</summary><div className="banner-editor-fields">
<p className="form-hint">Chọn Mở cuộc gọi điện thoại để gán số liên hệ, hoặc Mở màn hình trong app để chọn trang đích. Mỗi nút bấm có hành động riêng.</p>
<BannerActionFields actionType={formActionType} actionValue={formActionValue}
 onTypeChange={type => { setFormActionType(type); setFormActionValue(''); }} onValueChange={setFormActionValue} /></div></details>
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
          )}
        </div>

        {/* Right Column (Sticky): Fixed Mobile Simulator */}
        <div className="banner-right-pane">
          <div className="banner-preview-section">
            <div className="preview-header">
              <div className="preview-title">
                <Smartphone size={18} />
                <span>{showModal ? 'Xem trước trực tiếp' : 'Mô phỏng hiển thị trên App'}</span>
              </div>
              {showModal ? (
                <div className="preview-live-badge">
                  <span className="live-indicator-dot" />
                  <span>Thời gian thực</span>
                </div>
              ) : (
                <div className="preview-device-toggle">
                  <CheckCircle2 size={15} color="#10b981" />
                  <span>Đang hiển thị trên App</span>
                </div>
              )}
            </div>

            {showModal && <div className="preview-canvas-tools">
              <button type="button" disabled={!history.canUndo} onClick={history.undo}>↶ Hoàn tác</button>
              <button type="button" disabled={!history.canRedo} onClick={history.redo}>↷ Làm lại</button>
              <label>Thiết bị<select value={previewDevice} onChange={e => setPreviewDevice(e.target.value)}>
                <option value="390">iPhone · 390px</option><option value="360">Android · 360px</option><option value="430">Màn hình lớn · 430px</option>
              </select></label>
              <label className="canvas-toggle"><input type="checkbox" checked={previewDark} onChange={e => setPreviewDark(e.target.checked)} /> Giao diện tối</label>
            </div>}
            <div className={`mobile-simulator-wrapper ${showModal && previewDark ? 'preview-dark' : ''}`}
              style={showModal ? { width: `${Number(previewDevice) / 430 * 100}%`, marginInline: 'auto' } : undefined}>
              <div className="mobile-simulator-notch" />

              {showModal ? (
                /* Live Preview of Form state */
                (() => {
                  const bannerBg =
                    bgMode === 'CUSTOM_BG'
                      ? getBannerBackgroundStyle(
                          { darkenOverlay: formDarkenOverlay },
                          bgFilePreviewUrl || formBackgroundImageUrl,
                          formDarkenOverlay
                        )
                      : getGradientStyle(formCustomGradient.trim() || formGradient);
                  const mascotSrc =
                    filePreviewUrl ||
                    (formImageUrl || '/image_character.png');
                  const imgPos = formImagePosition || 'RIGHT';

                  return <BannerCanvas design={design} title={formTitle} badge={formBadgeText} subtitle={formSubtitle}
                    buttons={formButtons} mascot={imgPos !== 'NONE' && imageType !== 'none' ? mascotSrc : undefined}
                    background={bannerBg} fontFamily={formFontFamily} editable selected={selectedElement} snap={snapToGrid}
                    onSelect={setSelectedElement} onChange={setDesign} onInteractionStart={history.begin} onInteractionEnd={history.end} />;
                })()
              ) : activeBanners.length > 0 ? (
                (() => {
                  const currentBanner = activeBanners[activePreviewIndex] || activeBanners[0];
                  const savedDesign = parseDesign(currentBanner.designJson);
                  if (savedDesign) return <BannerCanvas design={savedDesign} title={currentBanner.title} badge={currentBanner.badgeText || ''}
                    subtitle={currentBanner.subtitle || ''} buttons={getBannerButtons(currentBanner)}
                    mascot={currentBanner.imagePosition !== 'NONE' ? currentBanner.imageUrl || '/image_character.png' : undefined}
                    background={getBannerBackgroundStyle(currentBanner)} fontFamily={currentBanner.fontFamily || 'Be Vietnam Pro'} />;
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

                        {pos !== 'TOP_RIGHT' &&
                          pos !== 'TOP_LEFT' &&
                          pos !== 'CUSTOM' &&
                          renderBannerButtonsGroup(currentBtns, pos, false)}
                      </div>

                      {imgPos !== 'NONE' && (
                        <img
                          src={mascotSrc}
                          alt="Banner Mascot"
                          className={`stitch-banner-mascot pos-${imgPosClass}`}
                          onError={e => {
                            (e.target as HTMLImageElement).src = '/image_character.png';
                          }}
                        />
                      )}

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

              {!showModal && activeBanners.length > 1 && (
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
              {showModal && <div className="preview-shortcuts">
                <strong>Kéo thả để thiết kế</strong>
                <p>Bấm chữ, mascot hoặc nút để chọn đúng phần Định dạng. Kéo 4 góc của khung nét đứt để đổi kích thước.</p>
                <p><kbd>← ↑ ↓ →</kbd> dịch 1% · <kbd>Shift + mũi tên</kbd> dịch 5% · <kbd>Alt + kéo</kbd> bỏ snap.</p>
                <p>Chọn Mascot để chỉnh thanh Kích thước (%) và Lật ảnh ngang.</p>
              </div>}
          </div>
        </div>
      </div>

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
