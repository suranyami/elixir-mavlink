# MAVLink

_Work in Progress_

A Mix task to generate code from a MAVLink xml definition file, and an
application that enables communication with other systems using the
MAVLink 1.0 or 2.0 protocol over serial, UDP and TCP connections.

MAVLink is a Micro Air Vehicle communication protocol used by Pixhawk,
Ardupilot and other leading autopilot platforms. For more information
on MAVLink see https://mavlink.io.

This library is not officially recognised or supported by MAVLink at this
time. We aim over time to achieve complete compliance with the MAVLink 2.0
specification, but our initial focus is on using this library on companion
computers and ground stations for our team entry in the
2020 UAV Outback Challenge https://uavchallenge.org/medical-rescue/.

## Testing locally with Ardupilot, MavProxy, SITL and X-Plane

It's possible to use SITL with X-Plane:

http://ardupilot.org/dev/docs/sitl-with-xplane.html

### Install dependencies:

<!-- Install Python 3:

```
brew install python
``` -->

Ensure the above version overrides the built-in Python 2 in macOS, by adding this
to the end of your `.zshrc` or `.bash_profile`:

```
export PATH="/usr/local/opt/python/libexec/bin:$PATH"
```

Verify with: `python --version`.

Remove this incompatible library:

```
sudo pip uninstall python-dateutil
```

### Install MavProxy

```
sudo pip install wxPython
sudo pip install gnureadline
sudo pip install billiard
sudo pip install numpy pyparsing
sudo pip install MAVProxy
```

### Ardupilot

Install Ardupilot dependencies:

```
brew tap ardupilot/homebrew-px4
brew install genromfs
brew install gcc-arm-none-eabi
brew install gawk
```

Download Ardupilot:

```
git clone git@github.com:ArduPilot/ardupilot.git
```

Build Ardupilot for macOS:

```
brew uninstall binutils
cd ardupilot
./Tools/environment_install/install-prereqs-mac.sh
```

Configure Ardupilot for SITL:

./waf configure --board sitl

And run Arducopter:

```
cd ardupilot/ArduCopter
cd ArduCopter
sim_vehicle.py -w
```

Start X-Plane and set up the data export settings per web page, then run arduplane and mavproxy

mavproxy.py --master=tcp:127.0.0.1:5760 --out 127.0.0.1:14550

Then
mix run scripts/listen.exs
will receive messages
Two advantages of using mavproxy

1. The TCP output from arduplane is unusual - serial or UDP is more common and we don’t need our library to understand TCP yet (maybe later)
2. mavproxy is build on pymavgen which is pretty much a reference implementation of Mavlink, so if it understands a message from us or arduplane, it’s a proper Mavlink message
   I have a problem with how to test the generated file. You can see the weird macro stuff I did in listen to compile from outside of lib. I’m sure there is a proper way to do this
   Let me check now to see how easy it is to do the same with X-Plane 11
   Robin Hilliard 9:26 PM
   With your real hardware you would still use mavproxy, you would set your arducopter to send UDP to mavproxy
   Let me check this X-Plane 11 thing then I’ll remind myself how to listen to real hardware
   Robin Hilliard 9:38 PM
   Got it going with X-Plane 11
   Screen Shot 2019-07-27 at 9.38.12 pm.png
   Screen Shot 2019-07-27 at 9.38.12 pm.png

Network/Data settings in X-Plane 11
3 files
Screen Shot 2019-07-27 at 9.40.29 pm.png

Screen Shot 2019-07-27 at 9.40.24 pm.png

Screen Shot 2019-07-27 at 9.39.22 pm.png

Note I turned off broadcast to mapping apps
Had to do two shots of the data screen to get the last three outputs - index 39 is the last
Now to receive from my hardware
First thing is to stop SITL
Robin Hilliard 9:51 PM
My arduplane on my pi was already set up like this in /etc/default/arduplane
Screen Shot 2019-07-27 at 9.50.38 pm.png
Screen Shot 2019-07-27 at 9.50.38 pm.png

It was already sending UDP direct to our listen script on port 14550
However with plane 3.9.8 I get
???: UNKNOWN FRAME {:udp, #Port<0.4>, {192, 168, 0, 10}, 41015, "GPIO_Sysfs: Unable to get value file descriptor for pin 4.\r\nGPIO_Sysfs: Unable to write pin 16 value.\r\nGPIO_Sysfs: Unable to get value file descriptor for pin 4.\r\nGPIO_Sysfs: Unable to write pin 16 value.\r\n"}
???: UNKNOWN FRAME {:udp, #Port<0.4>, {192, 168, 0, 10}, 41015, "GPIO_Sysfs: Unable to get value file descriptor for pin 4.\r\nGPIO_Sysfs: Unable to write pin 16 value.\r\nGPIO_Sysfs: Unable to get value file descriptor for pin 4.\r\nGPIO_Sysfs: Unable to write pin 16 value.\r\n"}
mixed in with the mavlink messages. This is a Navio bug currently being investigated (see https://community.emlid.com/t/arducopter-spams-gpio-related-mavlink-messages/14322/9)
Community ForumCommunity Forum
Arducopter spams GPIO related mavlink messages
Can I ask you to try with 3.6.5, @mkarklins @iain @robinhilliard?
Jul 11th
Only thing with X-Plane 11 is there are no model aircraft. I will use the Stinson for now as it is similar to a full size Decathlon
Sunday, July 28th
Robin Hilliard 9:51 AM
Just in case you missed it, there is a multicopter simulator built in to ardupilot for SITL http://ardupilot.org/dev/docs/sitl-simulator-software-in-the-loop.html http://ardupilot.org/dev/docs/copter-sitl-mavproxy-tutorial.html
X-Plane still useful - we should be able to set up a way to visualise the quad in X-Plane, and maybe even simulate the air launch
Robin Hilliard 10:00 AM
We can model a shed in X-Plane, send positions from your sim to X-Plane and X-Plane can be the view of what you see through the camera
For practicing remote control via camera
We can even delay sending the position to simulate video lag
Was thinking for your remote commands if camera could pitch up and down we could set up point-and-move control - point camera in direction you want to go, then say move x-metres in that direction
Maybe have LIDAR next to camera, also pitching. Then it would give you range, and it could override any movement that brought you closer than the LIDAR had measured
All this navigation mode would have to do is a little trig to work out a new waypoint, then direct to the waypoint
For yaw, yaw the copter
Robin Hilliard 10:32 AM
Team pilots will need to join Hawkesbury Model Air Sports: https://www.hmasinc.com.au/join-us. Note the joining cost includes MAAA membership which includes insurance
hmasinc.com.auhmasinc.com.au
Join Us - Radio Control Flying Club Sydney
Hawkesbury Model Air Sports Inc.

## to kill emlid noise bug in mavproxy:

```
set shownoise False
```

Which can also be added to `~/.mavinit.scr` to run every time `mavproxy.py` runs.

# Testing against real message definition files

```
git clone  git@github.com:mavlink/mavlink.git
```

The message definitions live in:

```
message_definitions/v1.0
```

mkdir message_definitions

cp ../mavlink/message_definitions/v1.0/\* message_definitions

mix mavlink message_definitions/ardupilotmega.xml lib/apm.ex APM
Warning: assuming ekf_status_flags is a bitmask although display="bitmask" not set

- creating lib/apm.ex
  Generated APM in 'lib/apm.ex'.
