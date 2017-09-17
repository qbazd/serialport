SerialPort libev integration example
====================================

Linux experiment going towards async IO processing based on libev
----------------------------------

WHY?
----

It is not straight forward how to use multiple IO sources (TCP,UDP,file,serialport,joystick,keyboard,mouse,other, GUI) at the same time. 

There are many approches: signals, threads, select, epoll, kqueues, libevent, libev, libuv, ...
After experimenting with some of these libev was choosen [http://software.schmorp.de/pkg/libev.html](http://software.schmorp.de/pkg/libev.html)

Libuv is also vital alternative, but I was unable to integrate serial device. As it would require to implement serialport inside libuv.

Vibe.d is nice (using libevent2) but total no go due to DMD is not working on ARM (which is needed).

D like implementation using deimos.ev is based on [https://gist.github.com/jpf91/1519658](https://gist.github.com/jpf91/1519658).


D example features
------------------

Example is using serialport on /dev/ttyUSB0 @115200 buad.
With loopback test (RX-TX connection). Example works with plugging and unplugging USB serialport while running.

Striped down, working C draft of the goal
-----------------------------------------

~~~

int open_serial(char * dev_name, baud){...};
int close_serial(int fd){...};

ev_io serial_watcher;
int serial_fd = -1;

static void
serial_cb (EV_P_ ev_io *w, int revents)
{
    if (revents & EV_READ){
      char buf[2048];
      int res;
      res = read(serial_fd,buf,2048);
      // it is important to check for serial port disconnection
      if (res == 0 ) {
        ev_io_stop(&serial_watcher);
        close_serial(serial_fd);
        serial_fd = -1;
      } else {
        // ... do whatever you like here with data
      }
   }
}

int
main (void)
{

 struct ev_loop *loop = EV_DEFAULT;
 serial_fd = open_serial("/dev/ttyACM0", 115200); // get filedescriptor

 ev_io_init (&serial_watcher, serial_cb, serial_fd, EV_READ);
 ev_io_start (loop, &serial_watcher);
 ev_run (loop, 0);

 return 0;
}

~~~



