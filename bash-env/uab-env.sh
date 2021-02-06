. $HOME/.uab-env/waf-alias.sh
export PATH="$HOME/.tools:$HOME/.uab-env/env-tools/:$PATH"
echo -e "Loading UAB Lab environment: \e[32m[SUCCESS]\e[39m"
$HOME/.uab-env/env-tools/get-student-info.sh
[ -f "$HOME/.uab-env/alumne-env.sh" ] && . $HOME/.uab-env/alumne-env.sh && echo -e "Loading Student info: \e[32m[SUCCESS]\e[39m"
