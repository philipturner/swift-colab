import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let interactiveshell = Python.import("IPython.core.interactiveshell")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let traitlets = Python.import("traitlets")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")

fileprivate let InteractiveShellABC = interactiveshell.InteractiveShellABC
fileprivate let Session = session.Session
fileprivate let Instance = traitlets.Instance
fileprivate let ZMQInteractiveShell = zmqshell.ZMQInteractiveShell

// Caller side: use `ctypes` to convert return value, which is the address of a
// Python object, into an actual Python object. This Swift file stores a
// reference to the return value's object so that it doesn't deallocate.
@_cdecl("create_shell")
public func create_shell(
  _ username_ptr: UnsafePointer<CChar>,
  _ sessionID_ptr: UnsafePointer<CChar>, 
  _ key_ptr: UnsafePointer<CChar>
) -> Int64 {
  InteractiveShellABC.register(SwiftShell)
  
  let username = String(cString: username_ptr)
  let sessionID = String(cString: sessionID_ptr)
  let key = String(cString: key_ptr).pythonObject.encode("utf8")
  
  let socket = CapturingSocket()
  let session = Session(username: username, session: sessionID, key: key)
  let shell = SwiftShell.instance()
  shell.display_pub.session = session
  shell.display_pub.pub_socket = socket
  
  socketAndShell = [socket, shell]
  return Int64(Python.id(socketAndShell))!
}

fileprivate var socketAndShell: PythonObject!

// Simulates a ZMQ socket, saving messages instead of sending them. We use this 
// to capture display messages.
fileprivate let CapturingSocket = PythonClass(
  "CapturingSocket",
  superclasses: [],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      `self`.messages = []
      return Python.None
    },
    
    "send_multipart": PythonInstanceMethod { args, kwargs in
      let `self` = args[0]
      let msg = args[1]
      `self`.messages[dynamicMember: "append"](msg)
      return Python.None
    }
  ]
).pythonObject

// An IPython shell, modified to work within Swift.
fileprivate let SwiftShell = PythonClass(
  "SwiftShell",
  superclasses: [ZMQInteractiveShell],
  members: [
    "kernel": Instance(
      "ipykernel.inprocess.ipkernel.InProcessKernel", allow_none: true),
    
    // Enable GUI integration for the kernel.
    "enable_gui": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      `self`.active_eventloop = gui
      return Python.None
    }
    
    // If the normal `enable_matplotlib` is called, it might freeze while importing `matplotlib_inline.backend_inline`.

    // Enable matplotlib integration for the kernel.
    "enable_matplotlib": PythonInstanceMethod { 
      args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = args[0].kernel.gui
      }
//       print("hello world 7")
//       return try ZMQInteractiveShell.enable_matplotlib.throwing
//         .dynamicallyCall(withArguments: [`self`, gui])
      
//       // TODO: Make these lines 80 characters
      print("checkpoint 1.1.1")
      let backend_inline = Python.import("matplotlib_inline").backend_inline
      print("checkpoint 1.3")
      let configure_inline_support = backend_inline.configure_inline_support
      print("checkpoint 1.5")
      let pt = Python.import("IPython.core.pylabtools")
      var backend = Python.None
      print("checkpoint 2")
      (gui, backend) = pt.find_gui_and_backend(gui, `self`.pylab_gui_select).tuple2
      print("checkpoint 3")
      
      if gui != "inline" {
        print("uh oh...")
        return Python.None
      }
      print("checkpoint 4")
      pt.activate_matplotlib(backend)
      print("checkpoint 5")
      configure_inline_support(`self`, backend)
      print("checkpoint 6")
      
      `self`.enable_gui(gui)
      print("checkpoint 7")
      `self`.magics_manager.registry["ExecutionMagics"].default_runner = pt.mpl_runner(`self`.safe_execfile)
      print("checkpoint 8")
      return PythonObject(tupleOf: gui, backend)
      
      
      
      
      def configure_inline_support(shell, backend):
    """Configure an IPython shell object for matplotlib use.

    Parameters
    ----------
    shell : InteractiveShell instance

    backend : matplotlib backend
    """
    # If using our svg payload backend, register the post-execution
    # function that will pick up the results for display.  This can only be
    # done with access to the real shell object.

    cfg = InlineBackend.instance(parent=shell)
    cfg.shell = shell
    if cfg not in shell.configurables:
        shell.configurables.append(cfg)

    if backend == 'module://matplotlib_inline.backend_inline':
        shell.events.register('post_execute', flush_figures)

        # Save rcParams that will be overwrittern
        shell._saved_rcParams = {}
        for k in cfg.rc:
            shell._saved_rcParams[k] = matplotlib.rcParams[k]
        # load inline_rc
        matplotlib.rcParams.update(cfg.rc)
        new_backend_name = "inline"
    else:
        try:
            shell.events.unregister('post_execute', flush_figures)
        except ValueError:
            pass
        if hasattr(shell, '_saved_rcParams'):
            matplotlib.rcParams.update(shell._saved_rcParams)
            del shell._saved_rcParams
        new_backend_name = "other"

    # only enable the formats once -> don't change the enabled formats (which the user may
    # has changed) when getting another "%matplotlib inline" call.
    # See https://github.com/ipython/ipykernel/issues/29
    cur_backend = getattr(configure_inline_support, "current_backend", "unset")
    if new_backend_name != cur_backend:
        # Setup the default figure format
        select_figure_formats(shell, cfg.figure_formats, **cfg.print_figure_kwargs)
        configure_inline_support.current_backend = new_backend_name
      
      
      
//       return Python.None
    },
    
//     Enable pylab support at runtime.
    "enable_pylab": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      try ZMQInteractiveShell.enable_pylab.throwing
        .dynamicallyCall(withArguments: `self`, gui)
      return Python.None
    }
  ]
).pythonObject

func configure)n
