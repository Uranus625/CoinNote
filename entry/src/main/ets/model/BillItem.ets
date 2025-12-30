export interface BillItem {
  id: number;
  type: string;
  amount: number;
  date: string; // YYYY/M/D
  payType: string;
  tags: string[];
  isReimbursable: boolean;
  note: string;
  direction: 'expense' | 'income';
}
