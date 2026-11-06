export type FeedbackType = 'SERVICE_QUALITY' | 'WARRANTY_ISSUE' | 'SUGGESTION';

export type FeedbackStatus = 'PENDING' | 'IN_PROGRESS' | 'RESOLVED';

export interface CustomerFeedback {
  id: string;
  orderCode: string;
  customerName: string;
  customerPhone?: string;
  customerCode?: string;
  deviceModel?: string;
  rating: number; // 1 - 5
  type: FeedbackType;
  typeName: string;
  tags: string[];
  content: string;
  images?: string[];
  status: FeedbackStatus;
  statusName: string;
  createdAt: string;
  reply?: string | null;
  replyAt?: string | null;
  repliedBy?: string | null;
  isUrgent: boolean;
}

export interface ReplyFeedbackPayload {
  feedbackId: string;
  status: FeedbackStatus;
  reply: string;
  repliedBy?: string;
}

