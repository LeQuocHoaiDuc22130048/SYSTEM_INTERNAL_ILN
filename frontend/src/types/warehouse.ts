export interface ActiveCheckoutInfo {
  checkoutId?: string;
  takenBy?: string;
  takenByName?: string;
  takenByEmployeeCode?: string;
  takenAt?: string;
  repairOrderId?: string;
  orderCode?: string;
  quantity?: number;
  repairBrand?: string;
}

export interface Board {
  id: string;
  name: string;
  qrCode: string;
  model: string;
  boardType?: string;
  firmware?: string;
  removedParts?: string;
  receivedDate?: string;
  note?: string;
  location: string;
  status: string;
  checkedOutBy?: string;
  checkedOutAt?: string;
  currentRepairOrder?: string;
  description?: string;
  serialNumber?: string;
  partId?: string;
  partIpn?: string;
  currentLocationId?: string;
  currentLocationCode?: string;
  quantity?: number;
  minQuantity?: number;
  activeCheckoutInfo?: ActiveCheckoutInfo;
}

export interface BoardHistoryItem {
  id: string;
  boardId: string;
  boardName: string;
  qrCode: string;
  takenBy: string;
  takenByName: string;
  takenAt?: string;
  returnedAt?: string;
  repairOrderId?: string;
  notes?: string;
}

export interface PartLot {
  id: string;
  storeLocationId?: string;
  storeLocationCode: string;
  storeLocationName: string;
  amount: number;
  lotCode?: string;
  origin?: string;
  condition?: string;
  expirationDate?: string;
  receivedDate?: string;
}

export interface Part {
  id: string;
  ipn: string;
  name: string;
  description?: string;
  minAmount: number;
  maxAmount?: number;
  purchasePrice?: number;
  salePrice?: number;
  parameters?: string;
  datasheetUrl?: string;
  imageUrl?: string;
  note?: string;
  manufacturingStatus?: string;
  categoryId?: string;
  categoryName?: string;
  footprintId?: string;
  manufacturerId?: string;
  measurementUnitId?: string;
  totalQuantity: number;
  lots: PartLot[];
  createdAt?: string;
}

export interface PartCheckoutHistoryItem {
  id: string;
  partId: string;
  partIpn?: string;
  partName?: string;
  storeLocationId?: string;
  locationCode?: string;
  locationName?: string;
  takenBy: string;
  takenByName?: string;
  takenByEmployeeCode?: string;
  quantity: number;
  returnedQuantity: number;
  takenAt: string;
  returnedAt?: string;
  purpose?: string;
  repairOrderId?: string;
  conditionStatus?: 'GOOD' | 'DAMAGED' | 'REPLACED';
  checkoutStatus: 'OPEN' | 'RETURNED' | 'LOST' | 'DAMAGED';
  notes?: string;
}

export interface LocationPartItem {
  partId: string;
  partLotId: string;
  ipn: string;
  name: string;
  description?: string;
  amount: number;
  unit?: string;
  categoryName?: string;
  imageUrl?: string;
  condition?: string;
}

export interface LocationBoardItem {
  boardId: string;
  qrCode: string;
  name: string;
  model?: string;
  repairBrand?: string;
  category?: string;
  status: string;
  quantity: number;
  minQuantity: number;
  location?: string;
}

export interface LocationScanData {
  locationId: string;
  code: string;
  name: string;
  description?: string;
  qrCode?: string;
  isFull?: boolean;
  parts: LocationPartItem[];
  boards?: LocationBoardItem[];
  totalPartTypes: number;
  totalQuantity: number;
  partTypesCount?: number;
  partQuantity?: number;
  boardTypesCount?: number;
  boardQuantity?: number;
}

export interface LocationInfo {
  id: string;
  code: string;
  name: string;
  description?: string;
  qrCode?: string;
  totalPartTypes?: number;
  totalQuantity?: number;
  partTypesCount?: number;
  partQuantity?: number;
  boardTypesCount?: number;
  boardQuantity?: number;
}

export interface WarehouseTabProps {
  showToast: (msg: string) => void;
  initialMode?: 'ALL' | 'BOARDS' | 'PARTS' | 'LOCATIONS' | 'PART_LOGS';
}

export interface BulkImportPartItem {
  ipn: string;
  name: string;
  categoryName?: string;
  description?: string;
  storeLocationCode?: string;
  quantity?: number;
  minAmount?: number;
  maxAmount?: number;
  purchasePrice?: number;
  salePrice?: number;
  parameters?: string;
  footprint?: string;
  note?: string;
  condition?: string;
}

export interface BulkImportErrorItem {
  rowNumber: number;
  ipn: string;
  errorMessage: string;
}

export interface BulkImportPartResponse {
  totalRows: number;
  successCount: number;
  updatedCount: number;
  failedCount: number;
  errors: BulkImportErrorItem[];
  items: Part[];
}

export interface UnifiedWarehouseItem {
  id: string;
  itemType: 'BOARD' | 'PART';
  name: string;
  code: string;
  qrCode?: string;
  categoryName?: string;
  location: string;
  storeLocationId?: string;
  quantity: number;
  minQuantity?: number;
  unit?: string;
  status: 'AVAILABLE' | 'LOW_STOCK' | 'OUT_OF_STOCK' | 'CHECKED_OUT' | 'MAINTENANCE' | string;
  model?: string;
  description?: string;
  imageUrl?: string;
  holderName?: string;
  updatedAt?: string;
  lots?: {
    id: string;
    storeLocationId?: string;
    storeLocationCode: string;
    storeLocationName: string;
    amount: number;
    condition?: string;
  }[];
}

export interface UnifiedWarehouseSummary {
  totalItems: number;
  totalQuantity: number;
  boardCount: number;
  partCount: number;
  lowStockCount: number;
  outOfStockCount: number;
}

