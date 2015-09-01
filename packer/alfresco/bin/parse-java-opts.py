import ConfigParser
import sys

config = ConfigParser.RawConfigParser()
config.optionxform = str

try:
    if len (sys.argv) > 1:
        config.read(sys.argv[1])
    else:
        config.readfp(sys.stdin)

    if config.has_section('JAVA_OPTS'):
        options = config.items('JAVA_OPTS')
        if options is not None:
            print ' '.join(['%s=%s' % item for item in options])

except ConfigParser.MissingSectionHeaderError, e:
    pass