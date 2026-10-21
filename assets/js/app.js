import { enableDOMTranslation } from './i18n/dom-translator.js?v=7';
import { mountShell } from './components/shell.js';
document.addEventListener('DOMContentLoaded',()=>{mountShell();enableDOMTranslation()});
