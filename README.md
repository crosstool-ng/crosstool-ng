# Crosstool-NG

## Introduction

Crosstool-NG aims at building toolchains. Toolchains are an essential component in a software development project. It will compile, assemble and link the code that is being developed. Some pieces of the toolchain will eventually end up in the resulting binaries: static libraries are but an example.

**Before reporting a bug**, please read [bug reporting guidelines](http://crosstool-ng.github.io/support/). Bugs that do not provide the required information will be closed without explanation.

Refer to [documentation at crosstool-NG website](http://crosstool-ng.github.io/docs/) for more information on how to configure, install and use crosstool-NG.

**Note 1:** If you elect to build a uClibc-based toolchain, you will have to prepare a config file for uClibc with <= crosstool-NG-1.21.0. In >= crosstool-NG-1.22.0 you only need to prepare a config file for uClibc(or uClibc-ng) if you really need a custom config for uClibc.

**Note 2:** If you call `ct-ng --help` you will get help for `make(2)`. This is because ct-ng is in fact a `make(2)` script. There is no clean workaround for this.

## Repository layout

To clone the crosstool-NG repository:

```
git clone https://github.com/crosstool-ng/crosstool-ng
```

## Build Status
- ![CI](https://github.com/crosstool-ng/crosstool-ng/workflows/CI/badge.svg)

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

- By creating a pull request, the PR is entered into the [backlog](https://waffle.io/crosstool-ng/crosstool-ng). A [travis-ci](https://travis-ci.org/crosstool-ng/crosstool-ng/builds) job will run to test your changes against a select set of samples. As they start to get worked, they should be placed in the `Ready` state. PRs that are being worked are `In Progress`. If a questions come up about the commit that might involve changes to the commit then the PR is placed in `Waiting For Response`, you have two options:
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
 
 2. Interactively rebase the offending commit(s) to fix the code review. This option is slightly annoying on Github, as the comments are stored with the commits, and are hidden when new commits replace the old commits. They used to disappear completely; now Github shows a grey 'View outdated' link next to the old commits.

This recipe also comes handy with other issues, like your topic branch not being up-to-date with master:

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

Report issues at [the project site on GitHub](https://github.com/crosstool-ng/crosstool-ng).

We have a [mailing list](mailto:crossgcc@sourceware.org). Archive and subscription info can be found here: [https://sourceware.org/ml/crossgcc/](https://sourceware.org/ml/crossgcc/)

Aloha! :-)
