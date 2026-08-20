export type GiveawayStatus = 'draft' | 'active' | 'completed';
export type TicketCount = 1 | 3;
export interface Giveaway { id:string; title:string; start_date:string; end_date:string; status:GiveawayStatus; created_at:string; }
export interface Participant { id:string; giveaway_id:string; username:string; tickets:TicketCount; created_at:string; updated_at:string; }
export interface Draw { id:string; giveaway_id:string; winner_participant_id:string; winner_username:string; drawn_at:string; participant_count:number; ticket_count:number; round_number:number; }
export interface Profile { id:string; email:string|null; role:'admin'|'user'; }
export interface DrawResult { draw_id:string; winner_participant_id:string; winner_username:string; participant_count:number; ticket_count:number; drawn_at:string; round_number:number; }
