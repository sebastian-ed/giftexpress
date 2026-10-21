import { enableDOMTranslation } from './i18n/dom-translator.js';
import { mountShell } from './components/shell.js';
document.addEventListener('DOMContentLoaded',()=>{mountShell();enableDOMTranslation()});
