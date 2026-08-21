(function(){'use strict';
const $=id=>document.getElementById(id);let active=false;
function isCars(){const s=$('category');if(!s)return false;const o=s.options[s.selectedIndex];return /\bcars?\b|السيارات/i.test((o?.textContent||'')+' '+(o?.dataset?.slug||''))}
function option(v,label){const o=document.createElement('option');o.value=v;o.textContent=label||v;return o}
function setup(){const brand=$('brand'),model=$('model'),category=$('category');if(!brand||!model||!category||!window.BINGO_CARS)return;
 const brandWrap=brand.closest('div')||brand.parentElement,modelWrap=model.closest('div')||model.parentElement;
 const make=document.createElement('select');make.id='carMakeSelect';make.className=brand.className;make.hidden=true;make.append(option('','Select make / اختر الشركة'));
 Object.keys(BINGO_CARS).sort((a,b)=>a.localeCompare(b)).forEach(x=>make.append(option(x)));
 const mod=document.createElement('select');mod.id='carModelSelect';mod.className=model.className;mod.hidden=true;mod.append(option('','Select model / اختر الموديل'));
 brand.insertAdjacentElement('afterend',make);model.insertAdjacentElement('afterend',mod);
 function fillModels(selected){mod.innerHTML='';mod.append(option('','Select model / اختر الموديل'));(BINGO_CARS[selected]||[]).forEach(x=>mod.append(option(x)));mod.disabled=!selected;if(selected&&brand.value!==selected)brand.value=selected;model.value=''}
 function mode(){active=isCars();brand.hidden=active;model.hidden=active;make.hidden=!active;mod.hidden=!active;if(active){brandWrap?.classList.add('bingo-car-selector');modelWrap?.classList.add('bingo-car-selector');if(brand.value&&BINGO_CARS[brand.value]){make.value=brand.value;fillModels(brand.value);if(model.value){mod.value=model.value}}}else{brandWrap?.classList.remove('bingo-car-selector');modelWrap?.classList.remove('bingo-car-selector')}}
 make.addEventListener('change',()=>fillModels(make.value));mod.addEventListener('change',()=>{model.value=mod.value});category.addEventListener('change',mode);mode();
 const form=$('listingForm');form?.addEventListener('submit',()=>{if(active){brand.value=make.value;model.value=mod.value}},true);
}
document.readyState==='loading'?document.addEventListener('DOMContentLoaded',setup,{once:true}):setup();
})();
