export const storage = {
  get(key, fallback=null){ try { const v=localStorage.getItem(key); return v===null?fallback:JSON.parse(v); } catch { return fallback; } },
  set(key, value){ localStorage.setItem(key, JSON.stringify(value)); return value; },
  remove(key){ localStorage.removeItem(key); }
};
