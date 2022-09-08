"use strict";

var CONFIG = {
  theme: 'light',
  isFluid: false
};

Object.keys(CONFIG).forEach(function (key) {
  if (localStorage.getItem(key) === null) {
    localStorage.setItem(key, CONFIG[key]);
  }
});

if (localStorage.getItem('theme') === 'dark') {
  document.documentElement.classList.add('dark');
}
//# sourceMappingURL=config.min.js.map
