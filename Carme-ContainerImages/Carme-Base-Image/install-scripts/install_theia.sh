#!/bin/bash
#-----------------------------------------------------------------------------------------------------------------------------------
# Copyright 2022 by CarmeTeam @ CC-HPC Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
#-----------------------------------------------------------------------------------------------------------------------------------


# install theia.ide and basic plugins ----------------------------------------------------------------------------------------------

# activate package manager
PACKAGE_INSTALL_PATH="/opt/package-manager"
PATH_TO_CONDA_BIN="${PACKAGE_INSTALL_PATH}/bin/conda"
[[ -f "${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh" ]] && source "${PACKAGE_INSTALL_PATH}/etc/profile.d/conda.sh"
[[ -f "${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh" ]] && source "${PACKAGE_INSTALL_PATH}/etc/profile.d/mamba.sh"


if command -v "mamba" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="mamba"
elif command -v "conda" >/dev/null 2>&1 ;then
  PACKAGE_MANAGER="conda"
else
  echo "ERROR: neither 'mamba' nor 'conda' seams to be installed"
  exit 200
fi


# activate base environment
"${PACKAGE_MANAGER}" activate base


# enter theia install folder
THEIA_INSTALL_DIR="/opt/theia-ide"
mkdir "${THEIA_INSTALL_DIR}"
cd "${THEIA_INSTALL_DIR}" || exit 200


# install theia system dependencies
# NOTE: that this installs python3 in the base image as well
apt install -y libsecret-1-dev


# install 'yarn' and 'nodejs'
"${PACKAGE_MANAGER}" install -y -c conda-forge yarn=1 nodejs=12


# write theia package file
THEIA_VERSION="1.22.1"
CODE_MAIN_PLUGINS_VERSION="1.62.3"
EDITORCONFIG_VERSION="0.16.6"
REV_VIEW_VERSION="0.0.85"
SHELLCHECK_VERSION="0.18.7"
MS_PYTHON_VERSION="2020.9.112786"
PY_INDENT_VERSION="1.14.2"

