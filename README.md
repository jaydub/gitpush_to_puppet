#gitpush_to_puppet

####Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [How It Works](#how-it-works)
4. [Limitations](#limitations)
5. [Usage](#usage)
6. [License](#license)
7. [To Do](#to-do)

## Overview

puppetmasterd server side set up for the deployment from git of manifests, 
modules and hieradata.

##Module Description

This particular method of deployment from git assumes:

1. Your puppetmaster server is otherwise entirely configured within
puppet itself, using the likes of `Aethylred/puppet` or
similar. This leaves only the contents of manifests, modules and
hieradata to deploy.

2. Consequently, no configuration is changed by hand on the server;
you do all that work on workstations and want to push the results to
testing and production servers.

3. All your modules have their own git repositories (or live in
subdirectories of a git repository), so they can be easily installed
and updated by `librarian-puppet`.

What this module does is sets up the necessary resources so that a
`git push` in your configuration repository to the server will result
in manifests, modules and hieradata being deployed on that server.

##How It Works

What this module does is:

* Sets up a bare git repository, staging directory and
  librarian-puppet directory under `/var/lib/puppet-conf`
* Adds a post-receive hook to the git repository that will copy a snapshot
  of the head of a branch into staging/ by way of the `git archive`
  command, and runs a full deployment script in that directory
* Initializes `librarian-puppet` and links `/etc/puppet/modules` to the
  librarian-puppet managed modules directory.

Your git repository should look like this:
```
manifests/
hieradata/
Puppetfile
librarian-puppet-config
post-receive
deploy-puppet-conf
```

Where the `deploy-puppet-conf` script should do something like this:

1. Shut down the puppetmaster service, so agents won't pull
inconsistant configuration
2. Run a libarian-puppet update based on your Puppetfile to pull down
or update modules (which will be symlinked into `/etc/puppet`)
3. Use rsync to update `manifests/` and `hieradata/`
4. Update the `post-recieve` hook
5. Restore the puppetmaster service and clean up.

##Limitations

If you look at the deployment script and think to yourself, I'll write
that using Fabric or Capistrano, then you should probably do that and
just skip this whole server-side-bare-git-repository nonsense.  This
system is more appropriate if you're only deploying to one
puppetmaster, or if a pool of puppetmaters are pulling configuration
from one primary puppetmaster, and you need to get configuration to
that first puppetmaster.

Conceivably, your deployment script can run anything and do anything,
but in practice, it runs as the same user that pushes to the server
repository, so it will need to use sudo to restart services and update
files under `/etc/puppet`. The default module behaviour is to install a
set of sudoers directives for the commands that appear in the
example `deploy-puppet-conf` script; you'll need to add your own to do
other things.

The default sudoers set is tied to the group `puppet-deploy`, so people
who should have `git push` access need to be in this group to both
write to the server git repository and run deployment commands. This
is over and above having SSH, or similiar, access to the server itself.

##Usage

* put your manifests, hieradata and Puppetfile in a repository, and
copy across the example deployment script.

* include the module on your puppetmaster and apply.

* add your push enabled users to the puppet-deploy group.

* back up your manifests, hieradata and modules. Yes, they will end up
  in the filebucket if you have that switched on, but you can break
  the means to extract them, so be careful.

* set the origin server of your git repository to the newly created
bare repository on the server.

* Push!

* Check that it worked:

** manifests and hieradata are in order
** /var/lib/puppet-conf/librarian-puppet/modules matches your
	expectations
** post-receive hook is in order

* Flip the switch on the modules directory and run again.

###Parameters

##License

Apache 2.0 License; a copy is included in the module.

##To Do

* This module could seriously mess up your puppet infrastructure, so
  it seriously needs spec tests before I unleash it onto Puppet
  Forge.
* A companion module that sets up modules, manifests and hieradata for
  load balanced puppetmasters from a master puppetmaster would make this
  much more useful.
