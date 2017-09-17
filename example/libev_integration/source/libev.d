///
module libev;

import deimos.ev;

import std.socket;
import std.typecons;
import std.exception;
import std.stdio;

/**
 * Reference-counted
 */
struct EventLoop
{
  private:
    struct Payload
    {
      ev_loop_t* _nativeLoop;
  
      this(ev_loop_t* ptr)
      {
        _nativeLoop = ptr;
      }
  
      ~this()
      {
        if (_nativeLoop !is null)  // Refcounted bug: dtor is being called for no reason before the ctor is called.
        {
          dispose();
        }
      }
  
      void dispose()
      {
        ev_loop_destroy(_nativeLoop);
        //_nativeLoop = null;
      }
  
      this(this) { assert(false); }
      void opAssign(EventLoop.Payload rhs) { assert(false); }
    }
  
    alias RefCounted!(Payload, RefCountedAutoInitialize.yes) Data;
    Data _data;

    this(ev_loop_t* ptr)
    {
      enforce(ptr, "Couldn't create EventLoop!");
      _data = Data(ptr);
    }

  public:
    this(uint flags)
    {
      auto ptr = ev_loop_new(flags);
      enforce(ptr, "Couldn't create EventLoop!");
      _data = Data(ptr);
    }

    /**
     * TODO: Should only be called from one thread! How to verify
     * that?
     */
    @property static EventLoop defaultLoop()
    {
      auto ptr = ev_default_loop(0);
      enforce(ptr, "Couldn't create EventLoop!");
      return EventLoop(ptr);
    }

    void fork()
    {
      ev_loop_fork(_data._nativeLoop);
    }

    @property bool isDefault()
    {
      return ev_is_default_loop(_data._nativeLoop) ? true : false;
    }

    @property ev_tstamp now()
    {
      return ev_now(_data._nativeLoop);
    }

    void suspend()
    {
      ev_suspend(_data._nativeLoop);
    }

    void resume()
    {
      ev_resume(_data._nativeLoop);
    }

    void run(uint flags = 0)
    {
      ev_run(_data._nativeLoop, flags);
    }

    /**
     * how = EVBREAK_ONE / EVBREAK_ALL
     */
    void doBreak(uint how)
    {
      ev_break(_data._nativeLoop, how);
    }

    void dispose()
    {
      _data.dispose();
    }

    @property ev_loop_t* nativePointer()
    {
      return _data._nativeLoop;
    }
}

private extern(C) void _nativeTimerCallback(ev_loop_t* cLoop, ev_timer* timer, int revent)
{
  Timer dTimer = cast(Timer)timer.data;
  assert(dTimer._loop.nativePointer == cLoop);
  dTimer.onTimer();
}

class Timer
{
  private:
    EventLoop _loop;
    ev_timer _nativeTimer;
    TimerCallback _callback;

  protected:
    void onTimer()
    {
      _callback(this);
    }

  public:
    alias void delegate(Timer) TimerCallback;

    this(EventLoop loop, ev_tstamp repeat, ev_tstamp repeat2, TimerCallback cb)
    {
      _loop = loop;
      _callback = cb;

      ev_timer_init(&_nativeTimer, &_nativeTimerCallback, repeat, repeat2);
      _nativeTimer.data = cast(void*)this;
    }

    void start()
    {
      ev_timer_start(_loop.nativePointer, &_nativeTimer);
    }

    void stop()
    {
      ev_timer_stop(_loop.nativePointer, &_nativeTimer);
    }

    @property EventLoop loop()
    {
      return _loop;
    }

    /**
     * TODO: Timer keeps a reference to EventLoop,
     * this method should remove this reference. Not sure if this works
     */
    void dispose()
    {
      if(_loop != EventLoop.init)
      {
        _loop = EventLoop.init;
      }
    }
}

private extern(C) void _nativeEventIORead(ev_loop_t* cLoop, ev_io* watcher, int revent)
{
  EventIO evIO = cast(EventIO)watcher.data;
  assert(evIO._loop.nativePointer == cLoop);
  evIO.onReadable();
}

private extern(C) void _nativeEventIOWrite(ev_loop_t* cLoop, ev_io* watcher, int revent)
{
  EventIO evIO = cast(EventIO)watcher.data;
  assert(evIO._loop.nativePointer == cLoop);
  evIO.onWriteable();
}

class EventIO
{
  private:
    EventLoop _loop;
    ev_io _nativeRead, _nativeWrite;
    int _fd ;
    EventIOCallback _read_callback, _write_callback;

  protected:
    void onReadable(){
      _read_callback(this);
    }

    void onWriteable(){
      _write_callback(this);
    }

  public:
    alias void delegate(EventIO) EventIOCallback;

    this(EventLoop loop, int fd, EventIOCallback read_callback, EventIOCallback write_callback)
    {
      _loop = loop;
      _fd = fd;

      if (read_callback != null) { 
        _read_callback = read_callback;
        ev_io_init(&_nativeRead, &_nativeEventIORead, _fd, EV_READ);
      }

      if (write_callback != null) { 
        _write_callback = write_callback;
        ev_io_init(&_nativeWrite, &_nativeEventIOWrite, _fd, EV_WRITE);
      }

      _nativeRead.data = cast(void*)this;
      _nativeWrite.data = cast(void*)this;
    }

    void start()
    {
      if(_read_callback != null)
        ev_io_start(_loop.nativePointer, &_nativeRead);
      
      if(_write_callback != null)
        ev_io_start(_loop.nativePointer, &_nativeWrite);
    }

    void stop()
    {
      ev_io_stop(_loop.nativePointer, &_nativeRead);
      ev_io_stop(_loop.nativePointer, &_nativeWrite);
    }

    @property EventLoop loop()
    {
      return _loop;
    }

    /**
     * TODO: Timer keeps a reference to EventLoop,
     * this method should remove this reference. Not sure if this works
     */
    void dispose()
    {
      if(_loop != EventLoop.init)
      {
        _loop = EventLoop.init;
      }
    }
}

