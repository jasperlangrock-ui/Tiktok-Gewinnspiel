export function normalizeUsername(value:string){let v=value.trim(); if(!v) return ''; if(!v.startsWith('@')) v='@'+v; return v;}
export function formatDate(value:string){return new Intl.DateTimeFormat('de-DE',{dateStyle:'medium'}).format(new Date(value));}
export function formatDateTime(value:string){return new Intl.DateTimeFormat('de-DE',{dateStyle:'medium',timeStyle:'short'}).format(new Date(value));}
export function plural(n:number,singular:string,plural=singular+'e'){return `${n} ${n===1?singular:plural}`;}
