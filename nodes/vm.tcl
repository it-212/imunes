#
# Copyright 2005-2013 University of Zagreb.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

# $Id: vm.tcl 63 2013-10-03 12:17:50Z valter $


#****h* imunes/vm.tcl
# NAME
#  vm.tcl -- defines vm specific procedures
# FUNCTION
#  This module is used to define all the vm specific procedures.
# NOTES
#  Procedures in this module start with the keyword vm and
#  end with function specific part that is the same for all the node
#  types that work on the same layer.
#****

set MODULE vm
registerModule $MODULE

################################################################################
########################### CONFIGURATION PROCEDURES ###########################
################################################################################

#****f* vm.tcl/vm.confNewNode
# NAME
#   vm.confNewNode -- configure new node
# SYNOPSIS
#   vm.confNewNode $node_id
# FUNCTION
#   Configures new node with the specified id.
# INPUTS
#   * node_id -- node id
#****
proc $MODULE.confNewNode { node_id } {
    global nodeNamingBase

    setNodeName $node_id [getNewNodeNameType vm $nodeNamingBase(vm)]
    setAutoDefaultRoutesStatus $node_id "enabled"

    set logiface_id [newLogIface $node_id "lo"]
    setIfcIPv4addrs $node_id $logiface_id "127.0.0.1/8"
    setIfcIPv6addrs $node_id $logiface_id "::1/128"
}

#****f* vm.tcl/vm.confNewIfc
# NAME
#   vm.confNewIfc -- configure new interface
# SYNOPSIS
#   vm.confNewIfc $node_id $iface_id
# FUNCTION
#   Configures new interface for the specified node.
# INPUTS
#   * node_id -- node id
#   * iface_id -- interface name
#****
proc $MODULE.confNewIfc { node_id iface_id } {
    autoIPv4addr $node_id $iface_id
    autoIPv6addr $node_id $iface_id
    autoMACaddr $node_id $iface_id
}

proc $MODULE.generateConfigIfaces { node_id ifaces } {
    set all_ifaces "[ifcList $node_id] [logIfcList $node_id]"
    if { $ifaces == "*" } {
	set ifaces $all_ifaces
    } else {
	# sort physical ifaces before logical ones (because of vlans)
	set negative_ifaces [removeFromList $all_ifaces $ifaces]
	set ifaces [removeFromList $all_ifaces $negative_ifaces]
    }

    set cfg {}
    foreach iface_id $ifaces {
	set cfg [concat $cfg [nodeCfggenIfc $node_id $iface_id]]

	lappend cfg ""
    }

    return $cfg
}

proc $MODULE.generateUnconfigIfaces { node_id ifaces } {
    set all_ifaces "[ifcList $node_id] [logIfcList $node_id]"
    if { $ifaces == "*" } {
	set ifaces $all_ifaces
    } else {
	# sort physical ifaces before logical ones
	set negative_ifaces [removeFromList $all_ifaces $ifaces]
	set ifaces [removeFromList $all_ifaces $negative_ifaces]
    }

    set cfg {}
    foreach iface_id $ifaces {
	set cfg [concat $cfg [nodeUncfggenIfc $node_id $iface_id]]

	lappend cfg ""
    }

    return $cfg
}

#****f* vm.tcl/vm.generateConfig
# NAME
#   vm.generateConfig -- configuration generator
# SYNOPSIS
#   set config [vm.generateConfig $node_id]
# FUNCTION
#   Returns the generated configuration. This configuration represents
#   the configuration loaded on the booting time of the virtual nodes
#   and it is closly related to the procedure vm.bootcmd.
#   For each interface in the interface list of the node, ip address is
#   configured and each static route from the simulator is added.
# INPUTS
#   * node_id -- node id
# RESULT
#   * config -- generated configuration
#****
proc $MODULE.generateConfig { node_id } {
    set cfg {}

    if { [getCustomEnabled $node_id] != true || [getCustomConfigSelected $node_id "NODE_CONFIG"] in "\"\" DISABLED" } {
	set cfg [concat $cfg [nodeCfggenStaticRoutes4 $node_id]]
	set cfg [concat $cfg [nodeCfggenStaticRoutes6 $node_id]]

	lappend cfg ""
    }

    set subnet_gws {}
    set nodes_l2data [dict create]
    if { [getAutoDefaultRoutesStatus $node_id] == "enabled" } {
	lassign [getDefaultGateways $node_id $subnet_gws $nodes_l2data] my_gws subnet_gws nodes_l2data
	lassign [getDefaultRoutesConfig $node_id $my_gws] all_routes4 all_routes6

	setDefaultIPv4routes $node_id $all_routes4
	setDefaultIPv6routes $node_id $all_routes6
    } else {
	setDefaultIPv4routes $node_id {}
	setDefaultIPv6routes $node_id {}
    }

    set cfg [concat $cfg [nodeCfggenAutoRoutes4 $node_id]]
    set cfg [concat $cfg [nodeCfggenAutoRoutes6 $node_id]]

    lappend cfg ""

    return $cfg
}