echo "{
  \"theia\": {
    \"frontend\": {
      \"config\": {
        \"applicationName\": \"CARME IDE\",
        \"preferences\": {
           \"terminal.integrated.cursorBlinking\": true,
           \"python.condaPath\": \"${PATH_TO_CONDA_BIN}\"
        },
        \"warnOnPotentiallyInsecureHostPattern\": false
      }
    }
  },
  \"private\": true,
  \"dependencies\": {
    \"@theia/callhierarchy\": \"${THEIA_VERSION}\",
    \"@theia/editor-preview\": \"${THEIA_VERSION}\",
    \"@theia/file-search\": \"${THEIA_VERSION}\",
    \"@theia/keymaps\": \"${THEIA_VERSION}\",
    \"@theia/messages\": \"${THEIA_VERSION}\",
    \"@theia/mini-browser\": \"${THEIA_VERSION}\",
    \"@theia/plugin-ext\": \"${THEIA_VERSION}\",
    \"@theia/plugin-ext-vscode\": \"${THEIA_VERSION}\",
    \"@theia/preferences\": \"${THEIA_VERSION}\",
    \"@theia/preview\": \"${THEIA_VERSION}\",
    \"@theia/scm\": \"${THEIA_VERSION}\",
    \"@theia/scm-extra\": \"${THEIA_VERSION}\",
    \"@theia/search-in-workspace\": \"${THEIA_VERSION}\",
    \"@theia/terminal\": \"${THEIA_VERSION}\",
    \"@theia/timeline\": \"${THEIA_VERSION}\",
    \"@theia/typehierarchy\": \"${THEIA_VERSION}\",
    \"@theia/vsx-registry\": \"${THEIA_VERSION}\"
  },
  \"devDependencies\": {
    \"@theia/cli\": \"${THEIA_VERSION}\"
  },
  \"scripts\": {
    \"prepare\": \"yarn run clean && yarn build && yarn run download:plugins\",
    \"clean\": \"theia clean\",
    \"build\": \"theia build --mode development\",
    \"start\": \"theia start --plugins=local-dir:plugins\",
    \"download:plugins\": \"theia download:plugins\"
  },
  \"theiaPluginsDir\": \"plugins\",
  \"theiaPlugins\": {
    \"vscode-builtin-configuration-editing\": \"http://open-vsx.org/api/vscode/configuration-editing/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.configuration-editing-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-debug-auto-launch\": \"http://open-vsx.org/api/vscode/debug-auto-launch/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.debug-auto-launch-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-cpp\": \"http://open-vsx.org/api/vscode/cpp/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.cpp-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-css\": \"http://open-vsx.org/api/vscode/css/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.css-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-go\": \"http://open-vsx.org/api/vscode/go/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.go-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-html\": \"http://open-vsx.org/api/vscode/html/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.html-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-javascript\": \"http://open-vsx.org/api/vscode/javascript/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.javascript-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-json\": \"http://open-vsx.org/api/vscode/json/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.json-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-log\": \"http://open-vsx.org/api/vscode/log/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.log-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-lua\": \"http://open-vsx.org/api/vscode/lua/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.lua-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-make\": \"http://open-vsx.org/api/vscode/make/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.make-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-markdown\": \"http://open-vsx.org/api/vscode/markdown/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.markdown-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-perl\": \"http://open-vsx.org/api/vscode/perl/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.perl-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-python\": \"http://open-vsx.org/api/vscode/python/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.python-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-r\": \"http://open-vsx.org/api/vscode/r/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.r-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-ruby\": \"http://open-vsx.org/api/vscode/ruby/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.ruby-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-shellscript\": \"http://open-vsx.org/api/vscode/shellscript/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.shellscript-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-sql\": \"http://open-vsx.org/api/vscode/sql/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.sql-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-xml\": \"http://open-vsx.org/api/vscode/xml/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.xml-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-builtin-yaml\": \"http://open-vsx.org/api/vscode/yaml/${CODE_MAIN_PLUGINS_VERSION}/file/vscode.yaml-${CODE_MAIN_PLUGINS_VERSION}.vsix\",
    \"vscode-editorconfig\": \"https://open-vsx.org/api/EditorConfig/EditorConfig/${EDITORCONFIG_VERSION}/file/EditorConfig.EditorConfig-${EDITORCONFIG_VERSION}.vsix\",
    \"vscode-references-view\": \"http://open-vsx.org/api/ms-vscode/references-view/${REV_VIEW_VERSION}/file/ms-vscode.references-view-${REV_VIEW_VERSION}.vsix\",
    \"vscode-shellcheck\": \"https://open-vsx.org/api/timonwong/shellcheck/${SHELLCHECK_VERSION}/file/timonwong.shellcheck-${SHELLCHECK_VERSION}.vsix\",
    \"vscode-ms-python\": \"https://open-vsx.org/api/ms-python/python/${MS_PYTHON_VERSION}/file/ms-python.python-${MS_PYTHON_VERSION}.vsix\",
    \"vscode-python-indent\": \"https://open-vsx.org/api/KevinRose/vsc-python-indent/${PY_INDENT_VERSION}/file/KevinRose.vsc-python-indent-${PY_INDENT_VERSION}.vsix\"
  }
}" > "package.json"


# build theia
yarn
yarn theia build


# fix theia index html file to work behind the proxy
echo "<!DOCTYPE html>
<html>

<head>
  <meta charset=\"UTF-8\">
  <script type=\"text/javascript\">
    var elBase = document.createElement('base');
    elBase.href = document.location.origin + document.location.pathname + '/';
    document.head.appendChild(elBase);

    var elScript = document.createElement('script');
    elScript.type = 'text/javascript';
    elScript.src = './bundle.js';
    document.head.appendChild(elScript);
  </script>
</head>

<body>
  <div class=\"theia-preload\"></div>
</body>

</html>" > "lib/index.html"

cd || exit 200


# clean up
rm -r /usr/local/share/.cache

apt autoremove --purge -y
apt clean
"${PACKAGE_MANAGER}" clean --all -y
#-----------------------------------------------------------------------------------------------------------------------------------
