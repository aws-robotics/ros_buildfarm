@[if os_name == 'ubuntu' and os_code_name in ['saucy', 'utopic', 'vivid', 'wily', 'yakkety', 'zesty', 'artful']]@
RUN find /etc/apt/ -name *.list -exec sed -i -e 's/archive.ubuntu.com\|security.ubuntu.com/old-releases.ubuntu.com/g' {} \;
@[end if]@
