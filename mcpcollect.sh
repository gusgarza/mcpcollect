#!/bin/bash

#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    <http://www.gnu.org/licenses/>.
#




### TO DO ####
#	Add support for returning relevent packages
#	Complete salt grain lists
#	Add switch for custom commands
#	



#### Grains

#aodh.server
#apache.server
#aptly.publisher
#backupninja.client
#backupninja.server
#ceilometer.agent
#ceilometer.server
#ceph.client
#ceph.common
#ceph.mgr
#ceph.mon
#ceph.osd
#ceph.radosgw
#ceph.setup
#cinder.controller
#cinder.volume
#devops_portal.config
#docker.client
#docker.host
#docker.swarm
#elasticsearch.client
#elasticsearch.server
#fluentd.agent
#galera.master
#galera.slave
#gerrit.client
#git.client
#glance.server
#glusterfs.client
#glusterfs.server
#gnocchi.common
#gnocchi.server
#grafana.client
#grafana.collector
#haproxy.proxy
#heat.server
#heka.remote_collector
#horizon.server
#influxdb.relay
#influxdb.server
#java.environment
#jenkins.client
#keepalived.cluster
#keystone.client
#keystone.server
#kibana.client
#kibana.server
#libvirt.server
#linux.network
#linux.storage
#linux.system
#logrotate.server
#maas.cluster
#maas.region
#memcached.server
#mysql.client
#neutron.compute
#neutron.gateway
#neutron.server
#nginx.server
#nova.compute
#nova.controller
#ntp.client
#ntp.server
#opencontrail.control
#opencontrail.web
#opencontrail.database
#opencontrail.client
#opencontrail.config
#openldap.client
#openssh.client
#openssh.server
#panko.server
#prometheus.alertmanager
#prometheus.collector
#prometheus.pushgateway
#prometheus.relay
#prometheus.server
#rabbitmq.cluster
#rabbitmq.server
#reclass.storage
#redis.cluster
#redis.server
#rsyslog.client
#rundeck.client
#rundeck.server
#salt.api
#salt.control
#salt.master
#salt.minion
#sphinx.server
#telegraf.agent
#telegraf.remote_agent
#xtrabackup.client
#xtrabackup.server
#                                       "for x in \`virsh list | egrep -v 'Id|--' | awk '{print \$2}'\`; do echo \$x; virsh dumpxml \$x; done " \

function usage {
        echo ""
	echo "    mcpcollector -s <mmo-somehost> -g ceph.osd -h osd001 -h osd002 -y -l"
        echo ""
        echo "    -a -- All logs -- Collect all logs from the specified log directory."
        echo "          The default is to only collect *.log files, setting this switch will collect"
        echo "          all files in the log directory. "
        echo "          This option will not work against component general, because that will collect all logs in"
        echo "          /var/log and could potentially consume too much disk on certain nodes"
        echo ""
        echo "    -g -- <salt grain>"
        echo "          Specify the salt grain name (ceph.mon, ceph.common) to collect information from"
        echo "          Hosts from grain are superceeded by host provided in -h"
        echo ""
        echo "    -h -- <target hostname or IP>"
        echo "          The MCP host name of the systems you want to collect information from"
        echo "		* Multiple host selections are supported (-h host1 -h host2)"
        echo ""
        echo "    -l -- Run on your localhost with ssh access to a Cfg or Salt node.  This option also requires the -s switch"
	echo "		* Note this requires ssh keys to be installed from your local host to the cfg node, or you will be prompted"
	echo "		  many times for your ssh password"
        echo ""
        echo "    -p -- Preview only --Do not collect any files, previews what will be collected for each grain"
        echo ""
        echo "    -s -- <cfg node or salt node>"
        echo "		* REQUIRED : hostname or IP of the salt of config host."
        echo ""
        echo "    -y -- Autoconfirm -- Do not print confirmation and summary prompt"
	echo ""
	echo "For questions or suggeststions contact Jerry Keen, jkeen@mirantis.com."

        exit

}


