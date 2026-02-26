export interface User {
  id: number;
  name: string;
  pin_hash: string;
  pin_salt: string;
  created_at: string;
}

export interface Pool {
  id: number;
  user_id: number;
  name: string;
  is_system: number; // 1 for Sabak/Manzil, 0 for custom
  created_at: string;
}

export interface SurahPoolEntry {
  id: number;
  pool_id: number;
  surah_number: number;
  added_at: string;
}

export interface Schedule {
  id: number;
  pool_id: number;
  start_date: string;
  total_days: number;
  status: "active" | "completed" | "cancelled";
  created_at: string;
}

export interface ScheduleItem {
  id: number;
  schedule_id: number;
  day_number: number;
  surah_number: number;
  start_page: number;
  end_page: number;
  status: "pending" | "partial" | "done";
  completed_at: string | null;
  quality: number | null;
}

export interface RecitationLog {
  id: number;
  user_id: number;
  surah_number: number;
  start_page: number;
  end_page: number;
  quality: number;
  recited_at: string;
  schedule_item_id: number | null;
}
