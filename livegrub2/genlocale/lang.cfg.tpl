source ${prefix}/include.cfg
initmenu()

# next config file to load
function 'nextconfig()' {
  globalexports()
  configfile ${prefix}/boot.cfg
}
