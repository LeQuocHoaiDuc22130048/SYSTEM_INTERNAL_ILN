export type QuotationStatus =
  | 'DRAFT'
  | 'SENT'
  | 'PARTIAL_APPROVED'
  | 'APPROVED'
  | 'REJECTED'
  | 'EXPIRED'
  | 'CANCELLED';

export type QuotationItemDecision = 'PENDING' | 'APPROVED' | 'REJECTED';

export type PaymentProofStatus = 'PENDING_VERIFY' | 'VERIFIED' | 'REJECTED';

export interface DiagnosedErrorDto {
  label: string;
  severity?: string;
}

export interface WarrantyOptionDto {
  code: string;
  label: string;
  description?: string;
  months: number;
  fee: number;
}

export interface QuotationLineItemResponse {
  id: string;
  description: string;
  quantity: number;
  unitPrice: number;
  amount: number;
  sortOrder: number;
}

export interface QuotationItemResponse {
  id: string;
  repairOrderId: string;
  orderCode: string;
  deviceName: string;
  deviceType?: string | null;
  serialNumber?: string | null;
  diagnosedErrors: DiagnosedErrorDto[];
  lineItems: QuotationLineItemResponse[];
  baseCost: number;
  warrantyOptions: WarrantyOptionDto[];
  selectedWarrantyCode?: string | null;
  selectedWarrantyLabel?: string | null;
  warrantyFee: number;
  finalAmount: number;
  decision: QuotationItemDecision;
  decisionLabel: string;
  rejectReason?: string | null;
  decidedAt?: string | null;
}

export interface PaymentProofResponse {
  id: string;
  quotationId: string;
  amount: number;
  transferContent: string;
  proofFileUrl: string;
  proofFileName?: string | null;
  note?: string | null;
  status: PaymentProofStatus;
  statusLabel: string;
  verifiedBy?: string | null;
  verifiedAt?: string | null;
  rejectionReason?: string | null;
  createdAt: string;
}

export interface QuotationBankInfoResponse {
  bankName: string;
  bankBin: string;
  bankAccountNumber: string;
  bankAccountHolder: string;
  transferContent: string;
  transferAmount: number;
  vietQrPayload: string;
}

export interface QuotationResponse {
  id: string;
  quoteCode: string;
  customerId: string;
  customerName: string;
  customerPhone?: string | null;
  title?: string | null;
  note?: string | null;
  status: QuotationStatus;
  statusLabel: string;
  totalEstimatedAmount: number;
  totalApprovedAmount: number;
  sentAt?: string | null;
  respondedAt?: string | null;
  expiresAt?: string | null;
  createdAt: string;
  itemCount: number;
  approvedItemCount: number;
  rejectedItemCount: number;
  pendingItemCount: number;
  bankInfo?: QuotationBankInfoResponse | null;
  items: QuotationItemResponse[];
  paymentProofs: PaymentProofResponse[];
}

export interface PendingQuotationOrderResponse {
  id: string;
  orderCode: string;
  deviceName: string;
  deviceType?: string | null;
  serialNumber?: string | null;
  status: string;
  statusLabel: string;
  receivedAt?: string | null;
  description?: string | null;
}

export interface CreateQuotationLineItemRequest {
  description: string;
  quantity: number;
  unitPrice: number;
}

export interface CreateQuotationItemRequest {
  repairOrderId: string;
  diagnosedErrors: DiagnosedErrorDto[];
  lineItems: CreateQuotationLineItemRequest[];
  warrantyOptions?: WarrantyOptionDto[];
}

export interface CreateQuotationRequest {
  customerId?: string;
  title?: string;
  note?: string;
  expiresAt?: string;
  sendImmediately?: boolean;
  items: CreateQuotationItemRequest[];
}

export interface QuotationItemDecisionRequest {
  quotationItemId: string;
  decision: QuotationItemDecision;
  selectedWarrantyCode?: string;
  rejectReason?: string;
}

export interface RespondQuotationRequest {
  items: QuotationItemDecisionRequest[];
}

