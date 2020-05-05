
# Import.sh

A minimalist way to source shell libraries from project directory to default user home library. Can be used in both script and interactive shell. Less than 200 lines of code, portable, multi OS and POSIX compliant. Installable with shctl.


## Usage

Import `import.sh` in your local scripts:
```
source import.sh
import is.sh
```


Import `import.sh` in your interactive shell:
```
# Import import.sh
source import.sh || \
  >&2 echo "Can not load import.sh."

# This part is really import to avoid shell
# to exit on any error.
set +eu

# See also: shell/bash/import.lib.sh
```

# Use in your multi file project:
```
# In any binaries, you can mention the relative
# lookup path

source import.sh ../lib
import is.sh
import myapp_lib1.sh
import myapp_lib2.sh
```

Determine the library lookup path:
```
# Determine library inatallation path
export SHLIB_PATH_SHARED="$BASHER_PREFIX/lib/bash"

```

To embed this library, just past the content of `bin/import.sh` it at the header of your script.


## Bugs

This software is under active development.