#                c) componentFlag=true; componentvalues+=("$OPTARG");;


while getopts "c:h:g::s:layp" arg; do
        case $arg in
                h) targetHostFlag=true;targethostvalues+=("$OPTARG");;
                s) confighostFlag=true;confighost="$OPTARG";;
                a) alllogsFlag=true;;
                g) saltgrainsFlag=true;saltgrain+=("$OPTARG");;
                y) skipconfirmationFlag=true;;
                p) previewFlag=true;;
		q) queryflag=true;;
		l) runlocalFlag=true;;
		*) usage;;
                \?) usage;;
        esac
done

if [ $OPTIND -eq 1 ]; then usage ; fi


datestamp=`date '+%Y%m%d%H%M%S'`
localbasedir="/tmp/mcpcollect"
localtargetdir="$localbasedir/$confighost/$datestamp"
keystonercv3="/root/keystonercv3"
keystonercv2="/root/keystonerc"
remotebasedir="/tmp/mcpcollect"
remotetargetdir="$remotebasedir/$datestamp"
green='\e[1;92m'
nocolor='\033[0m'
red='\e[1;31m'

function assignArrays {
	component=$1

	### For empty arrays, i.e.: no commands in the cmd array, do not put an empty space ("") leave the array empty.   For example use : cmd=(), Do not use cmd=("").

	declare -g generalCmd=(		"uname -a"\
					"df -h" \
					"mount" \
					"du -h --max-depth=1 /" \
					"lsblk" \
					"free -h"\
					"ifconfig"\
					"ps au --sort=-rss"\
					"salt-call pkg.list_pkgs versions_as_list=True" \
					"ntpq -p"\
				)
	declare -g generalCfg=(		"/etc/hosts"\
				)
	declare -g generalLog=(		"/var/log/syslog" \
				)
	declare -g generalSvc=()

	declare -g generalJct=()

	case $component in 
		ceph.mon)
			declare -g Cmd=(   	"ceph --version"                                       \
						"ceph tell osd.* version"                       \
						"ceph tell mon.* version"
						"ceph health detail"                            \
						"ceph -s"                                \
						"ceph df"                                       \
						"ceph mon stat"                 \
						"ceph pg dump | grep flags"                     \
						"ceph osd tree"                                 \
						"ceph osd getcrushmap -o /tmp/compiledmap; crushtool -d /tmp/compiledmap; rm /tmp/compiledmap" \
					)
			declare -g Log=(        "/var/log/ceph/"                        \
					)
			declare -g Svc=(        "ceph-mon"                                      \
						"ceph-mgr"                                      \
						"ceph"                                  \
					)
			declare -g Cfg=(        "/etc/ceph/"                                   \
					)
		;;
		ceph.osd)
			declare -g Cmd=(        "ceph --version"                                       \
						"ceph tell osd.* version"                       \
						"ceph tell mon.* version"
						"dmesg"         \
						"ps -ef | grep osd"
						"netstat -p | grep ceph"        \
						"df -h"  \
						"mount" \
						"lsblk" \
						"netstat -a | grep ceph"        \
						"netstat -l | grep ceph"        \
						"ls -altrn /var/run/ceph"       \
						"ceph osd stat"                 \
						"ceph osd dump | grep flags"            \
						"ceph health detail"                            \
						"ceph -s"                                \
						"ceph df"                                       \
						"ceph osd df"                           \
						"ceph osd perf"                         \
						"ceph pg dump"                                  \
						"ceph osd tree"                                 \
						"ceph osd getcrushmap -o /tmp/compiledmap; crushtool -d /tmp/compiledmap; rm /tmp/compiledmap" \
					)
			declare -g Log=(        "/var/log/ceph/"                        \
					)
			declare -g Svc=(        "ceph-mon"                                      \
						"ceph-mgr"                                      \
						"ceph"                                  \
					)
			declare -g Cfg=(        "/etc/ceph/"                                   \
					)
		;;
		ceph.radosgw)
			declare -g Log=(        "/var/log/ceph/"           \
					)
			declare -g Cfg=(        "/etc/ceph"                   \
					)
			declare -g Svc=(        "radosgw"                              \
					)
			declare -g Cmd=(                   \
					)
		;;

		cinder.volume)
			declare -g Log=(        "/var/log/cinder/"                         \
					)
			declare -g Cfg=(        "/etc/cinder/"                                 \
					)
			declare -g Svc=(        "cinder-volume"                        \
					)
			declare -g Cmd=(        "ls /var/lib/cinder/volumes"                    \
					)
		;;
		cinder.controller)
			declare -g Log=(        "/var/log/cinder/"                         \
					)
			declare -g Cfg=(        "/etc/cinder/"                                 \
					)
			declare -g Svc=(        "cinder-scheduler"                     \
						"cinder-volume"                        \
					)
			declare -g Cmd=(        "cinder list" \
					)
		;;
		docker.swarm)
			declare -g Log=(        "/var/log/docker/"           \
					)
			declare -g Cfg=(        "/etc/docker/"                   \
					)
			declare -g Svc=(        "dockerd"                              \
					)
			declare -g Cmd=(        "docker version"\
						"docker info"		\
					)
		;;
		elasticsearch.server)
			declare -g Log=(        "/var/log/elasticsearch/"           \
					)
			declare -g Cfg=(        "/etc/elasticsearch/"                   \
					)
			declare -g Svc=(        "elasticsearch"                              \
					)
			declare -g Cmd=(	"curl -X GET 'http://log01:9200/_cat/health?v'" \
						"curl -X GET 'http://log01:9200/_cat/indices?v'"\
					)

		;;
		fluentd.agent)
			declare -g Log=(        "/var/log/td-agent/"           \
					)
			declare -g Cfg=(        "/etc/td-agent/"                   \
					)
			declare -g Svc=(        "td-agent"                              \
					)
			declare -g Cmd=(       
					)

		;;
		haproxy.proxy)
			declare -g Log=(        "/var/log/haproxy*"         \
					)
			declare -g Cfg=(        "/etc/haproxy"                   \
					)
			declare -g Svc=(        "haproxy"                       \
					)
			declare -g Cmd=(        "haproxy -vv"           \
						"netstat -lntp"         \
						"echo 'show info;show stat;show pools' | nc -U /var/run/haproxy/admin.sock" \
					)
		;;
		horizon.server)
			declare -g Log=(        "/var/log/horizon/"                        \
						"/var/log/apache2/"
					)
			declare -g Svc=(        "apache2"                              \
					)
			declare -g Cmd=(        "netstat -nltp | egrep apache2"              \
					)
			declare -g Cfg=(        "/etc/apache2/"                                \
					)
		;;
		keystone.server)
			declare -g Log=(        "/var/log/keystone/" \
						"/var/log/apache2/"\
					)
			declare -g Cfg=(        "/etc/keystone/"                   \
						"/etc/apache2/" \
					)
			declare -g Svc=(        "apache2"                              \
					)
			declare -g Cmd=(        "netstat -nltp | grep apache2"           \
					)
		;;
		keystone.client)
			declare -g Log=(        "/var/log/keystone/"                       \
					)
			declare -g Cfg=(        "/etc/keystone/"                   \
					)
			declare -g Svc=(        "apache2"                              \
					)
			declare -g Cmd=(                                                      \
					)
		;;
		neutron.server)
			declare -g Log=(        "/var/log/neutron/"                            \
					)
			declare -g Cfg=(        "/etc/neutron/"         \
					)
			declare -g Svc=(        "neutron-openvswitch-agent"            \
					)
			declare -g Cmd=(        "neutron agent-list"                            \
					)
		;;
		ntp.client)
			declare -g Log=(        "/var/log/ntp.log"                \
					)
			declare -g Cfg=(        "/etc/ntp.conf"                   \
					)
			declare -g Svc=(        "ntpd"                              \
					)
			declare -g Cmd=(        "ntpq -p"           \
					)
		;;
		nova.compute)		               
			declare -g Cmd=(        "virsh list"                          \
						"ps -ef | grep libvirt" \
						"ps -ef | grep 'nova'"\
	#					"for x in \`virsh list | egrep -v 'Id|--' | awk '{print \$2}'\`; do echo \$x; virsh dumpxml \$x; done " \

					)
			declare -g Log=(        "/var/log/nova/"                           \
						"/var/log/libvirt/qemu/"			\
						"/var/log/syslog"	\
					)
			declare -g Svc=(        "nova-compute"                             \
					)

			declare -g Cfg=(        "/etc/nova/"                           \
						"/etc/libvirt/"
					)
		;;
		nova.controller)
			### Nova ###
			declare -g Cmd=(        "nova hypervisor-list"                          \
						"nova list --fields name,networks,host --all-tenants" \
						"nova service-list"\
					)
			declare -g Log=(        "/var/log/nova/"                           \
											       \
					)
			declare -g Svc=(        "nova-api"                             \
						"nova-conductor"                       \
						"nova-scheduler"                       \
					)

			declare -g Cfg=(        "/etc/nova/"                           \
					)

		;;
		rabbitmq.cluster | rabbitmq.server )
			declare -g Log=(        "/var/log/rabbitmq/"                \
					)
			declare -g Cfg=(        "/etc/rabbitmq/"                   \
					)
			declare -g Svc=(        "rabbitmq-server"               \
					)
			declare -g Cmd=(        "rabbitmqctl cluster_status"           \
						"rabbitmqctl status"    \
						"rabbitmqctl list_queues -p /openstack" \
						"rabbitmqctl list_queues -p /openstack messages consumers name" \
						"rabbitmqctl eval 'rabbit_diagnostics:maybe_stuck().'" \
					)
		;;

		reclass)
			### Reclas Model ###
			declare -a Cmd=("tar -zcvf reclass-$datestamp.tar.gz /var/salt/reclass $targetdir")
		;;
		telegraf.agent )
                        declare -g Jct=(        "journalctl -x -u telegraf --no-page"                \
						"journalctl -x -u otherone --no-page" \
					)
			declare -g Log=()
                        declare -g Cfg=(        "/etc/telegraf"			\
                                        )
                        declare -g Svc=(        "telegraf"                              \
                                        )
                        declare -g Cmd=(                  \
                                        )
		;;
		*)
			abortmessage+="no valid grains provided"
			abort
		;;

	esac
	Cmd=("${generalCmd[@]}" "${Cmd[@]}")
	Log=("${generalLog[@]}" "${Log[@]}")
	Cfg=("${generalCfg[@]}" "${Cfg[@]}")
	Svc=("${generalSvc[@]}" "${Svc[@]}")
}

