source ${prefix}/include.cfg
initmenu()

set default=${kbnum}

# next config file to load
function 'nextconfig()' {
  globalexports()
  cheatcodeexports()
  configfile ${prefix}/boot.cfg
}

