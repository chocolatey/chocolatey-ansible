# Contributing
The Chocolatey team has very explicit information here regarding the process for contributions, and we will be sticklers about the way you write your commit messages (yes, really), so to save yourself some rework, please make sure you read over this entire document prior to contributing.

<!-- TOC -->

- [Are You In the Right Place?](#are-you-in-the-right-place)
  - [Reporting an Issue/Bug?](#reporting-an-issuebug)
    - [SolutionVersion.cs](#solutionversioncs)
  - [Package Issue?](#package-issue)
  - [Package Request? Package Missing?](#package-request-package-missing)
  - [Submitting an Enhancement / Feature Request?](#submitting-an-enhancement--feature-request)
    - [Submitting an Enhancement For Choco](#submitting-an-enhancement-for-choco)
- [Contributing](#contributing)
  - [Prerequisites](#prerequisites)
    - [Definition of Trivial Contributions](#definition-of-trivial-contributions)
    - [Is the CLA Really Required?](#is-the-cla-really-required)
- [Contributing Process](#contributing-process)
  - [Get Buyoff Or Find Open Community Issues/Features](#get-buyoff-or-find-open-community-issuesfeatures)
  - [Set Up Your Environment](#set-up-your-environment)
  - [Code Format / Design](#code-format--design)
    - [CSharp](#csharp)
    - [PowerShell](#powershell)
  - [Debugging / Testing](#debugging--testing)
    - [Visual Studio](#visual-studio)
      - [Automated Tests](#automated-tests)
    - [Chocolatey Build](#chocolatey-build)
  - [Prepare Commits](#prepare-commits)
  - [Submit Pull Request (PR)](#submit-pull-request-pr)
  - [Respond to Feedback on Pull Request](#respond-to-feedback-on-pull-request)
- [Other General Information](#other-general-information)

<!-- /TOC -->

## Are You In the Right Place?
Chocolatey is a large ecosystem and each component has their own location for submitting issues and enhancement requests. This is the repository for Chocolatey Ansible collection.

Please follow this decision criteria to see if you are in the right location or if you should head to a different location to submit your request.

### Reporting an Issue/Bug?

Submitting an Issue (or a Bug)? See the **[Submitting Issues](https://github.com/chocolatey/chocolatey-ansible/tree/master/README.md#submitting-issues) section** in the README.

### Package Issue?

Please see [Request Package Fixes or Updates / Become a maintainer of an existing package](https://chocolatey.org/docs/package-triage-process).

### Submitting an Enhancement / Feature Request?

If this is for Chocolatey Ansible collection, this is the right place. See below. Otherwise see [Submitting Issues](https://github.com/chocolatey/chocolatey-ansible/tree/master/README.md#submitting-issues).

## Contributing

The process for contributions is roughly as follows:

### Prerequisites

 * Submit an [issue](https://github.com/chocolatey/chocolatey-ansible/issues). You will need the issue id for your commits.
 * Ensure you have signed the Contributor License Agreement (CLA) - without this we are not able to take contributions that are not trivial.
  * [Sign the Contributor License Agreement](https://www.clahub.com/agreements/chocolatey/choco).
  * You must do this for each Chocolatey project that requires it.
  * If you are curious why we would require a CLA, we agree with Julien Ponge - take a look at his [post](https://julien.ponge.org/blog/in-defense-of-contributor-license-agreements/).
 * You agree to follow the [etiquette regarding communication](https://github.com/chocolatey/choco#etiquette-regarding-communication).

#### Definition of Trivial Contributions
It's hard to define what is a trivial contribution. Sometimes even a 1 character change can be considered significant. Unfortunately because it can be subjective, the decision on what is trivial comes from the committers of the project and not from folks contributing to the project. It is generally safe to assume that you may be subject to signing the [CLA](https://www.clahub.com/agreements/chocolatey/choco) and be prepared to do so. Ask in advance if you are not sure and for reasons are not able to sign the [CLA](https://www.clahub.com/agreements/chocolatey/choco).

What is generally considered trivial:

* Fixing a typo
* Documentation changes
* Fixes to non-production code - like fixing something small in the build code.

What is generally not considered trivial:

 * Changes to any code that would be delivered as part of the final product. This includes any scripts that are delivered, such as PowerShell scripts. Yes, even 1 character changes could be considered non-trivial.

#### Is the CLA Really Required?

Yes, and this aspect is not up for discussion. If you would like more resources on understanding CLAs, please see the following articles:

* [What is a CLA and why do I care?](https://www.clahub.com/pages/why_cla)
* [In defense of Contributor License Agreements](https://julien.ponge.org/blog/in-defense-of-contributor-license-agreements/)
* [Contributor License Agreements](http://oss-watch.ac.uk/resources/cla)
* Dissenting opinion - [Why your project doesn't need a Contributor License Agreement](https://sfconservancy.org/blog/2014/jun/09/do-not-need-cla/)

Overall, the flexibility and legal protections provided by a CLA make it necessary to require a CLA. As there is a company and a licensed version behind Chocolatey, those protections must be afforded. We understand this means some folks won't be able to contribute and that's completely fine. We prefer you to know up front this is required so you can make the best decision about contributing.

If you work for an organization that does not allow you to contribute without attempting to own the rights to your work, please do not sign the CLA.

## Contributing Process

Start with [Prerequisites](#prerequisites) and make sure you can sign the Contributor License Agreement (CLA).

### Get Buyoff Or Find Open Community Issues/Features

 * Through a Github issue, talk about a feature or bug fix you like and why it should be in the Chocolatey Ansible Collection.
 * Once you get a nod from one of the [Chocolatey Team](https://github.com/chocolatey?tab=members), you can start on the feature.
 * Alternatively, if a feature is on the issues list with the [Up For Grabs](https://github.com/chocolatey/chocolatey-ansible/labels/Up For Grabs %2F Hacktoberfest) label, it is open for a community member (contributor) to patch. You should comment that you are signing up for it on the issue so someone else doesn't also sign up for the work.

### Set Up Your Environment

 * For git specific information:
    1. Create a fork of chocolatey/chocolatey-ansible under your GitHub account. See [forks](https://help.github.com/articles/working-with-forks/) for more information.
    1. [Clone your fork](https://help.github.com/articles/cloning-a-repository/) locally.
    1. Open a command line and navigate to that directory.
    1. Add the upstream fork - `git remote add upstream git@github.com:chocolatey/chocolatey-ansible.git` (or git remote add upstream https://github.com/chocolatey/chocolatey-ansible.git` if you are not using SSH).
    1. Run `git fetch upstream`
    1. Ensure you have user name and email set appropriately to attribute your contributions - see [Name](https://help.github.com/articles/setting-your-username-in-git/) / [Email](https://help.github.com/articles/setting-your-email-in-git/).
    1. Ensure that the local repository has the following settings (without `--global`, these only apply to the *current* repository):
      * `git config core.autocrlf false`
      * `git config core.symlinks false`
      * `git config merge.ff false`
      * `git config merge.log true`
      * `git config fetch.prune true`
    1. From there you create a branch named specific to the feature.
    1. In the branch you do work specific to the feature.
    1. For committing the code, please see [Prepare Commits](#prepare-commits).
    1. See [Submit Pull Request (PR)](#submit-pull-request-pr).
 * Please also observe the following:
    * Unless specifically requested, do not reformat the code. It makes it very difficult to see the change you've made.
    * Do not change files that are not specific to the feature.
    * More covered below in the [**Prepare commits**](#prepare-commits) section.
 * Test your changes and please help us out by updating and implementing some automated tests. It is recommended that all contributors spend some time looking over the tests in the source code. You can't go wrong emulating one of the existing tests and then changing it specific to the behavior you are testing.
    * While not an absolute requirement, automated tests will help reviewers feel comfortable about your changes, which gets your contributions accepted faster.
 * Please do not update your branch from the master unless we ask you to. See the responding to feedback section below.

### Prepare Commits
This section serves to help you understand what makes a good commit.

A commit should observe the following:

 * A commit is a small logical unit that represents a change.
 * Should include new or changed tests relevant to the changes you are making.
 * No unnecessary whitespace. Check for whitespace with `git diff --check` and `git diff --cached --check` before commit.
 * You can stage parts of a file for commit.

A commit message should observe the following (based on ["A Note About Git Commit Messages"](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html)):

  * The first line of the commit message should be a short description around 50 characters in length and be prefixed with the GitHub issue it refers to with parentheses surrounding that. If the GitHub issue is #25, you should have `(#25)` prefixed to the message.
  * If the commit is about documentation, the message should be prefixed with `(doc)`.
  * If it is a trivial commit or one of formatting/spaces fixes, it should be prefixed with `(maint)`.
  * After the subject, skip one line and fill out a body if the subject line is not informative enough.
  * Sometimes you will find that even a tiny code change has a commit body that needs to be very detailed and make take more time to do than the actual change itself!
  * The body:
    * Should wrap at `72` characters.
    * Explains more fully the reason(s) for the change and contrasts with previous behavior.
    * Uses present tense. "Fix" versus "Fixed".

A good example of a commit message is as follows:

```
(#7) Installation Adds All Required Folders

Previously the installation script worked for the older version of
Chocolatey. It does not work similarly for the newer version of choco
due to location changes for the newer folders. Update the install
script to ensure all folder paths exist.

Without this change the install script will not fully install the new
choco client properly.
```

### Submit Pull Request (PR)

Prerequisites:

 * You are making commits in a feature branch.
 * All specs should be passing.

Submitting PR:

 * Once you feel it is ready, submit the pull request to the `chocolatey/chocolatey-ansible` repository against the `master` branch ([more information on this can be found here](https://help.github.com/articles/creating-a-pull-request)) unless specifically requested to submit it against another branch (usually `stable` in these instances).
  * In the case of a larger change that is going to require more discussion, please submit a PR sooner. Waiting until you are ready may mean more changes than you are interested in if the changes are taking things in a direction the committers do not want to go.
 * In the pull request, outline what you did and point to specific conversations (as in URLs) and issues that you are are resolving. This is a tremendous help for us in evaluation and acceptance.
 * Once the pull request is in, please do not delete the branch or close the pull request (unless something is wrong with it).
 * One of the Chocolatey Team members, or one of the committers, will evaluate it within a reasonable time period (which is to say usually within 2-4 weeks). Some things get evaluated faster or fast tracked. We are human and we have active lives outside of open source so don't fret if you haven't seen any activity on your pull request within a month or two. We don't have a Service Level Agreement (SLA) for pull requests. Just know that we will evaluate your pull request.

### Respond to Feedback on Pull Request

We may have feedback for you in the form of requested changes or fixes. We generally like to see that pushed against the same topic branch (it will automatically update the PR). You can also fix/squash/rebase commits and push the same topic branch with `--force` (while it is generally acceptable to do this on topic branches not in the main repository, a force push should be avoided at all costs against the main repository).

If we have comments or questions when we do evaluate it and receive no response, it will probably lessen the chance of getting accepted. Eventually this means it will be closed if it is not accepted. Please know this doesn't mean we don't value your contribution, just that things go stale. If in the future you want to pick it back up, feel free to address our concerns/questions/feedback and reopen the issue/open a new PR (referencing old one).

Sometimes we may need you to rebase your commit against the latest code before we can review it further. If this happens, you can do the following:

 * `git fetch upstream` (upstream would be the mainstream repo or `chocolatey/chocolatey-ansible` in this case)
 * `git checkout master`
 * `git rebase upstream/master`
 * `git checkout your-branch`
 * `git rebase master`
 * Fix any merge conflicts
 * `git push origin your-branch` (origin would be your GitHub repo or `your-github-username/chocolatey-ansible` in this case). You may need to `git push origin your-branch --force` to get the commits pushed. This is generally acceptable with topic branches not in the mainstream repository.

The only reasons a pull request should be closed and resubmitted are as follows:

  * When the pull request is targeting the wrong branch (this doesn't happen as often).
  * When there are updates made to the original by someone other than the original contributor (and the PR is not open for contributions). Then the old branch is closed with a note on the newer branch this supersedes #github_number.

## Other General Information

If you reformat code or hit core functionality without an approval from a person on the Chocolatey Team, it's likely that no matter how awesome it looks afterwards, it will probably not get accepted. Reformatting code makes it harder for us to evaluate exactly what was changed.

If you do these things, it will make evaluation and acceptance easy. Now if you stray outside of the guidelines we have above, it doesn't mean we are going to ignore your pull request. It will just make things harder for us.  Harder for us roughly translates to a longer SLA for your pull request.
