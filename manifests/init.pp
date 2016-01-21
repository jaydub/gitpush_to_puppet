# Class: gitpush_to_puppet
#
# Installs directories and dependencies used to enable a git push based puppet
# configuration deployment.
#
#
# [Remember: No empty lines between comments and class definition]
class gitpush_to_puppet (
  $base_path    = '/var/lib/puppet-conf',
  $group        = 'puppet-deploy',
  $service_name = 'apache2',
  $deploy_cmd   = 'deploy-puppet-conf',
  $branch       = 'master',
  $own_modules  = false,
  $use_sudoers  = true,
  $purge        = false,
)
{
  if $purge {
    # Removes the group, and all directories. If it owns the modules, converts
    # the symlink back to a directory (but cannot restore the old modules!).
    # Doesn't remove any installed packages.

    if $own_modules {
      file { '/etc/puppet/modules':
        ensure => directory,
        force  => true,
      }
    }
    
    file { $base_path:
      ensure  => absent,
      purge   => true,
      recurse => true,
      force   => true,
    }

    if $use_sudoers {
      sudo::conf { 'puppetmasterd_stop':
        ensure => absent,
      }
      sudo::conf { 'puppetmasterd_start':
        ensure => absent,
      }
      sudo::conf { 'rsync_to_puppet_manifests':
        ensure => absent,
      }
      sudo::conf { 'rsync_to_puppet_hieradata':
        ensure => absent,
      }
      sudo::conf { 'chmod_post_receive':
        ensure => absent,
      }
    }
    group { 'puppet-deploy':
      ensure => present,
      name   => $group,
    }

  }
  else {
    # TODO: case $operatingsystem and version to fetch the right package name
    # from the correct provider.

    package { 'git':
      ensure => installed,
    }
    package { 'librarian-puppet':
      ensure   => installed,
      provider => gem,
    }

    group { 'puppet-deploy':
      ensure => present,
      name   => $group,
    }

    if $use_sudoers {
      $sudo_base = "%${group} ALL=(ALL) NOPASSWD:"
      # Add entries to sudoers
      sudo::conf { 'puppetmasterd_stop':
        content => "${sudo_base} /usr/sbin/service ${service_name} stop",
      }    
      sudo::conf { 'puppetmasterd_start':
        content => "${sudo_base} /usr/sbin/service ${service_name} start",
      }

      $rsync = '/usr/bin/rsync'
      $staging_m = "${base_path}/staging/manifests/"
      $puppet_m = '/etc/puppet/manifests/'
      $staging_h = "${base_path}/staging/hieradata/"
      $puppet_h = '/etc/puppet/hieradata/'

      sudo::conf { 'rsync_to_puppet_manifests':
        content => "${sudo_base} ${rsync} -vr --del ${staging_m} ${puppet_m}",
      }
    
      sudo::conf { 'rsync_to_puppet_hieradata':
        content => "${sudo_base} ${rsync} -vr --del ${staging_h} ${puppet_h}",
      }

      $post_receive = "${base_path}/repo.git/hooks/post-receive"
      sudo::conf { 'chmod_post_receive':
        content => "${sudo_base} /bin/chmod +x ${post_receive}",
      }
    }    
    file { $base_path:
      ensure => directory,
      mode   => '2775',
      group  => $group,
    }
    file { "${base_path}/repo.git":
      ensure  => directory,
      mode    => 'g+w',
      group   => $group,
      recurse => true,
    }
    file { "${base_path}/staging":
      ensure => directory,
      mode   => '2775',
      group  => $group,
      recurse => false,
    }
    file { "${base_path}/librarian-puppet":
      ensure  => directory,
      mode    => 'g+w',
      group   => $group,
      recurse => false,
    }
    
    # Set up the repository
    exec { 'git_init':
      provider => 'posix',
      cwd      => "${base_path}/repo.git",
      umask    => '0002',
      path     => '/usr/bin',
      command  => 'git init --bare',
      creates  => "${base_path}/repo.git/HEAD",
      require  => File["${base_path}/repo.git"],
    }

    file { "${base_path}/repo.git/hooks/post-receive":
      ensure  => present,
      mode    => '0775',
      group   => 'puppet-deploy',
      replace => false,
      content => template("${module_name}/post-receive.erb"),
      require => Exec['git_init'],
    }
    
    # Set up librarian-puppet.
    exec { 'librarian_puppet_init':
      provider    => 'shell',
      cwd         => "${base_path}/librarian-puppet",
      umask       => '0002',
      path        => ['/bin', '/usr/bin', '/usr/local/bin'],      
      environment => "HOME=${base_path}/librarian-puppet",
      command     => 'librarian-puppet init',
      creates     => "${base_path}/librarian-puppet/Puppetfile",
      require     => File["${base_path}/librarian-puppet"],
    }

    if $own_modules {
      file { '/etc/puppet/modules':
        ensure  => symlink,
        target  => "${base_path}/librarian-puppet/modules",
        force   => true,
        require => Exec['librarian_puppet_init'],
      }
    }
  }
}
