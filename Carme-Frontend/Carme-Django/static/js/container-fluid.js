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
}