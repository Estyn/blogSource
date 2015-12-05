---
title: "Using Geny Motion for Xamarin Android Development in a VM"
date: 2014-01-15
comments: true
categories: [Xamarin,Android, Genymotion]
tags: [test]
keywords: "Virtual Box, VM Ware, Hyper-v, emulator, networking"  

---
I've been doing a fair bit of android development using the Xamarin to allow me to code in c#.  I personally like to do all of my development in a virtual machine which allows me to have separate environments for different project.  This works well for most development, but for mobile development it posses some challenges when trying to run emulators.
<!--more-->

I had been using VMWare to virtualize my development and a nexus 4 for testing.  I was also using the android emulators, but as most android developers know they run very slow.  I hear about [Genymotion](http://www.genymotion.com/) which is a super face android emulator.  It uses [VirtualBox](http://www.virtualbox.org/) to host the android vm, unfortunately VirtualBox [does not recomend](http://www.virtualbox.org/manual/ch10.html#hwvirt) running VirtualBox and VMWare at the same time.  Luckily moving the VMWare VM to VirtualBox is as simple as opening the VM with VirtualBox, no conversion needed.

Getting Genymotion working is fairly simple.  Follow the regular instructions to install Genymotion, once it installed we need to configure debugging on the development VM to point to the Genymotion VM.

First start you Genymotion machine, and open the Genymotion Configuration app to determine the IP address of the emulator.  In my case it was 192.168.56.101.

Now in the development machine you will need to run adb.exe (C:\Users\Administrator\AppData\Local\Android\android-sdk\platform-tools\adb.exe) from the command prompt.

     .\adb.exe connect 192.168.56.101
You should see connected to 192.168.56.101 if everything worked correctly.  If you don't see that you will need to check your networking setting on you VM and on Genymotion.  In my case I configured both as NAT.

If you have both machines configured as NAT and you want to be able to access a service hosted on your dev machine from either your host of the emulator you will need to configure your development VM network's port forwarding.  Figure out your dev vm's ip address (10.0.2.15 in my case) then create your port forwarding rule.

- Name: MyRule 
- Protocol: TCP 
- HostIP: 127.0.0.1
- Host Port: 88
- Guest IP 10.0.2.15
- Guest Port: 88

Now you should be setup for development in your VM with a nice fast emulater running on your host.