source ${cfgprefix}/include.cfg
initmenu()

# next config file to load
function 'nextconfig()' {
  globalexports()
  configfile ${cfgprefix}/boot.cfg
}
