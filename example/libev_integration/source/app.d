// example libev + serialport 

import libev;

import std.stdio;
import std.random;
import std.format;

import serialport;

// serial libev warper
class SerialEV {

  EventIO _eio;
  SerialPort _serial;
  string _name;
  int _baud;
  EventLoop _loop;

  this(EventLoop loop, string dev_file, int baud){
    _name = dev_file;
    _baud = baud;
    _loop = loop;
  }

  @property bool running(){
    return _eio !is null;
  }

  void start(){
    if (_serial !is null && !_serial.closed) stop();
    
    try 
      _serial = new SerialPort(_name, _baud);
    catch (SerialPortException e)
      return;

    _eio = new EventIO(_loop, _serial.handle, &this.onRead, null);
    _eio.start();
    writeln(_name, " openned");
  }

  void stop(){
    if (_eio !is null) _eio.stop();
    if (_serial !is null) _serial.close();
    _serial = null;
    _eio = null;
    writeln(_name, " closed");
  }

  void onRead(EventIO evio){
    void[256] data = void;
    void[] tmp;
    try {
      tmp = _serial.read(data);
      writeln(_name, ": ",tmp.length, ">", cast(char[])tmp,"<");
    }
    catch (SerialPortException e)
    {
      this.stop();
    }
  }

  void write(void[] data){
    if (_serial !is null)
      _serial.write(data);
  }

}


void main()
{

  int count = 0;

  auto loop = EventLoop.defaultLoop;
  auto serial1 = new SerialEV(loop, "/dev/ttyUSB0", 115200);

  // reestablish connection
  void checkConnections(Timer timer)
  {
    if(serial1._serial is null || serial1._serial.closed()){
      serial1.start();
    } 
  }

  Timer check_connection_timer = new Timer(loop, 0.0, 0.1, &checkConnections);
  check_connection_timer.start();


  // send some data
  void onTimer(Timer timer)
  {
    count++;

    writefln("send %s times", count);

    // sync write
    serial1.write(cast(void[])"test %d\n".format(count) );

    if(count == 100){
      timer.stop();
      serial1.stop();
      loop.doBreak(1);
    }
  }

  Timer writer = new Timer(loop, 0.0, 0.1, &onTimer);
  writer.start();

  loop.run();

  writeln("program exited normally");
}