function abortprompt {
	read -p " Do you want to continue? [y/n] " -n 1 -r
	echo -e "${nocolor}\n"
        if [[ $REPLY =~ ^[Yy]$ ]]
        then
		echo ""
	else
                exit
        fi
}

function info {
        echo ""
        echo -e "${green}Info message :"
        leninfo=${#infomessage[@]}
        for (( i=0; i<${leninfomessage}; i++ ));
        do
                printf '        %s\n' "${infomessage[$i]}"
        done
        echo -e "${nocolor}"
	infomessage=()
}

function warning {
        echo ""
        echo -e "${green}Warning message :"
	lenwarningmessage=${#warningmessage[@]}
        for (( i=0; i<${lenwarningmessage}; i++ ));
        do
                printf '        %s\n' "${warningmessage[$i]}"
        done
	echo -e "${nocolor}"
	warningmessage=()
}

function abort {
	echo -e "${red}"
	echo "Exiting with error(s):" 
	lenabortmessage=${#abortmessage[@]}
	for (( i=0; i<${lenabortmessage}; i++ ));
	do
		printf '        %s\n' "${abortmessage[$i]}"
	done
	echo -e "${nocolor}"
	abortmessage=()
	exit
}

function collectJournalCtl {
	journalCommand="mkdir -p $remotetargetdir/var/log;cd $remotetargetdir/var/log;"
	lenJct=${#Jct[@]}
                countJct=1
                for (( i=0; i<${lenJct}; i++ ));
                        do
				journalCommand+=$(echo ${Jct[$i]} | grep -o "\-u.*" | awk -v a="$targethost" -v b="$component" -v c="$datestamp" -v d="$remotetargetdir" -v e="${Jct[$i]}" '{print e"|gzip > "a"-journal-"$2"-"c".log.gz;"}')
                        done
			sshJournalCollectFiles='sudo salt "*'$targethost'*" cmd.run "'$journalCommand'"'

        if [ $runlocalFlag ]; then
                ssh -q -oStrictHostKeyChecking=no $confighost $sshJournalCollectFiles
        else
                eval $sshCollectFiles
        fi
        echo "   complete."


}

function collectFiles {
	collectType=$1
	echo "Collecting $component files ($collectType) from $targethost"
	tarname="$targethost-$component-files-$datestamp.tar.gz"
	localdestdir="$remotetargetdir/$targethost"
	if [ "$collectType" = "log" ]; then
		sourceFile=("${Log[@]}")
	elif [ "$collectType" = "cfg" ]; then
		sourceFile=("${Cfg[@]}")
	elif [ "$collectType" = "all" ]; then
		sourceFile=("`echo ${Cfg[@]} ${Log[@]}`")
	fi
	sshCollectFiles='sudo salt "*'$targethost'*" cmd.run "mkdir -p '$remotetargetdir';tar czf '$remotetargetdir'/'$tarname' '$sourceFile'";scp -o StrictHostKeyChecking=no -r '$targethostip':'$remotetargetdir'/'$tarname' '$localdestdir'/'

	if [ "${#sourceFile[@]}" > 0  ]; then
		if [ $runlocalFlag ]; then
			ssh -q -oStrictHostKeyChecking=no $confighost $sshCollectFiles
		else
			eval $sshCollectFiles
		fi
		echo "   complete."
	else 
		echo -e "${green} No files defined for collection in $component.${nocolor}\n"
	fi
}

function cleanTargethost {
	echo "Cleaning temproary files from $targethost,$component..."
	sshCleanTarget='sudo salt "*'$targethost'*" cmd.run "rm -fR '$remotebasedir'"'
	if [ $runlocalFlag ]; then
		ssh -q -oStrictHostKeyChecking=no $confighost $sshCleanTarget
	else
                eval $sshCleanTarget
        fi
	echo "   complete."
}

function cleanCfgHost {
        echo "Cleaning temporary files from $confighost,$component..."
        sshCleanCfg='rm -fR '$remotebasedir''
        	ssh -q -oStrictHostKeyChecking=no $confighost $sshCleanCfg
	echo "   complete."
}

function transferResultsCfg {
	echo "Transferring results from $targethost to $confighost,$component..."
	localdestdir="$remotetargetdir/$targethost"
	sshXferResultsCfg='mkdir -p '$localdestdir';scp -o StrictHostKeyChecking=no -r '$targethostip':'$remotetargetdir'/* '$localdestdir
	if [ $runlocalFlag ]; then
		ssh -q -oStrictHostKeyChecking=no $confighost $sshXferResultsCfg
	else
		eval $sshXferResultsCfg
	fi
	echo "   complete."
}


function getIpAddrFromSalt {
	host=$1
	echo "Getting IP address for $host from reclass..."
	sshgetipaddress="for x in \$(sudo salt '"*$host*"' network.ip_addrs|grep '-' | awk -F' - ' '{print \$2}' | sed 's/ //g');do ping -c1 \$x 2>&1 >/dev/null; if [ \$? = 0 ];  then echo \$x ;break;fi; done"
	targethostip=(`ssh -q -o StrictHostKeyChecking=no $confighost $sshgetipaddress`)
	echo "   complete"
	if [ $runlocalFlag ]; then
		targethostip=(`ssh -q -o StrictHostKeyChecking=no $confighost $sshgetipaddress`)
 	else	
		targethostip=$(eval $sshgetipaddress)
	fi
}

function collectReclass {
	echo "Collecting the reclass model..."
	localdestdir="$remotetargetdir/$targethost"
	tarname="reclass-$confighost.tar.gz"
	sshCollectReclass="mkdir -p $localdestdir;sudo /bin/tar -czf $localdestdir/$tarname /srv/salt/reclass/; sudo /bin/chown $USER.$USER $localdestdir/$tarname"
	if [ $runlocalFlag ]; then
		ssh -q -o StrictHostKeyChecking=no $confighost $sshCollectReclass
	else
		eval $sshCollectReclass
	fi
	echo "   complete."
}

function transferResultsLocal {
	#compress tmpdir and copy to localhost
        echo "Transferring $component results from $confighost to localhost..."
	localdestdir="$localtargetdir/$targethost"
	mkdir -p $localdestdir
	tarname="$targethost-$component-$datestamp.tar.gz"
	ssh -q -o StrictHostKeyChecking=no $confighost "cd $remotetargetdir/$targethost;tar -czf $tarname *"
	scp -q -o StrictHostKeyChecking=no -r $confighost:$remotetargetdir/$targethost/$tarname $localdestdir/
	echo "   complete."
}

function executeRemoteCommands {
	commandType=$1
	sshExecuteRemoteCommands="if [ -f $keystonercv3 ]; then . $keystonercv3; elif [ -f $keystonerc ] ; then . $keystonerc; fi;"
	declare -a remoteCmds
	if [ "$commandType" = "svc" ]; then
		remoteCmds=("${Svc[@]}")
		label="collect services results"
	elif [ "$commandType" = "cmd" ]; then
		remoteCmds=("${Cmd[@]}")
		label="collect command results"
	elif [ "$commandType" = "cli" ]; then
		remoteCmds=("${Cli[@]}")
		label="collect commands provided from cli (${Cli[@]})"
	fi

	### Exit function if array is emtpy
	if [ ${#remoteCmds[@]} = 0 ]; then 
		echo -e "${green} Array for type $commandType is empty.${nocolor}\n"
		return 1
	fi
	processinit=$(checkProcessInitialization)
                    
	echo "Executing commands to $label ($commandType) from $targethost"
        lenCmd=${#remoteCmds[@]}
	countCmd=1
	outputFooter="----------------------------"
        for (( i=0; i<${lenCmd}; i++ ));
        do
	outputHeader="@@@=========================================== ${remoteCmds[$i]} ==========================================="		
	if [ "$commandType" = "svc" ]; then
		if [ "$processinit" = "systemd" ]; then
			sshExecuteRemoteCommands+="echo $outputHeader;echo ;systemctl status '${remoteCmds[$i]}';echo;echo $outputFooter;echo"
		elif [ "$processinit" = "sysvinit" ]; then
			sshExecuteRemoteCommands+="echo $outputHeader;echo ;service '${remoteCmds[$i]}' status;echo;echo $outputFooter;echo"
		fi
	elif [ "$commandType" = "cmd" ]; then
		sshExecuteRemoteCommands+="echo $outputHeader;echo ;${remoteCmds[$i]}; echo;echo $outputFooter;echo"
	fi
	if [ $countCmd -lt $lenCmd ]; then
                        sshExecuteRemoteCommands+=";"
        fi
        	((countCmd++))

	done
	localdestdir="$remotetargetdir/$targethost"
	sshExecuteRemoteCommands='mkdir -p '$localdestdir'/output; sudo salt "*'$targethost'*" cmd.run "'$sshExecuteRemoteCommands'" > '$localdestdir'/output/'$targethost'-'$component'-'$commandType''
	if [ $runlocalFlag ]; then
		ssh -q -oStrictHostKeyChecking=no $confighost $sshExecuteRemoteCommands
	else
		eval $sshExecuteRemoteCommands
	fi
}
function checkProcessInitialization () {
	sshProcessInitialization='sudo salt "*'$targethost'*" cmd.run "if [ $(pidof init) ]; then echo sysvinit; fi;if [ $(pidof systemd) ]; then echo systemd; fi"| grep -v '$targethost''
	if [ $runlocalFlag ]; then
                result=$(ssh -q -oStrictHostKeyChecking=no $confighost $sshProcessInitialization) 
        else
                result=$(eval $sshProcessInitialization)
        fi
	echo $result 
}

function scrubArrays {

	 lenLog=${#Log[@]}
	 for (( i=0; i<${lenLog}; i++ ));
                do
                        if [ "${Log[$i]}" = " " ] ; then
                                unset Log[$i]
                        fi
                done
	lenCmd=${#Cmd[@]}
	for (( i=0; i<${lenCmd}; i++ ));
                do
                        if [ "${Cmd[$i]}" = " " ] ; then
                                unset Cmd[$i]
                        fi
                done
	lenSvc=${#Svc[@]}
	for (( i=0; i<${lenSvc}; i++ ));
                do
                        if [ "${Svc[$i]}" = " " ] ; then
                                unset Svc[$i]
                        fi
                done
	lenCfg=${#Cfg[@]}
	for (( i=0; i<${lenCfg}; i++ ));
                do
                        if [ "${Cfg[$i]}" = " " ] ; then
                                unset Cfg[$i]
                        fi
		done
	lenJct=${#Jct[@]}
        for (( i=0; i<${lenJct}; i++ ));
                do
                        if [ "${Jct[$i]}" = " " ] ; then
                                unset Jct[$i]
                        fi
                done

}


function getTargetHostByGrains() {
	grain=$1
	sshGetHostByGrains="sudo salt --out txt  '*' grains.item roles  | grep '$grain' | awk -F':' '{printf \$1 \" \" }'"
	if [ $runlocalFlag ]; then
		result=$(ssh -q $confighost $sshGetHostByGrains)
	else
		eval $sshGetHostByGrains
	fi
	echo $result
}

containsElement () {
  local e match="$1"
  shift
  for e; do [[ "$e" == *"$match"* ]] && return 0; done
  return 1
}

function hostsAssociatedWithSaltGrain {
	grain=$1
	echo "Collecting hosts associated with $grain.."
	grainhostvalues=($(getTargetHostByGrains "$grain"))
	if [ ${#grainhostvalues[@]} = 0 ]; then 
		abortmessage+=("$target host not found in grain $grain")

	fi
	
	if [ $targetHostFlag ]; then
		targethostloopvalues=()
		for x in ${targethostvalues[@]}
		do	
			containsElement "$x" "${grainhostvalues[@]}"
			containsElementResult=$?
	
			if [ $containsElementResult = 0 ]; then
				targethostloopvalues+=("$x")
			fi
		done
	else

		targethostloopvalues=(${grainhostvalues[@]})
	fi
        if [ ${#targethostloopvalues[@]} = 0 ]; then
		abortmessage+=("No provided host not found in grain $grain")
        fi


	}


function collect {
			targethost=$1
			component=$2

			echo "Collecting results for target host $targethost, $component"
                        echo "==========================================================="
			executeRemoteCommands "cmd"
                        executeRemoteCommands "svc"
                        collectFiles "all"
			collectJournalCtl
                        transferResultsCfg
			cleanTargethost
			collectReclass
			if [ $runlocalFlag ]; then
	                        transferResultsLocal
        	                cleanCfgHost	
			fi

                        echo "Collection complete for $targethost"
                        echo "-----"
                        echo ""

}


function main {
	
# assignArrays "$component"
#        scrubArrays
#        journalstring=$(printf '%s > %s/%s'"${Log[@]}" "$remotetargetdir" "somelog.zip" | cut -d ";" -f 1-${#Log[@]})
#        echo $journalstring
#        exit

	targethostloopvalues=(${targethostvalues[@]});

	if [ "$confighost" != "" ]; then
		if [ ! -d "$localtargetdir" ]; then
			mkdir -p $localtargetdir
			### Check for error creating directory
		fi
	fi

	if [ ! $confighostFlag ] && [ $runlocalFlag ];  then
		echo " USAGE ERROR  -s is a required switch"
		usage
	fi

        if [ ${#componentvalues[@]} = 0 ] && [ ${#saltgrain[@]} != 0 ]; then
                componentvalues=(${saltgrain[@]})
        fi

	for y in ${componentvalues[@]};
        do
		component=$y
		if [ $saltgrainsFlag ]; then
			hostsAssociatedWithSaltGrain "$component"
		fi

		if [ ${#infomessage[@]} != 0 ]; then
			info
		fi

		if [ ${#warningmessage[@]} != 0 ]; then
			warning
		fi
		if [ ${#abortmessage[@]} != 0 ]; then
			abort
		fi

		if [ ${#componentvalues[@]} = 0 ] && [ ${#saltgrain[@]} != 0 ]; then
			componentvalues=(${saltgrain[@]})

		fi
		if [ $previewFlag ] || [ $skipconfirmationFlag ] ; then
			noconfirm=true
		fi
		assignArrays "$component"
		scrubArrays
		logWildCards
		componentSummary
		for x in ${targethostloopvalues[@]}; 
		do

			targethost=$x
			component="$y"
			assignArrays "$component"
			scrubArrays
                	logWildCards
			if [ ! $previewFlag ]; then
				if [ "$targethostIP" = "" ]; then
					getIpAddrFromSalt $targethost
				fi
				collect $targethost $component 
			fi
			

		done
	done

}

function logWildCards() {
# Manipulate the Log array for all logs or not
	if [ ! $alllogsFlag  ]; then
        	lenLog=${#Log[@]}
                countLog=1
                for (( i=0; i<${lenLog}; i++ ));
                	do
				if [ "${Log[$i]: -1}" = "/" ]; then
					Log[$i]+="*.log"
				fi
                        done

	fi
}

parseArrays () {
	case $1 in 
		cmd) 
			if [ "${#Cmd[@]}" = "0" ]; then
				string="<none>"
			else
				string=$(printf '%s, ' "${Cmd[@]}" | cut -d "," -f 1-${#Cmd[@]})
			fi
		;;
		log)
                        if [ "${#Log[@]}" = "0" ]; then
                                string="<none>"
                        else
				string=$(printf '%s, ' "${Log[@]}" | cut -d "," -f 1-${#Log[@]})
			fi
		;;
		svc)
			if [ "${#Svc[@]}" = "0" ]; then
                                string="<none>"
                        else
				string=$(printf '%s, ' "${Svc[@]}"| cut -d "," -f 1-${#Svc[@]})
			fi
		;;
		cfg)
			if [ "${#Cfg[@]}" = "0" ]; then
                                string="<none>"
                        else
				string=$(printf '%s, ' "${Cfg[@]}"| cut -d "," -f 1-${#Cfg[@]})
			fi
		;;
		jct)
                        if [ "${#Jct[@]}" = "0" ]; then
                                string="<none>"
                        else
                                string=$(printf '%s, ' "${Jct[@]}"| cut -d "," -f 1-${#Jct[@]})
                        fi
                ;;

	esac
	echo $string
}

function componentSummary () {
	echo ""
	printf 'Summary for component : %s\nOutput  : %s\n' "$component" "$localtargetdir"
	printf '%s' "Hosts : "
	printf '%s, ' "${targethostloopvalues[@]}"| cut -d "," -f 1-${#targethostloopvalues[@]}
	printf '%s \n' "====================================================="
	printf '%s %s\n' "Commands    :" "$(parseArrays cmd)"
	printf '%s %s\n' "Log Files   :" "$(parseArrays log)"
	printf '%s %s\n' "Journalctl  :" "$(parseArrays jct)"
	printf '%s %s\n' "Services    :" "$(parseArrays svc)"
	printf '%s %s\n' "Configs     :" "$(parseArrays cfg)"
	printf '%s \n' "-----------------------------------------------------"
	echo ""
	if [ ! $noconfirm ]; then
		abortprompt
	fi 
}



main


