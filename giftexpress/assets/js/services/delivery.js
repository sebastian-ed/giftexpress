export function resolveDelivery(zones,{district='',postalCode='',subtotal=0,now=new Date()}){
  const norm=s=>String(s||'').trim().toLowerCase();
  const zone=zones.find(z=>z.active!==false&&(z.districts||[]).some(d=>norm(d)===norm(district))||(z.active!==false&&(z.postal_codes||[]).includes(String(postalCode).trim())));
  if(!zone)return {eligible:false,message:'La dirección está fuera de la cobertura configurada.'};
  if(subtotal<(zone.min_order_ars||0))return {eligible:false,zone,message:`El pedido mínimo para ${zone.name} es $${Number(zone.min_order_ars).toLocaleString('es-AR')}.`};
  const day=now.getDay();const [h,m]=(zone.cutoff||'17:00').split(':').map(Number);const cutoff=new Date(now);cutoff.setHours(h,m,0,0);
  let deliveryDate=new Date(now);let sameDay=(zone.days||[]).includes(day)&&now<=cutoff;
  if(!sameDay){do{deliveryDate.setDate(deliveryDate.getDate()+1)}while(!(zone.days||[]).includes(deliveryDate.getDay()));}
  const fee=subtotal>=(zone.free_over_ars||Infinity)?0:(zone.price_ars||0);
  return {eligible:true,zone,fee,sameDay,deliveryDate,message:sameDay?`Entrega hoy · ${zone.eta||''}`:`Entrega ${deliveryDate.toLocaleDateString('es-AR',{weekday:'long',day:'numeric',month:'short'})} · ${zone.eta||''}`};
}
