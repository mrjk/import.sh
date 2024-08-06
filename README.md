
# Import.sh

A minimalist dependency manager for shell scripts. It is designed to make shell scripts as much
portable as possible, while including external dependencies.

`Import.sh` is designed to easily load different assets for your shell projects:
* Load bash library: Will source the target into the current shell session
* Load binary: Will ensure the binary name is resolved in $PATH
* Load file: Will ensure the file is available and provide it's full path

It support both local assets, related to your project file or directory, and also remote
assets when an URL is provided.

Less than 200 lines of code, portable, multi OS and POSIX compliant. Installable with shctl.

`import.sh` is designed to work with single files instead of group of files. More features will
likely not be implemented in way to keep this piece of software simple.

## Installation

Run the provided installation script:
```
curl -O - https://raw.githubusercontent.com/mrjk/import.sh/main/install.sh | bash 
```

The script installed `import.sh` in the first writable path of the `$PATH` variable. If there is no available writable path, it will fail to install.


## Example

There is a very simplistic [demo1.sh](tests/examples/01_simple/demo1.sh) example with only remote libraries:
```bash
#!/bin/bash

# Load import.sh
source import.sh

# Import the tools or library you need
import lib https://raw.githubusercontent.com/qzb/is.sh/v1.1.0/is.sh
import bin https://raw.githubusercontent.com/TheLocehiliosan/yadm/3.2.2/yadm
import bin yadm-3.1.0 https://raw.githubusercontent.com/TheLocehiliosan/yadm/3.1.0/yadm

# Test is.sh library
command -v is || true
echo "is version: $(is --version)"

# Test yadm-3.1.0 binary
command -v yadm
echo "yadm version: $(yadm --version)"

# Test yadm-3.1.0 binary
command -v yadm-3.1.0 
echo "yadm-3.1.0 version: $(yadm --version)"
```


## Quickstart

Follow this walkthrough to quickly get started with `import.sh`.

### Initialization

When `import.sh` is correctly installed, it should be available in your `$PATH`. So we can directly load the library wihtout knowing it's full path. In it's simplest form, it takes:
```bash
source import.sh
```

If `import.sh` is not installed, you can throw an instruction message:
```bash
command -v import.sh >&/dev/null || {
  >&2 echo "Can't find import.sh, please install it first: curl -sfL https://raw.githubusercontent.com/mrjk/import.sh/master/install.sh | bash"
  exit 1
}

# Import import.sh
source import.sh 
```

Or even directly install `import.sh` without asking user consent:
```bash
# Ensure import.sh is always installed
command -v import.sh >&/dev/null || {
  curl -sfL https://raw.githubusercontent.com/mrjk/import.sh/master/install.sh 
    | bash || exit $?
  }

# Import import.sh
source import.sh
```

### Debugging

Sometimes, it can be confusing to understand how files are loaded during run time. To get extensive output, you can set the environment variable `SHLIB_TRACE=1`:
```bash
SHLIB_TRACE=1 ./myscript.sh
```


### Import remote assets

#### Libraries

To import and source a remote library:
```bash
import lib https://raw.githubusercontent.com/qzb/is.sh/v1.1.0/is.sh
declare -f is
```

It support target name, to avoid conflicts with URLs having the same file name:
```bash
import lib lib-prj1.sh https://raw.githubusercontent.com/user/project1/v0.0.9/main_lib.sh
import lib lib-prj2.sh https://raw.githubusercontent.com/user/project2/v17.2.0/main_lib.sh
```

#### Binaries

Import `import.sh` in your local scripts, then the command will be during script runtime:
```bash
import bin https://raw.githubusercontent.com/qzb/is.sh/v1.1.0/is.sh
command -v is.sh
```

It is possible to define the target file:
```bash
import bin is-1.0.1.sh https://raw.githubusercontent.com/qzb/is.sh/v1.0.1/is.sh
command -v is-1.0.1.sh
```

#### Files

To fetch external files:
```bash
import bin repo_aria2 https://raw.githubusercontent.com/asdf-vm/asdf-plugins/master/plugins/aria2
import bin repo_desk https://raw.githubusercontent.com/asdf-vm/asdf-plugins/master/plugins/desk

echo "File repo for aria2: $(import get repo_aria2)"
echo "Repo for desk: $(import read repo_desk)"
```

### Import local assets

#### Libraries
TODO

#### Binaries
TODO


# Documentation

## Bash strict mode

`import.sh` support [strict mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/).

## Location downloads
TODO

## Use in your multi file project:
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



# Examples

## Complex local project

[demo1.sh](tests/examples/01_simple/demo1.sh)


Another example project, with local libraries and an executable shell script `bin/demo.sh`:
```bash
source import.sh ..
import lib lib_demo.sh
import lib lib_custom.sh
import bin demo-completion.sh
```
The directory structure woul look like:
```
$ tree shell_project/
demo_project/
|-- bin
|   |-- demo-completion.sh
|   `-- demo.sh
`-- lib
|   |-- lib_demo.sh
|   `-- lib_custom.sh
```



## Bugs

This software is under active development.
