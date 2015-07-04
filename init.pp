class ssfe (   $Install_Directory=  '/root/ssfe',
    $MicroCodeFile =   'puppet.mc',  #File name
                $Filter =     'source_net',   #Filter name
    $PacketRate =     '5000ms',       #Packet per ms

    $A_Action =     'accept',      #accept,reject,limit
          $A_SourceNetwork =   '10.0.0.1/32',  #192.168.1.5
    $A_SourcePort =   '0',     #0-65535
    $A_DestinationNetwork = '10.0.0.1/32',   #192.168.1.6
    $A_DestinationPort =   '0',    #0-65535
    $A_SourceIP =     '0',    #3232235781
    $A_DestinationIP =   '0',       #3232235782

    $B_Action =     'accept',  #accept,reject,limit  
          $B_SourceNetwork =   '128.0.0.1/32', #192.168.2.5
                $B_SourcePort =   '0',    #0-65535
                $B_DestinationNetwork = '128.0.0.1/32', #192.168.2.6
                $B_DestinationPort =   '0',    #0-65535
    $B_SourceIP =     '0',    #3232236037
    $B_DestinationIP =   '0',    #3232236038

    $List_Black = 'blacklist.txt',
    $List_White = 'whitelist.txt',

    $MaxChannels = '24',
    $MaxObjects = '64',
    $MaxAddPoint = '128',
    $MaxNet = '4',
    $DefaultAction = 'accept', )

    #(first octet * 16777216) + (second octet * 65536) + (third octet * 256) + (fourth octet)

        {

  case $A_Action {
      'accept':   { $a_state = 'accept' }
      'reject':   { $a_state = 'reject' }
      'limit':   { $a_state = 'limit' }
      default: { fail('Unsupported Action, set action to accept, reject or limit') }
}

        case $Filter {
                'source_ip':     { $g_filter = 'source_ip' }
                'destination_ip':   { $g_filter = 'destination_ip' }
                'source_port':     { $g_filter = 'source_ip' }
    'destination_port':  { $g_filter = 'destination_port' }
    'source_net':    { $g_filter = 'source_net' }
    'destination_net':  { $g_filter = 'destination_net'}
                default: { fail('Unsupported Filter, set filter to source/destination ip/port/net address') }
}

  package { 'kernel-module-sfc-RHEL6-2.6.32-431.el6.x86_64-4.1.0.6734-1.x86_64':
      ensure => '4.1.0.6734-1',
      before => File["${Install_Directory}/${MicroCodeFile}"],
  }

  file { 'conf.mc':
            ensure    => 'present',
    path               => '/root/ssfe/conf.mc',
                mode => '0644',
            source    => 'puppet:///modules/ssfe/conf.mc',
  }

  file { $MicroCodeFile:
      ensure  => 'present',
      path    => "${Install_Directory}/${MicroCodeFile}",
      mode    => '0644',
      content =>
"set_max_channels ${MaxChannels}
set_default_action ${DefaultAction}
set_max_objects ${MaxObjects}
set_max_miniaddrs ${MaxAddPoint}
ip4tbl_alloc src_subnet linear ${MaxNet} none
ip4tbl_alloc dst_subnet linear ${MaxNet} none
set_max_channel_bytes 64

start_code
	accept:
		load 1 r0
		stop
	reject:
		load 0 r0
		stop

        source_ip:
                test_ip4
                jmp_if_not default
                load_ip4_src r2
                test_eq r2 ${A_SourceIP}
                jmp_if ${A_Action}
                test_eq r2 ${B_SourceIP}
                jmp_if ${B_Action}
	
	source_net:
                test_ip4
                jmp_if_not accept
                append_ip4_src pkey
                lookup src_subnet p1
                stop

	destination_ip:
                test_ip4
                jmp_if_not default
                load_ip4_dst r2
                test_eq r2 ${A_DestinationIP}
                jmp_if ${A_Action}
                test_eq r2 ${B_DestinationIP}
                jmp_if ${B_Action}

        destination_net:
                test_ip4
                jmp_if_not accept
                append_ip4_dst pkey
                lookup dst_subnet p1
                stop
	
	source_port:
    		test_ip4
    		jmp_if_not default
    		test_tcp4 first_frag	#test_udp4 first_frag
    		jmp_if_not default
    		load_ip4_sport r3
    		test_eq r3 ${A_SourcePort}
    		jmp_if source_ip
		test_eq r3 ${B_SourcePort}
		jmp_if source_ip

	
	destination_port:
		test_ip4
                jmp_if_not default
                test_tcp4 first_frag	#test_udp4 first_frag
                jmp_if_not default
		load_ip4_dport r3
    		test_eq r3 ${A_DestinationPort}
    		jmp_if destination_ip
		test_eq r3 ${B_DestinationPort}
		jmp_if destination_ip

        limit:
                channel_state p1 u64 -
                test_rate_le p1 0 1pkts ${PacketRate}
                jmp_if_not reject
                jmp accept

        default:
                jmp ${DefaultAction}
end_code

ip4tbl_insert src_subnet ${A_SourceNetwork} ${A_Action}
ip4tbl_insert src_subnet ${B_SourceNetwork} ${B_Action}

ip4tbl_insert dst_subnet ${A_DestinationNetwork} ${A_Action}
ip4tbl_insert dst_subnet ${B_DestinationNetwork} ${B_Action}\n",
    }

  service { 'network':
      ensure => 'running',
      enable => true,
  }

  service { 'iptables':
      ensure => 'stopped',
      enable => true,
  }

  exec { 'CleanUp':
    cwd           => $Install_Directory,
      path        => ['/sbin','/bin'],
      subscribe   => File["${Install_Directory}/${MicroCodeFile}"],
      refreshonly => true,
    command       => '/sbin/solsec_fe cleanup',
        logoutput => true,
    returns       => '0',
  }

        exec { 'Create':
                cwd         => $Install_Directory,
                path        => ['/sbin','/bin'] ,
                subscribe   => File["${Install_Directory}/${MicroCodeFile}"],
                refreshonly => true,
                command     => '/sbin/solsec_fe create',
                logoutput   => true,
                returns     => '0',
        }

        exec { 'Load':
                cwd         => $Install_Directory,
                path        => ['/sbin','/bin'],
                subscribe   => File["${Install_Directory}/${MicroCodeFile}"],
                refreshonly => true,
                command     => "/sbin/solsec_fe load ${Install_Directory}/${MicroCodeFile}",
                logoutput   => true,
                returns     => '0',
        }


        exec { 'Enable':
                cwd         => $Install_Directory,
#                path => ["/sbin","bin"],
                subscribe   => File["${Install_Directory}/${MicroCodeFile}"],
                refreshonly => true,
                command     => "/sbin/solsec_fe enable ${Filter}",
                logoutput   => true,
                returns     => '0',
        }


        exec { 'Status':
                cwd         => $Install_Directory,
                path        => ['/sbin','/bin'],
                subscribe   => File["${Install_Directory}/${MicroCodeFile}"],
                refreshonly => true,
                command     => '/sbin/solsec_fe status',
                logoutput   => true,
                returns     => '0'
  }

}

