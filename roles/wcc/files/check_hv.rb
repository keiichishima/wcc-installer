#!/usr/bin/env ruby
APP_PATH = File.expand_path('../../config/application',  __FILE__)
require File.expand_path('../../config/boot',  __FILE__)
require 'rails/commands'
require 'libvirt'
require 'timeout'
require 'socket'

def set_vms_unknown(hv_id)
  @vms = Vm.find(:all, :conditions => "hv_id=#{hv_id} AND state!=5")
  @vms.each do |vm|
    vm.state = 4
    vm.save!
    puts "DEBUG : State of VM #{vm.id} is changed to UNKNOWN"
  end
end

def get_vm_status(hv)
  virsh_vms = Array.new

  res = `cmd('list', hv.name)`
  res2 = res.split("\n")
  res2.each do |re|
    val = re.split(" ")
    uuid_len = val[1].size rescue 0
    if uuid_len == 36
      if val[2] == "running"
        virsh_vms << [ val[1], 2 ]     ## RUNNING
      elsif val[2] == "shut"
        virsh_vms << [ val[1], 1 ]     ## STOP
      elsif val[2] == "paused"
        virsh_vms << [ val[1], 3 ]     ## PAUSE
      else
        virsh_vms << [ val[1], 4 ]     ## UNKNOWN
      end
    end
  end

  virsh_vms.each do |re|
    vm = Vm.where(:hv_id => hv.id).where(:uuid => re[0]).where("state != ?", 5).first
    unless vm.blank?
      puts "DEBUG : State of VM #{vm.id}, #{vm.uuid} is changed to #{re[1]}"
      vm.state = re[1].to_i
      vm.save!
    end
  end
end

def pingecho(host, timeout=5, service="echo")
  begin
    timeout(timeout) do
      s = TCPSocket.new(host, service)
      s.close
    end
  rescue Errno::ECONNREFUSED
    return true
  rescue   Timeout::Error, StandardError 
    return false 
  end
  return true
end

def cpu_usage(hv)
  result = `/usr/bin/ssh www-data@#{hv} cat /proc/stat`
  res = result.split("\n")
  return res[0].split(" ")
end

@hvs = HyperVisor.find(:all, :conditions => 'hvtype=1')
@hvs.each do |hv|
  puts "DEBUG : Ping to #{hv.name}..."
  prevstatus = hv.status rescue 2
  res = pingecho(hv.ipaddress, 3, "ssh")
  if res == true
    hv.status = 0    ## UP
  elsif res == false
    hv.status = 1    ## DOWN
    set_vms_unknown(hv.id)
  else
    hv.status = 2    ## UNKNOWN
    set_vms_unknown(hv.id)
  end

  if hv.status == 0
    begin
      puts "DEBUG : Connecting to #{hv.name}..."
      timeout(30) {
        conn = Libvirt::open("qemu+tls://#{hv.name}/system")
        hv.vm_num = conn.num_of_domains

        if prevstatus != hv.status
          get_vm_status(hv)
        end
        conn.close
      }

    rescue Timeout::Error
      puts "DEBUG : Connecting to #{hv.name} is timeout."
      hv.status = 2  ## UNKNOWN
      set_vms_unknown(hv.id)

    rescue 
      puts "DEBUG : Connecting to #{hv.name} is refused."
      hv.status = 2  ## UNKNOWN
      set_vms_unknown(hv.id)
    end

    puts "DEBUG : Connecting(SSH) to #{hv.name}..."
    result  = `/usr/bin/ssh www-data@#{hv.name} landscape-sysinfo --sysinfo-plugins=Memory`
    result2 = `/usr/bin/ssh www-data@#{hv.name} landscape-sysinfo --sysinfo-plugins=Load`

    cpu1 = cpu_usage(hv.name)
    sleep 3
    cpu2 = cpu_usage(hv.name)
    total = cpu2[1].to_i - cpu1[1].to_i + cpu2[2].to_i - cpu1[2].to_i + cpu2[3].to_i - cpu1[3].to_i + cpu2[4].to_i - cpu1[4].to_i
    cpu_usage = 100.0 - (1.0 * (cpu2[4].to_i - cpu1[4].to_i) / total * 100.0)
    hv.cpu_usage = cpu_usage.to_i
    print "DEBUG : CPU usage: #{sprintf("%d",cpu_usage.to_i)}%\n"

    result3 = `/usr/bin/ssh www-data@#{hv.name} cat /etc/lsb-release | grep DISTRIB_RELEASE`
    hv.osver = result3.sub(/DISTRIB_RELEASE=(.*)\s*/, '\1')
    print "DEBUG : OS Version : #{hv.osver}\n"

    if result.split(" ")[0] == "Memory"
      hv.mem_usage = result.split(" ")[2].to(-2)
    else
      hv.mem_usage = nil
    end

    if result2.split(" ")[0] == "System"
      hv.cpu_load = result2.split(" ")[2].to_f * 100
    else
      hv.cpu_load = nil
    end
  end

  puts "DEBUG : #{hv.name} status is #{hv.status}"
  hv.save!
end
