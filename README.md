# Crosstool-NG

[![Build Status][travis-status]][travis]

[![Throughput Graph](https://graphs.waffle.io/crosstool-ng/crosstool-ng/throughput.svg)](https://waffle.io/crosstool-ng/crosstool-ng/metrics/throughput)

[![Stories in Ready](https://badge.waffle.io/crosstool-ng/crosstool-ng.png?label=ready&title=Ready)](https://waffle.io/crosstool-ng/crosstool-ng) [![Stories in Waiting For Response](https://badge.waffle.io/crosstool-ng/crosstool-ng.png?label=waiting%20for%20response&title=Waiting%20For%20Response)](https://waffle.io/crosstool-ng/crosstool-ng) [![Stories in In Progress](https://badge.waffle.io/crosstool-ng/crosstool-ng.png?label=in%20progress&title=In%20Progress)](https://waffle.io/crosstool-ng/crosstool-ng)

## Introduction

crosstool-NG aims at building toolchains. Toolchains are an essential component in a software development project. It will compile, assemble and link the code that is being developed. Some pieces of the toolchain will eventually end up in the resulting binary/ies: static libraries are but an example.

Toolchains are made of different pieces of software, each being quite complex and requiring specially crafted options to build and work seamlessly. This is usually not that easy, even in the not-so-trivial case of native toolchains. The work reaches a higher degree of complexity when it comes to cross-compilation, where it can become quite a nightmare… mostly envolving host polution and linking issues.

Some cross-toolchains exist on the internet, and can be used for general development, but they have a number of limitations:

- They can be general purpose, in that they are configured for the majority - in that it is optimized for a specific target - and may be configured for a specific target when you might have multiple and want consistent configuration across the toolchains you use.
- They can be prepared for a specific target and thus are not easy to use, nor optimised for, or even supporting your target,
- They often are using aging components (compiler, C library, etc…) not supporting special features of your shiny new processor; On the other side, these toolchains offer some advantages:
 - They are ready to use and quite easy to install and setup,
 - They are proven if used by a wide community.

But once you want to get all the juice out of your specific hardware, you will want to build your own toolchain. This is where crosstool-NG comes into play.

There are also a number of tools that build toolchains for specific needs, which are not really scalable. Examples are:

- [buildroot](https://buildroot.org/) whose main purpose is to build complete root file systems, hence the name. But once you have your toolchain with buildroot, part of it is installed in the root-to-be, so if you want to build a whole new root, you either have to save the existing one as a template and restore it later, or restart again from scratch. This is not convenient,
- ptxdist[[en](http://www.pengutronix.de/software/ptxdist/index_en.html)][[de](http://www.pengutronix.de/software/ptxdist/index_de.html)], whose purpose is very similar to buildroot,
other projects (openembedded for example), which is again used to build complete root file systems.

crosstool-NG is really targetted at building toolchains, and only toolchains. It is then up to you to use it the way you want.

With crosstool-NG, you can learn precisely how each component is configured and built, so you can finely tweak the build steps should you need it.

crosstool-NG can build from generic, general purpose toolchains, to very specific and dedicated toolchains. Simply fill in specific values in the adequate options.

Of course, it doesn't prevent you from doing your home work first. You have to know with some degree of exactitude what your target is (archictecture, processor variant), what it will be used for (embedded, desktop, realtime), what degree of confidence you have with each component (stability, maintainability), and so on…

## Features

It's quite difficult to list all possible features available in crosstool-NG. Here is a list of those I find important:

* kernel-like menuconfig configuration interface
 * widespread, well-known interface
 * easy, yet powerful configuration
* growing number of supported architectures
 * see the status table for the current list
* support for alternative components in the toolchain
 * uClibc-, glibc-, newlib-, musl-libc-based toolchain supported right now!
 * others easy to implement
* different target OS supported
 * Linux
 * bare metal
* patch repository for those versions needing patching
 * patches for many versions of the toolchain components
 * support for custom local patch repository
* different threading models (depending on target)
 * NPTL
 * linuxthreads
* support for both soft- and hard-float toolchains
* support for multlib toolchains (experimental for now)
* debug facilities
 * native and cross gdb, gdbserver
 * debugging libraries: duma
 * debugging tools: ltrace, strace
 * restart a build at any step
* sample configurations repository usable as starting point for your own toolchain
 * see the status table for the current list

## Download and usage

You can:

- either get released versions and fixes there: /download/crosstool-ng/
- or check-out the [development stuff](#using-the-latest-development-stuff), or browse the code on-line, from the git repos at:
 - [https://github.com/crosstool-ng/crosstool-ng](https://github.com/crosstool-ng/crosstool-ng) (main development site)
 - crosstool-ng [Browse](http://crosstool-ng.org/git/crosstool-ng/) [GIT](git://crosstool-ng.org/crosstool-ng) [HTTP](http://crosstool-ng.org/git/crosstool-ng) (OSUOSL mirror)


### Using a released version

If you decide to use a released version (replace VERSION with the actual version you choose; the latest version is listed at the top of this page):

```
wget http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-VERSION.tar.bz2
```

Starting with 1.21.0, releases are signed with Bryan Hundven's pgp key

The fingerprint is:

```
561E D9B6 2095 88ED 23C6 8329 CAD7 C8FC 35B8 71D1
```

The public key is found on: http://pgp.surfnet.nl/

```
35B871D1
```

To validate the release tarball run you need to import the key from the keyserver and download the signature of the tarball:

```
gpg --recv-keys 35B871D1
wget http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-VERSION.tar.bz2.sig
```

Now, with the tarball and signature in the same directory, you can verify the tarball:

```gpg --verify crosstool-ng-VERSION.tar.bz2.sig```

Now you can unpack and install crosstool-NG:

```
tar xjf crosstool-ng-VERSION.tar.bz2
cd crosstool-ng-VERSION
./configure --prefix=/some/place
make
make install
export PATH="${PATH}:/some/place/bin"
```

Then, you are ready to use crosstool-NG.

- create a place to work in, then list the existing samples (pre-configured toolchains that are known to build and work) to see if one can fit your actual needs. Sample names are 4-part tuples, such as arm-unknown-linux-gnueabi. In the following, we'll use that as a sample name; adapt to your needs:

```
mkdir /a/directory/to/build/your/toolchain
cd /a/directory/to/build/your/toolchain
ct-ng help
ct-ng list-samples
ct-ng show-arm-unknown-linux-gnueabi
```
- once you know what sample to use, configure ct-ng to use it:

```
ct-ng arm-unknown-linux-gnueabi
```
- samples are configured to install in `${HOME}/x-tools/arm-unknown-linux-gnueabi` by default. This should be OK for a first time user, so you can now build your toolchain:

```
ct-ng build
```

- finally, you can set access to your toolchain, and call your new cross-compiler with :

```
export PATH="${PATH}:${HOME}/x-tools/arm-unknown-linux-gnueabi/bin"
arm-unknown-linux-gnueabi-gcc
```

Of course, replace arm-unknown-linux-gnueabi with the actual sample name you choose! ;-)

If no sample really fits your needs:

1. choose the one closest to what you want (see above), and start building it (see above, too)
 - this ensures sure it is working for your machine, before trying to do more advanced tests
2. fine-tune the configuration, and re-run the build, with:

```
ct-ng menuconfig
ct-ng build
```

Then, if all goes well, your toolchain will be available and you can set access to it as shown above.

See contacts, below for how to ask for further help.

**Note 1:** If you elect to build a uClibc-based toolchain, you will have to prepare a config file for uClibc with <= crosstool-NG-1.21.0. In >= crosstool-NG-1.22.0 you only need to prepare a config file for uClibc(or uClibc-ng) if you really need a custom config for uClibc.

**Note 2:** If you call `ct-ng --help` you will get help for `make(2)`. This is because ct-ng is in fact a `make(2)` script. There is no clean workaround for this.

## Using the latest development stuff

I usually setup my development environment like this:

```
mkdir $HOME/build
cd $HOME/build
git clone https://github.com/crosstool-ng/crosstool-ng
cd crosstool-ng
./bootstrap
./configure --prefix=$HOME/.local
make
make install
```

Now make sure `$HOME/.local/bin` is in your PATH (Newer Linux distributions [fc23, ubuntu-16.04, debian stretch] should have this in the PATH already):

```
echo -ne "\n\nif [ -d \"$HOME/.local/bin\" ]; then\n    PATH=\"$HOME/.local/bin:$PATH\"\nfi" >> ~/.profile
```

Then source your .profile to add the PATH to your current environment, or logout and log back in:

```
source ~/.profile
```

Now I create a directory to do my toolchain builds in:

```
mkdir $HOME/tc/
cd $HOME/tc/
```

Say we want to build armv6-rpi-linux-gnueabi:

```
mkdir armv6-rpi-linux-gnueabi
cd armv6-rpi-linux-gnueabi
ct-ng armv6-rpi-linux-gnueabi
```

Now build the sample:

```
ct-ng build
```

## Repository layout

|URL | Purpose |
|---|---|
| http://crosstool-ng.org/git | All available development repositories |
| http://crosstool-ng.org/git/crosstool-ng/ | Mirror of the development repository |
| https://github.com/crosstool-ng/crosstool-ng/ | Main development repository |

To clone the main repository:

```
git clone https://github.com/crosstool-ng/crosstool-ng
```

You can also download from our mirror at crosstool-ng.org:

```
git clone git://crosstool-ng.org/crosstool-ng
```

Alternatively, if you are sitting behind a restrictive proxy that does not let the git protocol through, you can clone with:

```
git clone http://crosstool-ng.org/git/crosstool-ng
```

#### Old repositories

These are the old Mercurial repositories. They are now read-only: [http://crosstool-ng.org/hg/](http://crosstool-ng.org/hg/)

### Pull Requests and Issues

You can find open Pull Requests on GitHub [here](https://github.com/crosstool-ng/crosstool-ng/pulls) and you can find open issues [here](https://github.com/crosstool-ng/crosstool-ng/issues).

#### Contributing

To contribute to crosstool-NG it is helpful to provide as much information as you can about your change, including any updates to documentation (if appropriate), and test... test... test.

- [Fork crosstool-ng on github](https://github.com/crosstool-ng/crosstool-ng#fork-destination-box)
- Clone the fork you made to your computer

```
git clone https://github.com/crosstool-ng/crosstool-ng
```

- Create a topic branch for your work

```
git checkout -b fix_comment_typo
```

- Make changes
 - hack
 - test
 - hack
 - etc...
- Add your changes

```
git add [file(s) that changed, add -p if you want to be more specific]
```

- Verify you are happy with your changes to be commited

```
git diff --cached
```

- Commit changes

```
git commit -s
```

The `-s` automatically adds your `Signed-off-by: [name] <email>` to your commit message. Your commit will be rejected without this.

Also, please explain what your change does. `"Fix stuff"` will be rejected. For examples of good commit messages, read the [changelog](https://github.com/crosstool-ng/crosstool-ng/commits/master).

- Push your topic branch with your changes to your fork

```
git push origin fix_comment_typo
```

- Go to the crosstool-ng project and click the `Compare & pull request` button for the branch you want to open a pull request with.
- Review the pull request changes, and verify that you are opening a pull request for the appropriate branch. The title and message should reflect the nature/theme of the changes in the PR, say the title is `Fix comment typos` and the message details any specifics you can provide.
 - You might change the crosstool-ng branch, if you are opening a pull request that is intended for a different branch. For example, when you created your topic branch you could have done:

```
git checkout -b fix_out_of_date_patch origin/1.22
```
 Then when you get to this pull request screen change the base branch from `master` to `1.22`

- By creating a pull request, the PR is entered into the [backlog](https://waffle.io/crosstool-ng/crosstool-ng). A [travis-ci](https://travis-ci.org/crosstool-ng/crosstool-ng/builds) job will run to test your changes against a select set of samples. As they start to get worked, they should be placed in the `Ready` state. PRs that are being worked are `In Progress`. If a questions come up about the commit that might envolve changes to the commit then the PR is placed in `Waiting For Response`, you have two options:
 1. Fix the issue with the commit by adding a new commit in the topic branch that fixes the code review. Then push your changes to your branch. This option keeps the comments in the PR, and allows for further code review. I personally dislike this, because people are lazy and fix reviews with `fix more review issues`. Please make good commit messages! All rules about commits from above apply! **THIS IS PREFERED**


Add your changes

```
git add [file(s) that changed, add -p if you want to be more specific]
```

Verify you are happy with your changes to be commited

```
git diff --cached
```

Commit changes

```
git commit -s
```

- Push your topic branch with your changes to your fork

```
git push origin fix_comment_typo
```

At this point the PR will be updated to have the latest commit to that branch, and can be subsequently reviewed.
 
 2. Interactively rebase the offending commit(s) to fix the code review. This option is slightly annoying on Github, as the comments are stored with the commits, and disapear when new commits replace the old commits. I do this when I don't care about the previous comments in the code review and need to do a total rewrite of my work. This comes with other issues, like your topic branch not being up-to-date with master. So I use this work-flow:

```
git fetch --all
git rebase --ignore-whitespace origin master
git rebase -i <offending-commit-id>^
```

**NOTE:** The `--ignore-whitespace` stops `git apply` (which is called by rebase) from changing any whitespace when it runs.

Replace `pick` with `edit` or remove the line to delete a commit.
Fix the issue in the code review.

```
git add [file(s)]
git rebase --continue
<update commit comment if needed>
git push --force origin fix_comment_typo
```

### Patchwork

We previously used patchwork for development, but it is no longer used. I'd like to see patches that are still applicable turned into Pull Requests on GitHub.

You can find the [list of pending patches](http://patchwork.ozlabs.org/project/crosstool-ng/) available on [patchwork](http://jk.ozlabs.org/projects/patchwork/).

## More Info

You can find *all* of this and more at [crosstool-ng.org](http://crosstool-ng.org/)


We are also available on IRC: irc.freenode.net #crosstool-ng

We also have a [mailing list](mailto:crossgcc@sourceware.org), when you can get ahold of anyone on IRC. Archive and subscription info can be found here: [https://sourceware.org/ml/crossgcc/](https://sourceware.org/ml/crossgcc/)

Aloha! :-)

[travis]: https://travis-ci.org/crosstool-ng/crosstool-ng
[travis-status]: https://travis-ci.org/crosstool-ng/crosstool-ng.svg