proc $MODULE.generateUnconfig { node_id } {
    set cfg {}

    set cfg [concat $cfg [nodeUncfggenStaticRoutes4 $node_id]]
    set cfg [concat $cfg [nodeUncfggenStaticRoutes6 $node_id]]

    lappend cfg ""

    set cfg [concat $cfg [nodeUncfggenAutoRoutes4 $node_id]]
    set cfg [concat $cfg [nodeUncfggenAutoRoutes6 $node_id]]

    lappend cfg ""

    return $cfg
}

#****f* vm.tcl/vm.ifacePrefix
# NAME
#   vm.ifacePrefix -- interface name prefix
# SYNOPSIS
#   vm.ifacePrefix
# FUNCTION
#   Returns vm interface name prefix.
# RESULT
#   * name -- name prefix string
#****
proc $MODULE.ifacePrefix {} {
    return "eth"
}

#****f* vm.tcl/vm.IPAddrRange
# NAME
#   vm.IPAddrRange -- IP address range
# SYNOPSIS
#   vm.IPAddrRange
# FUNCTION
#   Returns vm IP address range
# RESULT
#   * range -- vm IP address range
#****
proc $MODULE.IPAddrRange {} {
    return 20
}

#****f* vm.tcl/vm.netlayer
# NAME
#   vm.netlayer -- layer
# SYNOPSIS
#   set layer [vm.netlayer]
# FUNCTION
#   Returns the layer on which the vm communicates, i.e. returns NETWORK.
# RESULT
#   * layer -- set to NETWORK
#****
proc $MODULE.netlayer {} {
    return NETWORK
}

#****f* vm.tcl/vm.virtlayer
# NAME
#   vm.virtlayer -- virtual layer
# SYNOPSIS
#   set layer [vm.virtlayer]
# FUNCTION
#   Returns the layer on which the vm is instantiated i.e. returns VIRTUALIZED.
# RESULT
#   * layer -- set to VIRTUALIZED
#****
proc $MODULE.virtlayer {} {
    return VIRTUALIZED
}

#****f* vm.tcl/vm.bootcmd
# NAME
#   vm.bootcmd -- boot command
# SYNOPSIS
#   set appl [vm.bootcmd $node_id]
# FUNCTION
#   Procedure bootcmd returns the application that reads and employes the
#   configuration generated in vm.generateConfig.
#   In this case (procedure vm.bootcmd) specific application is /bin/sh
# INPUTS
#   * node_id -- node id
# RESULT
#   * appl -- application that reads the configuration (/bin/sh)
#****
proc $MODULE.bootcmd { node_id } {
    return "/bin/sh"
}

#****f* vm.tcl/vm.shellcmds
# NAME
#   vm.shellcmds -- shell commands
# SYNOPSIS
#   set shells [vm.shellcmds]
# FUNCTION
#   Procedure shellcmds returns the shells that can be opened
#   as a default shell for the system.
# RESULT
#   * shells -- default shells for the vm node
#****
proc $MODULE.shellcmds {} {
    return "csh bash sh tcsh"
}

#****f* vm.tcl/vm.nghook
# NAME
#   vm.nghook -- nghook
# SYNOPSIS
#   vm.nghook $eid $node_id $iface_id
# FUNCTION
#   Returns the id of the netgraph node and the name of the netgraph hook
#   which is used for connecting two netgraph nodes. This procedure calls
#   l3node.hook procedure and passes the result of that procedure.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#   * iface_id -- interface id
# RESULT
#   * nghook -- the list containing netgraph node id and the
#     netgraph hook (ngNode ngHook).
#****
proc $MODULE.nghook { eid node_id iface_id } {
    return [list $node_id-[getIfcName $node_id $iface_id] ether]
}

################################################################################
############################ INSTANTIATE PROCEDURES ############################
################################################################################

#****f* vm.tcl/vm.prepareSystem
# NAME
#   vm.prepareSystem -- prepare system
# SYNOPSIS
#   vm.prepareSystem
# FUNCTION
#   Does nothing
#****
proc $MODULE.prepareSystem {} {
    # nothing to do
}

