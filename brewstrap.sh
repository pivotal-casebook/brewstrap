#!/usr/bin/env bash

BREWSTRAP_BASE="https://github.com/schubert/brewstrap"
BREWSTRAP_BIN="${BREWSTRAP_BASE}/raw/master/bin/brewstrap.sh"
HOMEBREW_URL="https://gist.github.com/raw/323731/install_homebrew.rb"
RVM_URL="https://rvm.beginrescueend.com/install/rvm"
RVM_RUBY_VERSION="ruby-1.9.2-p290"
XCODE_SHA="2a67c713ab1ef7a47356ba86445f6e630c674b17"
XCODE_URL="http://developer.apple.com/downloads/download.action?path=Developer_Tools/xcode_4.1_for_lion/xcode_4.1_for_lion.dmg"
clear

TOTAL=9
STEP=1
function print_step() {
  echo -e "\033[1m($(( STEP++ ))/${TOTAL}) ${1}\033[0m\n"
}

echo -e "\033[1m\nStarting brewstrap...\033[0m\n"
echo -e "\n"
echo -e "Brewstrap will make sure your machine is bootstrapped and ready to run chef"
echo -e "by making sure XCode, Homebrew and RVM and chef are installed. From there it will"
echo -e "kick off a chef-solo run using whatever chef repository of cookbooks you point it at."
echo -e "\n"
echo -e "It expects the chef repo to exist as a public or private repository on github.com"
echo -e "\n"

[[ -s "$HOME/.brewstraprc" ]] && source "$HOME/.brewstraprc"


print_step "Collecting information.."
if [ -z $GITHUB_LOGIN ]; then
  echo -n "Github Username: "
  stty echo
  read GITHUB_LOGIN
  echo ""
fi

if [ -z $GITHUB_PASSWORD ]; then
  echo -n "Github Password: "
  stty -echo
  read GITHUB_PASSWORD
  echo ""
fi

if [ -z $GITHUB_TOKEN ]; then
  echo -n "Github Token: "
  stty echo
  read GITHUB_TOKEN
  echo ""
fi

if [ -z $PRIVATE_REPO ]; then
  echo -n "Private Chef Repo (Take the github HTTP URL): "
  stty echo
  read PRIVATE_REPO
  echo ""
fi
stty echo

rm -f $HOME/.brewstraprc
echo "GITHUB_LOGIN=${GITHUB_LOGIN}" >> $HOME/.brewstraprc
echo "GITHUB_PASSWORD=${GITHUB_PASSWORD}" >> $HOME/.brewstraprc
echo "GITHUB_TOKEN=${GITHUB_TOKEN}" >> $HOME/.brewstraprc
echo "PRIVATE_REPO=${PRIVATE_REPO}" >> $HOME/.brewstraprc

if [ ! -e /usr/local/bin/brew ]; then
  print_step "Installing homebrew"
  ruby -e "$(curl -fsSL ${HOMEBREW_URL})"
else
  print_step "Homebrew already installed"
fi

if [ ! -d /Developer/Applications/Xcode.app ]; then
  print_step "Installing Xcode"
  XCODE_DMG=`ls -c1 ~/Downloads/xcode*.dmg | tail -n1`
  cd `dirname $0`
  mkdir -p /Volumes/Xcode
  hdiutil attach -mountpoint /Volumes/Xcode $XCODE_DMG
  MPKG_PATH=`find /Volumes/Xcode | grep .mpkg | head -n1`
  sudo installer -verbose -pkg "${MPKG_PATH}" -target /
  hdiutil detach -Force /Volumes/Xcode
else
  print_step "Xcode already installed"
fi

GIT_PATH=`which git`
if [ $? != 0 ]; then
  print_step "Brew installing git"
  brew install git
else
  print_step "Git already installed"
fi

if [ ! -e ~/.rvm/bin/rvm ]; then
  print_step "Installing RVM"
  bash < <( curl -fsSL ${RVM_URL} )
else
  print_step "RVM already installed"
fi

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

if [ ! -e ~/.bash_profile ]; then
    echo "[[ -s \"\$HOME/.rvm/scripts/rvm\" ]] && source \"\$HOME/.rvm/scripts/rvm\"" > ~/.bash_profile
fi

rvm list | grep ruby-1.9.2
if [ $? -gt 0 ]; then
  print_step "Installing RVM Ruby ${RVM_RUBY_VERSION}"
  rvm install ${RVM_RUBY_VERSION}
else
  print_step "RVM Ruby ${RVM_RUBY_VERSION} already installed"
fi

rvm ${RVM_RUBY_VERSION} exec gem specification --version '>=0.9.12' chef 2>&1 | awk 'BEGIN { s = 0 } /^name:/ { s = 1; exit }; END { if(s == 0) exit 1 }'
if [ $? -gt 0 ]; then
  print_step "Installing chef gem"
  sh -c "rvm ${RVM_RUBY_VERSION} exec gem install chef"
else
  print_step "Chef already installed"
fi

if [ ! -d /tmp/chef ]; then
  print_step "Cloning private chef repo"
  git clone ${PRIVATE_REPO} /tmp/chef
else
  print_step "Updating private chef repo (password will be your github account password)"
  if [ -e /tmp/chef/.rvmrc ]; then
    rvm rvmrc trust /tmp/chef/
  fi
  cd /tmp/chef && git pull
fi

print_step "Kicking off chef-solo (password will be your local user password)"
sudo -E env GITHUB_PASSWORD=$GITHUB_PASSWORD GITHUB_LOGIN=$GITHUB_LOGIN GITHUB_TOKEN=$GITHUB_TOKEN rvm ${RVM_RUBY_VERSION} exec chef-solo -l debug -j /tmp/chef/node.json -c /tmp/chef/solo.rb
