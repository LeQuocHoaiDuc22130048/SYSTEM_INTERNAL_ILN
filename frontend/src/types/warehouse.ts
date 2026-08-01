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
  lotCode: string;
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
  manufacturingStatus: string;
  categoryId?: string;
  categoryName?: string;
  footprintId?: string;
  manufacturerId?: string;
  measurementUnitId?: string;
  totalQuantity: number;
  lots: PartLot[];
  createdAt?: string;
}


export interface WarehouseTabProps {
  showToast: (msg: string) => void;
}
