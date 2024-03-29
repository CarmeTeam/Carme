"use strict";


/* -------------------------------------------------------------------------- */
/*                                     Base                                   */
/* -------------------------------------------------------------------------- */
function _classCallCheck(instance, Constructor) { 
		if (!(instance instanceof Constructor)) { 
				throw new TypeError("Cannot call a class as a function"); 
		} 
}

function _defineProperties(target, props) { 
		for (var i = 0; i < props.length; i++) { 
				var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; 
				if ("value" in descriptor) descriptor.writable = true; 
				Object.defineProperty(target, descriptor.key, descriptor); 
		} 
}

function _createClass(Constructor, protoProps, staticProps) { 
		if (protoProps) _defineProperties(Constructor.prototype, protoProps); 
		if (staticProps) _defineProperties(Constructor, staticProps); 
		return Constructor; 
}


/* -------------------------------------------------------------------------- */
/*                                    Utils                                   */
/* -------------------------------------------------------------------------- */

var docReady = function docReady(fn) {
  // see if DOM is already available
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', fn);
  } else {
    setTimeout(fn, 1);
  }
};

var camelize = function camelize(str) {
  var text = str.replace(/[-_\s.]+(.)?/g, function (_, c) {
    return c ? c.toUpperCase() : '';
  });
  return "".concat(text.substr(0, 1).toLowerCase()).concat(text.substr(1));
};

var getData = function getData(el, data) {
  try {
    return JSON.parse(el.dataset[camelize(data)]);
  } catch (e) {
    return el.dataset[camelize(data)];
  }
};


/* -------------------------------------------------------------------------- */
/*                                   Store                                    */
/* -------------------------------------------------------------------------- */
var getItemFromStore = function getItemFromStore(key, defaultValue) {
  var store = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : localStorage;

  try {
    return JSON.parse(store.getItem(key)) || defaultValue;
  } catch (_unused) {
    return store.getItem(key) || defaultValue;
  }
};

var setItemToStore = function setItemToStore(key, payload) {
  var store = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : localStorage;
  return store.setItem(key, payload);
};


var utils = {
  docReady: docReady,
  camelize: camelize,
  getData: getData
};



/* -------------------------------------------------------------------------- */
/*                                  DomNode                                   */
/* -------------------------------------------------------------------------- */
var DomNode = /*#__PURE__*/function () {
  function DomNode(node) {
    _classCallCheck(this, DomNode);

    this.node = node;
  }

  _createClass(DomNode, [{
    key: "data",
    value: function data(key) {
      if (this.isValidNode()) {
        try {
          return JSON.parse(this.node.dataset[this.camelize(key)]);
        } catch (e) {
          return this.node.dataset[this.camelize(key)];
        }
      }

      return null;
    }
  }, {
    key: "on",
    value: function on(event, cb) {
      this.isValidNode() && this.node.addEventListener(event, cb);
    }
  }, {
    key: "isValidNode",
    value: function isValidNode() {
      return !!this.node;
    } // eslint-disable-next-line class-methods-use-this

  }, {
    key: "camelize",
    value: function camelize(str) {
      var text = str.replace(/[-_\s.]+(.)?/g, function (_, c) {
        return c ? c.toUpperCase() : '';
      });
      return "".concat(text.substr(0, 1).toLowerCase()).concat(text.substr(1));
    }
  }]);

  return DomNode;
}();



/* -------------------------------------------------------------------------- */
/*                        Theme Control: Dark-Mode                            */
/* -------------------------------------------------------------------------- */
var initialDomSetup = function initialDomSetup(element) {
  if (!element) return;
  element.querySelectorAll('[data-theme-control]').forEach(function (el) {
    var inputDataAttributeValue = getData(el, 'theme-control');
    var localStorageValue = getItemFromStore(inputDataAttributeValue);

    if (el.type === 'checkbox') {
      if (inputDataAttributeValue === 'theme') {
        localStorageValue === 'dark' && el.setAttribute('checked', true);
      } else {
        localStorageValue && el.setAttribute('checked', true);
      }
    } else {
      var isChecked = localStorageValue === el.value;
      isChecked && el.setAttribute('checked', true);
    }
  });
};

var changeTheme = function changeTheme(element) {
  element.querySelectorAll('[data-theme-control = "theme"]').forEach(function (el) {
    var inputDataAttributeValue = getData(el, 'theme-control');
    var localStorageValue = getItemFromStore(inputDataAttributeValue);

    if (el.type === 'checkbox') {
      localStorageValue === 'dark' ? el.checked = true : el.checked = false;
    } else {
      localStorageValue === el.value ? el.checked = true : el.checked = false;
    }
  });
};

var themeControl = function themeControl() {
  var themeController = new DomNode(document.body);
  initialDomSetup(themeController.node);
  themeController.on('click', function (e) {
    var target = new DomNode(e.target);
    
    if (target.data('theme-control')) {
      var control = target.data('theme-control');
      var value = e.target[e.target.type === 'radio' ? 'value' : 'checked'];
      
      if (control === 'theme') {
        typeof value === 'boolean' && (value = value ? 'dark' : 'light');
      }

      setItemToStore(control, value);

      switch (control) {
        case 'theme':
          {
            document.documentElement.classList[value === 'dark' ? 'add' : 'remove']('dark');
            var clickControl = new CustomEvent('clickControl', {
              detail: {
                control: control,
                value: value
              }
            });
            e.currentTarget.dispatchEvent(clickControl);
            changeTheme(themeController.node);
            break;
          }

        default:
          window.location.reload();
      }
    }
  });
};

docReady(themeControl);


/* -------------------------------------------------------------------------- */
/*                          Container: Fluid-Mode                             */
/* -------------------------------------------------------------------------- */
var isFluid = JSON.parse(localStorage.getItem('isFluid'));
if (isFluid) {
  var container = document.querySelector('[data-layout]');
  var container_header = document.querySelector('[data-layout-header]');
  var container_footer = document.querySelector('[data-layout-footer]');
  container.classList.remove('container');
  container.classList.add('container-fluid');
  container_header.classList.remove('container');
  container_header.classList.add('container-fluid');
  container_footer.classList.remove('container');
  container_footer.classList.add('container-fluid');
};


//# sourceMappingURL=theme.min.js.map
