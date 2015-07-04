set_max_channels 24
set_default_action accept
set_max_objects 5
set_max_miniaddrs 5

ip4tbl_alloc bad_nets linear 5 none

start_code
	accept:
		load 1 r0
		stop
	reject:
		load 0 r0
		stop
	start_src_filter:
		test_ip4
		jmp_if_not accept
		append_ip4_src pkey
		lookup bad_nets	p1
		stop
end_code

ip4tbl_insert bad_nets 192.168.113.113/21 reject