#****f* vm.tcl/vm.nodeCreate
# NAME
#   vm.nodeCreate -- nodeCreate
# SYNOPSIS
#   vm.nodeCreate $eid $node_id
# FUNCTION
#   Creates a new virtualized vm node (using jails/docker).
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeCreate { eid node_id } {
    prepareFilesystemForNode $node_id
    createNodeContainer $node_id
}

#****f* vm.tcl/vm.nodeNamespaceSetup
# NAME
#   vm.nodeNamespaceSetup -- vm node nodeNamespaceSetup
# SYNOPSIS
#   vm.nodeNamespaceSetup $eid $node_id
# FUNCTION
#   Linux only. Attaches the existing Docker netns to a new one.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeNamespaceSetup { eid node_id } {
    attachToL3NodeNamespace $node_id
}

#****f* vm.tcl/vm.nodeInitConfigure
# NAME
#   vm.nodeInitConfigure -- vm node nodeInitConfigure
# SYNOPSIS
#   vm.nodeInitConfigure $eid $node_id
# FUNCTION
#   Runs initial L3 configuration, such as creating logical interfaces and
#   configuring sysctls.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeInitConfigure { eid node_id } {
    configureICMPoptions $node_id
}

proc $MODULE.nodePhysIfacesCreate { eid node_id ifaces } {
    nodePhysIfacesCreate $node_id $ifaces
}

proc $MODULE.nodeLogIfacesCreate { eid node_id ifaces } {
    nodeLogIfacesCreate $node_id $ifaces
}

#****f* vm.tcl/vm.nodeIfacesConfigure
# NAME
#   vm.nodeIfacesConfigure -- configure vm node interfaces
# SYNOPSIS
#   vm.nodeIfacesConfigure $eid $node_id $ifaces
# FUNCTION
#   Configure interfaces on a vm. Set MAC, MTU, queue parameters, assign the IP
#   addresses to the interfaces, etc. This procedure can be called if the node
#   is instantiated.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#   * ifaces -- list of interface ids
#****
proc $MODULE.nodeIfacesConfigure { eid node_id ifaces } {
    startNodeIfaces $node_id $ifaces
}

#****f* vm.tcl/vm.nodeConfigure
# NAME
#   vm.nodeConfigure -- configure vm node
# SYNOPSIS
#   vm.nodeConfigure $eid $node_id
# FUNCTION
#   Starts a new vm. Simulates the booting proces of a node, starts all the
#   services, etc.
#   This procedure can be called if it is instantiated.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeConfigure { eid node_id } {
    runConfOnNode $node_id
}

################################################################################
############################# TERMINATE PROCEDURES #############################
################################################################################

#****f* vm.tcl/vm.nodeIfacesUnconfigure
# NAME
#   vm.nodeIfacesUnconfigure -- unconfigure vm node interfaces
# SYNOPSIS
#   vm.nodeIfacesUnconfigure $eid $node_id $ifaces
# FUNCTION
#   Unconfigure interfaces on a vm to a default state. Set name to iface_id,
#   flush IP addresses to the interfaces, etc. This procedure can be called if
#   the node is instantiated.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#   * ifaces -- list of interface ids
#****
proc $MODULE.nodeIfacesUnconfigure { eid node_id ifaces } {
    unconfigNodeIfaces $eid $node_id $ifaces
}

proc $MODULE.nodeIfacesDestroy { eid node_id ifaces } {
    nodeIfacesDestroy $eid $node_id $ifaces
}

proc $MODULE.nodeUnconfigure { eid node_id } {
    unconfigNode $eid $node_id
}

#****f* vm.tcl/vm.nodeShutdown
# NAME
#   vm.nodeShutdown -- layer 3 node shutdown
# SYNOPSIS
#   vm.nodeShutdown $eid $node_id
# FUNCTION
#   Shutdowns a vm node.
#   Simulates the shutdown proces of a node, kills all the services and
#   processes.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeShutdown { eid node_id } {
    killExtProcess "wireshark.*[getNodeName $node_id].*\\($eid\\)"
    killAllNodeProcesses $eid $node_id
}

#****f* vm.tcl/vm.nodeDestroy
# NAME
#   vm.nodeDestroy -- layer 3 node destroy
# SYNOPSIS
#   vm.nodeDestroy $eid $node_id
# FUNCTION
#   Destroys a vm node.
#   First, it destroys all remaining virtual ifaces (vlans, tuns, etc).
#   Then, it destroys the jail/container with its namespaces and FS.
# INPUTS
#   * eid -- experiment id
#   * node_id -- node id
#****
proc $MODULE.nodeDestroy { eid node_id } {
    destroyNodeVirtIfcs $eid $node_id
    removeNodeContainer $eid $node_id
    destroyNamespace $eid-$node_id
    removeNodeFS $eid $node_id
}
